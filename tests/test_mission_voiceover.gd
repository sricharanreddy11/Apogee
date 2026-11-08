extends SceneTree
var _checks := 0
var _failures := 0
var _catalog := MissionCatalog.new()
var _config := RocketConfig.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_config.command_pod_id = "POD_A"
	var stage := StageConfig.new()
	stage.engine_id = "ENG_L"
	stage.tank_ids.assign(["TANK_L"])
	_config.stages.assign([stage, stage.copy()])
	_config.attachment_ids.assign(["LEGS", "DECOUPLER"])
	_test_ascent()
	_test_fuel()
	_test_landing()
	_test_results()
	await _test_playback()
	await _test_screens()
	print("Mission voiceover: %d checks, %d failures." % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _sample(values: Dictionary = {}) -> FlightTelemetry:
	var t := FlightTelemetry.new()
	t.body_id = "earth"
	t.status = FlightState.Status.FLYING
	t.fuel_remaining_kg = 100
	t.fuel_fraction = 1.0
	for key: String in values:
		t.set(key, values[key])
	return t

func _test_ascent() -> void:
	var rules := MissionVoiceRules.new()
	var mission := _catalog.load_mission("M01")
	rules.begin(mission, _config, _sample({"status": FlightState.Status.READY}))
	var calls := rules.observe(_sample({"elapsed_time_s": 10, "status": FlightState.Status.READY, "throttle": 1.0}))
	_check(not calls.has("ignition") and not calls.has("liftoff"), "Time and commanded throttle alone cannot confirm ignition or liftoff.")
	calls = rules.observe(_sample({"elapsed_time_s": 11, "altitude_m": 0.5, "radial_speed_mps": 1.0, "throttle": 0.4, "fuel_burned_kg": 0.5}))
	_check(calls.has("ignition") and not calls.has("liftoff"), "Measured fuel burn confirms ignition without claiming full thrust or airborne clearance.")
	calls = rules.observe(_sample({"elapsed_time_s": 12, "altitude_m": 2.0, "radial_speed_mps": 2.0, "throttle": 0.4, "fuel_burned_kg": 1.0}))
	_check(calls.has("liftoff") and not calls.has("ignition"), "Liftoff needs actual clearance and positive climb; ignition is deduplicated.")
	calls = rules.observe(_sample({"elapsed_time_s": 13, "altitude_m": 49999, "radial_speed_mps": 100, "throttle": 0.4, "fuel_burned_kg": 2.0}))
	_check(not calls.has("altitude_50km"), "Rounded altitude cannot trigger the fifty-kilometer call early.")
	calls = rules.observe(_sample({"elapsed_time_s": 14, "altitude_m": 50000, "radial_speed_mps": 100, "throttle": 0.4, "fuel_burned_kg": 2.5}))
	_check(calls.has("altitude_50km"), "The exact measured fifty-kilometer crossing triggers the call.")
	calls = rules.observe(_sample({"elapsed_time_s": 15, "altitude_m": 51000, "radial_speed_mps": 100, "throttle": 0.0, "fuel_burned_kg": 2.5}))
	_check(calls.has("engine_cutoff"), "A real throttle transition after fuel burn confirms cutoff.")
	calls = rules.observe(_sample({"elapsed_time_s": 16, "active_stage": 1}))
	_check(calls.has("stage"), "The active stage must actually advance before separation is announced.")
	calls = rules.observe(_sample({"elapsed_time_s": 17, "active_stage": 1}))
	_check(not calls.has("stage"), "An unchanged stage is not announced again.")
	rules.begin(_catalog.load_mission("M03"), _config, _sample({"body_id": "moon", "altitude_m": 40000}))
	calls = rules.observe(_sample({"elapsed_time_s": 20, "body_id": "moon", "altitude_m": 35000, "radial_speed_mps": -5}))
	_check(not calls.has("liftoff"), "The airborne lunar checkpoint never invents an Earth liftoff.")
	_check(not rules.is_current("altitude_50km"), "An Earth altitude call cannot play near the Moon.")

func _test_fuel() -> void:
	var rules := MissionVoiceRules.new()
	var mission := _catalog.load_mission("M01")
	rules.begin(mission, _config, _sample({"fuel_fraction": 0.3}))
	_check(not rules.observe(_sample({"fuel_fraction": 0.25})).has("fuel_25"), "Exactly twenty-five percent is not below twenty-five percent.")
	_check(rules.observe(_sample({"fuel_fraction": 0.249})).has("fuel_25"), "Fuel warning starts only below the measured threshold.")
	_check(not rules.observe(_sample({"fuel_fraction": 0.20})).has("fuel_25"), "Low fuel does not repeat every physics frame.")
	_check(not rules.observe(_sample({"fuel_fraction": 0.10})).has("fuel_10"), "Exactly ten percent is not below ten percent.")
	_check(rules.observe(_sample({"fuel_fraction": 0.099})).has("fuel_10"), "Critical fuel requires a real ten-percent crossing.")
	_check(not rules.is_current("fuel_25"), "The older twenty-five-percent call becomes stale at critical fuel.")
	_check(rules.observe(_sample({"fuel_fraction": 0, "fuel_remaining_kg": 0})).has("fuel_empty"), "Propellant exhaustion requires no remaining fuel.")
	_check(not rules.is_current("fuel_10"), "Critical-fuel speech is discarded after depletion.")
	rules.begin(mission, _config, _sample({"fuel_fraction": 0.5}))
	var calls := rules.observe(_sample({"fuel_fraction": 0.05}))
	_check(calls.has("fuel_10") and not calls.has("fuel_25"), "A warp step crossing both fuel bands emits only the critical call.")
	_check(not calls.has("engine_cutoff"), "Elapsed flight without a measured engine burn never fabricates cutoff.")

func _test_landing() -> void:
	var mission := _catalog.load_mission("M04")
	var rules := MissionVoiceRules.new()
	rules.begin(mission, _config, _sample({"body_id": "moon", "altitude_m": 1200, "radial_speed_mps": -9}))
	var calls := rules.observe(_sample({"body_id": "moon", "altitude_m": 999.9, "radial_speed_mps": -9}))
	_check(calls.has("lunar_1000m"), "A descending lunar crossing triggers the thousand-meter call.")
	_check(calls.has("descent_warning"), "Descent warnings respect the simulator's real eight-m/s contact limit.")
	_check(not calls.has("gear_warning"), "Gear warnings wait until the configured close-to-ground band.")
	calls = rules.observe(_sample({"body_id": "moon", "altitude_m": 29, "radial_speed_mps": -3}))
	_check(calls.has("lunar_30m") and not calls.has("lunar_100m"), "Crossing multiple descent bands keeps only the closest live call.")
	_check(calls.has("gear_warning") and not calls.has("legs"), "Thirty meters never implies that landing legs are deployed.")
	_check(not rules.is_current("descent_warning"), "A descent warning is stale after recovery below the speed limit.")
	calls = rules.observe(_sample({"body_id": "moon", "altitude_m": 20, "radial_speed_mps": -3, "legs_deployed": true}))
	_check(calls.has("legs") and not rules.is_current("gear_warning"), "Confirmed gear deployment cancels an obsolete gear warning.")
	calls = rules.observe(_sample({"body_id": "moon", "altitude_m": 9, "radial_speed_mps": -3, "legs_deployed": true}))
	_check(calls.has("lunar_10m"), "Ten meters is measured, without a fabricated contact countdown.")
	rules.observe(_sample({"body_id": "moon", "altitude_m": 0, "status": FlightState.Status.LANDED}))
	_check(not rules.is_current("lunar_10m"), "Descent callouts expire at touchdown.")
	rules.begin(mission, _config, _sample({"body_id": "moon", "altitude_m": 1200}))
	calls = rules.observe(_sample({"body_id": "moon", "altitude_m": 900, "radial_speed_mps": 2}))
	_check(not calls.has("lunar_1000m"), "An ascending craft does not receive descent callouts.")
	rules.begin(mission, _config, _sample({"body_id": "moon", "altitude_m": 40}))
	calls = rules.observe(_sample({"body_id": "moon", "altitude_m": 0, "status": FlightState.Status.CRASHED, "pod_intact": false}))
	_check(calls == ["vehicle_lost"], "A crash suppresses altitude, gear, fuel, and success chatter.")

func _test_results() -> void:
	var result := MissionResult.new()
	_check(MissionVoiceRules.result_clip(result).is_empty(), "An unfinished mission cannot announce victory.")
	result.outcome = MissionResult.Outcome.FAILURE
	result.reason = "Flight ended before the objective was complete."
	_check(MissionVoiceRules.result_clip(result) == "mission_failed", "Ending a flight does not claim loss of the vehicle.")
	result.reason = "Closest approach was outside the survey corridor."
	_check(MissionVoiceRules.result_clip(result) == "mission_failed", "A missed flyby corridor does not claim a crash.")
	result.reason = "The spacecraft crashed."
	_check(MissionVoiceRules.result_clip(result) == "vehicle_lost", "Crash narration uses the authoritative crash result.")
	result.outcome = MissionResult.Outcome.SUCCESS
	for id: String in ["M01", "M02", "M03", "M04"]:
		result.mission_id = id
		_check(MissionVoiceRules.result_clip(result) == id + "_success", "A confirmed success selects that mission's victory: " + id)

func _test_playback() -> void:
	var voice := root.get_node("MissionVoiceManager")
	var manifest: Dictionary = JsonData.read_object("res://data/mission_voiceover.json").clips
	_check(voice._streams.size() == manifest.size(), "Every approved line has a bundled offline audio clip.")
	for id: String in manifest:
		_check(voice._streams[id].get_length() > 0.5, "Decodable narration: " + id)
	voice.begin_preflight()
	_check(voice._current == "control_online" and voice._queue.size() == 1, "Preflight greetings queue without overlapping.")
	_check(not voice.announce("control_online"), "Already-played lines cannot be queued again.")
	_check(voice.get_subtitle() == manifest.control_online.text, "Subtitles match the exact generated script.")
	voice.set_hold(true)
	var clock_before: float = voice._clock
	voice._process(1.0)
	_check(voice._player.stream_paused and voice._clock == clock_before, "Pause freezes voice playback and queue expiration.")
	voice.set_hold(false)
	voice.begin_attempt(_catalog.load_mission("M04"), _config, _sample({"body_id": "moon", "altitude_m": 1200, "radial_speed_mps": -9}))
	voice.observe(_sample({"body_id": "moon", "altitude_m": 900, "radial_speed_mps": -9, "fuel_fraction": 0.15}))
	_check(voice._current == "descent_warning", "A measured hazard interrupts routine narration.")
	_check(voice._queue.all(func(item: Dictionary) -> bool: return item.priority >= 85), "Urgent warnings discard routine backlog.")
	voice.observe(_sample({"body_id": "moon", "altitude_m": 90, "radial_speed_mps": -3, "fuel_fraction": 0.15}))
	voice._process(0.4)
	_check(voice._current == "gear_warning", "Once speed is safe, the still-valid gear warning takes priority.")
	voice.observe(_sample({"body_id": "moon", "altitude_m": 80, "radial_speed_mps": -3, "fuel_fraction": 0.15, "legs_deployed": true}))
	_check(voice._current != "gear_warning" and not voice._queue.any(func(item: Dictionary) -> bool: return item.id == "gear_warning"), "Resolved warnings stop and are removed from the queue.")
	voice.begin_preflight()
	voice._clock += 30.0
	voice._discard_stale()
	_check(voice._queue.is_empty(), "Expired routine calls are not replayed later.")
	voice.begin_attempt(_catalog.load_mission("M01"), _config, _sample())
	voice.observe(_sample({"fuel_fraction": 0.05}))
	_check(voice._current == "fuel_10", "A new attempt resets per-flight deduplication.")
	var result := MissionResult.new()
	result.mission_id = "M01"
	result.outcome = MissionResult.Outcome.SUCCESS
	voice.announce_result(result)
	_check(voice._current == "M01_success" and voice._queue.is_empty(), "A confirmed result preempts and clears in-flight chatter.")
	await create_timer(0.2).timeout
	var game := root.get_node("GameManager")
	_check(game._bgm_player.volume_db < game.BGM_VOLUME_DB - 5.0, "Music ducks while the narrator speaks.")
	voice.stop_all()
	await create_timer(0.4).timeout
	_check(absf(game._bgm_player.volume_db - game.BGM_VOLUME_DB) < 0.1, "Music returns to its original volume after speech.")
	_check(not voice._player.playing and voice.get_subtitle().is_empty(), "Stopping narration clears both sound and subtitle.")

func _test_screens() -> void:
	var game := root.get_node("GameManager")
	game.mod_enabled = false
	game.completed_missions.clear()
	game.select_mission("M01")
	await _settle()
	current_scene.get_node("%Primary").pressed.emit()
	await _settle()
	current_scene.get_node("%Reset").pressed.emit()
	current_scene.get_node("%Primary").pressed.emit()
	await _settle()
	_check(current_scene.name == "LaunchpadPreview", "A real validated build reaches voiced preflight.")
	_check(current_scene.get_node("%VoiceSubtitle").text.contains("Mission Control online"), "Preflight displays the active spoken line.")
	await _snapshot("preflight")
	current_scene.get_node("%PreflightPanel").get_node("%LaunchButton").pressed.emit()
	await _settle()
	_check(current_scene.name == "Flight", "Voiceover keeps the existing immediate launch flow.")
	_check(current_scene.get_node("%Comms").text.contains("Launch committed"), "Flight displays the matching launch subtitle.")
	await _snapshot("flight")
	var voice := root.get_node("MissionVoiceManager")
	_check(not voice._played.has("liftoff") and not voice._played.has("ignition"), "Opening active flight does not fake ignition or liftoff.")
	current_scene._set_throttle(0.4)
	for tick in 20:
		current_scene._physics_process(0.1)
	_check(voice.rules._seen.has("ignition"), "Actual simulator fuel burn generates ignition narration.")
	_check(voice.rules._seen.has("liftoff") and current_scene._simulator.get_telemetry().altitude_m > 1.0, "Actual simulator pad clearance generates liftoff narration.")
	current_scene._toggle_pause()
	_check(voice._player.stream_paused, "The real flight pause holds narration.")
	current_scene._toggle_pause()
	current_scene._open_manual()
	_check(voice._player.stream_paused, "The real flight manual holds narration.")
	current_scene._close_manual()
	_check(not voice._player.stream_paused, "Closing the manual resumes narration when flight is unpaused.")
	current_scene._set_throttle(0.0)
	current_scene._physics_process(0.1)
	_check(voice.rules._seen.has("engine_cutoff"), "Actual simulator throttle cutoff generates the engine event.")
	current_scene.get_node("%EndFlight").pressed.emit()
	await _settle()
	_check(current_scene.name == "MissionReport" and voice._current == "mission_failed", "Ending an incomplete flight announces an unmet objective, not a lost vehicle.")
	_check(current_scene.get_node("%VoiceSubtitle").text.contains("not achieved"), "The result screen retains exact narration subtitles.")
	await _snapshot("report")
	current_scene.get_node("%Secondary").pressed.emit()
	await _settle()
	_check(voice._current.is_empty() and not voice._player.playing, "Leaving the debrief stops its voice.")

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _snapshot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	var folder := "res://exports/qa/voiceover"
	DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder.path_join(label + ".png")) == OK, "Voice subtitle capture: " + label)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
