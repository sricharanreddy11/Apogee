class_name MockTelemetry
extends Node

## Scripted UI demonstration only. These samples are not a physical trajectory.
## Replace this provider with FlightSimulator at integration; keep the HUD API.
signal telemetry_updated(telemetry: FlightTelemetry)

@export_file("*.json") var sample_path: String = "res://data/mocks/first_flight.json"
@export_range(0.1, 20.0, 0.1) var playback_speed: float = 5.0
@export var paused: bool = false

var last_error: String = ""
var total_duration_s: float = 0.0

var _frames: Array[Dictionary] = []
var _elapsed_time_s: float = 0.0
var _body_id: String = "earth"
var _body_radius_m: float = 0.0
var _configured: bool = false
var _initialization_attempted: bool = false


func _ready() -> void:
	if not _initialization_attempted:
		initialize({"body_id": "earth", "spawn_profile": "surface_north"})


func initialize(scenario: Dictionary) -> bool:
	_initialization_attempted = true
	_configured = false
	last_error = ""
	_frames.clear()
	total_duration_s = 0.0
	_elapsed_time_s = 0.0
	set_process(false)
	if not scenario.get("body_id") is String:
		return _fail("Mock scenario needs a body_id string.")
	_body_id = scenario.body_id
	if scenario.get("spawn_profile", "surface_north") != "surface_north":
		return _fail("Mock telemetry supports only the surface_north spawn profile.")
	var bodies_data := _read_object("res://data/planets.json")
	if not last_error.is_empty():
		return false
	var bodies: Variant = bodies_data.get("bodies")
	if not bodies is Dictionary or not bodies.get(_body_id) is Dictionary:
		return _fail("Mock telemetry cannot find body '%s' in data/planets.json." % _body_id)
	var radius: Variant = bodies[_body_id].get("radius_m")
	if not _is_number(radius) or float(radius) <= 0.0:
		return _fail("Mock body '%s' needs a positive radius_m." % _body_id)
	_body_radius_m = float(radius)
	var sample_data := _read_object(sample_path)
	if not last_error.is_empty():
		return false
	var rows: Variant = sample_data.get("frames")
	if not rows is Array or rows.size() < 2:
		return _fail("%s needs at least two frames." % sample_path)
	var previous_time: float = -1.0
	for index in rows.size():
		var row: Variant = rows[index]
		if not row is Dictionary:
			return _fail("Mock frame %d must be an object." % index)
		for field: String in ["time_s", "altitude_m", "speed_mps", "fuel_fraction"]:
			if not _is_number(row.get(field)):
				return _fail("Mock frame %d needs a finite numeric %s." % [index, field])
		var sample_time := float(row.time_s)
		if (index == 0 and sample_time != 0.0) or sample_time <= previous_time:
			return _fail("Mock frame times must start at 0 and strictly increase.")
		if float(row.altitude_m) < 0.0 or float(row.speed_mps) < 0.0:
			return _fail("Mock altitude and speed must be nonnegative (frame %d)." % index)
		if float(row.fuel_fraction) < 0.0 or float(row.fuel_fraction) > 1.0:
			return _fail("Mock fuel_fraction must be between 0 and 1 (frame %d)." % index)
		_frames.append(row.duplicate(true))
		previous_time = sample_time
	total_duration_s = previous_time
	_configured = true
	set_process(true)
	restart()
	return true


func _process(delta: float) -> void:
	step(delta)


func restart() -> void:
	_elapsed_time_s = 0.0
	if _configured:
		telemetry_updated.emit(get_telemetry())


func step(dt_s: float) -> void:
	if not _configured or paused or not is_finite(dt_s) or dt_s <= 0.0:
		return
	if not is_finite(playback_speed) or playback_speed <= 0.0:
		return
	_elapsed_time_s = minf(_elapsed_time_s + dt_s * playback_speed, total_duration_s)
	telemetry_updated.emit(get_telemetry())


func get_telemetry() -> FlightTelemetry:
	var telemetry := FlightTelemetry.new()
	if not _configured:
		return telemetry
	var lower: Dictionary = _frames[0]
	var upper: Dictionary = _frames[1]
	for index in range(1, _frames.size()):
		upper = _frames[index]
		lower = _frames[index - 1]
		if _elapsed_time_s <= float(upper.time_s):
			break
	var fraction := clampf(
		(_elapsed_time_s - float(lower.time_s)) / (float(upper.time_s) - float(lower.time_s)),
		0.0, 1.0
	)
	telemetry.elapsed_time_s = _elapsed_time_s
	telemetry.altitude_m = lerpf(float(lower.altitude_m), float(upper.altitude_m), fraction)
	telemetry.speed_mps = lerpf(float(lower.speed_mps), float(upper.speed_mps), fraction)
	telemetry.fuel_fraction = clampf(lerpf(float(lower.fuel_fraction), float(upper.fuel_fraction), fraction), 0.0, 1.0)
	telemetry.body_id = _body_id
	telemetry.position_m = Vector2.UP * (_body_radius_m + telemetry.altitude_m)
	# Match direction and magnitudes for UI/map display. This is deliberately not
	# the derivative of altitude: scripted speed is not a physics calculation.
	telemetry.velocity_mps = Vector2.UP * telemetry.speed_mps
	telemetry.radial_speed_mps = telemetry.speed_mps
	telemetry.heading_rad = 0.0
	telemetry.throttle = 1.0 if _elapsed_time_s > 0.0 else 0.0
	telemetry.active_stage = 0
	telemetry.status = FlightState.Status.FLYING if _elapsed_time_s > 0.0 else FlightState.Status.READY
	telemetry.pod_intact = true
	# Mass, fuel kg, orbit, and landing values are intentionally left unavailable.
	return telemetry


func _read_object(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Cannot open mock data %s (error %d)." % [path, FileAccess.get_open_error()])
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		_fail("%s:%d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return {}
	if not parser.data is Dictionary:
		_fail("%s must contain a JSON object." % path)
		return {}
	return parser.data


func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _fail(message: String) -> bool:
	last_error = message
	_frames.clear()
	_configured = false
	set_process(false)
	return false
