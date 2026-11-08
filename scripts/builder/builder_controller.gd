class_name BuilderController
extends Control

## One navigation owner receives this detached design after fresh validation.
signal configuration_confirmed(config: RocketConfig)
signal back_requested

const PARTS_PATH := "res://data/parts.json"
const MAX_STAGES := 2
const MAX_TANKS := 3

var _mission: MissionDefinition
var _parts: Dictionary = {}
var _artwork: Dictionary = {}
var _body: Dictionary = {}
var _workshop := false
var _config: RocketConfig
var _catalog_error: String = ""
var _last_part_ids: Array[String] = []
var _last_stats: Dictionary = {}
var _previous_stats: Dictionary = {}
var _comparison_key := ""


func setup(mission: MissionDefinition, workshop: bool = false) -> void:
	_mission = mission
	_last_part_ids.clear()
	_last_stats.clear()
	_previous_stats.clear()
	_comparison_key = ""
	_parts.clear()
	_artwork.clear()
	_catalog_error = ""
	_workshop = workshop
	var bodies: Dictionary = JsonData.read_object("res://data/planets.json").get("bodies", {})
	var body_id := String(mission.scenario.get("body_id", "earth")) if mission != null else "earth"
	_body = bodies.get(body_id, {})
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
	_start_empty()


func load_config(config: RocketConfig) -> void:
	# Keep the whole design, including invalid unsupported arrangements, so the
	# validator can explain them instead of silently flattening the chosen rocket.
	_config = config.copy() if config != null else null
	if _config == null:
		_start_empty()
	if is_node_ready():
		%RocketName.text = _config.rocket_name
		_refresh_build()


func build_config() -> RocketConfig:
	if _config == null:
		_start_empty()
	return _config.copy()


func calculate(config: RocketConfig) -> Dictionary:
	var totals := {"cost_credits": 0, "dry_mass_kg": 0.0, "fuel_kg": 0.0, "wet_mass_kg": 0.0, "launch_twr": 0.0, "delta_v_mps": 0.0}
	if config == null:
		return totals
	for part_id in _part_ids(config):
		var part: Dictionary = _parts.get(part_id, {})
		totals.cost_credits += int(part.get("cost_credits", 0))
		totals.dry_mass_kg += float(part.get("dry_mass_kg", 0.0))
		totals.fuel_kg += float(part.get("fuel_capacity_kg", 0.0))
	totals.wet_mass_kg = totals.dry_mass_kg + totals.fuel_kg
	var gravity := float(_body.get("surface_gravity_mps2", 9.81))
	if not config.stages.is_empty() and config.stages[0] != null and totals.wet_mass_kg > 0.0 and gravity > 0.0:
		var engine: Dictionary = _parts.get(config.stages[0].engine_id, {})
		totals.launch_twr = float(engine.get("thrust_n", 0.0)) / (float(totals.wet_mass_kg) * gravity)
	var remaining_mass := float(totals.wet_mass_kg)
	for index in config.stages.size():
		var stage_config := config.stages[index]
		if stage_config == null:
			continue
		var engine: Dictionary = _parts.get(stage_config.engine_id, {})
		var dry := float(engine.get("dry_mass_kg", 0.0))
		var propellant := 0.0
		for tank_id in stage_config.tank_ids:
			var tank: Dictionary = _parts.get(tank_id, {})
			dry += float(tank.get("dry_mass_kg", 0.0))
			propellant += float(tank.get("fuel_capacity_kg", 0.0))
		var burnout_mass := remaining_mass - propellant
		if burnout_mass > 0.0:
			totals.delta_v_mps += float(engine.get("isp_s", 0.0)) * 9.80665 * log(remaining_mass / burnout_mass)
		remaining_mass = burnout_mass - dry
		if index == 0 and config.attachment_ids.has("DECOUPLER"):
			var separator: Dictionary = _parts.get("DECOUPLER", {})
			remaining_mass -= float(separator.get("dry_mass_kg", 0.0))
	return totals


