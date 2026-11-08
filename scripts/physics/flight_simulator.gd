class_name FlightSimulator
extends RefCounted

# Scaled circular restricted three-body model:
# - Earth is fixed at the origin.
# - The Moon follows its Keplerian circular orbit.
# - The rocket has no gravitational influence on either body.
# - Rocket acceleration is the sum of Earth and Moon gravity plus thrust.
const BODIES_PATH := "res://data/planets.json"
const PARTS_PATH := "res://data/parts.json"
const STANDARD_GRAVITY_MPS2 := 9.80665
const MAX_SUBSTEP_S := 1.0 / 120.0
const PREDICTION_SUBSTEP_S := 0.5
const MAX_PREDICTION_S := 16200.0
const MIN_PREDICTION_S := 1800.0
const SAFE_LANDING_RADIAL_MPS := 8.0
const SAFE_LANDING_TANGENTIAL_MPS := 5.0
const SAFE_LANDING_TILT_RAD := deg_to_rad(20.0)
const TURN_RATE_RAD_S := deg_to_rad(40.0)
const STEERING_RAMP_S := 0.52
const STEERING_BRAKE_S := 0.42
const REFERENCE_STEERING_MASS_KG := 3600.0

var _config: RocketConfig
var _state := FlightState.new()
var _body_id: String = ""
var _body_radius_m: float = 0.0
var _bodies: Dictionary = {}
var _parts: Dictionary = {}
var _steering: float = 0.0
var _turn_rate_rad_s := 0.0
var _stage_dry_mass_kg: Array[float] = []
var _stage_fuel_capacity_kg: Array[float] = []
var _stage_thrust_n: Array[float] = []
var _stage_isp_s: Array[float] = []
var _initial_fuel_kg: float = 0.0
var _separator_mass_kg: float = 0.0


func initialize(config: RocketConfig, scenario: Dictionary) -> void:
	_config = config.copy()
	_state = FlightState.new()
	_steering = 0.0
	_turn_rate_rad_s = 0.0
	_body_id = String(scenario.get("body_id", "earth"))
	var catalog_bodies: Dictionary = JsonData.read_object(BODIES_PATH).get("bodies", {})
	_bodies = {}
	# This intentionally remains a two-body game system even if the data catalog
	# contains bodies reserved for much later missions.
	for simulated_id: String in ["earth", "moon"]:
		if catalog_bodies.has(simulated_id):
			_bodies[simulated_id] = catalog_bodies[simulated_id]
	var body: Dictionary = _bodies.get(_body_id, {})
	_body_radius_m = float(body.get("radius_m", 0.0))
	if _body_radius_m <= 0.0:
		push_error("No positive body radius for %s in %s." % [_body_id, BODIES_PATH])
	_load_parts()
	_initialize_vehicle()
	_initialize_spawn(String(scenario.get("spawn_profile", "surface_north")))


func step(dt_s: float) -> void:
	if dt_s <= 0.0 or _has_terminal_contact():
		return
	var remaining := dt_s
	while remaining > 0.0 and not _has_terminal_contact():
		var substep := minf(remaining, MAX_SUBSTEP_S)
		_integrate(substep)
		remaining -= substep


func _has_terminal_contact() -> bool:
	return _state.status == FlightState.Status.LANDED or _state.status == FlightState.Status.CRASHED


func set_throttle(value: float) -> void:
	var active := _state.active_stage
	if _has_terminal_contact() or active < 0 or active >= _state.stage_fuel_kg.size() or _state.stage_fuel_kg[active] <= 0.0:
		_state.throttle = 0.0
		return
	_state.throttle = clampf(value, 0.0, 1.0)


func set_steering(value: float) -> void:
	_steering = clampf(value, -1.0, 1.0)


func toggle_engine() -> bool:
	if _state.throttle > 0.0:
		_state.throttle = 0.0
		return false
	set_throttle(1.0)
	return _state.throttle > 0.0


func set_legs_deployed(deployed: bool) -> void:
	if _has_terminal_contact():
		return
	_state.legs_deployed = deployed and _config != null and _config.attachment_ids.has("LEGS")


