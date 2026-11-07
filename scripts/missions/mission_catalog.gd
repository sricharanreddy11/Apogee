class_name MissionCatalog
extends RefCounted

## Reads mission files and their ordered navigation index before gameplay uses them.
## A failed operation returns null/an empty list; inspect last_error for the reason.
const MISSIONS_DIRECTORY := "res://data/missions/"
const MAX_EXACT_JSON_INTEGER := 9007199254740991.0
const OBJECTIVE_FIELDS := {
	"reach_altitude": ["min_altitude_m", "require_intact_pod"],
	"stable_orbit": ["min_periapsis_m", "max_apoapsis_m", "hold_duration_s"],
	"lunar_flyby": ["min_altitude_m", "max_altitude_m", "require_intact_pod"],
	"safe_landing": ["max_vertical_speed_mps", "max_horizontal_speed_mps", "max_orientation_deg", "require_landing_legs", "require_intact_pod"],
}

var last_error: String = ""
var _missions_directory: String
var _identifier_pattern := RegEx.create_from_string("^[A-Za-z0-9_-]+$")


func _init(directory: String = MISSIONS_DIRECTORY) -> void:
	_missions_directory = directory.path_join("")


func load_mission(id: String) -> MissionDefinition:
	last_error = ""
	if not _is_identifier(id):
		return _fail("Mission ID must contain only letters, numbers, underscores, or hyphens.")
	var missions := get_mission_list()
	if not last_error.is_empty():
		return null
	for mission in missions:
		if mission.id == id:
			return mission
	return _fail("Mission '%s' is not listed in the mission index." % id)


func get_mission_list() -> Array[MissionDefinition]:
	last_error = ""
	var index_path := _missions_directory.path_join("index.json")
	var index_file := FileAccess.open(index_path, FileAccess.READ)
	if index_file == null:
		last_error = "Could not open mission index %s (error %s)." % [index_path, FileAccess.get_open_error()]
		return []
	var rows := parse_mission_index_json(index_file.get_as_text())
	if not last_error.is_empty():
		last_error = "%s: %s" % [index_path, last_error]
		return []
	var missions: Array[MissionDefinition] = []
	for row in rows:
		var path := _missions_directory.path_join("%s.json" % String(row.id).to_lower())
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			last_error = "Could not open mission %s at %s (error %s)." % [row.id, path, FileAccess.get_open_error()]
			return []
		var mission := parse_mission_json(file.get_as_text(), row.id)
		if mission == null:
			last_error = "%s: %s" % [path, last_error]
			return []
		mission.unlock_requirement = "" if row.unlock_requirement == null else String(row.unlock_requirement)
		mission.starting_location = row.starting_location
		mission.destination = row.destination
		mission.released = row.get("released", true)
		missions.append(mission)
	return missions


func parse_mission_index_json(text: String) -> Array[Dictionary]:
	last_error = ""
	var data := _parse_object(text, "Mission index")
	if not last_error.is_empty():
		return []
	if not data.get("missions") is Array or data.missions.is_empty():
		last_error = "Mission index needs a nonempty 'missions' array."
		return []
	var rows: Array[Dictionary] = []
	var positions: Dictionary = {}
	var filenames: Dictionary = {}
	for index in data.missions.size():
		var row: Variant = data.missions[index]
		if not row is Dictionary:
			last_error = "Mission index entry %d must be an object." % (index + 1)
			return []
		for field: String in ["id", "unlock_requirement", "starting_location", "destination"]:
			if not row.has(field):
				last_error = "Mission index entry %d is missing '%s'." % [index + 1, field]
				return []
		if not _is_identifier(row.id):
			last_error = "Mission index entry %d needs a safe string ID." % (index + 1)
			return []
		var lowercase_id: String = row.id.to_lower()
		if filenames.has(lowercase_id):
			last_error = "Duplicate mission ID '%s' in mission index (IDs also share lowercase filenames)." % row.id
			return []
		if row.unlock_requirement != null and not _is_identifier(row.unlock_requirement):
			last_error = "Mission %s unlock_requirement must be null or a safe mission ID." % row.id
			return []
		for field: String in ["starting_location", "destination"]:
			if not _is_nonempty_text(row[field]):
				last_error = "Mission %s index field '%s' must be a nonempty string." % [row.id, field]
				return []
		if row.has("released") and not row.released is bool:
			last_error = "Mission %s index field 'released' must be a boolean." % row.id
			return []
		positions[row.id] = index
		filenames[lowercase_id] = true
		rows.append(row.duplicate(true))
	for index in rows.size():
		var predecessor: Variant = rows[index].unlock_requirement
		if predecessor == null:
			continue
		if not positions.has(predecessor):
			last_error = "Mission %s requires unknown mission '%s'." % [rows[index].id, predecessor]
			return []
		if int(positions[predecessor]) >= index:
			last_error = "Mission %s prerequisite '%s' must appear earlier in the index; cycles and forward prerequisites are invalid." % [rows[index].id, predecessor]
			return []
	return rows


