extends SceneTree

## Checklist gaps beyond the original suites. -- --capture also saves rendered
## evidence; -- --manual opens a playable campaign with an isolated test save.
var checks := 0
var failures := 0
var capture := false
var notices: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	preload("res://tests/campaign_fixture.gd").isolate(self)
	capture = OS.get_cmdline_user_args().has("--capture")
	var game := root.get_node("GameManager")
	if OS.get_cmdline_user_args().has("--manual"):
		DisplayServer.window_set_title("Apogee QA - isolated campaign")
		game.show_main_menu()
		return
	_test_budget_and_fuel()
	_test_events_and_map()
	game.show_main_menu()
	await settle()
	for id: String in ["M01", "M02", "M03", "M04"]:
		var card: MissionCard = current_scene.get_mission_card(id)
		var mission := MissionCatalog.new().load_mission(id)
		check(card.get_node("%MissionName").text == mission.title, id + " card title")
		card.signal_focused.emit(id)
		var details: String = current_scene.get_node("%SignalDetails").text
		check(details.contains(mission.objective_text) and details.contains("Budget %d CR" % mission.budget_credits) and details.contains("Reward +%d CR" % mission.reward_credits), id + " card exposes JSON objective, budget and reward")
		check(card.is_selectable == (id == "M01"), id + " fresh campaign lock")
	await snapshot("01-menu")
	await window_modes("menu")
	game.select_mission("M01")
	await settle()
	await snapshot("02-builder")
	current_scene.get_node("%Primary").pressed.emit()
	await settle()
	var panel: Control = current_scene.get_node("%PreflightPanel")
	check(root.get_visible_rect().encloses(current_scene.get_node("Margin/Layout/Header").get_global_rect()), "Preflight header fits viewport")
	check(root.get_visible_rect().encloses(panel.get_node("%LaunchButton").get_global_rect()) and root.get_visible_rect().encloses(panel.get_node("%EditRocketButton").get_global_rect()), "Preflight Launch and Edit stay inside viewport")
	await snapshot("03-preflight")
	# Three real attempts: success, crash, successful replay. No fabricated outcome.
	for attempt in 3:
		var flight := current_scene
		flight.set_physics_process(false)
		flight.report_requested.connect(func(_result: MissionResult) -> void: check(flight.get_time_warp() == 1.0, "Terminal flight resets warp before report"))
		var sim: FlightSimulator = flight.get("_simulator")
		var fresh := sim.get_telemetry()
		check(fresh.position_m == Vector2(0, -600000) and fresh.velocity_mps == Vector2.ZERO and fresh.elapsed_time_s == 0, "Attempt %d resets position, velocity and clock" % attempt)
		check(fresh.active_stage == 0 and fresh.fuel_remaining_kg == 2200 and fresh.fuel_burned_kg == 0 and flight.get_time_warp() == 1, "Attempt %d resets fuel, stages and warp" % attempt)
		var ui: FlightUIController = flight.get("_ui")
		check(not ui.events.triggered.has("altitude_25000") and not ui.events.triggered.has("fuel_low"), "Attempt %d clears prior notifications" % attempt)
		flight.get_node("%PreflightPanel").get_node("%LaunchButton").pressed.emit()
		for second in 3:
			flight.call("_physics_process", 1.0)
		for tick in 120:
			flight.call("_physics_process", 1.0 / 60.0)
		if attempt == 0:
			var before := sim.get_telemetry()
			flight.call("_physics_process", 1.0 / 60.0)
			check(absf(sim.get_telemetry().elapsed_time_s - before.elapsed_time_s - 1.0 / 60.0) < 0.00001, "1x advances exactly one authoritative physics step")
			Input.action_press("throttle_down")
			flight.call("_physics_process", 0.1)
			Input.action_release("throttle_down")
			check(is_equal_approx(sim.get_telemetry().throttle, 0.85), "Held S action lowers throttle")
			Input.action_press("throttle_up")
			Input.action_press("steer_left")
			flight.call("_physics_process", 0.1)
			Input.action_release("throttle_up")
			Input.action_release("steer_left")
			check(sim.get_telemetry().heading_rad < 0.0 and sim.get_telemetry().throttle == 1.0, "Held W/A actions raise throttle and steer left")
			Input.action_press("steer_right")
			flight.call("_physics_process", 0.1)
			Input.action_release("steer_right")
			check(absf(sim.get_telemetry().heading_rad) < 0.001, "Held D action steers right")
			await snapshot("04-active-flight")
			await window_modes("flight")
			var tab := InputEventAction.new()
			tab.action = "toggle_map"
			tab.pressed = true
			Input.parse_input_event(tab)
			Input.flush_buffered_events()
			check(flight.get_node("%Map").visible, "Tab input reaches map toggle")
			await snapshot("05-orbit-map")
			before = sim.get_telemetry()
			Input.action_press("steer_right")
			flight.call("_physics_process", 0.1)
			Input.action_release("steer_right")
			Input.action_press("steer_left")
			flight.call("_physics_process", 0.1)
			Input.action_release("steer_left")
			check(sim.get_telemetry().elapsed_time_s > before.elapsed_time_s, "Flight and steering continue in map view")
			Input.parse_input_event(tab.duplicate())
			Input.flush_buffered_events()
			check(not flight.get_node("%Map").visible, "Second Tab returns to rocket")
		if attempt == 1:
			var cutoff := InputEventAction.new()
			cutoff.action = "cut_throttle"
			cutoff.pressed = true
			Input.parse_input_event(cutoff)
			Input.flush_buffered_events()
			check(sim.get_telemetry().throttle == 0.0, "X input cuts engine")
		# Also exercise terminal warp reset for the existing unrestricted fast-forward.
		flight.call("_set_time_warp", 25.0)
		for tick in 1200:
			flight.call("_physics_process", 1.0 / 60.0)
			if flight.get("_finished"):
				break
		await settle()
		check(current_scene.name == "MissionReport", "Attempt %d opens report" % attempt)
		check(game.last_result.outcome == (MissionResult.Outcome.FAILURE if attempt == 1 else MissionResult.Outcome.SUCCESS), "Attempt %d has the real expected outcome" % attempt)
		check(game.agency_credits == 1000, "Attempt %d retains exactly one reward" % attempt)
		if attempt == 0:
			check(current_scene.get_node("%Advice").text.contains("+1000"), "First report displays reward")
			await snapshot("06-success-report")
		elif attempt == 1:
			await snapshot("07-failure-report")
		else:
			check(game.last_result.awarded_credits == 0 and not current_scene.get_node("%Advice").text.contains("+1000"), "Replay neither grants nor displays reward")
		if attempt < 2:
			current_scene.get_node("%Primary").pressed.emit()
			await settle()
	current_scene.get_node("%Next").pressed.emit()
	await settle()
	check(game.selected_mission_id == "M02" and current_scene.get_node("%BudgetValue").text.contains("4500"), "Next mission opens M02 builder with 4500 CR")
	check(not game.is_mission_unlocked("M03") and not game.is_mission_unlocked("M04"), "Later missions stay locked after only M01")
	await _test_safe_warp(game)
	print("M4 checklist: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_budget_and_fuel() -> void:
	var mission := MissionCatalog.new().load_mission("M01")
	var builder := BuilderController.new()
	builder.setup(mission)
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
	manager.begin_attempt(config)
	sim.stage()
	var staged := sim.get_telemetry()
	manager.evaluate(staged)
	var result := manager.abort_attempt()
	check(is_equal_approx(result.fuel_used_kg, burned) and result.initial_fuel_kg - result.fuel_remaining_kg > burned + 100, "Report burned fuel excludes discarded lower-stage propellant")
	var tracker := FlightStatsTracker.new()
	tracker.reset(builder.calculate(config))
	tracker.observe(staged)
	check(is_equal_approx(tracker.get_summary().fuel_used_kg, burned), "Shared stats tracker also excludes discarded propellant")
	builder.free()

func _test_events_and_map() -> void:
	var events := FlightEventDirector.new()
	events.flight_event.connect(func(id: String, _message: String) -> void: notices.append(id))
	var t := FlightTelemetry.new()
	t.fuel_fraction = 1.0
	for altitude: float in [24999.0, 25000.0, 49999.0, 50000.0, 50001.0]:
		t.altitude_m = altitude
		events.observe(t)
		check(notices.count("altitude_25000") == (1 if altitude >= 25000 else 0) and notices.count("altitude_50000") == (1 if altitude >= 50000 else 0), "Exact milestone thresholds at %.0f m" % altitude)
	t.fuel_fraction = 0.19
	events.observe(t)
	events.observe(t)
	check(notices.count("fuel_low") == 1, "Low fuel warning does not repeat")
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
	check(map.map_to_world(map.world_to_map(original)).distance_to(original) < 1, "Transform round trip survives zoom and pan")
	map.free()

func _test_safe_warp(game: Node) -> void:
	current_scene.get_node("%Primary").pressed.emit()
	await settle()
	var flight := current_scene
	flight.set_physics_process(false)
	flight.get_node("%PreflightPanel").get_node("%LaunchButton").pressed.emit()
	for second in 3:
		flight.call("_physics_process", 1.0)
	check(not flight.request_time_warp(5), "5x blocks powered ascent")
	var sim: FlightSimulator = flight.get("_simulator")
	flight.call("_set_throttle", 0.0)
	var state: FlightState = sim.get("_state")
	state.position_m = Vector2(0, -750000)
	var earth: Dictionary = JsonData.read_object("res://data/planets.json").bodies.earth
	state.velocity_mps = Vector2(sqrt(float(earth.mu_m3_s2) / 750000.0), 0)
	state.status = FlightState.Status.FLYING
	check(flight.request_time_warp(5), "5x accepts verified safe coast")
	var before := sim.get_telemetry().elapsed_time_s
	flight.call("_physics_process", 0.1)
	check(absf(sim.get_telemetry().elapsed_time_s - before - 0.5) < 0.00001, "5x advances five authoritative steps")
	flight.get_node("%EndFlight").pressed.emit()
	check(flight.get_time_warp() == 1, "Abort resets warp before report handoff")
	await settle()
	check(game.last_result.outcome == MissionResult.Outcome.ABORTED, "End action produces distinct abort")
	current_scene.get_node("%Secondary").pressed.emit()
	await settle()
	check(current_scene.name == "MainMenu", "Report returns to menu")

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
