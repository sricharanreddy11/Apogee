extends SceneTree

var _failures: int = 0
var _confirmations: int = 0
var _confirmed_config: RocketConfig


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mission := MissionManager.new()
	_check(mission.load_mission("M01"), "M01 loads for builder tests.")
	if mission.definition == null:
		quit(1)
		return
	var builder := BuilderController.new()
	builder.setup(mission.definition)
	var reference := builder.build_config()
	_check(builder.validate(reference, mission.definition).valid, "Reference Sparrow I is valid.")
	_check(builder.calculate(reference).cost_credits == 1600, "Reference cost is derived from catalog.")
	_check(builder.calculate(reference).wet_mass_kg == 3600.0, "Reference wet mass is derived from catalog.")
	_check(not builder.validate(null, mission.definition).valid, "Null config is blocked.")
	_check(not builder.validate(reference, null).valid, "Missing mission is blocked.")
	var broken := reference.copy()
	broken.command_pod_id = ""
	_check(not builder.validate(broken, mission.definition).valid, "Missing pod is blocked.")
	broken = reference.copy()
	broken.command_pod_id = "ENG_L"
	_check(not builder.validate(broken, mission.definition).valid, "Engine in pod slot is blocked.")
	broken = reference.copy()
	broken.stages[0].engine_id = ""
	_check(not builder.validate(broken, mission.definition).valid, "Missing engine is blocked.")
	broken = reference.copy()
	broken.stages[0].engine_id = "TANK_S"
	_check(not builder.validate(broken, mission.definition).valid, "Tank in engine slot is blocked.")
	broken = reference.copy()
	broken.stages[0].tank_ids.assign(["POD_A"])
	_check(not builder.validate(broken, mission.definition).valid, "Pod in tank slot is blocked.")
	broken = reference.copy()
	broken.stages[0].tank_ids.clear()
	_check(not builder.validate(broken, mission.definition).valid, "Missing tank is blocked.")
	broken = reference.copy()
	broken.stages.append(reference.stages[0].copy())
	_check(not builder.validate(broken, mission.definition).valid, "Two stages without a separator are blocked.")
	broken = reference.copy()
	broken.stages[0] = null
	_check(not builder.validate(broken, mission.definition).valid, "Missing stage object is blocked without a crash.")
	broken = reference.copy()
	broken.attachment_ids.append("DOES_NOT_EXIST")
	_check(not builder.validate(broken, mission.definition).valid, "Unknown attachment is blocked.")
	broken = reference.copy()
	broken.attachment_ids.append("")
	_check(not builder.validate(broken, mission.definition).valid, "Empty attachment ID is blocked.")
	mission.definition.budget_credits = 1599
	_check(not builder.validate(reference, mission.definition).valid, "Over-budget configuration is blocked.")
	mission.definition.budget_credits = 2000
	var heavy := reference.copy()
	for index in 10:
		heavy.stages[0].tank_ids.append("TANK_L")
	mission.definition.budget_credits = 100000
	var heavy_validation := builder.validate(heavy, mission.definition)
	_check(not heavy_validation.valid and "1–3 tanks" in "\n".join(heavy_validation.errors), "The builder rejects more than three tanks per stage.")
	builder.load_config(heavy)
	_check(builder.build_config().stages[0].tank_ids.size() == 11, "Unsupported loaded stack is preserved for validation, not flattened.")
	mission.definition.budget_credits = 2000
	var custom := reference.copy()
	custom.rocket_name = "My First Rocket"
	custom.stages[0].tank_ids.assign(["TANK_S"])
	builder.load_config(custom)
	custom.rocket_name = "External mutation"
	custom.stages[0].tank_ids.clear()
	var preserved := builder.build_config()
	_check(preserved.rocket_name == "My First Rocket" and preserved.stages[0].tank_ids == ["TANK_S"], "load_config preserves a detached design.")
	preserved.stages[0].tank_ids.clear()
	_check(builder.build_config().stages[0].tank_ids == ["TANK_S"], "build_config returns a detached design.")
	builder.free()
	await _test_scene(mission.definition)
	_test_preview(reference)
	_test_advanced()
	await _test_workshop()
	if _failures == 0:
		print("Builder handoff tests passed.")
	quit(0 if _failures == 0 else 1)