func parse_mission_json(text: String, expected_id: String) -> MissionDefinition:
	last_error = ""
	if not _is_identifier(expected_id):
		return _fail("Expected mission ID must contain only letters, numbers, underscores, or hyphens.")
	var data := _parse_object(text, "Mission JSON")
	if not last_error.is_empty():
		return null
	for field: String in ["id", "title", "objective_text", "budget_credits", "reward_credits", "scenario", "allowed_part_ids", "required_part_ids", "win_conditions", "discovery_ids"]:
		if not data.has(field):
			return _fail("Missing required mission field '%s'." % field)
	for field: String in ["id", "title", "objective_text"]:
		if not _is_nonempty_text(data[field]):
			return _fail("Mission field '%s' must be a nonempty string." % field)
	if data.id != expected_id:
		return _fail("Mission ID '%s' does not match requested ID '%s'." % [data.id, expected_id])
	if not _is_integer_at_least(data.budget_credits, 1.0):
		return _fail("Mission budget_credits must be a positive integer.")
	if not _is_integer_at_least(data.reward_credits, 0.0):
		return _fail("Mission reward_credits must be a nonnegative integer.")
	if not data.scenario is Dictionary:
		return _fail("Mission scenario must be an object.")
	var scenario: Dictionary = data.scenario
	for field: String in ["body_id", "spawn_profile"]:
		if not scenario.has(field) or not _is_nonempty_text(scenario[field]):
			return _fail("Mission scenario.%s must be a nonempty string." % field)
	for field: String in ["allowed_part_ids", "required_part_ids", "discovery_ids"]:
		if not data[field] is Array:
			return _fail("Mission field '%s' must be an array of string IDs." % field)
		for item: Variant in data[field]:
			if not _is_identifier(item):
				return _fail("Mission field '%s' must contain nonempty string IDs using letters, numbers, underscores, or hyphens." % field)
	var objective_type: Variant = data.get("objective_type", "reach_altitude")
	if not objective_type is String or not OBJECTIVE_FIELDS.has(objective_type):
		return _fail("Mission objective_type must be one of: reach_altitude, stable_orbit, lunar_flyby, safe_landing.")
	if not data.win_conditions is Dictionary:
		return _fail("Mission win_conditions must be an object.")
	var conditions: Dictionary = data.win_conditions
	if not _validate_win_conditions(conditions, objective_type):
		return null
	var payload: Variant = data.get("payload", {})
	if not payload is Dictionary:
		return _fail("Mission payload must be an object when supplied.")
	if not payload.is_empty():
		if not _is_nonempty_text(payload.get("name")):
			return _fail("Mission payload.name must be a nonempty string.")
		if payload.has("required") and not payload.required is bool:
			return _fail("Mission payload.required must be a boolean.")
		if payload.has("part_id") and not _is_identifier(payload.part_id):
			return _fail("Mission payload.part_id must be a safe string ID.")
	var mission := MissionDefinition.new()
	mission.id = data.id
	mission.title = data.title
	mission.objective_text = data.objective_text
	mission.objective_type = objective_type
	mission.payload = payload.duplicate(true)
	mission.budget_credits = int(data.budget_credits)
	mission.reward_credits = int(data.reward_credits)
	mission.scenario = scenario.duplicate(true)
	mission.win_conditions = conditions.duplicate(true)
	mission.allowed_part_ids.assign(data.allowed_part_ids)
	mission.required_part_ids.assign(data.required_part_ids)
	mission.discovery_ids.assign(data.discovery_ids)
	return mission


func _validate_win_conditions(conditions: Dictionary, objective_type: String) -> bool:
	var fields: Array = OBJECTIVE_FIELDS[objective_type]
	for field: Variant in conditions:
		if field not in fields:
			last_error = "Unsupported win condition '%s' for objective_type '%s'." % [field, objective_type]
			return false
	for field: String in fields:
		if field in ["require_intact_pod", "require_landing_legs"]:
			if not conditions.has(field) or not conditions[field] is bool:
				last_error = "Mission win_conditions.%s must be a boolean (true or false)." % field
				return false
		elif not conditions.has(field) or not _is_positive_number(conditions[field]):
			last_error = "Mission win_conditions.%s must be a positive finite number." % field
			return false
	if objective_type == "stable_orbit" and float(conditions.max_apoapsis_m) < float(conditions.min_periapsis_m):
		last_error = "Mission max_apoapsis_m must be at least min_periapsis_m."
		return false
	if objective_type == "lunar_flyby" and float(conditions.max_altitude_m) <= float(conditions.min_altitude_m):
		last_error = "Mission max_altitude_m must be greater than min_altitude_m."
		return false
	if objective_type == "safe_landing" and float(conditions.max_orientation_deg) > 180.0:
		last_error = "Mission max_orientation_deg must not exceed 180 degrees."
		return false
	return true


func _parse_object(text: String, label: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(text) != OK:
		last_error = "Invalid JSON at line %d: %s" % [parser.get_error_line() + 1, parser.get_error_message()]
		return {}
	if not parser.data is Dictionary:
		last_error = "%s must contain an object at its root." % label
		return {}
	return parser.data


func _is_identifier(value: Variant) -> bool:
	return value is String and _identifier_pattern.search(value) != null


func _is_nonempty_text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()


func _is_integer_at_least(value: Variant, minimum: float) -> bool:
	if not value is int and not value is float:
		return false
	var number := float(value)
	return is_finite(number) and number >= minimum and number <= MAX_EXACT_JSON_INTEGER and floor(number) == number


func _is_positive_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0


func _fail(message: String) -> MissionDefinition:
	last_error = message
	return null