func stage() -> bool:
	var old_stage := _state.active_stage
	if _has_terminal_contact() or old_stage < 0 or old_stage + 1 >= _state.stage_fuel_kg.size():
		return false
	var dropped_mass := _stage_dry_mass_kg[old_stage] + _state.stage_fuel_kg[old_stage]
	if old_stage == 0:
		dropped_mass += _separator_mass_kg
	_state.mass_kg = maxf(_state.mass_kg - dropped_mass, 0.001)
	_state.stage_fuel_kg[old_stage] = 0.0
	_state.active_stage += 1
	return true


func get_telemetry() -> FlightTelemetry:
	var telemetry := FlightTelemetry.new()
	telemetry.position_m = _state.position_m
	telemetry.velocity_mps = _state.velocity_mps
	telemetry.heading_rad = _state.heading_rad
	telemetry.angular_velocity_rad_s = _turn_rate_rad_s
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
	var fuel_remaining := 0.0
	for fuel in _state.stage_fuel_kg:
		fuel_remaining += fuel
	telemetry.fuel_remaining_kg = fuel_remaining
	telemetry.fuel_burned_kg = _state.fuel_burned_kg
	telemetry.contact_body_id = _state.contact_body_id
	telemetry.impact_radial_speed_mps = _state.impact_radial_speed_mps
	telemetry.impact_tangential_speed_mps = _state.impact_tangential_speed_mps
	telemetry.impact_tilt_rad = _state.impact_tilt_rad
	telemetry.fuel_fraction = fuel_remaining / _initial_fuel_kg if _initial_fuel_kg > 0.0 else 0.0
	var central_position := _body_position(_body_id, _state.elapsed_time_s)
	var central_velocity := _body_velocity(_body_id, _state.elapsed_time_s)
	telemetry.central_body_position_m = central_position
	telemetry.central_body_velocity_mps = central_velocity
	telemetry.earth_position_m = _body_position("earth", _state.elapsed_time_s)
	telemetry.moon_position_m = _body_position("moon", _state.elapsed_time_s)
	telemetry.earth_radius_m = float((_bodies.get("earth", {}) as Dictionary).get("radius_m", 0.0))
	telemetry.moon_radius_m = float((_bodies.get("moon", {}) as Dictionary).get("radius_m", 0.0))
	var relative_position := _state.position_m - central_position
	var relative_velocity := _state.velocity_mps - central_velocity
	var normal := relative_position.normalized()
	telemetry.altitude_m = relative_position.length() - _body_radius_m
	telemetry.speed_mps = relative_velocity.length()
	telemetry.radial_speed_mps = relative_velocity.dot(normal)
	telemetry.tangential_speed_mps = absf(relative_velocity.cross(normal))
	_populate_orbit(telemetry, relative_position, relative_velocity)
	return telemetry


func get_state_snapshot() -> Dictionary:
	return {
		"position_m": _state.position_m,
		"velocity_mps": _state.velocity_mps,
		"elapsed_time_s": _state.elapsed_time_s,
		"body_id": _body_id,
		"bodies": _body_snapshots(_state.elapsed_time_s),
	}


func get_prediction_snapshot() -> Dictionary:
	return {
		"position": _state.position_m,
		"velocity": _state.velocity_mps,
		"time": _state.elapsed_time_s,
		"status": _state.status,
		"body_id": _body_id,
		"bodies": _bodies.duplicate(true),
	}


static func predict_snapshot(snapshot: Dictionary, cancel: Semaphore) -> TrajectoryPrediction:
	var worker := FlightSimulator.new()
	worker._bodies = snapshot.bodies
	worker._body_id = snapshot.body_id
	worker._state.position_m = snapshot.position
	worker._state.velocity_mps = snapshot.velocity
	worker._state.elapsed_time_s = snapshot.time
	worker._state.status = snapshot.status
	return worker.get_trajectory_prediction(-1.0, 721, cancel)


