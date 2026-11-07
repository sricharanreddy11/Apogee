extends Node2D

signal report_requested(result: MissionResult)

var _simulator := FlightSimulator.new()
var _mission := MissionManager.new()
var _configured: bool = false
var _rocket_config: RocketConfig


func setup(config: RocketConfig, mission_id: String) -> void:
	_configured = _mission.load_mission(mission_id)
	if _configured:
		_rocket_config = config.copy()
		_simulator.initialize(config, _mission.definition.scenario)


func _ready() -> void:
	%Primary.disabled = not _configured
	%Primary.pressed.connect(func() -> void: report_requested.emit(_mission.finalize_result()))
	%Secondary.pressed.connect(_toggle_map)
	if _configured:
		%FlightArtwork.setup(_rocket_config)
		_update_views(_simulator.get_telemetry())


func _physics_process(delta: float) -> void:
	if not _configured:
		return
	# TODO(Member 1): Route flight input to the simulator here.
	_simulator.step(delta)
	var telemetry := _simulator.get_telemetry()
	_mission.evaluate(telemetry)
	_update_views(telemetry)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		_toggle_map()
		get_viewport().set_input_as_handled()


func _toggle_map() -> void:
	%Map.visible = not %Map.visible


func _update_views(telemetry: FlightTelemetry) -> void:
	%HUD.update_from_telemetry(telemetry)
	%FlightArtwork.update_visuals(telemetry)
	if %Map.visible:
		%Map.update_from_telemetry(telemetry)
