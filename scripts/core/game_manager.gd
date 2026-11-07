extends Node

const MENU := preload("res://scenes/ui/main_menu.tscn")
const SELECT := preload("res://scenes/missions/mission_select.tscn")
const BUILDER := preload("res://scenes/builder/rocket_builder.tscn")
const FLIGHT := preload("res://scenes/flight/flight.tscn")
const REPORT := preload("res://scenes/missions/mission_report.tscn")

var _mission: MissionDefinition


func _ready() -> void:
	get_tree().node_added.connect(_connect_initial_menu)


func _connect_initial_menu(node: Node) -> void:
	if node.scene_file_path == MENU.resource_path:
		node.mission_requested.connect(_select_mission)


func _select_mission(id: String) -> void:
	var manager := MissionManager.new()
	if not manager.load_mission(id):
		return
	_mission = manager.definition
	_show_mission()


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