func get_trajectory_prediction(duration_s: float = -1.0, sample_count: int = 721, cancel: Semaphore = null) -> TrajectoryPrediction:
	var prediction := TrajectoryPrediction.new()
	prediction.body_id = _body_id
	prediction.elapsed_time_s = _state.elapsed_time_s
	if sample_count < 2 or _has_terminal_contact():
		return prediction
	var position := _state.position_m
	var velocity := _state.velocity_mps
	var time := _state.elapsed_time_s
	if duration_s <= 0.0:
		duration_s = _complete_prediction_duration(position, velocity, time)
	var sample_dt := duration_s / float(sample_count - 1)
	var moon: Dictionary = _bodies.get("moon", {})
	var lunar_radius := float(moon.get("radius_m", 0.0))
	for index in sample_count:
		if cancel != null and cancel.try_wait():
			return prediction
		prediction.positions_m.append(position)
		prediction.sample_times_s.append(time)
		if index == sample_count - 1:
			break
		var remaining := sample_dt
		while remaining > 0.0:
			var dt := minf(remaining, PREDICTION_SUBSTEP_S)
			var motion := _velocity_verlet_step(position, velocity, time, dt, Vector2.ZERO)
			position = Vector2(motion.x, motion.y)
			velocity = Vector2(motion.z, motion.w)
			time += dt
			remaining -= dt
			var moon_position := _body_position("moon", time)
			var lunar_altitude := position.distance_to(moon_position) - lunar_radius
			if lunar_radius > 0.0 and lunar_altitude < prediction.lunar_closest_altitude_m:
				prediction.lunar_closest_altitude_m = lunar_altitude
				prediction.lunar_closest_time_s = time
				prediction.lunar_closest_position_m = position
				prediction.lunar_future_position_m = moon_position
			prediction.impact_body_id = "moon" if lunar_radius > 0.0 and lunar_altitude <= 0.0 else _impact_body_at(position, time, "moon")
			if not prediction.impact_body_id.is_empty():
				break
		if not prediction.impact_body_id.is_empty():
			prediction.positions_m.append(position)
			prediction.sample_times_s.append(time)
			break
	prediction.valid = prediction.positions_m.size() >= 2 and prediction.positions_m.size() == prediction.sample_times_s.size()
	return prediction


func _complete_prediction_duration(position: Vector2, velocity: Vector2, elapsed_time_s: float) -> float:
	# The projection is always ballistic, like an orbit line in a spaceflight
	# simulator. Live thrust changes the current velocity, then the next refresh
	# produces a new osculating trajectory from that state.
	var body: Dictionary = _bodies.get(_body_id, {})
	var mu := float(body.get("mu_m3_s2", 0.0))
	var relative_position := position - _body_position(_body_id, elapsed_time_s)
	var relative_velocity := velocity - _body_velocity(_body_id, elapsed_time_s)
	var radius := relative_position.length()
	if mu > 0.0 and radius > 0.0:
		var energy := relative_velocity.length_squared() * 0.5 - mu / radius
		if energy < 0.0:
			var semi_major := -mu / (2.0 * energy)
			var period := TAU * sqrt(semi_major * semi_major * semi_major / mu)
			return clampf(period * 1.05, MIN_PREDICTION_S, MAX_PREDICTION_S)
	return MAX_PREDICTION_S


func _load_parts() -> void:
	_parts.clear()
	var rows: Variant = JsonData.read_object(PARTS_PATH).get("parts", [])
	if not rows is Array:
		return
	for row in rows:
		if row is Dictionary:
			_parts[String(row.get("id", ""))] = row


func _initialize_vehicle() -> void:
	_stage_dry_mass_kg.clear()
	_stage_fuel_capacity_kg.clear()
	_stage_thrust_n.clear()
	_stage_isp_s.clear()
	_state.stage_fuel_kg.clear()
	_initial_fuel_kg = 0.0
	_separator_mass_kg = 0.0
	var permanent_dry_mass := _part_mass(_config.command_pod_id)
	for attachment_id in _config.attachment_ids:
		if attachment_id == "DECOUPLER":
			_separator_mass_kg += _part_mass(attachment_id)
		else:
			permanent_dry_mass += _part_mass(attachment_id)
	for stage_config in _config.stages:
		var stage_dry := 0.0
		var stage_fuel := 0.0
		var thrust := 0.0
		var isp := 0.0
		if stage_config != null:
			var engine: Dictionary = _parts.get(stage_config.engine_id, {})
			stage_dry += float(engine.get("dry_mass_kg", 0.0))
			thrust = float(engine.get("thrust_n", 0.0))
			isp = float(engine.get("isp_s", 0.0))
			for tank_id in stage_config.tank_ids:
				var tank: Dictionary = _parts.get(tank_id, {})
				stage_dry += float(tank.get("dry_mass_kg", 0.0))
				stage_fuel += float(tank.get("fuel_capacity_kg", 0.0))
		_stage_dry_mass_kg.append(stage_dry)
		_stage_fuel_capacity_kg.append(stage_fuel)
		_stage_thrust_n.append(thrust)
		_stage_isp_s.append(isp)
		_state.stage_fuel_kg.append(stage_fuel)
		permanent_dry_mass += stage_dry
		_initial_fuel_kg += stage_fuel
	_state.mass_kg = permanent_dry_mass + _separator_mass_kg + _initial_fuel_kg


