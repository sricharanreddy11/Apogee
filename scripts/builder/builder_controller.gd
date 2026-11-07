class_name BuilderController
extends Control

## One navigation owner receives this detached design after fresh validation.
signal configuration_confirmed(config: RocketConfig)
signal back_requested

const PARTS_PATH := "res://data/parts.json"
const DEFAULT_PARTS := {"pod": "POD_A", "tank": "TANK_L", "engine": "ENG_L"}

var _mission: MissionDefinition
var _parts: Dictionary = {}
var _artwork: Dictionary = {}
var _selected_parts := {"pod": "", "tank": "", "engine": ""}
var _config: RocketConfig
var _catalog_error: String = ""


func setup(mission: MissionDefinition) -> void:
	_mission = mission
	_parts.clear()
	_artwork.clear()
	_catalog_error = ""
	_selected_parts = {"pod": "", "tank": "", "engine": ""}
	var data := JsonData.read_object(PARTS_PATH)
	var rows: Variant = data.get("parts")
	if not rows is Array:
		_catalog_error = "Expected a parts array in data/parts.json."
		return
	for part in rows:
		if not part is Dictionary or not part.get("id") is String or not part.get("type") is String:
			_catalog_error = "Each catalog part needs an ID and type in data/parts.json."
			_parts.clear()
			return
		var part_id := String(part["id"])
		_parts[part_id] = part
		var art_path := "res://assets/rockets/%s.svg" % part_id.to_lower()
		if ResourceLoader.exists(art_path):
			_artwork[part_id] = load(art_path)
	_reset_assembly()


func load_config(config: RocketConfig) -> void:
	# Keep the whole design, including invalid unsupported arrangements, so the
	# validator can explain them instead of silently flattening the chosen rocket.
	_config = config.copy() if config != null else null
	if _config == null:
		_reset_assembly()
	_sync_selected_parts()
	if is_node_ready():
		%RocketName.text = _config.rocket_name
		_refresh_build()


func build_config() -> RocketConfig:
	if _config == null:
		_reset_assembly()
	return _config.copy()


func calculate(config: RocketConfig) -> Dictionary:
	var totals := {"cost_credits": 0, "dry_mass_kg": 0.0, "fuel_kg": 0.0, "wet_mass_kg": 0.0, "launch_twr": 0.0}
	if config == null:
		return totals
	for part_id in _part_ids(config):
		var part: Dictionary = _parts.get(part_id, {})
		totals.cost_credits += int(part.get("cost_credits", 0))
		totals.dry_mass_kg += float(part.get("dry_mass_kg", 0.0))
		totals.fuel_kg += float(part.get("fuel_capacity_kg", 0.0))
	totals["wet_mass_kg"] = totals.dry_mass_kg + totals.fuel_kg
	if not config.stages.is_empty() and config.stages[0] != null and totals.wet_mass_kg > 0.0:
		var engine: Dictionary = _parts.get(config.stages[0].engine_id, {})
		var body_id := String(_mission.scenario.get("body_id", "earth")) if _mission != null else "earth"
		var bodies: Dictionary = JsonData.read_object("res://data/planets.json").get("bodies", {})
		var body: Dictionary = bodies.get(body_id, {})
		var gravity := float(body.get("surface_gravity_mps2", 9.81))
		if gravity > 0.0:
			totals.launch_twr = float(engine.get("thrust_n", 0.0)) / (float(totals.wet_mass_kg) * gravity)
	return totals


func validate(config: RocketConfig, mission: MissionDefinition) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if config == null:
		errors.append("No rocket configuration was supplied.")
		return {"valid": false, "errors": errors, "warnings": warnings}
	if mission == null:
		errors.append("Select a mission before preparing launch.")
		return {"valid": false, "errors": errors, "warnings": warnings}
	if not _catalog_error.is_empty():
		errors.append(_catalog_error)
	if _parts.is_empty():
		errors.append("The parts catalog is unavailable.")
	_check_part_type(config.command_pod_id, "pod", "command pod", errors)
	if config.stages.is_empty():
		errors.append("Add one propulsion stage with an engine and fuel tank.")
	elif config.stages.size() > 1:
		errors.append("Vehicle lab supports one stage. Restore Sparrow I to replace this unsupported arrangement.")
	for index in config.stages.size():
		var stage_config := config.stages[index]
		if stage_config == null:
			errors.append("Stage %d is missing. Install an engine and fuel tank, or restore Sparrow I." % (index + 1))
			continue
		_check_part_type(stage_config.engine_id, "engine", "stage %d engine" % (index + 1), errors)
		if stage_config.tank_ids.is_empty():
			errors.append("Stage %d needs a fuel tank." % (index + 1))
		elif stage_config.tank_ids.size() > 1:
			errors.append("Vehicle lab has one fuel-tank mount. Choose one tank or restore Sparrow I to replace this unsupported stack.")
		for tank_id in stage_config.tank_ids:
			_check_part_type(tank_id, "tank", "stage %d fuel tank" % (index + 1), errors)
	for attachment_id in config.attachment_ids:
		if attachment_id.is_empty():
			errors.append("Attachment IDs cannot be empty.")
		var attachment: Dictionary = _parts.get(attachment_id, {})
		if not attachment.is_empty() and String(attachment.get("type", "")) not in ["attachment", "legs", "payload", "decoupler"]:
			errors.append("%s cannot be placed in an attachment slot." % attachment_id)
	var part_ids := _part_ids(config)
	for part_id in part_ids:
		if part_id.is_empty():
			continue
		if not _parts.has(part_id):
			errors.append("Unknown part %s." % part_id)
		elif not mission.allowed_part_ids.is_empty() and not mission.allowed_part_ids.has(part_id):
			errors.append("%s is unavailable for this mission." % part_id)
	for part_id in mission.required_part_ids:
		if not part_ids.has(part_id) and not (part_id == "POD_A" and config.command_pod_id.is_empty()):
			errors.append("Add required part %s." % part_id)
	var totals := calculate(config)
	if int(totals.cost_credits) > mission.budget_credits:
		errors.append("The build costs %d CR and exceeds the %d CR mission budget." % [totals.cost_credits, mission.budget_credits])
	if float(totals.launch_twr) > 0.0 and float(totals.launch_twr) <= 1.0:
		warnings.append("Launch thrust-to-weight is %.2f. The rocket may not lift off; use a lighter tank or a stronger engine." % totals.launch_twr)
	return {"valid": errors.is_empty(), "errors": errors, "warnings": warnings}


