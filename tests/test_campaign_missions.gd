extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_orbit_hold()
	_test_flyby()
	_test_touchdown()
	await _test_crash_sequence()
	await _test_campaign_flight()
	if _failures == 0:
		print("Mission results, orbit hold, lunar flyby, touchdown and campaign saves passed.")
	quit(0 if _failures == 0 else 1)


func _test_orbit_hold() -> void:
	var manager := MissionManager.new()
	_check(manager.load_mission("M02"), "Load M02.")
	var t := FlightTelemetry.new()
	t.body_id = "earth"
	t.status = FlightState.Status.FLYING
	t.has_bound_orbit = true
	t.periapsis_altitude_m = 110000
	t.apoapsis_altitude_m = 190000
	_check(not manager.evaluate(t), "Entering the orbit band is not a success.")
	t.elapsed_time_s = 1.9
	_check(not manager.evaluate(t), "Orbit has to be held for the full two seconds.")
	t.periapsis_altitude_m = 99000
	t.elapsed_time_s = 2.0
	_check(not manager.evaluate(t), "Leaving the band resets the hold.")
	t.periapsis_altitude_m = 110000
	t.elapsed_time_s = 3.0
	_check(not manager.evaluate(t), "Re-entry starts a fresh hold.")
	t.elapsed_time_s = 5.0
	_check(manager.evaluate(t) and manager.finalize_result().outcome == MissionResult.Outcome.SUCCESS, "M02 completes after two continuous seconds.")


func _test_flyby() -> void:
	var manager := MissionManager.new()
	_check(manager.load_mission("M03"), "Load M03.")
	var builder := BuilderController.new()
	builder.setup(manager.definition)
	builder.install_part("payload", "PROBE")
	var config := builder.build_config()
	manager.begin_attempt(config, builder.calculate(config))
	builder.free()
	var sim := FlightSimulator.new()
	sim.initialize(config, manager.definition.scenario)
	var initial := sim.get_telemetry()
	_check(initial.altitude_m > 30000.0 and initial.radial_speed_mps < 0.0, "M03 begins inbound outside the survey corridor.")
	var projected := sim.get_trajectory_prediction(500, 251)
	_check(projected.valid and projected.impact_body_id.is_empty() and projected.lunar_closest_altitude_m > 15000 and projected.lunar_closest_altitude_m < 30000, "The map forecasts a safe pass.")
	var completed := false
	var entered := false
	for index in 2400:
		sim.step(1.0 / 6.0)
		var t := sim.get_telemetry()
		completed = manager.evaluate(t)
		if not entered and t.altitude_m <= 30000:
			entered = true
			_check(not completed, "Crossing into the survey corridor does not complete M03.")
		if completed:
			_check(t.altitude_m > 30000 and t.radial_speed_mps > 0, "M03 completes after the spacecraft exits outbound.")
			break
	_check(entered and completed, "The unpowered reference flight completes M03 in the simulator.")
	var result := manager.finalize_result()
	_check(result.outcome == MissionResult.Outcome.SUCCESS and result.discovery_ids.has("LUNAR_SURVEY"), "Flyby awards the survey discovery.")
	_check(absf(result.closest_approach_m - projected.lunar_closest_altitude_m) < 1000, "The projected and flown lunar passes agree within 1 km.")


func _test_touchdown() -> void:
	var manager := MissionManager.new()
	_check(manager.load_mission("M04"), "Load M04.")
	var builder := BuilderController.new()
	builder.setup(manager.definition)
	builder.install_part("legs", "LEGS")
	var config := builder.build_config()
	var stats := builder.calculate(config)
	builder.free()
	manager.begin_attempt(config, stats)
	var simulator := FlightSimulator.new()
	var hard := _impact(simulator, config, manager.definition.scenario, 20.0)
	_check(hard.status == FlightState.Status.CRASHED and not hard.pod_intact, "A hard landing stays a crash through all physics substeps.")
	_check(absf(hard.impact_radial_speed_mps) >= 19.0 and hard.contact_body_id == "moon", "Telemetry retains the real impact speed and body.")
	simulator.set_throttle(1.0)
	_check(simulator.get_telemetry().throttle == 0.0, "A terminal spacecraft cannot reignite.")
	_check(manager.evaluate(hard) and manager.finalize_result().outcome == MissionResult.Outcome.FAILURE, "M04 rejects a hard impact.")
	manager.load_mission("M04")
	manager.begin_attempt(config, stats)
	var soft := _impact(simulator, config, manager.definition.scenario, 5.0)
	_check(soft.status == FlightState.Status.LANDED, "A slow, upright lunar contact with legs is safe.")
	_check(manager.evaluate(soft) and manager.finalize_result().discovery_ids.has("APOLLO_TRIBUTE"), "Touchdown at the marker unlocks the Apollo tribute.")