func _initialize_spawn(profile: String) -> void:
	var body_position := _body_position(_body_id, 0.0)
	var body_velocity := _body_velocity(_body_id, 0.0)
	match profile:
		"moon_flyby_demo":
			# A safe, deliberately exaggerated lunar flyby for the physics showcase.
			# These are Moon-relative offsets; adding the Moon's orbital velocity is
			# essential or the craft would appear to fall behind the moving Moon.
			var moon_position := _body_position("moon", 0.0)
			var moon_velocity := _body_velocity("moon", 0.0)
			_state.position_m = moon_position + Vector2(-300000.0, 250000.0)
			_state.velocity_mps = moon_velocity + Vector2(450.0, 0.0)
			_state.heading_rad = PI * 0.5
			_state.throttle = 0.0
			_state.status = FlightState.Status.FLYING
		"lunar_survey":
			# The unpowered reference pass clears the Moon and exits the survey band.
			_state.position_m = body_position + Vector2(-120000.0, 137500.0)
			_state.velocity_mps = body_velocity + Vector2(650.0, 0.0)
			_state.heading_rad = PI * 0.5
			_state.status = FlightState.Status.FLYING
		"lunar_approach":
			_state.position_m = body_position + Vector2.RIGHT * (_body_radius_m + 30000.0)
			_state.velocity_mps = body_velocity + Vector2.DOWN * 140.0
			_state.heading_rad = PI * 0.5
			_state.status = FlightState.Status.FLYING
		"lunar_descent":
			_state.position_m = body_position + Vector2.UP * (_body_radius_m + 22000.0)
			_state.velocity_mps = body_velocity + Vector2.DOWN * 55.0
			_state.status = FlightState.Status.FLYING
		_:
			_state.position_m = body_position + Vector2.UP * _body_radius_m
			_state.velocity_mps = body_velocity
			_state.heading_rad = 0.0
			_state.status = FlightState.Status.READY


func _integrate(dt_s: float) -> void:
	var previous_turn_rate := _turn_rate_rad_s
	var inertia := clampf(sqrt(_state.mass_kg / REFERENCE_STEERING_MASS_KG), 0.7, 1.6)
	var ramp := STEERING_BRAKE_S if is_zero_approx(_steering) else STEERING_RAMP_S
	_turn_rate_rad_s = move_toward(previous_turn_rate, _steering * TURN_RATE_RAD_S, TURN_RATE_RAD_S * dt_s / (ramp * inertia))
	_state.heading_rad = wrapf(_state.heading_rad + (previous_turn_rate + _turn_rate_rad_s) * 0.5 * dt_s, -PI, PI)
	var thrust_acceleration := Vector2.ZERO
	var active := _state.active_stage
	if active >= 0 and active < _state.stage_fuel_kg.size() and _state.throttle > 0.0:
		var fuel := _state.stage_fuel_kg[active]
		var thrust := _stage_thrust_n[active] * _state.throttle
		var isp := _stage_isp_s[active]
		if fuel > 0.0 and thrust > 0.0 and isp > 0.0 and _state.mass_kg > 0.0:
			var requested_fuel := thrust / (isp * STANDARD_GRAVITY_MPS2) * dt_s
			var burned := minf(requested_fuel, fuel)
			var burn_fraction := burned / requested_fuel if requested_fuel > 0.0 else 0.0
			var average_mass := maxf(_state.mass_kg - burned * 0.5, 0.001)
			thrust_acceleration = Vector2.UP.rotated(_state.heading_rad) * (thrust * burn_fraction / average_mass)
			_state.fuel_burned_kg += burned
			_state.stage_fuel_kg[active] -= burned
			_state.mass_kg = maxf(_state.mass_kg - burned, 0.001)
			if _state.stage_fuel_kg[active] <= 0.0001:
				_state.stage_fuel_kg[active] = 0.0
				_state.throttle = 0.0
	var motion := _velocity_verlet_step(
		_state.position_m, _state.velocity_mps, _state.elapsed_time_s, dt_s, thrust_acceleration
	)
	_state.position_m = Vector2(motion.x, motion.y)
	_state.velocity_mps = Vector2(motion.z, motion.w)
	_state.elapsed_time_s += dt_s
	_resolve_collisions()


