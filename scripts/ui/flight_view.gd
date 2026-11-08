extends Control

signal engine_pressed
signal stage_pressed
signal legs_pressed
signal crash_sequence_finished

# Art scale: a 64-pixel wide fuselage represents a 3.2-meter diameter.
const METERS_PER_ART_PIXEL := 0.05
const MIN_ZOOM := 0.00005
const MAX_ZOOM := 8.5
const DETAIL_ENTER_PX := 13.0
const DETAIL_EXIT_PX := 18.0

var landing_mode := false
var _config: RocketConfig
var _telemetry: FlightTelemetry
var _landed := false
var _crashed := false
var _crash_camera: Tween
var _surface_y_m := 0.0
var _vehicle_power: Tween
var _sky_target := Vector2.ZERO
var _sky_mix := Vector2.ZERO
var _sky_initialized := false
var _vent_gain := 0.0
var _vent_target := 0.0
@onready var _rig: RocketRig = %RocketRig
@onready var _vehicle_rig: RocketRig = %VehicleRig
@onready var _vehicle_cam: PanelContainer = %VehicleCam
@onready var _vehicle_stage: Button = %VehicleStage
@onready var _vehicle_legs: Button = %VehicleLegs
@onready var _vehicle_mount: Node2D = %VehicleMount
@onready var _stage_readout: Label = %StageReadout
@onready var _vehicle_jets: Node2D = %VehicleJets
@onready var _power_flash: ColorRect = %PowerFlash
@onready var _sky_material: ShaderMaterial = %Sky.material
@onready var _vent: AudioStreamPlayer2D = %SteeringVent


func setup(config: RocketConfig) -> void:
	_config = config.copy() if config != null else null
	_landed = false
	_crashed = false
	_sky_initialized = false
	if is_node_ready():
		_setup_rigs()


func get_config() -> RocketConfig:
	return _config.copy() if _config != null else null


func update_visuals(telemetry: FlightTelemetry, steering := 0.0) -> void:
	_telemetry = telemetry
	if not is_node_ready():
		return
	_rig.apply_flight(telemetry.active_stage, telemetry.throttle, telemetry.legs_deployed)
	_vehicle_rig.apply_flight(telemetry.active_stage, telemetry.throttle, telemetry.legs_deployed)
	var powered := telemetry.status != FlightState.Status.CRASHED and telemetry.status != FlightState.Status.LANDED
	var atmosphere := telemetry.body_id == "earth" and telemetry.altitude_m < 80000.0
	_rig.update_effects(telemetry.fuel_fraction, atmosphere, powered)
	_vehicle_rig.update_effects(telemetry.fuel_fraction, atmosphere, powered)
	_vehicle_rig.position = -_vehicle_rig.get_active_stack_center()
	_vehicle_jets.position = _vehicle_rig.transform * _neck_socket(_vehicle_rig)
	_update_sky_target(telemetry)
	if _config != null:
		_stage_readout.text = "STAGE %d / %d" % [telemetry.active_stage + 1, _config.stages.size()]
	_vehicle_legs.text = "RETRACT" if telemetry.legs_deployed else "DEPLOY"
	_update_world()
	var can_steer := _config != null and telemetry.status in [FlightState.Status.READY, FlightState.Status.FLYING]
	_set_steering_effects(steering if can_steer else 0.0)
	if telemetry.status == FlightState.Status.CRASHED and not _crashed:
		_play_crash()
	if telemetry.status == FlightState.Status.LANDED and not _landed:
		_landed = true
		if telemetry.contact_body_id == "moon":
			%LandingDust.position = Vector2(0.0, _surface_y_m)
			%LandingDust.restart()
			%LandingDust.emitting = true


func get_touchdown_screen_position() -> Vector2:
	var pixel: Vector2 = %WorldViewport.get_canvas_transform() * Vector2(0.0, _surface_y_m)
	return pixel * size / Vector2(%WorldViewport.size)


func mount_vehicle_cam(host: Control) -> void:
	var panel_size := _vehicle_cam.size
	_vehicle_cam.reparent(host, false)
	_vehicle_cam.set_anchors_preset(Control.PRESET_CENTER)
	_vehicle_cam.offset_left = -panel_size.x * 0.5
	_vehicle_cam.offset_top = -panel_size.y * 0.5
	_vehicle_cam.offset_right = panel_size.x * 0.5
	_vehicle_cam.offset_bottom = panel_size.y * 0.5