func _minimum_delta_v(mission: MissionDefinition) -> float:
	if mission.scenario.get("spawn_profile") != "surface_north":
		return 0.0
	var radius := float(_body.get("radius_m", 0.0))
	var mu := float(_body.get("mu_m3_s2", 0.0))
	if radius <= 0.0:
		return 0.0
	var is_orbit := mission.objective_type == "stable_orbit"
	var target := radius + float(mission.win_conditions.get("min_periapsis_m" if is_orbit else "min_altitude_m", 0.0))
	var target_speed_sq := mu / target if is_orbit else 0.0
	return sqrt(maxf(0.0, target_speed_sq + 2.0 * mu * (1.0 / radius - 1.0 / target)))


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
	if config.stages.is_empty() or config.stages.size() > MAX_STAGES:
		errors.append("Fit one or two propulsion stages.")
	for index in config.stages.size():
		var stage_config := config.stages[index]
		if stage_config == null:
			errors.append("Stage %d is missing." % (index + 1))
			continue
		_check_part_type(stage_config.engine_id, "engine", "stage %d engine" % (index + 1), errors)
		if stage_config.tank_ids.is_empty() or stage_config.tank_ids.size() > MAX_TANKS:
			errors.append("Stage %d needs 1–3 tanks." % (index + 1))
		for tank_id in stage_config.tank_ids:
			_check_part_type(tank_id, "tank", "stage %d fuel tank" % (index + 1), errors)
	var fitted := {}
	for attachment_id in config.attachment_ids:
		if attachment_id.is_empty():
			errors.append("Attachment IDs cannot be empty.")
			continue
		var attachment: Dictionary = _parts.get(attachment_id, {})
		if attachment.is_empty():
			continue
		var kind: String = attachment.type
		if kind not in ["legs", "payload", "decoupler"] or fitted.has(kind):
			errors.append("Invalid or duplicate attachment: %s." % attachment_id)
		fitted[kind] = true
	if config.stages.size() == 2 and not fitted.has("decoupler"):
		errors.append("Fit a separator between stages.")
	elif config.stages.size() == 1 and fitted.has("decoupler"):
		errors.append("A separator needs two stages.")
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
	if errors.is_empty():
		if mission.scenario.get("spawn_profile") == "surface_north" and float(totals.launch_twr) <= 1.0:
			warnings.append("Low thrust: %.2f TWR." % totals.launch_twr)
		if float(totals.delta_v_mps) < _minimum_delta_v(mission):
			warnings.append("Low Δv for this trajectory.")
	return {"valid": errors.is_empty(), "errors": errors, "warnings": warnings}


func show_validation_errors(errors: Array[String], warnings: Array[String] = []) -> void:
	if not is_node_ready():
		return
	%BuildStatus.text = "BUILD NEEDS ATTENTION\n" + "\n".join(errors)
	if not warnings.is_empty():
		%BuildStatus.text += "\nWARNING: " + "\n".join(warnings)
	%BuildStatus.theme_type_variation = &"WarningLabel"
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
	var console := preload("res://scripts/ui/console_button.gd")
	console.apply(%Primary, "primary")
	console.apply(%Secondary)
	console.apply(%Clear, "danger")
	console.apply(%Reset, "preset")
	console.apply(%Pioneer, "preset")
	console.apply(%AddStage, "utility")
	console.apply(%RemoveStage, "utility")
	%RocketName.text = build_config().rocket_name
	%RocketName.text_changed.connect(_on_name_changed)
	%RocketPreview.accepts_part = _accepts_part
	%RocketPreview.part_dropped.connect(install_part)
	%RocketPreview.part_removed.connect(remove_part)
	%RocketPreview.part_previewed.connect(_preview_part)
	%Reset.pressed.connect(_reset_assembly)
	%AddStage.pressed.connect(add_stage)
	%RemoveStage.pressed.connect(_remove_stage)
	%Pioneer.pressed.connect(_load_pioneer)
	%Primary.visible = not _workshop
	if _workshop:
		%Secondary.text = "‹ Chart"
	%Clear.pressed.connect(_clear_assembly)
	%Primary.pressed.connect(_prepare_launch)
	%Secondary.pressed.connect(func() -> void: back_requested.emit())
	_populate_catalog()
	_refresh_build()


func _populate_catalog() -> void:
	%Carousel.impact_provider = part_impact
	for part_id: String in _parts:
		if _is_allowed(part_id):
			var part: Dictionary = _parts[part_id]
			%Carousel.add_part(part, _artwork.get(part_id), _part_spec(part))


