extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var mission := MissionCatalog.new().load_mission("M04")
	var config := RocketConfig.new()
	config.command_pod_id = "POD_A"
	config.rocket_name = "Material / vibration review"
	config.attachment_ids.assign(["DECOUPLER", "LEGS", "PROBE"])
	for engine: String in ["ENG_L", "ENG_V"]:
		var stage := StageConfig.new()
		stage.engine_id = engine
		stage.tank_ids.assign(["TANK_L"])
		config.stages.append(stage)
	var simulator := FlightSimulator.new()
	simulator.initialize(config, mission.scenario)
	var t := simulator.get_telemetry()
	check(absf(t.altitude_m - 10000.0) < 0.01, "M04 starts exactly 10 km above the moving Moon.")
	check(t.body_id == "moon" and t.status == FlightState.Status.FLYING, "M04 retains its airborne Moon-relative scenario.")
	check(is_equal_approx(t.radial_speed_mps, -55.0), "The spawn change preserves the existing descent velocity.")
	var view: Control = load("res://scenes/flight/flight_view.tscn").instantiate()
	view.setup(config)
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.size = Vector2(700, 430)
	root.add_child(view)
	view.set_process(false)
	view.update_visuals(t)
	check(view.get_node("%FarMarker").visible, "The high-altitude rocket opens Vehicle Cam.")
	view._process(0.1)
	var vibration: Node2D = view.get_node("%VehicleVibration")
	check(vibration.position.is_zero_approx() and vibration.rotation == 0.0, "Coasting produces no vibration.")
	var before := simulator.get_telemetry()
	var world: Transform2D = view.get_node("%Craft").transform
	var frame_position: Vector2 = view.get_node("%VehicleCam").position
	var button_position: Vector2 = view.get_node("%VehicleStage").position
	simulator.set_throttle(0.25)
	view.update_visuals(simulator.get_telemetry())
	var low := rms_motion(view)
	simulator.set_throttle(1.0)
	view.update_visuals(simulator.get_telemetry())
	var high := rms_motion(view)
	check(low > 0.02 and high > low * 3.5, "Vehicle vibration grows with actual commanded engine thrust.")
	check(absf(vibration.position.x) <= 5.4 and absf(vibration.position.y) <= 6.3 and absf(vibration.rotation) <= 0.0105, "Stronger vibration stays within its display bounds.")
	check(view.get_node("%Craft").transform.is_equal_approx(world), "Display vibration leaves the world craft transform unchanged.")
	check(view.get_node("%VehicleCam").position.is_equal_approx(frame_position), "The camera bezel stays still.")
	check(view.get_node("%VehicleStage").position.is_equal_approx(button_position), "Vehicle Cam controls stay still and clickable.")
	var after := simulator.get_telemetry()
	check(after.position_m == before.position_m and after.velocity_mps == before.velocity_mps and after.fuel_remaining_kg == before.fuel_remaining_kg, "Render animation cannot change authoritative flight physics or fuel.")
	view.set_motion_paused(true)
	view._process(0.2)
	check(vibration.position.is_zero_approx() and vibration.rotation == 0.0, "Pausing clears display vibration immediately.")
	view.set_motion_paused(false)
	check(rms_motion(view) > 0.02, "Resuming restores powered vibration.")
	simulator.set_throttle(0.0)
	view.update_visuals(simulator.get_telemetry())
	check(vibration.position.is_zero_approx(), "Engine cutoff stops vibration without drift.")
	simulator.stage()
	simulator.set_throttle(1.0)
	view.update_visuals(simulator.get_telemetry())
	var upper := rms_motion(view)
	check(upper > 0.02 and upper < high * 0.3, "The weaker vacuum engine vibrates less than the launch engine at equal throttle.")
	t = simulator.get_telemetry()
	t.fuel_remaining_kg = 0.0
	view.update_visuals(t)
	check(vibration.position.is_zero_approx(), "Empty fuel suppresses vibration even with a stale throttle value.")
	t = simulator.get_telemetry()
	t.status = FlightState.Status.LANDED
	t.contact_body_id = "moon"
	view.update_visuals(t)
	check(vibration.position.is_zero_approx(), "Touchdown suppresses powered vibration.")
	t = simulator.get_telemetry()
	view.update_visuals(t)
	view._set_vehicle_cam(false)
	view._process(0.1)
	check(vibration.position.is_zero_approx(), "Closing Vehicle Cam resets its vibration.")
	t.status = FlightState.Status.CRASHED
	t.pod_intact = false
	view.update_visuals(t)
	check(vibration.position.is_zero_approx() and vibration.rotation == 0.0, "A crash clears powered vibration immediately.")
	view.setup(config)
	check(vibration.position.is_zero_approx() and view._vibration_strength == 0.0, "Loading a fresh assembly clears previous vibration.")
	view.queue_free()
	await process_frame
	print("Vehicle vibration / lunar spawn: %d checks, %d failures." % [checks, failures])
	quit(0 if failures == 0 else 1)

func rms_motion(view: Control) -> float:
	view._vibration_clock = 0.0
	view._vibration_strength = 0.0
	var sum := 0.0
	for frame in 120:
		view._process(1.0 / 60.0)
		sum += view.get_node("%VehicleVibration").position.length_squared()
	return sqrt(sum / 120.0)
