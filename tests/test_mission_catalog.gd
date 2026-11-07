extends SceneTree

var _failures: int = 0
var _checks: int = 0
var _catalog := MissionCatalog.new()
var _valid_json: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_valid_json = FileAccess.get_file_as_string("res://data/missions/m01.json")
	var mission := _catalog.load_mission("M01")
	_check(mission != null, "Load unchanged M01 data.")
	if mission == null:
		push_error(_catalog.last_error)
		quit(1)
		return
	_check(mission.id == "M01" and mission.budget_credits == 2000 and mission.reward_credits == 1000, "Preserve M01 ID, budget, and reward.")
	_check(mission.win_conditions.min_altitude_m == 100000 and mission.win_conditions.require_intact_pod, "Preserve M01 reach-altitude objective.")
	_check(_catalog.last_error.is_empty(), "Successful load clears diagnostics.")

	for id: String in ["", "../m01", "M01/../../secret", "M01.json", " M01", "M01\\other"]:
		_check(_catalog.load_mission(id) == null and not _catalog.last_error.is_empty(), "Reject unsafe mission ID: %s" % id)
	_check(_catalog.load_mission("MISSING_MISSION") == null and _catalog.last_error.contains("not listed"), "An unlisted mission reports a readable error.")
	_check(_catalog.parse_mission_json(_valid_json, "") == null, "Parser rejects an empty expected ID.")
	_check(_catalog.parse_mission_json("{\n  \"id\": }", "M01") == null and _catalog.last_error.contains("line 2"), "Malformed JSON reports its line number: %s" % _catalog.last_error)
	for text: String in ["[]", "null", "42", "true", "\"mission\""]:
		_check(_catalog.parse_mission_json(text, "M01") == null and _catalog.last_error.contains("root"), "Reject a non-object root: %s" % text)
	_check(_catalog.parse_mission_json(_valid_json, "M02") == null and _catalog.last_error.contains("does not match"), "Reject a mismatched mission ID.")

	for field: String in ["id", "title", "objective_text", "budget_credits", "reward_credits", "scenario", "allowed_part_ids", "required_part_ids", "win_conditions", "discovery_ids"]:
		var data := _valid_data()
		data.erase(field)
		_reject(data, field, "Missing required field %s." % field)
	for field: String in ["id", "title", "objective_text"]:
		for value: Variant in [null, 10, false, [], {}, "", "  "]:
			_reject_field(field, value)
	for value: Variant in [-1, 0, 1.5, "2000", false, null, [], {}]:
		_reject_field("budget_credits", value)
	for value: Variant in [-1, 1.5, "1000", false, null, [], {}]:
		_reject_field("reward_credits", value)
	var no_reward := _valid_data()
	no_reward.reward_credits = 0
	_check(_catalog.parse_mission_json(JSON.stringify(no_reward), "M01") != null, "Zero reward is valid.")

	for value: Variant in [null, false, [], "earth"]:
		_reject_field("scenario", value)
	for field: String in ["body_id", "spawn_profile"]:
		var missing := _valid_data()
		missing.scenario.erase(field)
		_reject(missing, "scenario.%s" % field, "Require scenario.%s." % field)
		for value: Variant in [null, 10, false, [], {}, "", " "]:
			var data := _valid_data()
			data.scenario[field] = value
			_reject(data, "scenario.%s" % field, "Reject invalid scenario.%s." % field)

	for field: String in ["allowed_part_ids", "required_part_ids", "discovery_ids"]:
		for value: Variant in [null, "POD_A", {}, 1, [null], [1], [false], [""], ["../POD_A"]]:
			_reject_field(field, value)
	for value: Variant in [null, false, [], "reach altitude"]:
		_reject_field("win_conditions", value)
	for field: String in ["min_altitude_m", "require_intact_pod"]:
		var data := _valid_data()
		data.win_conditions.erase(field)
		_reject(data, field, "Require objective field %s." % field)
	for value: Variant in [-1, 0, null, "100000", true, [], {}]:
		var data := _valid_data()
		data.win_conditions.min_altitude_m = value
		_reject(data, "min_altitude_m", "Reject invalid target altitude.")
	for value: Variant in [0, 1, null, "true", [], {}]:
		var data := _valid_data()
		data.win_conditions.require_intact_pod = value
		_reject(data, "require_intact_pod", "Reject a non-boolean intact-pod rule.")
	var unsupported := _valid_data()
	unsupported.win_conditions.orbit_required = true
	_reject(unsupported, "Unsupported win condition", "Reject unsupported objectives instead of silently ignoring them.")
	_check(_catalog.parse_mission_json(_valid_json.replace("100000", "1e999"), "M01") == null, "Reject a non-finite target altitude.")
	_check(_catalog.parse_mission_json(_valid_json.replace("2000", "1e999"), "M01") == null, "Reject a non-finite budget.")

	var first := _catalog.parse_mission_json(_valid_json, "M01")
	first.scenario.body_id = "changed"
	first.win_conditions.min_altitude_m = 1
	first.allowed_part_ids.clear()
	first.required_part_ids.clear()
	first.discovery_ids.append("CHANGED")
	var second := _catalog.load_mission("M01")
	_check(second.scenario.body_id == "earth" and second.win_conditions.min_altitude_m == 100000, "Loaded mission dictionaries are independent.")
	_check(second.allowed_part_ids.size() == 4 and second.required_part_ids == ["POD_A"] and second.discovery_ids.is_empty(), "Loaded mission arrays are independent.")
	_check(_catalog.last_error.is_empty(), "A successful reload clears old validation errors.")
	_test_mission_index()
	_test_objective_types()
	_test_missing_catalog_files()

	var manager := MissionManager.new()
	_check(manager.load_mission("M01"), "MissionManager uses the validated catalog.")
	_check(not manager.load_mission("MISSING_MISSION") and manager.definition == null, "Failed reload clears the previous definition.")
	_check(not manager.last_error.is_empty() and manager.finalize_result().mission_id.is_empty(), "Failed reload resets the result and keeps a diagnostic.")
	_check(manager.load_mission("M01") and manager.last_error.is_empty(), "MissionManager recovers after a failed reload.")

	if _failures == 0:
		print("Mission catalog: %d checks passed." % _checks)
	quit(0 if _failures == 0 else 1)


