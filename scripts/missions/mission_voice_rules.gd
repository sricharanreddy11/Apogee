class_name MissionVoiceRules
extends RefCounted
## Only detached simulator snapshots and authoritative results can create calls.
var latest: FlightTelemetry
var _mission: MissionDefinition
var _seen: Dictionary = {}
var _surface_start := false
var _burned := false
var _stage_count := 0
var _has_legs := false
var _terminal := false

func begin(mission: MissionDefinition, config: RocketConfig, initial: FlightTelemetry) -> void:
	_mission = mission
	latest = initial
	_seen.clear()
	_surface_start = initial != null and initial.status == FlightState.Status.READY
	_stage_count = config.stages.size() if config != null else 0
	_has_legs = config != null and config.attachment_ids.has("LEGS")
	_burned = false
	_terminal = false

func observe(t: FlightTelemetry) -> Array[String]:
	var calls: Array[String] = []
	if t == null or _mission == null or _terminal:
		return calls
	var previous := latest
	if previous != null and t.elapsed_time_s < previous.elapsed_time_s:
		return calls
	latest = t
	if t.status == FlightState.Status.CRASHED:
		_once("vehicle_lost", calls)
		_terminal = true
		return calls
	if t.status == FlightState.Status.LANDED or not t.pod_intact:
		_terminal = true
		return calls
	if previous == null:
		return calls
	if t.fuel_burned_kg > previous.fuel_burned_kg + 0.000001:
		_burned = true
		_once("ignition", calls)
	if _surface_start and t.status == FlightState.Status.FLYING and t.altitude_m > 1.0 and t.radial_speed_mps > 0.0:
		_once("liftoff", calls)
	if t.active_stage > previous.active_stage and t.active_stage < _stage_count:
		_once("stage", calls)
	if _burned and previous.throttle > 0.0 and t.throttle <= 0.0 and t.active_stage == previous.active_stage and t.fuel_remaining_kg > 0.0001:
		_once("engine_cutoff", calls)
	if _has_legs and t.legs_deployed and not previous.legs_deployed:
		_once("legs", calls)
	if previous.fuel_remaining_kg > 0.0001 and t.fuel_remaining_kg <= 0.0001:
		_once("fuel_empty", calls)
	elif t.fuel_remaining_kg > 0.0001:
		if previous.fuel_fraction >= 0.10 and t.fuel_fraction < 0.10:
			_once("fuel_10", calls)
		elif previous.fuel_fraction >= 0.25 and t.fuel_fraction < 0.25:
			_once("fuel_25", calls)
	if t.body_id == "earth" and previous.body_id == "earth" and t.radial_speed_mps > 0.0 and previous.altitude_m < 50000.0 and t.altitude_m >= 50000.0:
		_once("altitude_50km", calls)
	if _is_lunar_descent(t):
		# A warp step can cross several bands; announce only the lowest live band.
		for threshold: int in [10, 30, 100, 1000]:
			if previous.body_id == "moon" and previous.altitude_m >= threshold and t.altitude_m < threshold:
				_once("lunar_%dm" % threshold, calls)
				break
		if _warning_descent(t):
			_once("descent_warning", calls)
		if _has_legs and t.altitude_m < 100.0 and not t.legs_deployed:
			_once("gear_warning", calls)
	return calls

func _once(id: String, calls: Array[String]) -> void:
	if not _seen.has(id):
		_seen[id] = true
		calls.append(id)

func _is_lunar_descent(t: FlightTelemetry) -> bool:
	return _mission != null and _mission.id == "M04" and t.body_id == "moon" and t.status == FlightState.Status.FLYING and t.radial_speed_mps < 0.0 and t.altitude_m >= 0.0 and t.altitude_m < 1000.0

func _warning_descent(t: FlightTelemetry) -> bool:
	# Collision safety is currently stricter than the mission JSON's 20 m/s.
	# Use the actual simulator limit, never the outdated objective prose.
	var limit := minf(float(_mission.win_conditions.get("max_vertical_speed_mps", 0.0)), FlightSimulator.SAFE_LANDING_RADIAL_MPS)
	return _is_lunar_descent(t) and absf(t.radial_speed_mps) > limit

func is_current(id: String) -> bool:
	var t := latest
	if t == null:
		return true
	if id == "vehicle_lost":
		return t.status == FlightState.Status.CRASHED
	if t.status in [FlightState.Status.CRASHED, FlightState.Status.LANDED] or not t.pod_intact:
		return false
	match id:
		"ignition": return t.throttle > 0.0 and t.fuel_remaining_kg > 0.0001
		"liftoff": return t.status == FlightState.Status.FLYING and t.altitude_m > 1.0 and t.radial_speed_mps > 0.0
		"engine_cutoff": return t.throttle <= 0.0
		"legs": return t.legs_deployed
		"fuel_25": return t.fuel_fraction < 0.25 and t.fuel_fraction >= 0.10 and t.fuel_remaining_kg > 0.0001
		"fuel_10": return t.fuel_fraction < 0.10 and t.fuel_remaining_kg > 0.0001
		"fuel_empty": return t.fuel_remaining_kg <= 0.0001
		"altitude_50km": return t.body_id == "earth" and t.altitude_m >= 50000.0 and t.altitude_m < 100000.0 and t.radial_speed_mps > 0.0
		"lunar_1000m": return _is_lunar_descent(t) and t.altitude_m >= 100.0
		"lunar_100m": return _is_lunar_descent(t) and t.altitude_m < 100.0 and t.altitude_m >= 30.0
		"lunar_30m": return _is_lunar_descent(t) and t.altitude_m < 30.0 and t.altitude_m >= 10.0
		"lunar_10m": return _is_lunar_descent(t) and t.altitude_m < 10.0
		"descent_warning": return _warning_descent(t)
		"gear_warning": return _is_lunar_descent(t) and t.altitude_m < 100.0 and not t.legs_deployed
	return true

static func result_clip(result: MissionResult) -> String:
	if result == null or result.outcome == MissionResult.Outcome.IN_PROGRESS:
		return ""
	if result.outcome == MissionResult.Outcome.SUCCESS:
		return result.mission_id + "_success" if result.mission_id in ["M01", "M02", "M03", "M04"] else "mission_success"
	# An ended attempt, missed corridor, or unmet objective does not imply a crash.
	return "vehicle_lost" if result.reason == "The spacecraft crashed." else "mission_failed"