func set_vehicle_controls(can_stage: bool, can_toggle_legs: bool) -> void:
	_vehicle_stage.disabled = not can_stage
	_vehicle_legs.disabled = not can_toggle_legs


func _ready() -> void:
	var vent_loop := _vent.stream.duplicate() as AudioStreamWAV
	vent_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	vent_loop.loop_end = roundi(vent_loop.get_length() * vent_loop.mix_rate)
	_vent.stream = vent_loop
	_setup_rigs()
	%CrashEffect.finished.connect(crash_sequence_finished.emit)
	_vehicle_stage.pressed.connect(stage_pressed.emit)
	_vehicle_legs.pressed.connect(legs_pressed.emit)
	_vehicle_cam.resized.connect(_center_vehicle_power)
	_center_vehicle_power()
	%WorldViewport.size_changed.connect(_update_world)
	_update_world()


func _process(delta: float) -> void:
	if _sky_mix.distance_squared_to(_sky_target) > 0.00000001:
		_sky_mix = _sky_mix.lerp(_sky_target, 1.0 - exp(-2.7 * delta))
		_apply_sky()
	_vent_gain = move_toward(_vent_gain, _vent_target, delta * (16.0 if _vent_target > _vent_gain else 8.0))
	if _vent_gain > 0.0:
		_vent.volume_db = linear_to_db(maxf(0.001, _vent_gain * 0.37))
		if not _vent.playing:
			_vent.play()
	elif _vent.playing:
		_vent.stop()


func _update_sky_target(telemetry: FlightTelemetry) -> void:
	var earth_altitude := telemetry.position_m.distance_to(telemetry.earth_position_m) - telemetry.earth_radius_m
	var air := 1.0 - smoothstep(0.0, 116000.0, maxf(earth_altitude, 0.0)) if telemetry.earth_radius_m > 0.0 else 0.0
	var slipstream := smoothstep(200.0, 2500.0, telemetry.speed_mps) * air
	_sky_target = Vector2(air, slipstream)
	if not _sky_initialized:
		_sky_initialized = true
		_sky_mix = _sky_target
		_apply_sky()


func _apply_sky() -> void:
	_sky_material.set_shader_parameter("atmosphere", _sky_mix.x)
	_sky_material.set_shader_parameter("slipstream", _sky_mix.y)


func stop_steering_effects() -> void:
	_set_steering_effects(0.0)


func _set_steering_effects(turn: float) -> void:
	%WorldJets.set_turn(turn)
	_vehicle_jets.set_turn(turn)
	_vent_target = absf(turn)
	if not is_zero_approx(turn):
		var source := _vehicle_cam.get_global_rect().get_center() - global_position if %FarMarker.visible else size * 0.5
		_vent.position = source - Vector2(signf(turn) * 18.0, 0.0)


func _neck_socket(rig: RocketRig) -> Vector2:
	return Vector2(0.0, -rig.height_px + 53.0)


func _setup_rigs() -> void:
	if _crash_camera != null:
		_crash_camera.kill()
	%CrashEffect.reset()
	%FlightCamera.offset = Vector2.ZERO
	%ImpactFlash.color.a = 0.0
	%Craft.show()
	stop_steering_effects()
	_rig.setup(_config)
	_vehicle_rig.setup(_config)
	# Fit the full stack with room for the feet and exhaust in any orientation.
	_vehicle_mount.scale = Vector2.ONE * minf(0.65, 165.0 / (_vehicle_rig.height_px + 110.0))