func _valid_data() -> Dictionary:
	return JSON.parse_string(_valid_json)


func _test_mission_index() -> void:
	var missions := _catalog.get_mission_list()
	_check(missions.size() == 4 and _catalog.last_error.is_empty(), "All four indexed mission files load together.")
	if missions.size() != 4:
		return
	var expected_ids := ["M01", "M02", "M03", "M04"]
	var expected_requirements := ["", "M01", "M02", "M02"]
	var expected_budgets := [2000, 4500, 7500, 10000]
	var expected_rewards := [1000, 2000, 2500, 4000]
	for index in missions.size():
		var mission := missions[index]
		_check(mission.id == expected_ids[index], "Keep explicit mission-list order.")
		_check(mission.unlock_requirement == expected_requirements[index], "Merge prerequisite metadata for %s." % mission.id)
		_check(mission.budget_credits == expected_budgets[index] and mission.reward_credits == expected_rewards[index], "Preserve %s budget and reward." % mission.id)
		_check(not mission.starting_location.is_empty() and not mission.destination.is_empty() and mission.released, "Merge display metadata for %s." % mission.id)
	_check(missions[0].objective_type == "reach_altitude", "Infer the unchanged M01 objective type.")
	_check(missions[3].scenario.body_id == "moon", "M04 starts near the Moon.")
	missions[0].starting_location = "changed"
	_check(_catalog.load_mission("M01").starting_location == "Earth surface", "Individual loads include fresh index metadata.")
	var index_text := FileAccess.get_file_as_string("res://data/missions/index.json")
	_check(_catalog.parse_mission_index_json("{\n  \"missions\": } ").is_empty() and _catalog.last_error.contains("line 2"), "Malformed index JSON reports its line number.")
	for value: Variant in [null, [], 5, true, "index", {}, {"missions": null}, {"missions": {}}, {"missions": []}, {"missions": [null]}]:
		_reject_index(value, "", "Reject invalid mission-index shape.")
	for field: String in ["id", "unlock_requirement", "starting_location", "destination"]:
		var data: Dictionary = JSON.parse_string(index_text)
		data.missions[0].erase(field)
		_reject_index(data, field, "Reject missing index field %s." % field)
	for field: String in ["id", "starting_location", "destination"]:
		for value: Variant in [null, 5, false, [], {}, "", " "]:
			var data: Dictionary = JSON.parse_string(index_text)
			data.missions[0][field] = value
			_reject_index(data, "", "Reject invalid index %s." % field)
	for value: Variant in [5, false, [], {}, "", "../M01"]:
		var data: Dictionary = JSON.parse_string(index_text)
		data.missions[1].unlock_requirement = value
		_reject_index(data, "unlock_requirement", "Reject invalid prerequisite type or ID.")
	for value: Variant in [null, 1, "true", [], {}]:
		var data: Dictionary = JSON.parse_string(index_text)
		data.missions[0].released = value
		_reject_index(data, "released", "Reject non-boolean release flags.")
	for duplicate: String in ["M01", "m01"]:
		var data: Dictionary = JSON.parse_string(index_text)
		data.missions[1].id = duplicate
		_reject_index(data, "Duplicate", "Reject duplicate IDs and lowercase filename collisions.")
	var unknown: Dictionary = JSON.parse_string(index_text)
	unknown.missions[1].unlock_requirement = "M99"
	_reject_index(unknown, "unknown", "Reject unknown prerequisite IDs.")
	var self_reference: Dictionary = JSON.parse_string(index_text)
	self_reference.missions[1].unlock_requirement = "M02"
	_reject_index(self_reference, "cycles", "Reject self-referencing prerequisites.")
	var cycle: Dictionary = JSON.parse_string(index_text)
	cycle.missions[0].unlock_requirement = "M02"
	_reject_index(cycle, "cycles", "Reject prerequisite cycles.")
	var forward: Dictionary = JSON.parse_string(index_text)
	forward.missions[1].unlock_requirement = "M03"
	forward.missions[2].unlock_requirement = null
	_reject_index(forward, "earlier", "Reject prerequisites listed after their dependent mission.")
	var optional_release: Dictionary = JSON.parse_string(index_text)
	optional_release.missions[0].erase("released")
	optional_release.missions[3].released = false
	_check(_catalog.parse_mission_index_json(JSON.stringify(optional_release)).size() == 4, "Release flags are optional and unreleased metadata remains valid.")


