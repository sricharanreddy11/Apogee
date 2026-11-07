class_name MissionManager
extends RefCounted

var definition: MissionDefinition
var last_error: String = ""
var _result := MissionResult.new()
var _catalog := MissionCatalog.new()


func load_mission(id: String) -> bool:
	definition = null
	_result = MissionResult.new()
	definition = _catalog.load_mission(id)
	last_error = _catalog.last_error
	if definition == null:
		return false
	_result.mission_id = definition.id
	return true


func evaluate(_telemetry: FlightTelemetry) -> void:
	# TODO(Member 3): Track stats, check terminal conditions, and record the outcome.
	pass


func finalize_result() -> MissionResult:
	# TODO(Member 3): Compute the score and reward from the recorded outcome.
	return _result
