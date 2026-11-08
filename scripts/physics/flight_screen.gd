extends Control

signal report_requested(result: MissionResult)
signal showcase_exit_requested

var _simulator := FlightSimulator.new()
var _mission := MissionManager.new()
var _configured: bool = false
var _rocket_config: RocketConfig
var _mission_id := ""
var _commanded_throttle := 0.0
var _last_nonzero_throttle := 1.0
var _prediction_cooldown := 0.0
var _showing_orbit := false
var _updating_controls := false
var _report_sent := false
var _time_warp := 1.0
var _showcase_mode := false
var _scenario: Dictionary = {}
var _display_title := ""


func setup(config: RocketConfig, mission_id: String) -> void:
	_configured = _mission.load_mission(mission_id)
	if _configured:
		_mission_id = mission_id
		_rocket_config = config.copy()
		_scenario = _mission.definition.scenario.duplicate(true)
		_display_title = "%s / %s" % [_mission_id, _mission.definition.title]
		_simulator.initialize(config, _scenario)


func setup_showcase() -> void:
	_showcase_mode = true
	_configured = true
	_mission_id = "DEMO"
	_display_title = "DEMO / LUNAR GRAVITY SHOWCASE"
	_scenario = {
		"body_id": "earth",
		"spawn_profile": "moon_flyby_demo",
	}
	_rocket_config = _showcase_rocket()
	_simulator.initialize(_rocket_config, _scenario)


func _ready() -> void:
	%EndFlight.pressed.connect(_request_report)
	%ViewButton.pressed.connect(_toggle_map)
	%EngineButton.pressed.connect(_toggle_engine)
	%StageButton.pressed.connect(_request_stage)
	%LegsButton.pressed.connect(_toggle_legs)
	%Warp1.pressed.connect(_set_time_warp.bind(1.0))
	%Warp5.pressed.connect(_set_time_warp.bind(5.0))
	%Warp25.pressed.connect(_set_time_warp.bind(25.0))
	%Warp50.pressed.connect(_set_time_warp.bind(50.0))
	%Throttle.value_changed.connect(_on_throttle_changed)
	%FlightArtwork.engine_pressed.connect(_toggle_engine)
	%FlightArtwork.stage_pressed.connect(_request_stage)
	if not _configured:
		_configure_direct_preview()
	%EndFlight.disabled = not _configured
	if _configured:
		%MissionLabel.text = _display_title
		%FlightArtwork.setup(_rocket_config)
		%FlightArtwork.set_body(String(_scenario.get("body_id", "earth")))
		%Map.reset_path()
		_update_views(_simulator.get_telemetry())
		_update_control_state(_simulator.get_telemetry())
	_update_warp_controls()
	if _showcase_mode:
		%EndFlight.text = "BACK"
		%ControlStatus.text = "25× AUTO-FORWARD · ENGINE OFF\nGOLD = PROJECTED LUNAR FLYBY"
		_set_time_warp(25.0)
		call_deferred("_start_showcase")


