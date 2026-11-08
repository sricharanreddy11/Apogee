extends SceneTree

## Checklist gaps beyond the original suites. -- --capture also saves rendered
## evidence; -- --manual opens a playable campaign with an isolated test save.
var checks := 0
var failures := 0
var capture := false


func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := root.get_node("GameManager")
	var save: CampaignSave = game.get("_campaign_save")
	save.path = "user://m4-qa-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	game.agency_credits = 0
	game.mod_enabled = false
	game.completed_missions.clear()
	game.best_scores.clear()
	game.discovered_ids.clear()
	capture = OS.get_cmdline_user_args().has("--capture")
	if OS.get_cmdline_user_args().has("--manual"):
		DisplayServer.window_set_title("Apogee QA - isolated campaign")
		game.show_main_menu()
		return
	_test_budget_and_fuel()
	_test_map()
	await _test_campaign(game)
	print("M4 checklist: %d checks, %d failures" % [checks, failures])
	for suffix in ["", ".previous", ".tmp"]:
		if FileAccess.file_exists(save.path + suffix):
			DirAccess.remove_absolute(save.path + suffix)
	quit(0 if failures == 0 else 1)


func _test_campaign(game: Node) -> void:
	game.show_main_menu()
	await settle()
	if not _screen_is("MainMenu"):
		return
	for id: String in ["M01", "M02", "M03", "M04"]:
		var card: MissionCard = current_scene.get_mission_card(id)
		var mission := MissionCatalog.new().load_mission(id)
		check(card != null and card.get_node("%MissionName").text == mission.title, id + " card title")
		if card == null:
			continue
		card.signal_focused.emit(id)
		var details: String = current_scene.get_node("%SignalDetails").text
		check(card.is_selectable == (id == "M01"), id + " fresh campaign lock")
		check(details == mission.objective_text if id == "M01" else details.begins_with("Complete "), id + " card shows objective or unlock requirement")
	await snapshot("01-menu")
	await window_modes("menu")
	check(game.select_mission("M01"), "First Flight can be selected.")
	await settle()
	if not _screen_is("MissionBriefing"):
		return
	var first := MissionCatalog.new().load_mission("M01")
	check(current_scene.get_node("%Details").text == first.objective_text, "Briefing shows the objective.")
	check(current_scene.get_node("%Budget").text == "%d CR" % first.budget_credits, "Briefing shows the budget.")
	check(current_scene.get_node("%Reward").text == "%d CR" % first.reward_credits, "Briefing shows the reward.")
	current_scene.get_node("%Primary").pressed.emit()
	await settle()
	if not _screen_is("RocketBuilder"):
		return
	check(current_scene.get_node("%Primary").disabled, "An empty build cannot prepare for launch.")
	current_scene.get_node("%Reset").pressed.emit()
	await snapshot("02-builder")

	for attempt in 3:
		var flight := await _launch(attempt == 0)
		if flight == null:
			return
		var sim: FlightSimulator = flight.get("_simulator")
		var fresh := sim.get_telemetry()
		check(fresh.position_m == Vector2(0, -600000) and fresh.velocity_mps == Vector2.ZERO and is_zero_approx(fresh.elapsed_time_s), "Attempt %d starts on the pad with a fresh clock." % attempt)
		check(fresh.active_stage == 0 and fresh.fuel_remaining_kg == 2200 and fresh.fuel_burned_kg == 0 and flight.get_time_warp() == 1.0, "Attempt %d resets fuel, stages and warp." % attempt)
		check(not flight.get("_liftoff_announced"), "Attempt %d starts with fresh flight comms." % attempt)
		flight.get_node("%EngineButton").pressed.emit()
		for tick in 60:
			flight.call("_physics_process", 0.1)
		if attempt == 0:
			await _test_flight_inputs(flight, sim)
		if attempt == 1:
			_press_action(&"cut_throttle")
			check(sim.get_telemetry().throttle == 0.0, "X input cuts the engine.")
			flight.call("_set_time_warp", 25.0)
		for tick in 1500:
			flight.call("_physics_process", 0.1)
			if flight.get("_finished"):
				break
		check(flight.get("_finished"), "Attempt %d reaches a terminal result." % attempt)
		if attempt == 1:
			await create_timer(2.35).timeout
		await settle()
		if not _screen_is("MissionReport"):
			return
		var result: MissionResult = game.last_result
		var expected := MissionResult.Outcome.FAILURE if attempt == 1 else MissionResult.Outcome.SUCCESS
		check(result.outcome == expected, "Attempt %d produces the expected result." % attempt)
		check(game.agency_credits == first.reward_credits, "Attempt %d retains exactly one reward." % attempt)
		if attempt == 0:
			check(result.awarded_credits == first.reward_credits and current_scene.get_node("%Advice").text.contains("+%d" % first.reward_credits), "First success displays its reward.")
			await snapshot("06-success-report")
		elif attempt == 1:
			check(result.contact_body_id == "earth", "The failed attempt recorded a real impact.")
			await snapshot("07-failure-report")
		else:
			check(result.awarded_credits == 0 and not current_scene.get_node("%Advice").text.contains("+%d" % first.reward_credits), "Replay grants no duplicate reward.")
		if attempt < 2:
			current_scene.get_node("%Primary").pressed.emit()
			await settle()
			if not _screen_is("RocketBuilder"):
				return
			check(current_scene.build_config().rocket_name == "Sparrow I", "Retry retains the confirmed rocket.")

	current_scene.get_node("%Next").pressed.emit()
	await settle()
	if not _screen_is("MissionBriefing"):
		return
	var orbital := MissionCatalog.new().load_mission("M02")
	check(game.selected_mission_id == orbital.id and current_scene.get_node("%Budget").text == "%d CR" % orbital.budget_credits, "Next opens the M02 briefing and its budget.")
	check(not game.is_mission_unlocked("M03") and not game.is_mission_unlocked("M04"), "Later missions remain locked after M01.")
	await _test_safe_warp(game)