func _impact(simulator: FlightSimulator, config: RocketConfig, scenario: Dictionary, speed: float) -> FlightTelemetry:
	simulator.initialize(config, scenario)
	simulator.set_legs_deployed(true)
	var initial := simulator.get_telemetry()
	var state: FlightState = simulator.get("_state")
	state.position_m = initial.moon_position_m + Vector2.UP * (initial.moon_radius_m + 0.0625)
	state.velocity_mps = initial.central_body_velocity_mps + Vector2.DOWN * speed
	simulator.step(1.0 / 30.0)
	return simulator.get_telemetry()


func _test_crash_sequence() -> void:
	var builder := BuilderController.new()
	builder.setup(MissionCatalog.new().load_mission("M01"))
	var flight: Control = load("res://scenes/flight/flight.tscn").instantiate()
	flight.setup(builder.build_config(), "M01")
	builder.free()
	var results: Array[MissionResult] = []
	flight.report_requested.connect(func(result: MissionResult) -> void: results.append(result))
	root.add_child(flight)
	flight.set_physics_process(false)
	var simulator: FlightSimulator = flight.get("_simulator")
	var state: FlightState = simulator.get("_state")
	state.status = FlightState.Status.FLYING
	state.position_m = Vector2.UP * (simulator.get_telemetry().earth_radius_m + 1.0)
	state.velocity_mps = Vector2.DOWN * 40.0
	flight.call("_physics_process", 0.10)
	await process_frame
	var view := flight.get_node("%FlightArtwork")
	_check(view.get_node("%CrashEffect").visible and not view.get_node("%Craft").visible, "Ground impact replaces the rocket with the crash effect.")
	_check(results.is_empty(), "The crash animation runs before the mission debrief.")
	await create_timer(2.28).timeout
	_check(results.size() == 1 and results[0].outcome == MissionResult.Outcome.FAILURE, "A completed crash sequence sends one failed result.")
	flight.free()