func _physics_process(delta: float) -> void:
	if not _configured:
		return
	var throttle_axis := Input.get_axis("throttle_down", "throttle_up")
	if not is_zero_approx(throttle_axis):
		_commanded_throttle = clampf(_commanded_throttle + throttle_axis * delta * 1.5, 0.0, 1.0)
		if _commanded_throttle > 0.0:
			_last_nonzero_throttle = _commanded_throttle
		_simulator.set_throttle(_commanded_throttle)
	_simulator.set_steering(Input.get_axis("steer_left", "steer_right"))
	# Time warp is only fast-forward: run the unchanged simulation repeatedly.
	# No force, fuel, steering, gravity, or collision parameter is scaled.
	for _tick in maxi(roundi(_time_warp), 1):
		_simulator.step(delta)
	var telemetry := _simulator.get_telemetry()
	_commanded_throttle = telemetry.throttle
	if not _showcase_mode:
		_mission.evaluate(telemetry)
	_update_views(telemetry)
	_update_control_state(telemetry)
	_prediction_cooldown -= delta
	if _showing_orbit and _prediction_cooldown <= 0.0:
		%Map.set_prediction(_simulator.get_trajectory_prediction())
		_prediction_cooldown = 0.5


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		_toggle_map()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cut_throttle"):
		_set_throttle(0.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("stage_rocket"):
		_request_stage()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_legs"):
		_toggle_legs()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("normal_speed"):
		_set_time_warp(1.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fast_speed"):
		_set_time_warp(5.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("warp_25"):
		_set_time_warp(25.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("warp_50"):
		_set_time_warp(50.0)
		get_viewport().set_input_as_handled()


func _toggle_map() -> void:
	_set_orbit_view(not _showing_orbit)


func _set_orbit_view(enabled: bool) -> void:
	_showing_orbit = enabled
	%Map.visible = _showing_orbit
	%FlightArtwork.visible = not _showing_orbit
	%ViewTitle.visible = not _showing_orbit
	%ViewButton.text = "FLIGHT  [Tab]" if _showing_orbit else "ORBIT  [Tab]"
	%ViewTitle.text = "FLIGHT VIEW"
	if _showing_orbit:
		%Map.set_prediction(_simulator.get_trajectory_prediction())
		_prediction_cooldown = 0.5


func _start_showcase() -> void:
	_set_orbit_view(true)
	%Map.set_auto_frame_enabled(true)
	%Map.set_prediction(_simulator.get_trajectory_prediction())


func _update_views(telemetry: FlightTelemetry) -> void:
	%HUD.update_from_telemetry(telemetry)
	%FlightArtwork.update_visuals(telemetry)
	%Map.update_from_telemetry(telemetry)


func _toggle_engine() -> void:
	if not _configured:
		return
	if _commanded_throttle > 0.0:
		_last_nonzero_throttle = _commanded_throttle
		_set_throttle(0.0)
	else:
		_set_throttle(maxf(_last_nonzero_throttle, 1.0))


func _request_stage() -> void:
	if _configured and _simulator.stage():
		%ControlStatus.text = "STAGE SEPARATED"


func _toggle_legs() -> void:
	if not _configured or not _rocket_config.attachment_ids.has("LEGS"):
		return
	var deployed := not _simulator.get_telemetry().legs_deployed
	_simulator.set_legs_deployed(deployed)
	%ControlStatus.text = "LANDING LEGS DEPLOYED" if deployed else "LANDING LEGS RETRACTED"


func _on_throttle_changed(value: float) -> void:
	if not _updating_controls:
		_set_throttle(value / 100.0)


func _set_throttle(value: float) -> void:
	_commanded_throttle = clampf(value, 0.0, 1.0)
	if _commanded_throttle > 0.0:
		_last_nonzero_throttle = _commanded_throttle
	_simulator.set_throttle(_commanded_throttle)


func _set_time_warp(multiplier: float) -> void:
	var allowed := [1.0, 5.0, 25.0, 50.0]
	if not allowed.has(multiplier):
		return
	_time_warp = multiplier
	_update_warp_controls()


func get_time_warp() -> float:
	return _time_warp


func _update_warp_controls() -> void:
	var buttons: Array[Button] = [%Warp1, %Warp5, %Warp25, %Warp50]
	var values := [1.0, 5.0, 25.0, 50.0]
	for index in buttons.size():
		buttons[index].button_pressed = is_equal_approx(_time_warp, values[index])


func _update_control_state(telemetry: FlightTelemetry) -> void:
	_updating_controls = true
	%Throttle.value = telemetry.throttle * 100.0
	_updating_controls = false
	%ThrottleValue.text = "%d%%" % roundi(telemetry.throttle * 100.0)
	%EngineButton.text = "CUTOFF  [X]" if telemetry.throttle > 0.0 else "IGNITE"
	%StageButton.disabled = _rocket_config == null or telemetry.active_stage + 1 >= _rocket_config.stages.size()
	%LegsButton.disabled = _rocket_config == null or not _rocket_config.attachment_ids.has("LEGS")
	%LegsButton.text = "RETRACT  [L]" if telemetry.legs_deployed else "LEGS  [L]"
	if telemetry.status == FlightState.Status.CRASHED:
		%ControlStatus.text = "POD LOST · END FLIGHT FOR REPORT"
	elif telemetry.status == FlightState.Status.LANDED:
		%ControlStatus.text = "SAFE TOUCHDOWN · END FLIGHT FOR REPORT"


func _request_report() -> void:
	if _report_sent or not _configured:
		return
	_report_sent = true
	%EndFlight.disabled = true
	if _showcase_mode:
		showcase_exit_requested.emit()
		return
	report_requested.emit(_mission.finalize_result())


func _configure_direct_preview() -> void:
	setup_showcase()


func _showcase_rocket() -> RocketConfig:
	var config := RocketConfig.new()
	config.rocket_name = "Flyby Demonstrator"
	config.command_pod_id = "POD_A"
	var stage_config := StageConfig.new()
	stage_config.engine_id = "ENG_V"
	stage_config.tank_ids.append("TANK_S")
	config.stages.append(stage_config)
	config.attachment_ids.append("PROBE")
	return config