## Velocity Verlet is time-reversible for coast motion and does not inject the
## artificial orbital energy that forward Euler does. An elliptical orbit
## therefore naturally moves fastest at periapsis and slowest at apoapsis.
func _velocity_verlet_step(
	position: Vector2, velocity: Vector2, elapsed_time_s: float, dt_s: float,
	external_acceleration: Vector2
) -> Vector4:
	var acceleration_start := _gravity_at(position, elapsed_time_s) + external_acceleration
	var next_position := position + velocity * dt_s + acceleration_start * (0.5 * dt_s * dt_s)
	var acceleration_end := _gravity_at(next_position, elapsed_time_s + dt_s) + external_acceleration
	var next_velocity := velocity + (acceleration_start + acceleration_end) * (0.5 * dt_s)
	return Vector4(next_position.x, next_position.y, next_velocity.x, next_velocity.y)


func _resolve_collisions() -> void:
	for id: String in _bodies:
		var body: Dictionary = _bodies[id]
		var radius := float(body.get("radius_m", 0.0))
		var body_position := _body_position(id, _state.elapsed_time_s)
		var relative_position := _state.position_m - body_position
		if radius <= 0.0 or relative_position.length() > radius + 0.01:
			continue
		var normal := relative_position.normalized()
		if normal == Vector2.ZERO:
			normal = Vector2.UP
		_state.position_m = body_position + normal * radius
		var body_velocity := _body_velocity(id, _state.elapsed_time_s)
		var relative_velocity := _state.velocity_mps - body_velocity
		var radial_speed := relative_velocity.dot(normal)
		if _state.status == FlightState.Status.READY and id == _body_id:
			if radial_speed > 0.0:
				# Preserve outward liftoff velocity while the contact tolerance still
				# overlaps the pad; FLYING begins once the craft clears that shell.
				_state.velocity_mps = body_velocity + relative_velocity
			else:
				_state.velocity_mps = body_velocity
			return
		var tangential_velocity := relative_velocity - normal * radial_speed
		var thrust_direction := Vector2.UP.rotated(_state.heading_rad)
		var tilt := acos(clampf(thrust_direction.dot(normal), -1.0, 1.0))
		var safe := _state.legs_deployed and absf(radial_speed) <= SAFE_LANDING_RADIAL_MPS \
			and tangential_velocity.length() <= SAFE_LANDING_TANGENTIAL_MPS and tilt <= SAFE_LANDING_TILT_RAD
		_state.contact_body_id = id
		_state.impact_radial_speed_mps = radial_speed
		_state.impact_tangential_speed_mps = tangential_velocity.length()
		_state.impact_tilt_rad = tilt
		_state.velocity_mps = body_velocity
		_state.throttle = 0.0
		_turn_rate_rad_s = 0.0
		_state.status = FlightState.Status.LANDED if safe else FlightState.Status.CRASHED
		_state.pod_intact = safe
		return
	var active_distance := _state.position_m.distance_to(_body_position(_body_id, _state.elapsed_time_s))
	if _state.status == FlightState.Status.READY and active_distance > _body_radius_m + 0.01:
		_state.status = FlightState.Status.FLYING


func _gravity_at(position: Vector2, elapsed_time_s: float) -> Vector2:
	var acceleration := Vector2.ZERO
	for id: String in _bodies:
		var body: Dictionary = _bodies[id]
		var offset := _body_position(id, elapsed_time_s) - position
		var distance_sq := offset.length_squared()
		var radius := float(body.get("radius_m", 0.0))
		if distance_sq > maxf(radius * radius * 0.01, 1.0):
			acceleration += offset.normalized() * float(body.get("mu_m3_s2", 0.0)) / distance_sq
	return acceleration


func _body_position(id: String, elapsed_time_s: float) -> Vector2:
	var body: Dictionary = _bodies.get(id, {})
	var primary_id := String(body.get("primary_id", ""))
	if primary_id.is_empty():
		return Vector2.ZERO
	var radius := float(body.get("orbit_radius_m", 0.0))
	var phase := float(body.get("orbit_phase_rad", 0.0))
	var angular_speed := _body_angular_speed(body)
	if radius <= 0.0 or angular_speed <= 0.0:
		return _body_position(primary_id, elapsed_time_s)
	var angle := phase + angular_speed * elapsed_time_s
	return _body_position(primary_id, elapsed_time_s) + Vector2.RIGHT.rotated(angle) * radius


