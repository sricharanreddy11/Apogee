extends SceneTree

var _failures := 0
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := MissionManager.new()
	_check(manager.load_mission("M01"), "Mission loads.")
	var builder: BuilderController = load("res://scenes/builder/rocket_builder.tscn").instantiate()
	builder.setup(manager.definition)
	root.add_child(builder)
	await process_frame
	await process_frame
	var fuel: Control = builder.get_node("%FuelMetric")
	var mass: Control = builder.get_node("%MassMetric")
	var thrust: Control = builder.get_node("%ThrustMetric")
	var range_card: Control = builder.get_node("%RangeMetric")
	var preview: Control = builder.get_node("%RocketPreview")
	_check(fuel.current == 0.0 and not fuel.has_previous and builder.get_node("%Primary").disabled, "Initial empty build has zero fuel and no fabricated comparison.")
	var empty_impact := builder.part_impact("TANK_S")
	_check(empty_impact.after.fuel_kg == 900.0 and empty_impact.before.fuel_kg == 0.0, "Shelf hover predicts adding fuel to an empty build.")
	_check(builder.calculate(builder.build_config()).fuel_kg == 0.0, "Shelf tooltips never install parts.")
	builder.get_node("%Reset").pressed.emit()
	var tank_impact := builder.part_impact("TANK_S")
	_check(tank_impact.after.fuel_kg == 3100.0 and tank_impact.action.begins_with("ADD"), "Shelf hover names an empty tank mount and previews addition rather than silently replacing fuel.")
	var shelf_tooltip: Control = builder.get_node("%PartDiscs/TANK_S")._make_custom_tooltip("")
	_check(shelf_tooltip.get_child(0).get_child(2).get_child_count() == 4, "Hover tooltip contains four visual comparison cards.")
	shelf_tooltip.free()
	_check(thrust.target == 1.0 and range_card.target > 0.0, "Only physical mission thresholds are shown as targets.")
	var original := builder.calculate(builder.build_config())
	var tank_point: Vector2 = preview._rects.tank.get_center()
	_check(preview._can_drop_data(tank_point, {"apogee_part_id": "TANK_S"}), "Small tank is previewable.")
	_check(fuel.current == 900.0 and fuel.previous == 2200.0, "Hover compares desired fuel against actual fuel.")
	_check(mass.current == 2200.0 and mass.previous == 3600.0, "Hover compares desired wet mass against the installed build.")
	_check(builder.calculate(builder.build_config()) == original, "Hover never mutates the installed configuration.")
	_check(builder.get_node("%ComparisonLegend").text.contains("PREVIEW"), "Preview is explicitly distinguished from the live build.")
	preview.part_previewed.emit("", "")
	_check(fuel.current == 2200.0 and fuel.previous == 0.0, "Cancel restores the current build and its original comparison.")
	preview._drop_data(tank_point, {"apogee_part_id": "TANK_S"})
	_check(fuel.current == 900.0 and fuel.previous == 2200.0, "Installing stores the immediately preceding assembly.")
	_check(builder.get_node("%BudgetDelta").text.contains("−350 CR"), "Budget shows the exact cost reduction.")
	builder.get_node("%RocketName").text_changed.emit("Renamed rocket")
	_check(fuel.previous == 2200.0, "Renaming preserves the previous assembly comparison.")
	builder.call("_refresh_build")
	_check(fuel.previous == 2200.0, "Validation refresh does not erase the last change.")
	preview._can_drop_data(tank_point, {"apogee_part_id": "TANK_L"})
	_check(fuel.current == 2200.0 and fuel.previous == 900.0, "A second desired build compares with the actual installed small tank.")
	preview._notification(Control.NOTIFICATION_DRAG_END)
	_check(fuel.current == 900.0 and fuel.previous == 2200.0, "Drag-end cancellation restores the previous-edit comparison.")
	manager.definition.budget_credits = 1300
	preview._can_drop_data(tank_point, {"apogee_part_id": "TANK_L"})
	_check(builder.get_node("%BudgetDelta").text.contains("over budget"), "An unaffordable desired build shows its budget gap.")
	_check(builder.get_node("%BuildStatus").text.contains("PREVIEW") and builder.get_node("%BuildStatus").text.contains("exceeds"), "Preview explicitly shows desired-build validation.")
	_check(not builder.get_node("%Primary").disabled, "Preview does not alter readiness of the valid installed build.")
	preview._can_drop_data(preview._rects.pod.get_center(), {"apogee_part_id": "TANK_L"})
	_check(fuel.current == 900.0 and not builder.get_node("%ComparisonLegend").text.contains("PREVIEW"), "An incompatible mount clears the desired-build preview.")
	builder.get_node("%Clear").pressed.emit()
	_check(fuel.current == 0.0 and mass.current == 0.0 and thrust.current == 0.0 and range_card.current == 0.0, "Empty assemblies render finite zero metrics.")
	_check(fuel.previous == 900.0 and builder.get_node("%Primary").disabled, "Clear keeps its comparison and blocks launch.")
	manager.definition.scenario["spawn_profile"] = "lunar_approach"
	builder.call("_refresh_build")
	_check(thrust.target == 0.0 and range_card.target == 0.0, "In-space missions do not invent surface-launch goals.")
	builder.free()
	var workshop := MissionDefinition.new()
	workshop.budget_credits = 10000
	workshop.scenario = {"body_id": "earth"}
	builder = load("res://scenes/builder/rocket_builder.tscn").instantiate()
	builder.setup(workshop, true)
	root.add_child(builder)
	builder.get_node("%Pioneer").pressed.emit()
	fuel = builder.get_node("%FuelMetric")
	mass = builder.get_node("%MassMetric")
	_check(fuel.current == 4400.0 and fuel.previous == 0.0, "A preset compares against the build before the user's click, not its internal steps.")
	_check(mass.current == 6330.0 and mass.previous == 0.0, "Preset mass comparison preserves the entire preceding configuration.")
	builder.free()
	print("Builder metrics: %d checks, %d failures." % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