func show_validation_errors(errors: Array[String], warnings: Array[String] = []) -> void:
	if not is_node_ready():
		return
	%BuildStatus.text = "BUILD NEEDS ATTENTION\n" + "\n".join(errors)
	if not warnings.is_empty():
		%BuildStatus.text += "\nWARNING: " + "\n".join(warnings)
	%BuildStatus.modulate = Color("#ffb454")
	%Primary.disabled = true


func _check_part_type(part_id: String, expected_type: String, slot_name: String, errors: Array[String]) -> void:
	if part_id.is_empty():
		errors.append("Add a %s." % slot_name)
	elif _parts.has(part_id) and String(_parts[part_id].get("type", "")) != expected_type:
		errors.append("%s is not a valid %s (expected %s)." % [part_id, slot_name, expected_type])


func _part_ids(config: RocketConfig) -> Array[String]:
	var ids: Array[String] = [config.command_pod_id]
	for stage_config in config.stages:
		if stage_config == null:
			continue
		ids.append(stage_config.engine_id)
		ids.append_array(stage_config.tank_ids)
	ids.append_array(config.attachment_ids)
	return ids


func _ready() -> void:
	%RocketName.text = build_config().rocket_name
	%RocketName.text_changed.connect(_on_name_changed)
	%RocketPreview.accepts_part = _accepts_part
	%RocketPreview.part_dropped.connect(_install_part)
	%RocketPreview.part_removed.connect(_remove_part)
	%Reset.pressed.connect(_reset_assembly)
	%Clear.pressed.connect(_clear_assembly)
	%Primary.pressed.connect(_prepare_launch)
	%Secondary.pressed.connect(func() -> void: back_requested.emit())
	_populate_catalog()
	_refresh_build()


func _populate_catalog() -> void:
	for part_id: String in _parts:
		if _is_allowed(part_id):
			var part: Dictionary = _parts[part_id]
			%Carousel.add_part(part, _artwork.get(part_id), _part_spec(part))


func _part_spec(part: Dictionary) -> String:
	match part.type:
		"tank":
			return "%d kg fuel" % int(part.fuel_capacity_kg)
		"engine":
			return "%d kN" % int(float(part.thrust_n) / 1000.0)
		_:
			return "%d kg dry" % int(part.dry_mass_kg)


func _accepts_part(slot: String, part_id: String) -> bool:
	var part: Dictionary = _parts.get(part_id, {})
	return _selected_parts.has(slot) and part.get("type") == slot and _is_allowed(part_id)


func _install_part(slot: String, part_id: String) -> void:
	install_part(slot, part_id)


func install_part(slot: String, part_id: String) -> bool:
	if not _accepts_part(slot, part_id):
		return false
	if _config == null:
		_reset_assembly()
	if slot == "pod":
		_config.command_pod_id = part_id
	else:
		var stage_config := _editable_stage()
		if slot == "engine":
			stage_config.engine_id = part_id
		elif slot == "tank":
			# Replacing this mount is an explicit user edit, not a load-time flatten.
			stage_config.tank_ids.assign([part_id])
	_sync_selected_parts()
	if is_node_ready():
		_refresh_build()
	return true


func _remove_part(slot: String) -> void:
	remove_part(slot)


func remove_part(slot: String) -> void:
	if not _selected_parts.has(slot) or _config == null:
		return
	if slot == "pod":
		_config.command_pod_id = ""
	else:
		var stage_config := _editable_stage()
		if slot == "engine":
			stage_config.engine_id = ""
		elif slot == "tank":
			stage_config.tank_ids.clear()
	_sync_selected_parts()
	if is_node_ready():
		_refresh_build()


func _editable_stage() -> StageConfig:
	if _config.stages.is_empty():
		_config.stages.append(StageConfig.new())
	elif _config.stages[0] == null:
		_config.stages[0] = StageConfig.new()
	return _config.stages[0]


