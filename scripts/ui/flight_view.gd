extends Control

signal engine_pressed
signal stage_pressed
signal legs_pressed

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
var _surface_y_m := 0.0
var _vehicle_fade: Tween
@onready var _rig: RocketRig = %RocketRig
@onready var _vehicle_rig: RocketRig = %VehicleRig


func setup(config: RocketConfig) -> void:
	_config = config.copy() if config != null else null
	_landed = false
	if is_node_ready():
		_setup_rigs()


func get_config() -> RocketConfig:
	return _config.copy() if _config != null else null


func update_visuals(telemetry: FlightTelemetry) -> void:
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
	if _config != null:
		%StageReadout.text = "STAGE %d / %d" % [telemetry.active_stage + 1, _config.stages.size()]
	%VehicleLegs.text = "RETRACT" if telemetry.legs_deployed else "DEPLOY"
	_update_world()
	if telemetry.status == FlightState.Status.LANDED and not _landed:
		_landed = true
		if telemetry.contact_body_id == "moon":
			%LandingDust.position = Vector2(0.0, _surface_y_m)
			%LandingDust.restart()
			%LandingDust.emitting = true


func get_touchdown_screen_position() -> Vector2:
	var pixel: Vector2 = %WorldViewport.get_canvas_transform() * Vector2(0.0, _surface_y_m)
	return pixel * size / Vector2(%WorldViewport.size)


func set_vehicle_controls(can_stage: bool, can_toggle_legs: bool) -> void:
	%VehicleStage.disabled = not can_stage
	%VehicleLegs.disabled = not can_toggle_legs


func _ready() -> void:
	_setup_rigs()
	%VehicleStage.pressed.connect(stage_pressed.emit)
	%VehicleLegs.pressed.connect(legs_pressed.emit)
	%WorldViewport.size_changed.connect(_update_world)
	_update_world()


func _setup_rigs() -> void:
	_rig.setup(_config)
	_vehicle_rig.setup(_config)
	# Fit the full stack with room for the feet and exhaust in any orientation.
	%VehicleMount.scale = Vector2.ONE * minf(0.65, 165.0 / (_vehicle_rig.height_px + 110.0))


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

	var zoom_factor := clampf(viewport_size.y * 0.58 / (altitude + 20.0), MIN_ZOOM, MAX_ZOOM)
	%FlightCamera.zoom = Vector2.ONE * zoom_factor
	%FlightCamera.position = Vector2(0.0, lerpf(-support, altitude, 0.36))
	%FlightCamera.force_update_scroll()
	%Surface.update_surface(radius, altitude, normal.angle(), viewport_size / zoom_factor,
		%FlightCamera.position.y, _telemetry.body_id == "moon", landing_mode)
	var projected_height := _rig.get_active_stack_height_px() * METERS_PER_ART_PIXEL * zoom_factor
	var threshold := DETAIL_EXIT_PX if %FarMarker.visible else DETAIL_ENTER_PX
	_set_vehicle_cam(_config != null and projected_height < threshold)
	%FarMarker.position = %Craft.position
	%FarMarker.rotation = local_heading
	%FarMarker.scale = Vector2.ONE / zoom_factor
	%VehicleMount.rotation = local_heading


func _set_vehicle_cam(show_detail: bool) -> void:
	if show_detail == %FarMarker.visible:
		return
	%FarMarker.visible = show_detail
	if _vehicle_fade != null:
		_vehicle_fade.kill()
	var mouse_mode := Control.MOUSE_FILTER_STOP if show_detail else Control.MOUSE_FILTER_IGNORE
	%VehicleCam.mouse_filter = mouse_mode
	%VehicleStage.mouse_filter = mouse_mode
	%VehicleLegs.mouse_filter = mouse_mode
	%VehicleCam.show()
	_vehicle_fade = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_vehicle_fade.tween_property(%VehicleCam, "modulate:a", 1.0 if show_detail else 0.0, 0.22)
	if not show_detail:
		_vehicle_fade.tween_callback(%VehicleCam.hide)


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
	if _rig == null or %FarMarker.visible or size.x <= 0.0 or size.y <= 0.0:
		return ""
	var viewport_point := point * Vector2(%WorldViewport.size) / size
	var rig_point := _rig.get_global_transform_with_canvas().affine_inverse() * viewport_point
	return _rig.hit_test_flight_component(rig_point)