func _test_scene(mission: MissionDefinition) -> void:
	var scene := load("res://scenes/builder/rocket_builder.tscn").instantiate() as BuilderController
	scene.setup(mission)
	scene.configuration_confirmed.connect(_on_confirmed)
	root.add_child(scene)
	await process_frame
	var name_edit := scene.get_node("%RocketName") as LineEdit
	name_edit.text = "Renamed Sparrow"
	name_edit.text_changed.emit(name_edit.text)
	_check(scene.build_config().rocket_name == "Renamed Sparrow", "Editable name becomes part of the configured rocket.")
	_check(scene.get_node("%BudgetValue").text.contains("1600 / 2000 CR"), "Builder shows data-backed mission budget.")
	_check(scene.get_node("%Primary").text == "Prepare Launch", "Builder distinguishes prepare from actual launch.")
	scene.get_node("%Primary").pressed.emit()
	_check(_confirmations == 1 and _confirmed_config.rocket_name == "Renamed Sparrow", "Valid prepare emits one configured rocket.")
	mission.budget_credits = 1
	scene.get_node("%Primary").pressed.emit()
	_check(_confirmations == 1, "Action revalidates even if pressed is emitted directly.")
	_check(scene.get_node("%BuildStatus").text.contains("exceeds"), "Rejected action explains its budget error.")
	_check(scene.get_node("%Primary").disabled, "Rejected action disables prepare.")
	mission.budget_credits = 2000
	var invalid := scene.build_config()
	invalid.stages[0].engine_id = ""
	scene.load_config(invalid)
	scene.get_node("%Primary").pressed.emit()
	_check(_confirmations == 1, "Invalid loaded rocket cannot proceed.")
	invalid = scene.build_config()
	invalid.stages[0].engine_id = "UNKNOWN_ENGINE"
	scene.load_config(invalid)
	_check(scene.get_node("%BuildStatus").text.contains("Unknown part"), "Unknown loaded IDs render readable errors without a catalog lookup crash.")
	scene.get_node("%Reset").pressed.emit()
	_check(scene.build_config().stages[0].tank_ids == ["TANK_L"] and not scene.get_node("%Primary").disabled, "Restore returns to the configured reference design.")
	scene.get_node("%Clear").pressed.emit()
	_check(scene.get_node("%Primary").disabled, "Clear rocket blocks prepare launch.")
	_check(scene.install_part("pod", "POD_A") and scene.install_part("tank", "TANK_S") and scene.install_part("engine", "ENG_L"), "Part installation rebuilds the cleared rocket.")
	_check(scene.calculate(scene.build_config()).wet_mass_kg == 2200.0, "Small tank uses the actual 2200 kg wet mass.")
	_check(not scene.install_part("pod", "TANK_S"), "Wrong slot installation is rejected.")
	_check(not scene.get_node("%Primary").disabled, "Reassembled valid rocket can prepare launch.")
	scene.queue_free()
	await process_frame


func _test_preview(config: RocketConfig) -> void:
	var preview := RocketPreview.new()
	preview.setup(config)
	var detached := preview.get_config()
	detached.stages[0].tank_ids.clear()
	_check(preview.get_config().stages[0].tank_ids == ["TANK_L"], "Rocket visual owns a detached copy of actual part IDs.")
	preview.free()


