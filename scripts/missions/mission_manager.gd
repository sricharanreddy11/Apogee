class_name MissionManager
extends RefCounted

var definition: MissionDefinition
var _result := MissionResult.new()


func load_mission(id: String) -> bool:
	definition = null
	_result = MissionResult.new()
	var data := JsonData.read_object("res://data/missions/%s.json" % id.to_lower())
	if data.is_empty():
		return false
	if data.get("id") != id or not data.get("scenario") is Dictionary or not data.get("win_conditions") is Dictionary:
		push_error("Invalid ID, scenario, or win conditions for mission %s." % id)
		return false
	var mission := MissionDefinition.new()
	mission.id = id
	mission.title = String(data.get("title", ""))
	mission.objective_text = String(data.get("objective_text", ""))
	mission.budget_credits = int(data.get("budget_credits", 0))
	mission.reward_credits = int(data.get("reward_credits", 0))
	mission.scenario = data.scenario
	mission.win_conditions = data.win_conditions
	mission.allowed_part_ids.assign(data.get("allowed_part_ids", []))
	mission.required_part_ids.assign(data.get("required_part_ids", []))
	mission.discovery_ids.assign(data.get("discovery_ids", []))
	definition = mission
	_result.mission_id = mission.id
	return true


func evaluate(_telemetry: FlightTelemetry) -> void:
	# TODO(Member 3): Track stats, check terminal conditions, and record the outcome.
	pass


func finalize_result() -> MissionResult:
	# TODO(Member 3): Compute the score and reward from the recorded outcome.
	return _result