func part_impact(part_id: String) -> Dictionary:
	# Hover chooses an empty compatible mount first, then previews replacement.
	# The chosen action is explicit because a part can fit more than one stage.
	var candidates := _mounts()
	candidates.append(_mount("legs"))
	var chosen: Dictionary = {}
	for mount in candidates:
		if not _accepts_part(String(mount.get("key", "legs")), part_id):
			continue
		if chosen.is_empty():
			chosen = mount
		if String(mount.id).is_empty():
			chosen = mount
			break
	if chosen.is_empty() or _mission == null:
		return {"action": "No compatible mount · add a stage if needed"}
	var desired := build_config()
	_apply_part(desired, chosen, part_id)
	var result := validate(desired, _mission)
	var location := String(chosen.kind)
	if chosen.has("stage"):
		location = "stage %d %s" % [int(chosen.stage) + 1, location]
	return {
		"action": ("ADD · " if String(chosen.id).is_empty() else "REPLACE · ") + location,
		"before": calculate(build_config()), "after": calculate(desired),
		"budget": _mission.budget_credits,
		"thrust_target": 1.0 if _mission.scenario.get("spawn_profile") == "surface_north" else 0.0,
		"range_target": _minimum_delta_v(_mission),
		"note": String(result.errors[0]) if not result.valid else (String(result.warnings[0]) if not result.warnings.is_empty() else "Ready to fit · drag to choose a different mount"),
	}


func _part_spec(part: Dictionary) -> String:
	match part.type:
		"tank":
			return "%d kg fuel" % int(part.fuel_capacity_kg)
		"engine":
			return "%d kN" % int(float(part.thrust_n) / 1000.0)
		_:
			return "%d kg dry" % int(part.dry_mass_kg)


func _mounts() -> Array[Dictionary]:
	var mounts: Array[Dictionary] = [{"key": "pod", "kind": "pod", "id": _config.command_pod_id}]
	if _is_allowed("PROBE") or _config.attachment_ids.has("PROBE"):
		mounts.append({"key": "payload", "kind": "payload", "id": _attachment("payload")})
	for index in range(clampi(_config.stages.size(), 1, MAX_STAGES) - 1, -1, -1):
		var stage_config := _config.stages[index] if index < _config.stages.size() else null
		var tanks: Array[String] = [] if stage_config == null else stage_config.tank_ids
		for tank_index in range(mini(tanks.size() + 1, MAX_TANKS) - 1, -1, -1):
			var key := "tank" if index == 0 and tank_index == 0 else "tank_%d_%d" % [index, tank_index]
			var part_id := tanks[tank_index] if tank_index < tanks.size() else ""
			mounts.append({"key": key, "kind": "tank", "id": part_id, "stage": index, "tank": tank_index, "spare": tank_index > 0 and part_id.is_empty()})
		mounts.append({"key": "engine" if index == 0 else "engine_1", "kind": "engine", "id": "" if stage_config == null else stage_config.engine_id, "stage": index})
		if index == 1:
			mounts.append({"key": "decoupler", "kind": "decoupler", "id": _attachment("decoupler")})
	return mounts


func _mount(slot: String) -> Dictionary:
	if slot == "legs":
		return {"kind": "legs", "id": _attachment("legs")}
	for mount in _mounts():
		if mount.key == slot:
			return mount
	return {}


func _attachment(kind: String) -> String:
	for part_id in _config.attachment_ids:
		var part: Dictionary = _parts.get(part_id, {})
		if part.get("type") == kind:
			return part_id
	return ""


func _accepts_part(slot: String, part_id: String) -> bool:
	var part: Dictionary = _parts.get(part_id, {})
	return _config != null and not part.is_empty() and _is_allowed(part_id) and _mount(slot).get("kind") == part.type


func install_part(slot: String, part_id: String, play_feedback: bool = true) -> bool:
	if not _accepts_part(slot, part_id):
		return false
	var mount := _mount(slot)
	if String(mount.id) == part_id:
		return true
	_apply_part(_config, mount, part_id)
	_refresh_build()
	if play_feedback and is_node_ready():
		%RocketPreview.play_installation(slot)
	return true


func _apply_part(config: RocketConfig, mount: Dictionary, part_id: String) -> void:
	match mount.kind:
		"pod":
			config.command_pod_id = part_id
		"engine":
			_ensure_stage(config, mount.stage).engine_id = part_id
		"tank":
			var tanks := _ensure_stage(config, mount.stage).tank_ids
			if mount.tank == tanks.size():
				tanks.append(part_id)
			else:
				tanks[mount.tank] = part_id
		_:
			config.attachment_ids.erase(String(mount.id))
			config.attachment_ids.append(part_id)