func _test_campaign_flight() -> void:
	var game := root.get_node("GameManager")
	var save: CampaignSave = game.get("_campaign_save")
	save.path = "user://campaign-test-%d.json" % OS.get_process_id()
	game.agency_credits = 0
	game.completed_missions.clear()
	game.best_scores.clear()
	game.discovered_ids.clear()
	_check(game.select_mission("M01"), "Campaign selects First Flight.")
	await scene_changed
	current_scene.get_node("%Primary").pressed.emit()
	await scene_changed
	current_scene.get_node("%Primary").pressed.emit()
	await scene_changed
	current_scene.get_node("%PreflightPanel").get_node("%LaunchButton").pressed.emit()
	await scene_changed
	_check(current_scene.name == "Flight", "The real preflight button starts flight.")
	var flight := current_scene
	flight.set_physics_process(false)
	var throttle := flight.get_node("%Throttle") as Slider
	_check(throttle is VSlider, "The cockpit provides a vertical throttle lever.")
	throttle.value = 40.0
	for index in 120:
		flight.call("_physics_process", 1.0 / 60.0)
	var sim: FlightSimulator = flight.get("_simulator")
	_check(sim.get_telemetry().altitude_m > 0.0, "Positive net thrust lifts Sparrow I from the pad at 40%.")
	flight.get_node("%PauseFlight").pressed.emit()
	_check(not throttle.editable and flight.get_node("%EngineButton").disabled, "Pause locks the cockpit lever and ignition.")
	flight.get_node("%PauseFlight").pressed.emit()
	_check(throttle.editable and is_equal_approx(throttle.value, 40.0), "Resuming restores the lever at the current thrust.")
	flight.get_node("%EngineButton").pressed.emit()
	flight.get_node("%EngineButton").pressed.emit()
	_check(is_equal_approx(sim.get_telemetry().throttle, 0.4), "Reignition restores the previous throttle.")
	flight.call("_set_time_warp", 50.0)
	_check(is_equal_approx(flight.get_time_warp(), 1.0), "Warp is blocked while powered.")
	throttle.value = 100
	for index in 2000:
		flight.call("_physics_process", 0.1)
		if flight.get("_finished"):
			break
	_check(flight.get("_finished"), "Flight automatically finalizes after reaching the M01 target.")
	await process_frame
	await process_frame
	_check(current_scene.name == "MissionReport", "Success automatically opens the live report.")
	var result: MissionResult = game.last_result
	_check(result.outcome == MissionResult.Outcome.SUCCESS and result.max_altitude_m >= 100000, "M01 reports a real success and altitude.")
	_check(result.fuel_used_kg > 0 and result.awarded_credits == 1000 and game.is_mission_unlocked("M02"), "First completion records stats, pays once, and unlocks M02.")
	_check(current_scene.get_node("%Next").visible and current_scene.get_node("%Stats").text.contains("1600 CR"), "Report shows launch cost and the next mission.")
	_check(current_scene.get_node("%FactSlot").visible and current_scene.get_node("%FactTitle").text == "Where space begins", "First Flight reveals its own sourced space fact.")
	_check(not current_scene.get_node("%Log").visible, "The debrief starts with detailed telemetry tucked away.")
	current_scene.get_node("%LogButton").button_pressed = true
	_check(current_scene.get_node("%Log").visible and current_scene.get_node("%Stats").is_visible_in_tree(), "The flight log still exposes detailed telemetry.")
	var failed_landing := MissionResult.new()
	failed_landing.mission_id = "M04"
	failed_landing.outcome = MissionResult.Outcome.FAILURE
	var failed_report: Control = load("res://scenes/missions/mission_report.tscn").instantiate()
	failed_report.setup(failed_landing)
	root.add_child(failed_report)
	_check(failed_report.get_node("%Heading").text == "Mission failed" and failed_report.get_node("%FactTitle").text == "Finding a clear landing spot", "Failed attempts retain their mission's archive fact.")
	var exhibit := failed_report.get_node("%Display")
	exhibit.progress = 1.0
	failed_report.get_node("%ReplayFact").pressed.emit()
	_check(is_zero_approx(exhibit.progress), "Replaying a fact restarts its schematic without restarting the mission.")
	failed_report.free()
	_check(save.load_progress().get("agency_credits") == 1000, "Progress can be loaded from disk.")
	current_scene.get_node("%Primary").pressed.emit()
	await scene_changed
	_check(current_scene.name == "RocketBuilder" and current_scene.build_config().rocket_name == "Sparrow I", "Retry preserves the design and returns to the builder.")
	var replay := MissionResult.new()
	replay.mission_id = "M01"
	replay.outcome = MissionResult.Outcome.SUCCESS
	replay.score = 100
	replay.discovery_ids.append("SPACE_BOUNDARY")
	game.show_report(replay)
	await scene_changed
	_check(replay.awarded_credits == 0 and game.agency_credits == 1000 and replay.discovery_ids.is_empty(), "Replay does not pay or grant the badge again.")
	_check(save.load_progress().get("best_scores", {}).get("M01") == 100, "Replay can update the saved best score.")
	var progress := save.load_progress()
	_check(save.save_progress(progress) == OK, "A third save replaces an existing backup.")
	var file := FileAccess.open(save.path, FileAccess.WRITE)
	if file != null:
		file.store_string("{\"version\":0}")
		file.close()
		_check(save.load_progress().get("agency_credits") == 1000, "An unreadable primary save falls back to the previous version.")
	for suffix in ["", ".previous", ".tmp"]:
		if FileAccess.file_exists(save.path + suffix):
			DirAccess.remove_absolute(save.path + suffix)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error(description)