func _test_objective_types() -> void:
	for id: String in ["M02", "M03", "M04"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/missions/%s.json" % id.to_lower()))
		var mission := _catalog.parse_mission_json(JSON.stringify(data), id)
		_check(mission != null and mission.objective_type == data.objective_type, "Load typed objective for %s." % id)
		for field: String in data.win_conditions.keys():
			var missing: Dictionary = data.duplicate(true)
			missing.win_conditions.erase(field)
			_reject_mission(missing, field, "Reject missing %s objective rule." % id)
			var values: Array = [0, 1, null, "true"] if data.win_conditions[field] is bool else [-1, 0, null, "10", true]
			for value: Variant in values:
				var invalid: Dictionary = data.duplicate(true)
				invalid.win_conditions[field] = value
				_reject_mission(invalid, field, "Reject invalid %s objective rule %s." % [id, field])
		var unknown: Dictionary = data.duplicate(true)
		unknown.win_conditions.unknown_rule = true
		_reject_mission(unknown, "Unsupported", "Reject unknown %s objective rules." % id)
		var omitted_type: Dictionary = data.duplicate(true)
		omitted_type.erase("objective_type")
		_reject_mission(omitted_type, "", "New objective shapes need an explicit type.")
	for value: Variant in [null, 5, "", "destroy_planet", [], {}]:
		_reject_field("objective_type", value)
	var orbit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/missions/m02.json"))
	orbit.win_conditions.max_apoapsis_m = 99999
	_reject_mission(orbit, "at least", "Reject inverted orbit bounds.")
	var flyby: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/missions/m03.json"))
	flyby.win_conditions.max_altitude_m = flyby.win_conditions.min_altitude_m
	_reject_mission(flyby, "greater", "Reject an empty flyby altitude band.")
	var landing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/missions/m04.json"))
	landing.win_conditions.max_orientation_deg = 181
	_reject_mission(landing, "180", "Reject an impossible maximum tilt.")
	for value: Variant in [null, [], "instrument", 5, {"name": ""}, {"name": "Instrument", "required": 1}, {"name": "Instrument", "part_id": "../part"}]:
		_reject_field("payload", value)
	var payload_mission := _catalog.load_mission("M03")
	_check(payload_mission.payload.name == "Lunar survey instrument" and payload_mission.payload.required, "M03 records its future science payload requirement.")
	payload_mission.payload.name = "changed"
	_check(_catalog.load_mission("M03").payload.name == "Lunar survey instrument", "Payload metadata is independent across loads.")


func _test_missing_catalog_files() -> void:
	var directory := "user://mission_catalog_fixture_%d" % Time.get_ticks_usec()
	var absolute_directory := ProjectSettings.globalize_path(directory)
	var absent := MissionCatalog.new(directory)
	_check(absent.get_mission_list().is_empty() and absent.last_error.contains("index"), "Missing index returns no missions and a diagnostic.")
	_check(DirAccess.make_dir_recursive_absolute(absolute_directory) == OK, "Create an isolated mission fixture folder.")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/missions/index.json"))
	data.missions.resize(2)
	var index_file := FileAccess.open(directory.path_join("index.json"), FileAccess.WRITE)
	index_file.store_string(JSON.stringify(data))
	index_file.close()
	var mission_file := FileAccess.open(directory.path_join("m01.json"), FileAccess.WRITE)
	mission_file.store_string(_valid_json)
	mission_file.close()
	_check(absent.get_mission_list().is_empty() and absent.last_error.contains("M02"), "A missing later mission file returns no partial list.")
	_check(absent.load_mission("M01") == null and absent.last_error.contains("M02"), "An individual load also validates the complete catalog.")
	var invalid_file := FileAccess.open(directory.path_join("m02.json"), FileAccess.WRITE)
	invalid_file.store_string("{\n invalid }")
	invalid_file.close()
	_check(absent.get_mission_list().is_empty() and absent.last_error.contains("m02.json") and absent.last_error.contains("line 2"), "A malformed later mission returns no partial list and identifies its file and line.")
	for filename: String in ["index.json", "m01.json", "m02.json"]:
		DirAccess.remove_absolute(absolute_directory.path_join(filename))
	DirAccess.remove_absolute(absolute_directory)


func _reject_index(data: Variant, diagnostic: String, description: String) -> void:
	var rows := _catalog.parse_mission_index_json(JSON.stringify(data))
	_check(rows.is_empty() and not _catalog.last_error.is_empty() and (diagnostic.is_empty() or _catalog.last_error.contains(diagnostic)), description)


func _reject_mission(data: Dictionary, diagnostic: String, description: String) -> void:
	var result := _catalog.parse_mission_json(JSON.stringify(data), data.id)
	_check(result == null and not _catalog.last_error.is_empty() and (diagnostic.is_empty() or _catalog.last_error.contains(diagnostic)), description)


func _reject_field(field: String, value: Variant) -> void:
	var data := _valid_data()
	data[field] = value
	_reject(data, field, "Reject invalid %s: %s" % [field, str(value)])


func _reject(data: Dictionary, diagnostic: String, description: String) -> void:
	var result := _catalog.parse_mission_json(JSON.stringify(data), "M01")
	_check(result == null and _catalog.last_error.contains(diagnostic), description)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