func _sync_selected_parts() -> void:
	_selected_parts = {"pod": "", "tank": "", "engine": ""}
	if _config == null:
		return
	_selected_parts.pod = _config.command_pod_id
	if not _config.stages.is_empty() and _config.stages[0] != null:
		_selected_parts.engine = _config.stages[0].engine_id
		if not _config.stages[0].tank_ids.is_empty():
			_selected_parts.tank = _config.stages[0].tank_ids[0]


func _clear_assembly() -> void:
	var rocket_name := _config.rocket_name if _config != null else "Custom rocket"
	_config = RocketConfig.new()
	_config.rocket_name = rocket_name
	_config.stages.append(StageConfig.new())
	_sync_selected_parts()
	if is_node_ready():
		_refresh_build()


func _reset_assembly() -> void:
	_config = RocketConfig.new()
	_config.rocket_name = "Sparrow I"
	var stage_config := StageConfig.new()
	for slot: String in DEFAULT_PARTS:
		var part_id: String = DEFAULT_PARTS[slot]
		var accepted_id := part_id if _accepts_part(slot, part_id) else ""
		match slot:
			"pod":
				_config.command_pod_id = accepted_id
			"engine":
				stage_config.engine_id = accepted_id
			"tank":
				if not accepted_id.is_empty():
					stage_config.tank_ids.append(accepted_id)
	_config.stages.append(stage_config)
	_sync_selected_parts()
	if is_node_ready():
		%RocketName.text = _config.rocket_name
		_refresh_build()


func _is_allowed(part_id: String) -> bool:
	return _mission != null and (_mission.allowed_part_ids.is_empty() or _mission.allowed_part_ids.has(part_id))


func _refresh_build() -> void:
	if not is_node_ready():
		return
	var config := build_config()
	_sync_selected_parts()
	var stats := calculate(config)
	var parts_by_slot := {}
	var art_by_slot := {}
	var installed := 0
	for slot: String in _selected_parts:
		var part_id: String = _selected_parts[slot]
		if not part_id.is_empty() and _parts.has(part_id) and _parts[part_id].get("type") == slot:
			installed += 1
			parts_by_slot[slot] = _parts[part_id]
			art_by_slot[slot] = _artwork.get(part_id)
	%CraftName.text = "%d of 3 modules installed" % installed
	%RocketPreview.show_parts(parts_by_slot, art_by_slot)
	if _mission == null:
		%MissionTag.text = "ASSEMBLY BAY / NO MISSION SELECTED"
		%MissionBriefing.text = "Use F5 and select a mission from the main menu to start designing."
		%Details.text = "No mission loaded."
		%BuildStatus.text = "SELECT A MISSION FIRST"
		%Primary.disabled = true
		%Clear.disabled = true
		%Reset.disabled = true
		return
	%Clear.disabled = false
	%Reset.disabled = false

	var cost := int(stats.cost_credits)
	%MissionTag.text = "ASSEMBLY BAY    /    %s  %s" % [_mission.id, _mission.title.to_upper()]
	var body := String(_mission.scenario.get("body_id", "earth")).capitalize()
	var spawn := String(_mission.scenario.get("spawn_profile", "surface_north")).replace("_", " ")
	%MissionBriefing.text = "%s\nStart: %s / %s  |  Budget: %d CR  |  Reward: %d CR" % [
		_mission.objective_text, body, spawn, _mission.budget_credits, _mission.reward_credits,
	]
	%BudgetValue.text = "%d / %d CR" % [cost, _mission.budget_credits]
	%BudgetBar.max_value = maxi(1, _mission.budget_credits)
	%BudgetBar.value = cost
	%BudgetBar.modulate = Color("#ff767e") if cost > _mission.budget_credits else Color.WHITE
	%Details.text = "%d CR remaining\n%.0f kg dry mass\n%.0f kg wet mass\n%.0f kg fuel\n%.2f launch TWR" % [
		_mission.budget_credits - cost, stats.dry_mass_kg, stats.wet_mass_kg, stats.fuel_kg, stats.launch_twr,
	]
	var validation := validate(config, _mission)
	%Primary.disabled = not validation.valid
	%BuildStatus.text = "READY FOR PREFLIGHT" if validation.valid else "\n".join(validation.errors)
	if not validation.warnings.is_empty():
		%BuildStatus.text += "\nWARNING: " + "\n".join(validation.warnings)
	%BuildStatus.modulate = Color("#72e6af") if validation.valid else Color("#ffb454")


func _on_name_changed(value: String) -> void:
	_config.rocket_name = value.strip_edges()
	_refresh_build()


func _prepare_launch() -> void:
	# Synchronize the shown name and revalidate at the transition boundary.
	_config.rocket_name = %RocketName.text.strip_edges()
	if _config.rocket_name.is_empty():
		_config.rocket_name = "Untitled rocket"
		%RocketName.text = _config.rocket_name
	var config := build_config()
	var validation := validate(config, _mission)
	_refresh_build()
	if validation.valid:
		configuration_confirmed.emit(config)
