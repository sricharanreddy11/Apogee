extends SceneTree

var _failures: int = 0
var _emission_count: int = 0
var _last_emission: FlightTelemetry


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mock := MockTelemetry.new()
	mock.playback_speed = 1.0
	mock.telemetry_updated.connect(_on_telemetry)
	_check(mock.initialize({"body_id": "earth", "spawn_profile": "surface_north"}), "Earth mock initializes.")
	_check(_emission_count == 1 and _last_emission != null, "Initialize emits a typed snapshot.")
	_check(is_equal_approx(mock.total_duration_s, 60.0), "Duration comes from the final sample.")
	var start := mock.get_telemetry()
	_check(start.position_m == Vector2(0.0, -600000.0), "Mock starts at Earth's north surface.")
	_check(start.fuel_fraction == 1.0 and start.status == FlightState.Status.READY, "Start values are ready and full fuel.")
	mock.step(5.0)
	var midpoint := mock.get_telemetry()
	_check(is_equal_approx(midpoint.altitude_m, 2500.0), "Altitude interpolates between frames.")
	_check(is_equal_approx(midpoint.speed_mps, 125.0), "Speed interpolates between frames.")
	_check(is_equal_approx(midpoint.fuel_fraction, 0.925), "Fuel interpolates between frames.")
	mock.step(5.0)
	_check_anchor(mock.get_telemetry(), 10.0, 5000.0, 250.0, 0.85)
	mock.step(20.0)
	_check_anchor(mock.get_telemetry(), 30.0, 35000.0, 900.0, 0.55)
	var detached := mock.get_telemetry()
	detached.altitude_m = -1.0
	detached.fuel_fraction = -1.0
	_check(mock.get_telemetry().altitude_m == 35000.0, "Mutating a snapshot does not affect the provider.")
	_check(start.altitude_m == 0.0, "Old snapshots do not change as playback advances.")
	mock.paused = true
	var before_pause := _emission_count
	mock.step(10.0)
	_check(mock.get_telemetry().elapsed_time_s == 30.0 and _emission_count == before_pause, "Pause freezes time and emissions.")
	mock.paused = false
	mock.step(-10.0)
	mock.step(NAN)
	mock.step(INF)
	_check(mock.get_telemetry().elapsed_time_s == 30.0, "Invalid time steps do not advance playback.")
	mock.step(1000.0)
	_check_anchor(mock.get_telemetry(), 60.0, 100000.0, 1400.0, 0.2)
	mock.step(1000.0)
	_check(mock.get_telemetry().elapsed_time_s == 60.0, "Final frame is held.")
	mock.restart()
	_check(mock.get_telemetry().elapsed_time_s == 0.0 and mock.get_telemetry().fuel_fraction == 1.0, "Restart resets each attempt.")
	mock.playback_speed = 5.0
	mock.step(2.0)
	_check(mock.get_telemetry().elapsed_time_s == 10.0, "Playback speed controls demonstration pacing.")
	mock.playback_speed = -2.0
	mock.step(2.0)
	_check(mock.get_telemetry().elapsed_time_s == 10.0, "Negative playback speed cannot reverse time.")
	_check(not mock.initialize({"body_id": "missing"}) and not mock.last_error.is_empty(), "Unknown body has a readable error.")
	_check(not mock.is_processing(), "Failed initialization stops automatic playback.")
	mock.free()
	_test_invalid_samples()
	if _failures == 0:
		print("Mock telemetry tests passed.")
	quit(0 if _failures == 0 else 1)


func _test_invalid_samples() -> void:
	var mock := MockTelemetry.new()
	mock.sample_path = "user://m0_invalid_mock_test.json"
	var file := FileAccess.open(mock.sample_path, FileAccess.WRITE)
	file.store_string('{"frames":[{"time_s":0,"altitude_m":0,"speed_mps":0,"fuel_fraction":1},{"time_s":10,"altitude_m":1,"speed_mps":1,"fuel_fraction":1.5}]}')
	file.close()
	_check(not mock.initialize({"body_id": "earth"}), "Out-of-range fuel sample is rejected.")
	_check(mock.last_error.contains("fuel_fraction"), "Invalid fuel points at the field to fix.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mock.sample_path))
	mock.sample_path = "res://data/mocks/does_not_exist.json"
	_check(not mock.initialize({"body_id": "earth"}), "Missing sample is rejected without a crash.")
	mock.free()


func _check_anchor(sample: FlightTelemetry, time_s: float, altitude: float, speed: float, fuel: float) -> void:
	_check(is_equal_approx(sample.elapsed_time_s, time_s), "Sample time matches anchor.")
	_check(is_equal_approx(sample.altitude_m, altitude), "Sample altitude matches anchor.")
	_check(is_equal_approx(sample.speed_mps, speed), "Sample speed matches anchor.")
	_check(is_equal_approx(sample.fuel_fraction, fuel), "Sample fuel matches anchor.")
	_check(sample.fuel_fraction >= 0.0 and sample.fuel_fraction <= 1.0, "Fuel stays in 0..1.")
	_check(is_equal_approx(sample.velocity_mps.length(), sample.speed_mps), "Velocity matches display speed magnitude.")
	_check(is_equal_approx(sample.position_m.length() - 600000.0, sample.altitude_m), "Position uses the agreed altitude coordinate.")
	_check(not sample.has_bound_orbit, "Mock does not fabricate a valid orbit.")


func _on_telemetry(telemetry: FlightTelemetry) -> void:
	_emission_count += 1
	_last_emission = telemetry


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
