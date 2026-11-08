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
var _prediction_worker: Thread
var _prediction_cancel: Semaphore
var _finished := false
var _paused := false
var _comms: Dictionary
var _mission_comms: Dictionary
var _liftoff_announced := false
var _comms_remaining := 0.0


func setup(config: RocketConfig, mission_id: String) -> void:
	_configured = _mission.load_mission(mission_id)
	if _configured:
		_mission_id = mission_id
		_rocket_config = config.copy()
		_scenario = _mission.definition.scenario.duplicate(true)
		_display_title = "%s / %s" % [_mission_id, _mission.definition.title]
		_simulator.initialize(config, _scenario)
		var builder := BuilderController.new()
		builder.setup(_mission.definition)
		_mission.begin_attempt(config, builder.calculate(config))
		builder.free()


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
	%PauseFlight.pressed.connect(_toggle_pause)
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
	%FlightArtwork.legs_pressed.connect(_toggle_legs)
	if not _configured:
		_configure_direct_preview()
	%EndFlight.disabled = not _configured
	if _configured:
		%MissionLabel.text = _display_title
		if not _showcase_mode:
			%Objective.text = _mission.definition.objective_text
			if _mission_id == "M04":
				var limits := _mission.definition.win_conditions
				%Objective.text = "Lunar touchdown  /  Vertical ≤ %.0f m/s  ·  Sideways ≤ %.0f m/s  ·  Tilt ≤ %.0f°  ·  Legs deployed  ·  Pod intact" % [
					limits.max_vertical_speed_mps, limits.max_horizontal_speed_mps, limits.max_orientation_deg,
				]
			_comms = JsonData.read_object("res://data/mission_comms.json")
			_mission_comms = _comms.get(_mission_id, {})
			_say(String(_mission_comms.get("intro", "")))
		%FlightArtwork.setup(_rocket_config)
		%FlightArtwork.landing_mode = _mission_id == "M04"
		%Map.reset_path()
		%Map.show_landing_site = _mission_id == "M04"
		_update_views(_simulator.get_telemetry())
		_update_control_state(_simulator.get_telemetry())
	_update_warp_controls()
	if _showcase_mode:
		%EndFlight.text = "BACK"
		%ControlStatus.text = "25× AUTO-FORWARD · ENGINE OFF\nGOLD = PROJECTED LUNAR FLYBY"
		_set_time_warp(25.0)
		call_deferred("_start_showcase")


func _physics_process(delta: float) -> void:
	if not _configured or _finished:
		return
	_collect_prediction()
	if _paused:
		return
	var throttle_axis := Input.get_axis("throttle_down", "throttle_up")
	var steering := Input.get_axis("steer_left", "steer_right")
	if not is_zero_approx(throttle_axis):
		var rate := 0.20 if _mission_id == "M04" else 1.5
		_set_throttle(_commanded_throttle + throttle_axis * delta * rate)
	if not is_zero_approx(steering) and _time_warp > 1.0:
		_set_time_warp(1.0)
	_simulator.set_steering(steering)
	var telemetry := _simulator.get_telemetry()
	for _tick in maxi(roundi(_time_warp), 1):
		_simulator.step(delta)
		telemetry = _simulator.get_telemetry()
		if not _showcase_mode and _mission.evaluate(telemetry):
			_finished = true
			break
		if _time_warp > 1.0 and not _can_warp(telemetry):
			_set_time_warp(1.0)
			break
	_commanded_throttle = telemetry.throttle
	_update_views(telemetry)
	_update_control_state(telemetry)
	_update_comms(telemetry, delta)
	if _finished:
		_finish_attempt.call_deferred()
		return
	_prediction_cooldown -= delta
	if _showing_orbit and _prediction_cooldown <= 0.0:
		_request_prediction()


func _request_prediction() -> void:
	_collect_prediction()
	if _prediction_worker != null:
		return
	_prediction_worker = Thread.new()
	_prediction_cancel = Semaphore.new()
	if _prediction_worker.start(FlightSimulator.predict_snapshot.bind(_simulator.get_prediction_snapshot(), _prediction_cancel), Thread.PRIORITY_LOW) != OK:
		_prediction_worker = null
	_prediction_cooldown = 0.6


func _collect_prediction() -> void:
	if _prediction_worker == null or _prediction_worker.is_alive():
		return
	var prediction := _prediction_worker.wait_to_finish() as TrajectoryPrediction
	_prediction_worker = null
	if _showing_orbit and prediction != null:
		%Map.set_prediction(prediction)


func _exit_tree() -> void:
	if _prediction_worker != null:
		_prediction_cancel.post()
		_prediction_worker.wait_to_finish()
		_prediction_worker = null


