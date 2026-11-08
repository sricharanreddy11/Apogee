extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := MissionCatalog.new()
	var mission := catalog.load_mission("M01")
	_check(mission != null, "M01 loads for the flight test.")
	if mission == null:
		quit(1)
		return
	var builder := BuilderController.new()
	builder.setup(mission)
	var config := builder.build_config()
	builder.free()

	var simulator := FlightSimulator.new()
	simulator.initialize(config, mission.scenario)
	var initial := simulator.get_telemetry()
	_check(is_equal_approx(initial.mass_kg, 3600.0), "Wet mass is initialized from the actual selected parts.")
	_check(is_equal_approx(initial.fuel_remaining_kg, 2200.0) and is_equal_approx(initial.fuel_fraction, 1.0), "Fuel starts full.")
	_check(initial.status == FlightState.Status.READY and is_zero_approx(initial.altitude_m), "Surface launch begins ready on the pad.")
	var first_moon_position := initial.moon_position_m
	var warp_probe := FlightSimulator.new()
	warp_probe.initialize(config, mission.scenario)
	warp_probe.step(0.75)
	_check(is_equal_approx(warp_probe.get_telemetry().elapsed_time_s, 0.75), "A time-warp-sized step advances the full simulated duration through fixed substeps.")

	simulator.set_throttle(1.0)
	simulator.step(1.0)
	var powered := simulator.get_telemetry()
	_check(powered.status == FlightState.Status.FLYING and powered.altitude_m > 1.0, "Thrust lifts a valid M01 rocket.")
	_check(powered.fuel_remaining_kg < initial.fuel_remaining_kg and powered.mass_kg < initial.mass_kg, "Engine burn consumes fuel and lowers mass.")
	_check(powered.moon_position_m != first_moon_position and powered.earth_position_m == Vector2.ZERO, "Earth stays fixed while the Moon revolves.")

	simulator.set_steering(1.0)
	simulator.step(1.0 / 60.0)
	var initial_turn := simulator.get_telemetry().heading_rad
	_check(initial_turn > 0.0 and initial_turn < FlightSimulator.TURN_RATE_RAD_S / 120.0, "Steering eases into motion on the first tick.")
	simulator.step(0.6)
	var release_heading := simulator.get_telemetry().heading_rad
	_check(is_equal_approx(simulator.get_telemetry().angular_velocity_rad_s, FlightSimulator.TURN_RATE_RAD_S), "Holding steering builds to the capped turn rate.")
	simulator.set_steering(0.0)
	simulator.step(0.2)
	_check(simulator.get_telemetry().angular_velocity_rad_s > 0.1, "A short release still has angular momentum.")
	simulator.step(0.4)
	var settled_heading := simulator.get_telemetry().heading_rad
	_check(settled_heading > release_heading and settled_heading - release_heading < 0.16, "Steering carries a controlled amount of follow-through.")
	simulator.step(0.15)
	_check(is_equal_approx(simulator.get_telemetry().heading_rad, settled_heading), "The heading stops drifting after steering settles.")
	simulator.set_throttle(0.0)
	var cutoff_fuel := simulator.get_telemetry().fuel_remaining_kg
	simulator.step(0.5)
	_check(is_equal_approx(simulator.get_telemetry().fuel_remaining_kg, cutoff_fuel), "Engine cutoff stops fuel consumption.")
	var prediction := simulator.get_trajectory_prediction(120.0, 31)
	_check(prediction.valid and prediction.positions_m.size() == prediction.sample_times_s.size(), "Coast prediction returns paired world positions and times.")
	if prediction.valid:
		_check(prediction.positions_m[0].is_equal_approx(simulator.get_telemetry().position_m), "Prediction begins at the current rocket position.")

	var first_flight := FlightSimulator.new()
	first_flight.initialize(config, mission.scenario)
	first_flight.set_throttle(1.0)
	var max_altitude := 0.0
	for _frame in 60 * 120:
		first_flight.step(1.0 / 60.0)
		var flight_sample := first_flight.get_telemetry()
		max_altitude = maxf(max_altitude, flight_sample.altitude_m)
		if flight_sample.status == FlightState.Status.CRASHED:
			break
	_check(max_altitude >= 100000.0, "The default M01 rocket can clear the 100 km gameplay target.")

	var staged := RocketConfig.new()
	staged.rocket_name = "Pioneer test"
	staged.command_pod_id = "POD_A"
	staged.attachment_ids.assign(["DECOUPLER"])
	staged.stages.append(_stage("ENG_L", ["TANK_L"]))
	staged.stages.append(_stage("ENG_V", ["TANK_S"]))
	var staging_simulator := FlightSimulator.new()
	staging_simulator.initialize(staged, mission.scenario)
	var pre_stage := staging_simulator.get_telemetry()
	_check(staging_simulator.stage(), "A lower stage separates when an upper stage exists.")
	var post_stage := staging_simulator.get_telemetry()
	_check(post_stage.active_stage == 1 and post_stage.mass_kg < pre_stage.mass_kg, "Staging advances the active engine and drops spent mass.")
	_check(is_equal_approx(post_stage.fuel_remaining_kg, 900.0), "Staging discards lower-stage propellant but preserves upper-stage fuel.")
	_check(not staging_simulator.stage(), "The final stage cannot be separated into a nonexistent stage.")

	var lunar_simulator := FlightSimulator.new()
	lunar_simulator.initialize(config, {"body_id": "moon", "spawn_profile": "lunar_approach"})
	var lunar := lunar_simulator.get_telemetry()
	_check(is_equal_approx(lunar.altitude_m, 30000.0), "Lunar approach starts relative to the moving Moon.")
	_check(lunar.central_body_position_m == lunar.moon_position_m, "Moon missions publish the Moon as their active reference body.")

	if _failures == 0:
		print("Flight simulator tests passed.")
	quit(0 if _failures == 0 else 1)


func _stage(engine_id: String, tank_ids: Array[String]) -> StageConfig:
	var result := StageConfig.new()
	result.engine_id = engine_id
	result.tank_ids.assign(tank_ids)
	return result


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error(description)