func remove_part(slot: String) -> void:
	if _config == null:
		return
	var mount := _mount(slot)
	if mount.is_empty() or String(mount.id).is_empty():
		return
	match mount.kind:
		"pod":
			_config.command_pod_id = ""
		"engine":
			_editable_stage(mount.stage).engine_id = ""
		"tank":
			_editable_stage(mount.stage).tank_ids.remove_at(mount.tank)
		_:
			_config.attachment_ids.erase(String(mount.id))
	_refresh_build()


func _editable_stage(index: int) -> StageConfig:
	return _ensure_stage(_config, index)


func _ensure_stage(config: RocketConfig, index: int) -> StageConfig:
	while config.stages.size() <= index:
		config.stages.append(StageConfig.new())
	if config.stages[index] == null:
		config.stages[index] = StageConfig.new()
	return config.stages[index]


func add_stage() -> bool:
	if _config.stages.size() >= MAX_STAGES or not _is_allowed("DECOUPLER"):
		return false
	if _config.stages.is_empty():
		_config.stages.append(StageConfig.new())
	_config.stages.append(StageConfig.new())
	_refresh_build()
	return true


func _remove_stage() -> void:
	if _config.stages.size() <= 1:
		return
	_config.stages.pop_back()
	if _config.stages.size() == 1:
		_config.attachment_ids.erase("DECOUPLER")
	_refresh_build()


func _clear_assembly() -> void:
	var rocket_name := _config.rocket_name if _config != null else "Custom rocket"
	_config = RocketConfig.new()
	_config.rocket_name = rocket_name
	_config.stages.append(StageConfig.new())
	_refresh_build()


func _start_empty() -> void:
	_config = RocketConfig.new()
	_config.rocket_name = "Untitled rocket"
	_config.stages.append(StageConfig.new())
	if is_node_ready():
		%RocketName.text = _config.rocket_name
		_refresh_build()


func _reset_assembly() -> void:
	_config = RocketConfig.new()
	_config.rocket_name = "Sparrow I"
	_config.command_pod_id = "POD_A" if _is_allowed("POD_A") else ""
	var stage_config := StageConfig.new()
	stage_config.engine_id = "ENG_L" if _is_allowed("ENG_L") else ""
	if _is_allowed("TANK_L"):
		stage_config.tank_ids.append("TANK_L")
	_config.stages.append(stage_config)
	if is_node_ready():
		%RocketName.text = _config.rocket_name
		_refresh_build()


func _load_pioneer() -> void:
	var before := calculate(build_config())
	_reset_assembly()
	if not add_stage():
		return
	install_part("engine_1", "ENG_V", false)
	install_part("tank_1_0", "TANK_L", false)
	install_part("decoupler", "DECOUPLER", false)
	_config.rocket_name = "Pioneer II"
	%RocketName.text = _config.rocket_name
	# Loading a preset is one user edit, regardless of its internal assembly steps.
	_previous_stats = before
	_refresh_build()


func _is_allowed(part_id: String) -> bool:
	return _mission != null and (_mission.allowed_part_ids.is_empty() or _mission.allowed_part_ids.has(part_id))


func _refresh_build() -> void:
	if not is_node_ready():
		return
	var config := build_config()
	%RocketPreview.show_assembly(_mounts(), _artwork, _is_allowed("LEGS"), _attachment("legs"))
	if _mission == null:
		%MissionTag.text = "OFFLINE"
		%MissionBriefing.text = "Select a mission from the star chart."
		%BuildStatus.text = "NO MISSION"
		%Primary.disabled = true
		return
	var stats := calculate(config)
	var ids := _part_ids(config)
	if not _last_stats.is_empty() and ids != _last_part_ids:
		_previous_stats = _last_stats.duplicate()
	_last_part_ids = ids
	_last_stats = stats.duplicate()
	_comparison_key = ""
	%MissionTag.text = _mission.id
	%MissionBriefing.text = _mission.objective_text
	_render_metrics(stats, _previous_stats)
	var validation := validate(config, _mission)
	%Primary.disabled = not validation.valid or _workshop
	%RocketPreview.set_system_ready(validation.valid and not config.attachment_ids.is_empty())
	_render_status(validation)
	%AddStage.visible = _is_allowed("DECOUPLER")
	%AddStage.disabled = config.stages.size() >= MAX_STAGES
	%RemoveStage.visible = config.stages.size() > 1
	%Pioneer.visible = _is_allowed("DECOUPLER") and _is_allowed("ENG_V")