func _can_warp(telemetry: FlightTelemetry) -> bool:
	return telemetry.throttle <= 0.0 and absf(telemetry.angular_velocity_rad_s) < 0.01 and (
		telemetry.status == FlightState.Status.READY or
		(telemetry.status == FlightState.Status.FLYING and (telemetry.altitude_m >= 1000.0 or telemetry.radial_speed_mps >= 0.0))
	)


func _toggle_pause() -> void:
	if _finished or not _configured:
		return
	_paused = not _paused
	%PauseFlight.text = "RESUME" if _paused else "PAUSE"
	%ControlStatus.text = "FLIGHT PAUSED" if _paused else "FLIGHT RESUMED"
	_update_control_state(_simulator.get_telemetry())


func _say(line: String) -> void:
	if line.is_empty():
		return
	%Comms.text = "CONTROL  /  " + line
	_comms_remaining = 5.0


func _update_comms(telemetry: FlightTelemetry, delta: float) -> void:
	if _showcase_mode:
		return
	if not _liftoff_announced and _comms_remaining <= 0.0 and telemetry.status == FlightState.Status.FLYING and telemetry.elapsed_time_s >= 4.0:
		_liftoff_announced = true
		_say(String(_mission_comms.get("flying", "")))
	elif _comms_remaining > 0.0:
		_comms_remaining -= delta
		if _comms_remaining <= 0.0:
			%Comms.text = ""


