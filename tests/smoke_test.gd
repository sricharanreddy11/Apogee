extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mission := MissionManager.new()
	_check(mission.load_mission("M01"), "Load M01.")
	if mission.definition == null:
		quit(1)
		return
	var builder := BuilderController.new()
	builder.setup(mission.definition)
	var config := builder.build_config()
	var totals := builder.calculate(config)
	_check(totals.cost_credits == 1600, "Sparrow I costs 1,600 credits.")
	_check(is_equal_approx(totals.wet_mass_kg, 3600.0), "Sparrow I weighs 3,600 kg wet.")
	_check(builder.validate(config, mission.definition).valid, "Sparrow I passes M01 validation.")
	mission.definition.budget_credits = 1599
	_check(not builder.validate(config, mission.definition).valid, "Over-budget build is blocked.")
	builder.free()

	var simulator := FlightSimulator.new()
	simulator.initialize(config, mission.definition.scenario)
	var snapshot := simulator.get_telemetry()
	_check(snapshot.position_m == Vector2(0.0, -600000.0), "Spawn at Earth's north surface.")
	snapshot.position_m = Vector2.ZERO
	_check(simulator.get_telemetry().position_m != Vector2.ZERO, "Telemetry is detached.")
	_check(not InputMap.action_get_events("toggle_map").is_empty(), "Map input is bound.")

	if change_scene_to_file("res://scenes/ui/main_menu.tscn") != OK:
		_check(false, "Main menu loads.")
		quit(1)
		return
	await scene_changed
	for expected: String in ["MissionSelect", "RocketBuilder", "Flight", "MissionReport", "RocketBuilder"]:
		var button := current_scene.get_node_or_null("%Primary") as Button
		if button == null or button.disabled:
			_check(false, "Navigation button is enabled before %s." % expected)
			break
		button.pressed.emit()
		await process_frame
		await process_frame
		if current_scene == null or current_scene.name != expected:
			_check(false, "Navigate to %s." % expected)
			break
		if expected == "Flight":
			var toggle := current_scene.get_node("%Secondary") as Button
			var map_view := current_scene.get_node("%Map") as Control
			toggle.pressed.emit()
			_check(map_view.visible, "The map preview toggles on.")

	if _failures == 0:
		print("Apogee smoke check passed.")
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error(description)
