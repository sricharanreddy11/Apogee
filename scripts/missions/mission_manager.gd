class_name MissionManager
extends RefCounted

var definition: MissionDefinition
var last_error: String = ""
var _result := MissionResult.new()
var _catalog := MissionCatalog.new()
var _last_elapsed := -1.0
var _orbit_since := -1.0
var _flyby_inbound := false
var _initial_fuel_kg := 0.0
var _has_payload := false


func load_mission(id: String) -> bool:
	var loaded := _catalog.load_mission(id)
	last_error = _catalog.last_error
	return use_definition(loaded)


func use_definition(value: MissionDefinition) -> bool:
	definition = value
	_result = MissionResult.new()
	_last_elapsed = -1.0
	_orbit_since = -1.0
	_flyby_inbound = false
	_initial_fuel_kg = 0.0
	_has_payload = false
	if definition == null:
		return false
	_result.mission_id = definition.id
	return true


func begin_attempt(config: RocketConfig, stats: Dictionary) -> void:
	_result.launch_cost_credits = int(stats.get("cost_credits", 0))
	_initial_fuel_kg = float(stats.get("fuel_kg", 0.0))
	var payload_id := String(definition.payload.get("part_id", "PROBE"))
	_has_payload = config.attachment_ids.has(payload_id)


## Returns true once the flight has a terminal result.
func evaluate(telemetry: FlightTelemetry) -> bool:
	if definition == null:
		return false
	if _result.outcome != MissionResult.Outcome.IN_PROGRESS:
		return true
	if telemetry.elapsed_time_s < _last_elapsed:
		return false
	_last_elapsed = telemetry.elapsed_time_s
	_result.flight_time_s = telemetry.elapsed_time_s
	_result.max_altitude_m = maxf(_result.max_altitude_m, telemetry.altitude_m)
	_result.peak_speed_mps = maxf(_result.peak_speed_mps, telemetry.speed_mps)
	_result.fuel_used_kg = telemetry.fuel_burned_kg
	_result.fuel_remaining_kg = telemetry.fuel_remaining_kg
	_result.stages_used = maxi(_result.stages_used, telemetry.active_stage + 1)

	var rules := definition.win_conditions
	if telemetry.status == FlightState.Status.CRASHED:
		_record_contact(telemetry)
		_fail("The spacecraft crashed.", "Brake earlier and align the pod with the surface normal.")
	elif not telemetry.pod_intact and bool(rules.get("require_intact_pod", true)):
		_fail("The command pod was lost.", "Protect the command pod through the end of the flight.")
	else:
		match definition.objective_type:
			"reach_altitude":
				if telemetry.altitude_m >= float(rules.min_altitude_m):
					_succeed("The intact spacecraft reached %.0f km." % (float(rules.min_altitude_m) / 1000.0), 1.0)
			"stable_orbit":
				_evaluate_orbit(telemetry, rules)
			"lunar_flyby":
				_evaluate_flyby(telemetry, rules)
			"safe_landing":
				if telemetry.status == FlightState.Status.LANDED:
					_evaluate_landing(telemetry, rules)
		if _result.outcome == MissionResult.Outcome.IN_PROGRESS and telemetry.status == FlightState.Status.LANDED:
			_record_contact(telemetry)
			_fail("The spacecraft touched down before completing the objective.", "Review the flight objective before retrying.")
	return _result.outcome != MissionResult.Outcome.IN_PROGRESS


func _evaluate_orbit(t: FlightTelemetry, rules: Dictionary) -> void:
	if t.body_id != "earth" or t.status != FlightState.Status.FLYING or not t.has_bound_orbit:
		_orbit_since = -1.0
		return
	_result.last_earth_orbit_km = {
		"last_bound_periapsis_km": t.periapsis_altitude_m / 1000.0,
		"last_bound_apoapsis_km": t.apoapsis_altitude_m / 1000.0,
	}
	if t.periapsis_altitude_m < float(rules.min_periapsis_m) or t.apoapsis_altitude_m > float(rules.max_apoapsis_m):
		_orbit_since = -1.0
		return
	if _orbit_since < 0.0:
		_orbit_since = t.elapsed_time_s
	var hold := t.elapsed_time_s - _orbit_since
	_result.longest_orbit_hold_s = maxf(_result.longest_orbit_hold_s, hold)
	if hold >= float(rules.hold_duration_s):
		var band := maxf(1.0, float(rules.max_apoapsis_m) - float(rules.min_periapsis_m))
		_succeed("Earth orbit held for %.0f seconds." % float(rules.hold_duration_s), 1.0 - (t.apoapsis_altitude_m - t.periapsis_altitude_m) / band)