func _body_velocity(id: String, elapsed_time_s: float) -> Vector2:
	var body: Dictionary = _bodies.get(id, {})
	var primary_id := String(body.get("primary_id", ""))
	if primary_id.is_empty():
		return Vector2.ZERO
	var radius := float(body.get("orbit_radius_m", 0.0))
	var phase := float(body.get("orbit_phase_rad", 0.0))
	var angular_speed := _body_angular_speed(body)
	if radius <= 0.0 or angular_speed <= 0.0:
		return _body_velocity(primary_id, elapsed_time_s)
	var angle := phase + angular_speed * elapsed_time_s
	var tangent := Vector2.DOWN.rotated(angle)
	return _body_velocity(primary_id, elapsed_time_s) + tangent * (angular_speed * radius)


func _body_angular_speed(body: Dictionary) -> float:
	var radius := float(body.get("orbit_radius_m", 0.0))
	var primary: Dictionary = _bodies.get(String(body.get("primary_id", "")), {})
	var primary_mu := float(primary.get("mu_m3_s2", 0.0))
	if radius > 0.0 and primary_mu > 0.0:
		# Circular Kepler orbit: omega² = mu / r³.
		return sqrt(primary_mu / (radius * radius * radius))
	var fallback_period := float(body.get("orbit_period_s", 0.0))
	return TAU / fallback_period if fallback_period > 0.0 else 0.0


func _populate_orbit(telemetry: FlightTelemetry, position: Vector2, velocity: Vector2) -> void:
	var body: Dictionary = _bodies.get(_body_id, {})
	var mu := float(body.get("mu_m3_s2", 0.0))
	var radius := position.length()
	if mu <= 0.0 or radius <= 0.0:
		return
	var energy := velocity.length_squared() * 0.5 - mu / radius
	var angular_momentum := absf(position.cross(velocity))
	if energy >= 0.0 or angular_momentum <= 0.0:
		return
	var semi_major := -mu / (2.0 * energy)
	var eccentricity_sq := 1.0 + 2.0 * energy * angular_momentum * angular_momentum / (mu * mu)
	var eccentricity := sqrt(maxf(eccentricity_sq, 0.0))
	var periapsis := semi_major * (1.0 - eccentricity) - _body_radius_m
	var apoapsis := semi_major * (1.0 + eccentricity) - _body_radius_m
	telemetry.has_bound_orbit = true
	telemetry.periapsis_altitude_m = periapsis
	telemetry.apoapsis_altitude_m = apoapsis
	telemetry.predicted_impact = periapsis < 0.0
	var eccentricity_vector := (velocity.length_squared() * position - velocity.dot(position) * velocity) / mu - position.normalized()
	var periapsis_direction := eccentricity_vector.normalized() if eccentricity_vector.length_squared() > 0.00000001 else position.normalized()
	telemetry.periapsis_position_m = telemetry.central_body_position_m + periapsis_direction * (periapsis + _body_radius_m)
	telemetry.apoapsis_position_m = telemetry.central_body_position_m - periapsis_direction * (apoapsis + _body_radius_m)


func _impact_body_at(position: Vector2, elapsed_time_s: float, skip_id: String) -> String:
	for id: String in _bodies:
		if id == skip_id:
			continue
		var body: Dictionary = _bodies[id]
		if position.distance_to(_body_position(id, elapsed_time_s)) <= float(body.get("radius_m", 0.0)):
			return id
	return ""


func _body_snapshots(elapsed_time_s: float) -> Dictionary:
	var snapshots := {}
	for id: String in _bodies:
		var body: Dictionary = _bodies[id]
		snapshots[id] = {
			"position_m": _body_position(id, elapsed_time_s),
			"velocity_mps": _body_velocity(id, elapsed_time_s),
			"radius_m": float(body.get("radius_m", 0.0)),
			"mu_m3_s2": float(body.get("mu_m3_s2", 0.0)),
		}
	return snapshots


func _part_mass(part_id: String) -> float:
	return float((_parts.get(part_id, {}) as Dictionary).get("dry_mass_kg", 0.0))
