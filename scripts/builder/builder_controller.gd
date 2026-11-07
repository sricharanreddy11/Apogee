class_name BuilderController
extends Control

signal launch_requested(config: RocketConfig)
signal back_requested

const PARTS_PATH := "res://data/parts.json"

var _mission: MissionDefinition
var _parts: Dictionary = {}


func setup(mission: MissionDefinition) -> void:
	_mission = mission
	_parts.clear()
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
		_parts[part["id"]] = part


func build_config() -> RocketConfig:
	# TODO(Member 2): Build this config from the player's current selection.
	var config := RocketConfig.new()
	config.rocket_name = "Sparrow I"
	config.command_pod_id = "POD_A"
	var stage_config := StageConfig.new()
	stage_config.engine_id = "ENG_L"
	stage_config.tank_ids.append("TANK_L")
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
	if config.command_pod_id.is_empty() or config.stages.is_empty():
		errors.append("Add a command pod and a propulsion stage.")
	for stage_config in config.stages:
		if stage_config.engine_id.is_empty() or stage_config.tank_ids.is_empty():
			errors.append("Each stage needs an engine and a fuel tank.")
	var part_ids := _part_ids(config)
	for part_id in part_ids:
		if not _parts.has(part_id):
			errors.append("Unknown part %s." % part_id)
		elif not mission.allowed_part_ids.is_empty() and not mission.allowed_part_ids.has(part_id):
			errors.append("%s is unavailable for this mission." % part_id)
	for part_id in mission.required_part_ids:
		if not part_ids.has(part_id):
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
	var config := build_config()
	var launch: Button = %Primary
	if _mission == null:
		%Details.text = "Open this screen from the main menu to load a mission."
		launch.disabled = true
	else:
		var stats := calculate(config)
		var validation := validate(config, _mission)
		%Details.text = "%s\nCommand pod + large tank + launch engine\n%d / %d credits  |  %.0f kg wet  |  %.0f kg fuel" % [
			config.rocket_name, stats.cost_credits, _mission.budget_credits,
			stats.wet_mass_kg, stats.fuel_kg,
		]
		if not validation.valid:
			%Details.text += "\n" + "\n".join(validation.errors)
			launch.disabled = true
		launch.pressed.connect(func() -> void: launch_requested.emit(config.copy()))
	%Secondary.pressed.connect(func() -> void: back_requested.emit())
