extends SceneTree

## Exercise the real RocketLab controls through the M1 navigation boundary.
var _failures: int = 0
var _checks: int = 0
var _confirmations: int = 0
var _preflight_visits: int = 0
var _launch_requests: int = 0
var _launched_config: RocketConfig
var _launched_mission_id: String = ""


func _initialize() -> void:
	scene_changed.connect(_on_scene_changed)
	call_deferred("_run")


func _run() -> void:
	var game := root.get_node("GameManager")
	game.completed_missions.clear()
	game.agency_credits = 0
	game.flight_launch_requested.connect(_on_launch)
	game.show_main_menu()
	await _settle()
	var menu_id := current_scene.get_instance_id()
	current_scene.get_node("%MissionList").get_node("M02").get_node("%SelectButton").pressed.emit()
	_check(not game.select_mission("M02"), "Locked missions are also rejected by the navigation API.")
	await _settle()
	_check(current_scene.get_instance_id() == menu_id, "A locked mission keeps the same menu instance.")
	current_scene.get_node("%MissionList").get_node("M01").get_node("%SelectButton").pressed.emit()
	await _settle()
	_check(current_scene.name == "MissionBriefing", "M01 opens the mission briefing.")
	current_scene.get_node("%Primary").pressed.emit()
	await _settle()
	_check(current_scene.name == "RocketBuilder", "The briefing opens RocketLab.")
	var builder := current_scene as BuilderController
	if builder == null:
		quit(1)
		return
	builder.configuration_confirmed.connect(_on_confirmation)
	var builder_id := builder.get_instance_id()
	var preview: Control = builder.get_node("%RocketPreview")
	_check(preview.get_script().resource_path == "res://scripts/builder/rocket_preview.gd", "The builder uses the upstream interactive assembly preview.")
	_check(builder.get_node("%MissionBriefing").text.contains("100 km"), "RocketLab shows the selected mission objective.")
	var categories := builder.get_node("%Categories")
	var discs := builder.get_node("%PartDiscs")
	_check(discs.get_child_count() == 4, "The catalog creates one disc per available part.")
	_check(discs.get_node("TANK_S").visible and discs.get_node("POD_A").visible, "All available parts are visible on storage shelves.")
	_check(categories.get_node("tank").text == "FUEL TANKS", "Fuel shelf is labeled.")
	var shelf_part: Button = discs.get_node("TANK_S")
	shelf_part.button_down.emit()
	await create_timer(0.2).timeout
	_check(shelf_part.scale.x > 1.2, "Holding a stored part enlarges it.")
	shelf_part.button_up.emit()
	await create_timer(0.2).timeout
	_check(is_equal_approx(shelf_part.scale.x, 1.0), "Releasing restores the stored part's size.")
	_check(builder.calculate(builder.build_config()).wet_mass_kg == 0.0 and builder.get_node("%Primary").disabled, "A new mission starts empty with launch disabled.")
	_check(builder.install_part("pod", "POD_A") and builder.install_part("tank", "TANK_L") and builder.install_part("engine", "ENG_L"), "Players can assemble the rocket from scratch using shelf parts.")

	var small_tank := {"apogee_part_id": "TANK_S"}
	var pod_point := _slot_point(preview, "pod")
	var tank_point := _slot_point(preview, "tank")
	_check(not preview._can_drop_data(pod_point, small_tank), "A tank cannot attach to the command-pod mount.")
	preview._drop_data(pod_point, small_tank)
	_check(builder.build_config().command_pod_id == "POD_A", "A rejected drop preserves the installed pod.")
	for drag_data: Variant in [null, {}, "TANK_S", {"apogee_part_id": 1}, {"apogee_part_id": "UNKNOWN"}, {"apogee_part_id": "../POD_A"}, {"apogee_part_id": "ENG_L"}]:
		_check(not preview._can_drop_data(tank_point, drag_data), "Malformed, unknown, and wrong-type parts are rejected.")
		preview._drop_data(tank_point, drag_data)
	_check(builder.build_config().stages[0].tank_ids == ["TANK_L"], "Invalid drag data cannot replace an installed tank.")
	var detach := InputEventMouseButton.new()
	detach.position = tank_point
	detach.button_index = MOUSE_BUTTON_RIGHT
	detach.pressed = true
	preview._gui_input(detach)
	_check(builder.build_config().stages[0].tank_ids.is_empty(), "Right-click detaches the installed tank.")
	_check(builder.get_node("%Primary").disabled, "A missing tank disables Prepare Launch.")
	builder.get_node("%Primary").pressed.emit()
	_check(_confirmations == 0 and current_scene.get_instance_id() == builder_id, "A forced press cannot confirm an incomplete rocket.")
	var near_tank_point := _slot_point(preview, "tank") + Vector2(-88.0, 0.0)
	_check(preview._can_drop_data(near_tank_point, small_tank), "A tank can attach near its mount outside the silhouette.")
	preview._drop_data(near_tank_point, small_tank)
	_check(builder.build_config().stages[0].tank_ids == ["TANK_S"], "A valid drop installs the selected small tank.")
	_check(not builder.get_node("%Primary").disabled, "A complete small-tank rocket enables preparation.")
	_check(builder.get_node("%BudgetValue").text.contains("1250 / 2000"), "The live budget updates to 1,250 credits.")
	var small_stats := builder.calculate(builder.build_config())
	_check(small_stats.cost_credits == 1250 and is_equal_approx(small_stats.wet_mass_kg, 2200.0), "The small-tank craft costs 1,250 credits and weighs 2,200 kg wet.")

	builder.get_node("%Clear").pressed.emit()
	var empty := builder.build_config()
	_check(empty.command_pod_id.is_empty() and empty.stages[0].engine_id.is_empty() and empty.stages[0].tank_ids.is_empty(), "Clear removes all three modules.")
	_check(builder.get_node("%Primary").disabled, "Clear blocks preparation.")
	builder.get_node("%Reset").pressed.emit()
	var reference := builder.build_config()
	_check(reference.command_pod_id == "POD_A" and reference.stages[0].engine_id == "ENG_L" and reference.stages[0].tank_ids == ["TANK_L"], "Restore Sparrow I restores the complete reference assembly.")
	_check(not builder.get_node("%Primary").disabled, "The restored reference is ready to prepare.")
	preview._drop_data(_slot_point(preview, "tank"), small_tank)
	var mission: MissionDefinition = game.get_selected_mission()
	mission.budget_credits = 1249
	builder.get_node("%Primary").pressed.emit()
	_check(_confirmations == 0 and current_scene.get_instance_id() == builder_id, "Preparation rechecks a changed mission budget before emitting.")
	_check(builder.get_node("%BuildStatus").text.contains("exceeds"), "The rejected preparation explains the budget problem.")
	mission.budget_credits = 2000
	var rocket_name := builder.get_node("%RocketName") as LineEdit
	rocket_name.text = "Arc Sparrow"
	rocket_name.text_changed.emit(rocket_name.text)
	_check(not builder.get_node("%Primary").disabled, "Editing after budget restoration restores valid readiness.")
	builder.get_node("%Primary").pressed.emit()
	await _settle()
	_check(_confirmations == 1 and _preflight_visits == 1, "One confirmation opens exactly one preflight scene.")
	_check(current_scene.name == "LaunchpadPreview", "Prepare Launch opens the launchpad.")
	_check(game.current_rocket_config.rocket_name == "Arc Sparrow" and game.current_rocket_config.stages[0].tank_ids == ["TANK_S"], "The navigation handoff stores the chosen name and part IDs.")
	var pad := current_scene
	var panel := pad.get_node("%PreflightPanel")
	_check(panel.get_node("%RocketName").text == "Arc Sparrow", "Preflight shows the selected rocket name.")
	_check(panel.get_node("%CostLabel").text.contains("1250 / 2000"), "Preflight uses the small-tank cost.")
	_check(is_equal_approx(panel.get_node("%MassMetric").current, 2200.0), "Preflight uses the small-tank wet mass.")
	_check(is_equal_approx(panel.get_node("%FuelMetric").current, small_stats.fuel_kg), "Preflight's fuel visual matches the confirmed build.")
	_check(is_equal_approx(panel.get_node("%ThrustMetric").current, small_stats.launch_twr), "Preflight's thrust gauge matches the builder calculation.")
	_check(is_equal_approx(panel.get_node("%RangeMetric").current, small_stats.delta_v_mps), "Preflight's delta-v visual matches the builder calculation.")
	_check(panel.get_node("%BudgetBar").value == 1250 and panel.get_node("%RangeMetric").target > 0, "Preflight shows the actual budget usage and mission minimum.")
	_check(not panel.get_node("%FuelMetric").has_previous, "Confirmed preflight metrics do not invent a previous-build comparison.")
	_check(pad.get_node("%RocketPreview").get_config().stages[0].tank_ids == ["TANK_S"], "The launchpad visual receives the actual chosen tank.")
	_check(_launch_requests == 0 and pad.session_phase == 0, "Preparing a rocket does not request an automatic launch.")
	panel.get_node("%EditRocketButton").pressed.emit()
	await _settle()
	_check(current_scene.name == "RocketBuilder", "Edit Rocket returns to RocketLab.")
	builder = current_scene as BuilderController
	builder.configuration_confirmed.connect(_on_confirmation)
	_check(builder.build_config().rocket_name == "Arc Sparrow" and builder.build_config().stages[0].tank_ids == ["TANK_S"], "Editing preserves the custom name and small tank.")
	_check(builder.get_node("%BudgetValue").text.contains("1250 / 2000"), "The restored builder recalculates the selected design.")
	_check(builder.get_node("%PartDiscs").get_child_count() == 4, "Returning to the builder does not duplicate catalog discs.")
	builder.get_node("%Primary").pressed.emit()
	await _settle()
	_check(_confirmations == 2 and _preflight_visits == 2, "The second confirmation adds one preflight visit.")
	pad = current_scene
	panel = pad.get_node("%PreflightPanel")
	panel.get_node("%LaunchButton").pressed.emit()
	panel.get_node("%LaunchButton").pressed.emit()
	panel.launch_requested.emit()
	await _settle()
	_check(_launch_requests == 1 and _launched_mission_id == "M01", "Repeated launch actions produce one integration request for M01.")
	_check(_launched_config != null and _launched_config.rocket_name == "Arc Sparrow" and _launched_config.stages[0].tank_ids == ["TANK_S"], "The launch integration request carries the configured small-tank rocket.")
	_check(current_scene.name == "Flight", "Launch transitions from preflight into active flight.")
	_check(_preflight_visits == 2, "Launch does not create a duplicate preflight visit.")
	_check(current_scene.get_node("%FlightArtwork").get_config().rocket_name == "Arc Sparrow", "Flight retains the exact configured rocket artwork.")
	if _failures == 0:
		print("RocketLab integration: %d checks passed." % _checks)
	quit(0 if _failures == 0 else 1)


func _slot_point(preview: Control, key: String) -> Vector2:
	var rect: Rect2 = preview._rects[key]
	return rect.get_center()


func _on_confirmation(_config: RocketConfig) -> void:
	_confirmations += 1


func _on_launch(config: RocketConfig, mission_id: String) -> void:
	_launch_requests += 1
	_launched_config = config.copy()
	_launched_mission_id = mission_id


func _on_scene_changed() -> void:
	if current_scene != null and current_scene.name == "LaunchpadPreview":
		_preflight_visits += 1


func _settle() -> void:
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