func _evaluate_flyby(t: FlightTelemetry, rules: Dictionary) -> void:
	if t.body_id != "moon" or t.status != FlightState.Status.FLYING:
		return
	var minimum := float(rules.min_altitude_m)
	var maximum := float(rules.max_altitude_m)
	if t.radial_speed_mps < 0.0:
		if t.altitude_m >= maximum:
			_flyby_inbound = true
		if _flyby_inbound and (_result.closest_approach_m < 0.0 or t.altitude_m < _result.closest_approach_m):
			_result.closest_approach_m = t.altitude_m
	if not _flyby_inbound:
		return
	if t.altitude_m < _result.closest_approach_m:
		_result.closest_approach_m = t.altitude_m
	if t.radial_speed_mps <= 0.0 or t.altitude_m <= maximum:
		return
	var closest := _result.closest_approach_m
	if closest < minimum or closest > maximum:
		_fail("Closest approach was %.1f km, outside the survey corridor." % (closest / 1000.0), "Adjust the gold coast track to pass between %.0f and %.0f km." % [minimum / 1000.0, maximum / 1000.0])
	elif definition.payload.get("required", false) and not _has_payload:
		_fail("The flyby carried no science payload.", "Fit the science payload in Rocket Lab.")
	else:
		var midpoint := (minimum + maximum) * 0.5
		_succeed("Survey complete. Closest approach: %.1f km." % (closest / 1000.0), 1.0 - absf(closest - midpoint) / ((maximum - minimum) * 0.5))


func _evaluate_landing(t: FlightTelemetry, rules: Dictionary) -> void:
	_record_contact(t)
	var radial := absf(t.impact_radial_speed_mps)
	var tangential := t.impact_tangential_speed_mps
	var tilt := rad_to_deg(t.impact_tilt_rad)
	if t.contact_body_id != String(definition.scenario.body_id) 		or radial > float(rules.max_vertical_speed_mps) 		or tangential > float(rules.max_horizontal_speed_mps) 		or tilt > float(rules.max_orientation_deg) 		or (rules.require_landing_legs and not t.legs_deployed):
		_fail("Touchdown missed the landing requirements.", "Deploy the legs and reduce vertical speed, sideways speed, and tilt.")
		return
	var precision := 1.0 - (radial / float(rules.max_vertical_speed_mps) + tangential / float(rules.max_horizontal_speed_mps) + tilt / float(rules.max_orientation_deg)) / 3.0
	_succeed("Safe lunar touchdown at %.1f m/s vertical speed." % radial, precision)
	# The in-game marker uses the north rim of the lunar landing scenario.
	if (t.position_m - t.moon_position_m).normalized().dot(Vector2.UP) < cos(deg_to_rad(12.0)):
		_result.discovery_ids.erase("APOLLO_TRIBUTE")


func _record_contact(t: FlightTelemetry) -> void:
	_result.contact_body_id = t.contact_body_id
	_result.touchdown_vertical_mps = absf(t.impact_radial_speed_mps)
	_result.touchdown_horizontal_mps = t.impact_tangential_speed_mps
	_result.touchdown_tilt_deg = rad_to_deg(t.impact_tilt_rad)
	_result.peak_speed_mps = maxf(_result.peak_speed_mps, Vector2(t.impact_radial_speed_mps, t.impact_tangential_speed_mps).length())


func _succeed(reason: String, precision: float) -> void:
	_result.outcome = MissionResult.Outcome.SUCCESS
	_result.reason = reason
	_result.discovery_ids.assign(definition.discovery_ids)
	var fuel_efficiency := _result.fuel_remaining_kg / _initial_fuel_kg if _initial_fuel_kg > 0.0 else 0.0
	var savings := 1.0 - float(_result.launch_cost_credits) / float(definition.budget_credits)
	_result.score = roundi(50.0 + 20.0 * clampf(fuel_efficiency, 0, 1) + 15.0 * clampf(savings, 0, 1) + 15.0 * clampf(precision, 0, 1))


func _fail(reason: String, advice: String) -> void:
	_result.outcome = MissionResult.Outcome.FAILURE
	_result.reason = reason
	_result.advice = advice


func finalize_result() -> MissionResult:
	if _result.outcome == MissionResult.Outcome.IN_PROGRESS:
		var advice := "Keep the rocket on the required trajectory before ending the attempt."
		if definition != null:
			match definition.objective_type:
				"reach_altitude":
					advice = "Build speed upward and reach the target altitude with the pod intact."
				"stable_orbit":
					advice = "Build sideways speed and keep both orbit markers inside the target band."
				"lunar_flyby":
					advice = "Pass through the survey corridor and fly back out before ending the attempt."
				"safe_landing":
					advice = "Brake toward the Moon, deploy the legs, and touch down upright."
		_fail("Flight ended before the objective was complete.", advice)
	return _result
