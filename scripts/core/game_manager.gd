extends Node

const MENU := preload("res://scenes/ui/main_menu.tscn")
const SELECT := preload("res://scenes/missions/mission_select.tscn")
const BUILDER := preload("res://scenes/builder/rocket_builder.tscn")
const FLIGHT := preload("res://scenes/flight/flight.tscn")
const REPORT := preload("res://scenes/missions/mission_report.tscn")

var _mission: MissionDefinition


func select_mission(id: String, open_builder: bool = false) -> bool:
	var manager := MissionManager.new()
	if not manager.load_mission(id):
		return false
	_mission = manager.definition
	if open_builder:
		_show_builder()
	else:
		_show_mission()
	return true


func _show_mission() -> void:
	var screen := SELECT.instantiate()
	screen.setup(_mission)
	screen.build_requested.connect(_show_builder)
	screen.back_requested.connect(_show_menu)
	_switch_screen(screen)


func _show_builder() -> void:
	var screen := BUILDER.instantiate()
	screen.setup(_mission)
	screen.launch_requested.connect(_show_flight)
	screen.back_requested.connect(_show_mission)
	_switch_screen(screen)


func _show_flight(config: RocketConfig) -> void:
	var screen := FLIGHT.instantiate()
	screen.setup(config, _mission.id)
	screen.report_requested.connect(_show_report)
	_switch_screen(screen)


func _show_report(result: MissionResult) -> void:
	var screen := REPORT.instantiate()
	screen.setup(result)
	screen.retry_requested.connect(_show_builder)
	screen.menu_requested.connect(_show_menu)
	_switch_screen(screen)


func _show_menu() -> void:
	_switch_screen(MENU.instantiate())


func _switch_screen(screen: Node) -> void:
	var error := get_tree().change_scene_to_node(screen)
	if error != OK:
		screen.free()
		push_error("Could not change screen (error %s)." % error)