func _update_world() -> void:
	if _telemetry == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var viewport_size := Vector2(%WorldViewport.size)
	var normal := (_telemetry.position_m - _telemetry.central_body_position_m).normalized()
	if normal.is_zero_approx():
		normal = Vector2.UP
	var local_heading := wrapf(_telemetry.heading_rad - normal.angle() - PI * 0.5, -PI, PI)
	var altitude := maxf(0.0, _telemetry.altitude_m)
	var radius := _telemetry.moon_radius_m if _telemetry.body_id == "moon" else _telemetry.earth_radius_m
	_surface_y_m = altitude

	# The simulation's contact datum is the foot of the craft. Rotate the rig
	# around the surviving midpoint, then put its lowest contact point above that datum.
	var pivot := _rig.get_active_stack_center()
	var support := _rig.get_contact_depth_px(local_heading) * METERS_PER_ART_PIXEL
	%Craft.position = Vector2(0.0, -support)
	%Craft.rotation = local_heading
	_rig.position = -pivot * METERS_PER_ART_PIXEL
	%WorldJets.position = _rig.transform * _neck_socket(_rig)

	var zoom_factor := clampf(viewport_size.y * 0.58 / (altitude + 20.0), MIN_ZOOM, MAX_ZOOM)
	%FlightCamera.zoom = Vector2.ONE * zoom_factor
	%FlightCamera.position = Vector2(0.0, lerpf(-support, altitude, 0.36))
	%FlightCamera.force_update_scroll()
	%Surface.update_surface(radius, altitude, normal.angle(), viewport_size / zoom_factor,
		%FlightCamera.position.y, _telemetry.body_id == "moon", landing_mode)
	var projected_height := _rig.get_active_stack_height_px() * METERS_PER_ART_PIXEL * zoom_factor
	var threshold := DETAIL_EXIT_PX if %FarMarker.visible else DETAIL_ENTER_PX
	_set_vehicle_cam(not _crashed and _config != null and projected_height < threshold)
	%FarMarker.position = %Craft.position
	%FarMarker.rotation = local_heading
	%FarMarker.scale = Vector2.ONE / zoom_factor
	_vehicle_mount.rotation = local_heading


func _play_crash() -> void:
	_crashed = true
	%Craft.hide()
	_set_vehicle_cam(false)
	%CrashEffect.play_at(Vector2(0.0, _surface_y_m))
	%ImpactFlash.color.a = 0.26
	_crash_camera = create_tween().set_parallel(true)
	_crash_camera.tween_property(%ImpactFlash, "color:a", 0.0, 0.26)
	_crash_camera.tween_method(_shake_on_impact, 0.0, 1.0, 0.70)


func _shake_on_impact(progress: float) -> void:
	var decay := pow(1.0 - progress, 2.0)
	%FlightCamera.offset = Vector2(sin(progress * 74.0), sin(progress * 93.0)) * decay * 2.6
	%FlightCamera.force_update_scroll()


func _set_vehicle_cam(show_detail: bool) -> void:
	if show_detail == %FarMarker.visible:
		return
	%FarMarker.visible = show_detail
	if _vehicle_power != null:
		_vehicle_power.kill()
	_set_vehicle_input(false)
	if show_detail and not _vehicle_cam.visible:
		_vehicle_cam.scale = Vector2(0.07, 0.012)
	_vehicle_cam.show()
	_vehicle_power = create_tween()
	if show_detail:
		_vehicle_cam.modulate.a = 1.0
		_power_flash.color.a = 0.85
		_vehicle_power.tween_property(_vehicle_cam, "scale:x", 1.0, 0.065).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_vehicle_power.tween_property(_vehicle_cam, "scale:y", 1.0, 0.15).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		_vehicle_power.parallel().tween_property(_power_flash, "color:a", 0.0, 0.14)
		_vehicle_power.tween_callback(_set_vehicle_input.bind(true))
	else:
		_power_flash.color.a = 0.72
		_vehicle_power.tween_property(_vehicle_cam, "scale:y", 0.012, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_vehicle_power.tween_property(_vehicle_cam, "scale:x", 0.04, 0.07)
		_vehicle_power.parallel().tween_property(_vehicle_cam, "modulate:a", 0.0, 0.07)
		_vehicle_power.tween_callback(_vehicle_cam.hide)


func _center_vehicle_power() -> void:
	_vehicle_cam.pivot_offset = _vehicle_cam.size * 0.5


func _set_vehicle_input(enabled: bool) -> void:
	var mouse_mode := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	_vehicle_cam.mouse_filter = mouse_mode
	_vehicle_stage.mouse_filter = mouse_mode
	_vehicle_legs.mouse_filter = mouse_mode


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not _component_at(event.position).is_empty() else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		match _component_at(event.position):
			"engine":
				engine_pressed.emit()
				accept_event()
			"stage":
				stage_pressed.emit()
				accept_event()


func _component_at(point: Vector2) -> String:
	if _rig == null or _crashed or %FarMarker.visible or size.x <= 0.0 or size.y <= 0.0:
		return ""
	var viewport_point := point * Vector2(%WorldViewport.size) / size
	var rig_point := _rig.get_global_transform_with_canvas().affine_inverse() * viewport_point
	return _rig.hit_test_flight_component(rig_point)
