class_name FlightSimulator
extends RefCounted

const BODIES_PATH := "res://data/planets.json"

var _config: RocketConfig
var _state := FlightState.new()
var _body_id: String = ""
var _body_radius_m: float = 0.0
var _steering: float = 0.0


func initialize(config: RocketConfig, scenario: Dictionary) -> void:
	_config = config.copy()
	_state = FlightState.new()
	_steering = 0.0
	_body_id = String(scenario.get("body_id", "earth"))
	var data := JsonData.read_object(BODIES_PATH)
	var bodies: Dictionary = data.get("bodies", {})
	var body: Dictionary = bodies.get(_body_id, {})
	_body_radius_m = float(body.get("radius_m", 0.0))
	if _body_radius_m <= 0.0:
		push_error("No positive body radius for %s in %s." % [_body_id, BODIES_PATH])
	_state.position_m = Vector2.UP * _body_radius_m
	# TODO(Member 1): Resolve spawn profiles and initialize mass and per-stage fuel.


func step(_dt_s: float) -> void:
	# TODO(Member 1): Integrate gravity, thrust, fuel, rotation, and collisions at 60 Hz.
	pass


func set_throttle(value: float) -> void:
	_state.throttle = clampf(value, 0.0, 1.0)


func set_steering(value: float) -> void:
	_steering = clampf(value, -1.0, 1.0)


func stage() -> bool:
	# TODO(Member 1): Apply staging rules and detach the spent stage.
	return false


func get_telemetry() -> FlightTelemetry:
	var telemetry := FlightTelemetry.new()
	telemetry.position_m = _state.position_m
	telemetry.velocity_mps = _state.velocity_mps
	telemetry.heading_rad = _state.heading_rad
	telemetry.throttle = _state.throttle
	telemetry.elapsed_time_s = _state.elapsed_time_s
	telemetry.active_stage = _state.active_stage
	telemetry.mass_kg = _state.mass_kg
	telemetry.body_id = _body_id
	telemetry.altitude_m = _state.position_m.length() - _body_radius_m
	telemetry.speed_mps = _state.velocity_mps.length()
	telemetry.status = _state.status
	telemetry.pod_intact = _state.pod_intact
	telemetry.legs_deployed = _state.legs_deployed
	# TODO(Member 1): Publish fuel and body-relative velocity/orbital fields.
	return telemetry


func get_state_snapshot() -> Dictionary:
	# TODO(Member 1): Add the active body state required by trajectory prediction.
	return {
		"position_m": _state.position_m,
		"velocity_mps": _state.velocity_mps,
		"elapsed_time_s": _state.elapsed_time_s,
		"body_id": _body_id,
	}