func _render_status(validation: Dictionary, preview: bool = false) -> void:
	%BuildStatus.text = "GO" if validation.valid else validation.errors[0]
	if validation.valid and not validation.warnings.is_empty():
		%BuildStatus.text = validation.warnings[0]
	if preview:
		%BuildStatus.text = "PREVIEW · " + %BuildStatus.text
	%BuildStatus.tooltip_text = "\n".join(validation.errors + validation.warnings)
	%BuildStatus.theme_type_variation = &"SuccessLabel" if validation.valid and validation.warnings.is_empty() else &"WarningLabel"


func _preview_part(slot: String, part_id: String) -> void:
	if _mission == null or not is_node_ready():
		return
	if not _accepts_part(slot, part_id):
		if not _comparison_key.is_empty():
			_comparison_key = ""
			_render_metrics(_last_stats, _previous_stats)
			_render_status(validate(build_config(), _mission))
		return
	var key := slot + ":" + part_id
	if key == _comparison_key:
		return
	_comparison_key = key
	var desired := build_config()
	_apply_part(desired, _mount(slot), part_id)
	_render_metrics(calculate(desired), _last_stats, true)
	var result := validate(desired, _mission)
	_render_status(result, true)
	%ComparisonLegend.tooltip_text = "Preview only; release to install.\n" + "\n".join(result.errors + result.warnings)


func _render_metrics(stats: Dictionary, before: Dictionary, preview: bool = false) -> void:
	if stats.is_empty():
		return
	%ComparisonLegend.text = "PART PREVIEW" if preview else ("LAST EDIT" if not before.is_empty() else "")
	%ComparisonLegend.visible = not %ComparisonLegend.text.is_empty()
	%ComparisonLegend.modulate = Color("ffd18a") if preview else Color.WHITE
	%ComparisonLegend.tooltip_text = "Filled bars show this build. Pale ticks show the previous build; diamonds mark mission minimums. Hover a part over a compatible mount to compare before fitting."
	var largest_tank := 1.0
	for part_id: String in _parts:
		if _is_allowed(part_id) and _parts[part_id].type == "tank":
			largest_tank = maxf(largest_tank, float(_parts[part_id].get("fuel_capacity_kg", 0.0)))
	var fuel_scale := largest_tank * MAX_TANKS * maxi(1, _config.stages.size())
	fuel_scale = maxf(fuel_scale, maxf(float(stats.fuel_kg), float(before.get("fuel_kg", 0.0))))
	var mass_scale := maxf(1.0, maxf(float(stats.wet_mass_kg), float(before.get("wet_mass_kg", 0.0))))
	var thrust_scale := maxf(2.0, maxf(float(stats.launch_twr), float(before.get("launch_twr", 0.0)))) * 1.15
	var goal := _minimum_delta_v(_mission)
	var range_scale := maxf(1.0, maxf(goal, maxf(float(stats.delta_v_mps), float(before.get("delta_v_mps", 0.0))))) * 1.15
	%FuelMetric.present("fuel", stats, before, 0.0, fuel_scale)
	%MassMetric.present("mass", stats, before, 0.0, mass_scale)
	%ThrustMetric.present("thrust", stats, before, 1.0 if _mission.scenario.get("spawn_profile") == "surface_north" else 0.0, thrust_scale)
	%RangeMetric.present("range", stats, before, goal, range_scale)
	var cost := int(stats.cost_credits)
	var budget := _mission.budget_credits
	%BudgetValue.text = "%d / %d CR" % [cost, budget]
	%BudgetBar.max_value = maxi(1, budget)
	%BudgetBar.value = cost
	%BudgetBar.theme_type_variation = &"OverBudget" if cost > budget else &""
	var change := cost - int(before.get("cost_credits", cost))
	var balance := "%d CR left" % (budget - cost) if cost <= budget else "%d CR over budget" % (cost - budget)
	%BudgetDelta.text = balance + ("   ·   %s%d CR" % ["+" if change >= 0 else "−", absi(change)] if not before.is_empty() else "")
	%BudgetDelta.modulate = Color("ff8e96") if cost > budget else Color("93afc0")
	%BudgetBar.tooltip_text = "%d credits used of %d. %s." % [cost, budget, balance]


func _on_name_changed(value: String) -> void:
	_config.rocket_name = value.strip_edges()
	_refresh_build()


func _prepare_launch() -> void:
	if _workshop:
		return
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