func _launch(capture_preflight: bool = false) -> Control:
	current_scene.get_node("%Primary").pressed.emit()
	await settle()
	if not _screen_is("LaunchpadPreview"):
		return null
	var panel: Control = current_scene.get_node("%PreflightPanel")
	var viewport := root.get_visible_rect()
	check(viewport.encloses(current_scene.get_node("Margin/Layout/Header").get_global_rect()), "Preflight header fits the viewport.")
	check(viewport.encloses(panel.get_node("%LaunchButton").get_global_rect()) and viewport.encloses(panel.get_node("%EditRocketButton").get_global_rect()), "Preflight Launch and Edit fit the viewport.")
	if capture_preflight:
		await snapshot("03-preflight")
	scene_changed.connect(_hold_new_flight, CONNECT_ONE_SHOT)
	panel.get_node("%LaunchButton").pressed.emit()
	await settle()
	if not _screen_is("Flight"):
		return null
	return current_scene as Control


func _hold_new_flight() -> void:
	if current_scene.name == "Flight":
		current_scene.set_physics_process(false)


func _test_flight_inputs(flight: Control, sim: FlightSimulator) -> void:
	var before := sim.get_telemetry()
	flight.call("_physics_process", 1.0 / 60.0)
	check(absf(sim.get_telemetry().elapsed_time_s - before.elapsed_time_s - 1.0 / 60.0) < 0.00001, "1× advances one authoritative step.")
	Input.action_press("throttle_down")
	flight.call("_physics_process", 0.1)
	Input.action_release("throttle_down")
	check(is_equal_approx(sim.get_telemetry().throttle, 0.85), "Holding S lowers throttle.")
	Input.action_press("throttle_up")
	Input.action_press("steer_left")
	flight.call("_physics_process", 0.1)
	Input.action_release("throttle_up")
	Input.action_release("steer_left")
	check(sim.get_telemetry().angular_velocity_rad_s < 0.0 and sim.get_telemetry().throttle == 1.0, "Holding W and A raises throttle and turns left.")
	Input.action_press("steer_right")
	flight.call("_physics_process", 0.3)
	Input.action_release("steer_right")
	check(sim.get_telemetry().angular_velocity_rad_s > 0.0, "Holding D reverses the turn.")
	check(root.get_node("MissionVoiceManager").rules._seen.has("liftoff"), "Liftoff narration follows measured ascent.")
	await snapshot("04-active-flight")
	await window_modes("flight")
	_press_action(&"toggle_map")
	check(flight.get_node("%Map").get("_auto_frame_enabled"), "Tab enables orbit auto-framing.")
	check(flight.get_node("%Map").visible and flight.get_node("%FlightArtwork").visible, "The orbit map and forward view stay visible together.")
	await snapshot("05-orbit-map")


func _press_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate() as InputEventAction
	release.pressed = false
	root.push_input(release)


func _screen_is(expected: String) -> bool:
	var matches := current_scene != null and current_scene.name == expected
	check(matches, "Opened " + expected + ".")
	return matches