func _test_advanced() -> void:
	var catalog := MissionCatalog.new()
	var orbital := catalog.load_mission("M02")
	var builder := BuilderController.new()
	builder.setup(orbital)
	_check(is_equal_approx(builder.calculate(builder.build_config()).delta_v_mps, 3600.0 * 9.80665 * log(3600.0 / 1400.0)), "Sparrow I Δv matches the rocket equation.")
	_check(builder.add_stage() and not builder.add_stage(), "The editor supports a maximum of two stages.")
	_check(builder.install_part("tank_1_0", "TANK_L") and builder.install_part("engine_1", "ENG_V"), "The upper stage accepts its own tank and engine.")
	_check(not builder.validate(builder.build_config(), orbital).valid, "Two stages require a separator.")
	_check(builder.install_part("decoupler", "DECOUPLER"), "The separator fits between stages.")
	var pioneer := builder.build_config()
	var stats := builder.calculate(pioneer)
	_check(builder.validate(pioneer, orbital).valid, "Pioneer II passes the orbital builder rules.")
	_check(stats.cost_credits == 2900 and stats.wet_mass_kg == 6330.0, "Pioneer II has the specified cost and wet mass.")
	var delta_v := 3600.0 * 9.80665 * log(6330.0 / 4130.0) + 5200.0 * 9.80665 * log(3250.0 / 1050.0)
	_check(is_equal_approx(stats.delta_v_mps, delta_v), "Staged Δv discards the first stage structure and separator before the upper burn.")
	_check(builder.install_part("tank_0_1", "TANK_S") and builder.install_part("tank_0_2", "TANK_S"), "A stage accepts three tanks.")
	_check(not builder.install_part("tank_0_3", "TANK_S"), "A fourth tank cannot be installed.")
	builder.remove_part("tank_0_1")
	_check(builder.build_config().stages[0].tank_ids == ["TANK_L", "TANK_S"], "Detaching a tank compacts the remaining stack.")
	var flyby := catalog.load_mission("M03")
	builder.setup(flyby)
	_check(not builder.validate(builder.build_config(), flyby).valid, "Lunar Encounter requires a science payload.")
	_check(builder.install_part("payload", "PROBE") and builder.validate(builder.build_config(), flyby).valid, "Fitting PROBE meets the flyby build requirement.")
	var landing := catalog.load_mission("M04")
	builder.setup(landing)
	_check(not builder.validate(builder.build_config(), landing).valid, "One Small Step requires landing legs.")
	_check(builder.install_part("legs", "LEGS") and builder.validate(builder.build_config(), landing).valid, "Fitting LEGS meets the lunar landing build requirement.")
	builder.free()
	var rig := RocketRig.new()
	rig.setup(pioneer)
	_check(rig.get_node("Stage1").get_child_count() == 4, "The native rocket rig includes the first stage engine, tank, exhaust and separator.")
	rig.apply_flight(0, 0.75, false)
	_check(rig.get_node("Stage1").get_child(0).visible, "Throttle lights the active engine.")
	rig.apply_flight(1, 0.75, true)
	_check(not rig.get_node("Stage1").visible and rig.get_node("Stage2").get_child(0).visible, "Stage changes discard the lower visual and light the upper engine.")
	rig.free()


func _test_workshop() -> void:
	var game := root.get_node("GameManager")
	game.show_main_menu()
	await scene_changed
	current_scene.get_node("%Workshop").pressed.emit()
	await scene_changed
	var hangar := current_scene as BuilderController
	_check(hangar != null and not hangar.get_node("%Primary").visible, "Workshop opens the hangar without a campaign launch.")
	_check(hangar.get_node("%PartDiscs").get_child_count() == 9, "Workshop exposes the full nine-part catalog.")
	hangar.get_node("%Pioneer").pressed.emit()
	var preview: Control = hangar.get_node("%RocketPreview")
	var mount: Rect2 = preview._rects["legs"]
	var legs := {"apogee_part_id": "LEGS"}
	_check(preview._can_drop_data(mount.get_center(), legs), "Landing legs have a dedicated mount in the hangar.")
	preview._drop_data(mount.get_center(), legs)
	var config := hangar.build_config()
	_check(config.stages.size() == 2 and config.attachment_ids.has("LEGS"), "The Workshop assembles both stages and landing legs.")
	hangar.get_node("%TestFire").pressed.emit()
	_check(preview.get_node("%TestRig").visible, "Test fire switches to the animated native rig.")
	_check(hangar.build_config().attachment_ids == config.attachment_ids, "Test fire preserves the design.")
	hangar.get_node("%Secondary").pressed.emit()
	await scene_changed
	_check(current_scene.name == "MainMenu", "Workshop returns to the star chart.")


func _on_confirmed(config: RocketConfig) -> void:
	_confirmations += 1
	_confirmed_config = config


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
