class_name BuilderController
extends Control

signal launch_requested(config: RocketConfig)
signal back_requested

const PARTS_PATH := "res://data/parts.json"
const DEFAULT_PARTS := {"pod": "POD_A", "tank": "TANK_L", "engine": "ENG_L"}

var _mission: MissionDefinition
var _parts: Dictionary = {}
var _artwork: Dictionary = {}
var _selected_parts := {"pod": "", "tank": "", "engine": ""}


func setup(mission: MissionDefinition) -> void:
	_mission = mission
	_parts.clear()
	_artwork.clear()
	_selected_parts = {"pod": "", "tank": "", "engine": ""}
	var data := JsonData.read_object(PARTS_PATH)
	var rows: Variant = data.get("parts")
	if not rows is Array:
		push_error("Expected a parts array in %s." % PARTS_PATH)
		return
	for part in rows:
		if not part is Dictionary or not part.has("id"):
			push_error("Expected a part object with an ID in %s." % PARTS_PATH)
			_parts.clear()
			return
		var part_id := String(part["id"])
		_parts[part_id] = part
		var art_path := "res://assets/rockets/%s.svg" % part_id.to_lower()
		if ResourceLoader.exists(art_path):
			_artwork[part_id] = load(art_path)
	_reset_assembly()


func build_config() -> RocketConfig:
	var config := RocketConfig.new()
	config.rocket_name = "Sparrow I" if _selected_parts == DEFAULT_PARTS else "Custom rocket"
	config.command_pod_id = _selected_parts.pod
	var stage_config := StageConfig.new()
	stage_config.engine_id = _selected_parts.engine
	if not String(_selected_parts.tank).is_empty():
		stage_config.tank_ids.append(_selected_parts.tank)
	config.stages.append(stage_config)
	return config


func calculate(config: RocketConfig) -> Dictionary:
	var totals := {"cost_credits": 0, "dry_mass_kg": 0.0, "fuel_kg": 0.0}
	for part_id in _part_ids(config):
		var part: Dictionary = _parts.get(part_id, {})
		totals.cost_credits += int(part.get("cost_credits", 0))
		totals.dry_mass_kg += float(part.get("dry_mass_kg", 0.0))
		totals.fuel_kg += float(part.get("fuel_capacity_kg", 0.0))
	totals["wet_mass_kg"] = totals.dry_mass_kg + totals.fuel_kg
	return totals


func validate(config: RocketConfig, mission: MissionDefinition) -> Dictionary:
	var errors: Array[String] = []
	if config.command_pod_id.is_empty():
		errors.append("Add a command pod.")
	if config.stages.is_empty():
		errors.append("Add a propulsion stage.")
	for stage_config in config.stages:
		if stage_config.engine_id.is_empty():
			errors.append("Add an engine to each stage.")
		if stage_config.tank_ids.is_empty():
			errors.append("Add a fuel tank to each stage.")
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
	if int(calculate(config).cost_credits) > mission.budget_credits:
		errors.append("The build exceeds the mission budget.")
	# TODO(Member 2): Enforce part types and stack rules. Add engineering warnings.
	return {"valid": errors.is_empty(), "errors": errors, "warnings": []}


func _part_ids(config: RocketConfig) -> Array[String]:
	var ids: Array[String] = [config.command_pod_id]
	for stage_config in config.stages:
		ids.append(stage_config.engine_id)
		ids.append_array(stage_config.tank_ids)
	ids.append_array(config.attachment_ids)
	return ids


func _ready() -> void:
	%RocketPreview.accepts_part = _accepts_part
	%RocketPreview.part_dropped.connect(_install_part)
	%RocketPreview.part_removed.connect(_remove_part)
	%Reset.pressed.connect(_reset_assembly)
	%Clear.pressed.connect(_clear_assembly)
	%Primary.pressed.connect(_launch)
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
	if _accepts_part(slot, part_id):
		_selected_parts[slot] = part_id
		_refresh_build()


func _remove_part(slot: String) -> void:
	_selected_parts[slot] = ""
	_refresh_build()


func _clear_assembly() -> void:
	for slot in _selected_parts:
		_selected_parts[slot] = ""
	_refresh_build()


func _reset_assembly() -> void:
	for slot: String in DEFAULT_PARTS:
		var part_id: String = DEFAULT_PARTS[slot]
		_selected_parts[slot] = part_id if _accepts_part(slot, part_id) else ""
	if is_node_ready():
		_refresh_build()


func _is_allowed(part_id: String) -> bool:
	return _mission != null and (_mission.allowed_part_ids.is_empty() or _mission.allowed_part_ids.has(part_id))


func _refresh_build() -> void:
	var config := build_config()
	var stats := calculate(config)
	var parts_by_slot := {}
	var art_by_slot := {}
	var installed := 0
	for slot: String in _selected_parts:
		var part_id: String = _selected_parts[slot]
		if not part_id.is_empty():
			installed += 1
			parts_by_slot[slot] = _parts[part_id]
			art_by_slot[slot] = _artwork.get(part_id)
	%CraftName.text = "%s\n%d of 3 modules" % [config.rocket_name, installed]
	%RocketPreview.show_parts(parts_by_slot, art_by_slot)
	if _mission == null:
		%Details.text = "Use F5 and choose Build a rocket to start First Flight."
		%Primary.disabled = true
		%Clear.disabled = true
		%Reset.disabled = true
		return

	var cost := int(stats.cost_credits)
	%MissionTag.text = "ASSEMBLY BAY    /    %s  %s" % [_mission.id, _mission.title.to_upper()]
	%BudgetValue.text = "%d / %d CR" % [cost, _mission.budget_credits]
	%BudgetBar.max_value = maxi(1, _mission.budget_credits)
	%BudgetBar.value = cost
	%BudgetBar.modulate = Color("#ff767e") if cost > _mission.budget_credits else Color.WHITE
	%Details.text = "%d CR remaining\n%.0f kg dry mass\n%.0f kg wet mass\n%.0f kg fuel" % [
		_mission.budget_credits - cost, stats.dry_mass_kg, stats.wet_mass_kg, stats.fuel_kg,
	]
	var validation := validate(config, _mission)
	%Primary.disabled = not validation.valid
	%BuildStatus.text = "READY FOR FLIGHT PREVIEW" if validation.valid else "\n".join(validation.errors)
	%BuildStatus.modulate = Color("#72e6af") if validation.valid else Color("#ffb454")


func _launch() -> void:
	var config := build_config()
	if _mission != null and validate(config, _mission).valid:
		launch_requested.emit(config)