func _test_budget_and_fuel() -> void:
	var mission := MissionCatalog.new().load_mission("M01")
	var builder := BuilderController.new()
	builder.setup(mission)
	builder.call("_reset_assembly")
	var config := builder.build_config()
	# Current M01 part combinations cannot cost exactly 2000 CR (max 3 tanks).
	# Check the inclusive rule at a reachable exact price, without changing JSON.
	mission.budget_credits = 1600
	check(builder.validate(config, mission).valid, "Exact budget is inclusive")
	mission.budget_credits = 1599
	check(not builder.validate(config, mission).valid, "One credit over budget is rejected")
	var sim := FlightSimulator.new()
	sim.initialize(config, mission.scenario)
	sim.step(2.0)
	check(sim.get_telemetry().position_m.distance_to(Vector2(0, -600000)) < 0.01 and sim.get_telemetry().velocity_mps == Vector2.ZERO, "Unignited craft stays on surface within 1 cm contact tolerance")
	var state: FlightState = sim.get("_state")
	state.position_m = Vector2(0, -610000)
	state.status = FlightState.Status.FLYING
	sim.step(0.1)
	check(sim.get_telemetry().velocity_mps.y > 0.9, "Airborne unpowered craft accelerates under Earth gravity")
	state.stage_fuel_kg[0] = 0.01
	sim.set_throttle(1.0)
	sim.step(0.1)
	check(sim.get_telemetry().fuel_remaining_kg == 0.0 and sim.get_telemetry().throttle == 0.0, "Last usable fuel burns out and cuts thrust")
	var exhausted_mass := sim.get_telemetry().mass_kg
	sim.step(0.1)
	check(sim.get_telemetry().mass_kg == exhausted_mass, "Empty engine consumes no more mass")
	var orbital := MissionCatalog.new().load_mission("M02")
	builder.setup(orbital)
	builder.call("_reset_assembly")
	builder.add_stage()
	builder.install_part("engine_1", "ENG_V")
	builder.install_part("tank_1_0", "TANK_L")
	builder.install_part("decoupler", "DECOUPLER")
	config = builder.build_config()
	sim.initialize(config, orbital.scenario)
	sim.set_throttle(1.0)
	sim.step(1.0)
	var burned := sim.get_telemetry().fuel_burned_kg
	var manager := MissionManager.new()
	manager.load_mission("M02")
	var stats := builder.calculate(config)
	manager.begin_attempt(config, stats)
	sim.stage()
	var staged := sim.get_telemetry()
	manager.evaluate(staged)
	var result := manager.finalize_result()
	check(staged.active_stage == 1, "The upper stage takes over after separation.")
	check(is_equal_approx(result.fuel_used_kg, burned) and float(stats.fuel_kg) - result.fuel_remaining_kg > burned + 100, "The report excludes discarded propellant from fuel burned.")
	builder.free()


func _test_map() -> void:
	var t := FlightTelemetry.new()
	var map := OrbitMap.new()
	map.size = Vector2(800, 500)
	t.earth_radius_m = 600000
	t.position_m = Vector2(15000, -650000)
	map.update_from_telemetry(t)
	for index in 100:
		map.call("_zoom_at", Vector2(250, 250), 1.2)
	check(is_equal_approx(map.get_zoom(), OrbitMap.MAX_ZOOM), "Map upper zoom limit")
	for index in 100:
		map.call("_zoom_at", Vector2(250, 250), 1.0 / 1.2)
	check(is_equal_approx(map.get_zoom(), OrbitMap.MIN_ZOOM), "Map lower zoom limit")
	var original := t.position_m
	map.pan_by_screen_delta(Vector2(100, 50))
	check(t.position_m == original, "Map pan never changes world position")
	check(not map.get_pan_offset_m().is_zero_approx(), "Panning moves the map camera.")
	map.reset_camera()
	check(map.get_pan_offset_m().is_zero_approx(), "Reset recenters the map camera.")
	map.free()

func _test_safe_warp(game: Node) -> void:
	current_scene.get_node("%Primary").pressed.emit()
	await settle()
	if not _screen_is("RocketBuilder"):
		return
	current_scene.get_node("%Reset").pressed.emit()
	var flight := await _launch()
	if flight == null:
		return
	var sim: FlightSimulator = flight.get("_simulator")
	flight.get_node("%EngineButton").pressed.emit()
	flight.call("_set_time_warp", 5.0)
	check(flight.get_time_warp() == 1.0, "5× is blocked while the engine is firing.")
	flight.call("_set_throttle", 0.0)
	var state: FlightState = sim.get("_state")
	state.position_m = Vector2(0, -750000)
	var earth: Dictionary = JsonData.read_object("res://data/planets.json").bodies.earth
	state.velocity_mps = Vector2(sqrt(float(earth.mu_m3_s2) / 750000.0), 0)
	state.status = FlightState.Status.FLYING
	flight.call("_set_time_warp", 5.0)
	check(flight.get_time_warp() == 5.0, "5× is available during coast.")
	var before := sim.get_telemetry().elapsed_time_s
	flight.call("_physics_process", 0.1)
	check(absf(sim.get_telemetry().elapsed_time_s - before - 0.5) < 0.00001, "5× advances five authoritative steps.")
	flight.get_node("%EndFlight").pressed.emit()
	await settle()
	if not _screen_is("MissionReport"):
		return
	check(game.last_result.outcome == MissionResult.Outcome.FAILURE and game.last_result.reason.begins_with("Flight ended"), "Ending an incomplete attempt reports the reason.")
	current_scene.get_node("%Secondary").pressed.emit()
	await settle()
	_screen_is("MainMenu")


func snapshot(label: String) -> void:
	if not capture:
		return
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var folder := "res://exports/qa/checklist"
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder + "/" + label + ".png") == OK, "Capture " + label)

func window_modes(label: String) -> void:
	if not capture:
		return
	for mode: int in [DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_FULLSCREEN]:
		DisplayServer.window_set_mode(mode)
		await settle()
		await snapshot("%s-mode-%d" % [label, mode])
		check(DisplayServer.window_get_mode() == mode, label + " window mode applied")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await settle()

func settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