func _input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("pause_flight"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_map"):
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
	%ViewTitle.text = "01  /  FORWARD WINDOW"
	_update_landing_guidance(_simulator.get_telemetry())
	if _showing_orbit:
		_request_prediction()
	elif _prediction_worker != null:
		_prediction_cancel.post()


func _start_showcase() -> void:
	_set_orbit_view(true)
	%Map.set_auto_frame_enabled(true)
	_request_prediction()


func _update_views(telemetry: FlightTelemetry) -> void:
	%HUD.update_from_telemetry(telemetry)
	_update_landing_guidance(telemetry)
	%FlightArtwork.update_visuals(telemetry)
	%Map.update_from_telemetry(telemetry)


func _update_landing_guidance(telemetry: FlightTelemetry) -> void:
	var visible := not _showing_orbit and _mission_id == "M04" and telemetry.body_id == "moon" and telemetry.altitude_m < 1000.0
	%LandingPanel.visible = visible
	if not visible:
		return
	var rules := _mission.definition.win_conditions
	var radial := telemetry.radial_speed_mps
	var lateral := telemetry.tangential_speed_mps
	var normal := telemetry.position_m - telemetry.central_body_position_m
	var tilt := absf(rad_to_deg(wrapf(telemetry.heading_rad - normal.angle() - PI * 0.5, -PI, PI)))
	if not telemetry.contact_body_id.is_empty():
		radial = telemetry.impact_radial_speed_mps
		lateral = telemetry.impact_tangential_speed_mps
		tilt = rad_to_deg(telemetry.impact_tilt_rad)
	var descending := radial < 0.0
	var safe := (
		absf(radial) <= float(rules.max_vertical_speed_mps)
		and lateral <= float(rules.max_horizontal_speed_mps)
		and tilt <= float(rules.max_orientation_deg)
		and telemetry.legs_deployed
	)
	%LandingGuidance.text = "LUNAR APPROACH\nVERT %s %.1f / %.0f m/s\nSIDE   %.1f / %.0f m/s\nTILT   %.1f / %.0f°\n%s" % [
		"↓" if descending else "↑", absf(radial), rules.max_vertical_speed_mps,
		lateral, rules.max_horizontal_speed_mps, tilt, rules.max_orientation_deg,
		"LEGS UP" if not telemetry.legs_deployed else ("TOUCHDOWN READY" if safe else "CORRECT APPROACH"),
	]
	%LandingGuidance.modulate = Color("#a3f1c4") if safe else Color("#ffcc8b")


func _toggle_engine() -> void:
	if not _configured:
		return
	if _commanded_throttle > 0.0:
		_last_nonzero_throttle = _commanded_throttle
		_set_throttle(0.0)
	else:
		_set_throttle(_last_nonzero_throttle)


func _request_stage() -> void:
	if _configured and not _paused and not _finished and _simulator.stage():
		%ControlStatus.text = "STAGE SEPARATED"
		_say(String(_comms.get("stage", "")))


func _toggle_legs() -> void:
	if not _configured or _paused or _finished or not _rocket_config.attachment_ids.has("LEGS"):
		return
	var deployed := not _simulator.get_telemetry().legs_deployed
	_simulator.set_legs_deployed(deployed)
	%ControlStatus.text = "LANDING LEGS DEPLOYED" if deployed else "LANDING LEGS RETRACTED"
	if deployed:
		_say(String(_comms.get("legs", "")))


func _on_throttle_changed(value: float) -> void:
	if not _updating_controls:
		_set_throttle(value / 100.0)


func _set_throttle(value: float) -> void:
	if _paused or _finished:
		return
	if value > 0.0 and _time_warp > 1.0:
		_set_time_warp(1.0)
	_commanded_throttle = clampf(value, 0.0, 1.0)
	if _commanded_throttle > 0.0:
		_last_nonzero_throttle = _commanded_throttle
	_simulator.set_throttle(_commanded_throttle)


func _set_time_warp(multiplier: float) -> void:
	var allowed := [1.0, 5.0, 25.0, 50.0]
	if not allowed.has(multiplier) or (multiplier > 1.0 and not _can_warp(_simulator.get_telemetry())):
		return
	_time_warp = multiplier
	_update_warp_controls()


func get_time_warp() -> float:
	return _time_warp


func _update_warp_controls() -> void:
	var buttons: Array[Button] = [%Warp1, %Warp5, %Warp25, %Warp50]
	var values := [1.0, 5.0, 25.0, 50.0]
	var can_warp := _can_warp(_simulator.get_telemetry())
	for index in buttons.size():
		buttons[index].set_pressed_no_signal(is_equal_approx(_time_warp, values[index]))
		buttons[index].disabled = index > 0 and not can_warp


func _update_control_state(telemetry: FlightTelemetry) -> void:
	_updating_controls = true
	%Throttle.set_value_no_signal(telemetry.throttle * 100.0)
	_updating_controls = false
	for button: Button in [%Warp5, %Warp25, %Warp50]:
		button.disabled = not _can_warp(telemetry)
	%ThrottleValue.text = ("%.1f%%" if _mission_id == "M04" else "%.0f%%") % (telemetry.throttle * 100.0)
	%EngineButton.text = "CUTOFF  [X]" if telemetry.throttle > 0.0 else "IGNITE"
	var controls_locked := _paused or _finished or telemetry.status in [FlightState.Status.LANDED, FlightState.Status.CRASHED]
	%Throttle.editable = not controls_locked
	%EngineButton.disabled = controls_locked
	%StageButton.disabled = controls_locked or _rocket_config == null or telemetry.active_stage + 1 >= _rocket_config.stages.size()
	%LegsButton.disabled = controls_locked or _rocket_config == null or not _rocket_config.attachment_ids.has("LEGS")
	%LegsButton.text = "RETRACT  [L]" if telemetry.legs_deployed else "LEGS  [L]"
	%FlightArtwork.set_vehicle_controls(not %StageButton.disabled, not %LegsButton.disabled)
	if telemetry.status == FlightState.Status.CRASHED:
		%ControlStatus.text = "POD LOST"
	elif telemetry.status == FlightState.Status.LANDED:
		%ControlStatus.text = "SAFE TOUCHDOWN"


func _finish_attempt() -> void:
	if _report_sent:
		return
	var result := _mission.finalize_result()
	if _mission_id != "M04" or result.contact_body_id != "moon":
		_request_report()
		return
	_set_orbit_view(false)
	%ViewButton.disabled = true
	%PauseFlight.disabled = true
	%EndFlight.text = "REPORT"
	if not result.discovery_ids.has("APOLLO_TRIBUTE") or GameManager.discovered_ids.has("APOLLO_TRIBUTE"):
		var reveal := create_tween()
		reveal.tween_interval(1.2)
		reveal.tween_callback(_request_report)
		return
	var touchdown: Vector2 = %FlightArtwork.get_touchdown_screen_position()
	%LunarVisitor.position = touchdown + Vector2(-95.0, -9.0)
	%LunarVisitor.show()
	%LunarVisitor.play("wave")
	%Comms.text = "FICTIONAL ASTRONAUT  /  Nice landing, explorer. You made that look easy."
	var arrival := create_tween()
	arrival.tween_property(%LunarVisitor, "position:x", touchdown.x - 32.0, 1.4)
	arrival.tween_interval(2.8)
	arrival.tween_callback(_request_report)


func _request_report() -> void:
	if _report_sent or not _configured:
		return
	_report_sent = true
	_finished = true
	%EndFlight.disabled = true
	if _showcase_mode:
		showcase_exit_requested.emit()
		return
	_mission.evaluate(_simulator.get_telemetry())
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
