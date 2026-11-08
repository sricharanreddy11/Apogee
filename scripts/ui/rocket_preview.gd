class_name RocketPreview
extends Control

signal engine_pressed
signal stage_pressed

@export var show_launchpad: bool = true
@export var show_background: bool = true
@export var interactive_flight_controls: bool = false

var _config: RocketConfig
var _rig: RocketRig
var _telemetry: FlightTelemetry
var _body_id := "earth"
var _landed := false


func setup(config: RocketConfig) -> void:
	_config = config.copy() if config != null else null
	_landed = false
	if is_node_ready():
		_rig.setup(_config)
		_layout_rig()


func get_config() -> RocketConfig:
	return _config.copy() if _config != null else null


func set_body(body_id: String) -> void:
	_body_id = body_id
	queue_redraw()


func update_visuals(telemetry: FlightTelemetry) -> void:
	_telemetry = telemetry
	queue_redraw()
	if _rig == null:
		return
	_rig.apply_flight(telemetry.active_stage, telemetry.throttle, telemetry.legs_deployed)
	_rig.rotation = telemetry.heading_rad
	if not _landed and telemetry.status == FlightState.Status.LANDED:
		_landed = true
		if telemetry.body_id == "moon":
			_rig.lunar_touchdown()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive_flight_controls else Control.MOUSE_FILTER_IGNORE
	_rig = RocketRig.new()
	_rig.name = "RocketRig"
	add_child(_rig)
	_rig.setup(_config)
	resized.connect(_layout_rig)
	_layout_rig()


func _layout_rig() -> void:
	if show_launchpad:
		_rig.position = Vector2(size.x * 0.56, size.y * 0.84)
		_rig.scale = Vector2.ONE * minf(size.x / 210.0, size.y * 0.62 / maxf(_rig.height_px, 1.0))
	else:
		# The normal flight camera deliberately has no zoom: the rocket stays centered
		# at a readable, fixed framing while the simulation moves in world space.
		_rig.position = size * 0.5 + Vector2(0.0, _rig.height_px * 0.5)
		_rig.scale = Vector2.ONE * minf(1.35, minf(size.x / 240.0, size.y * 0.68 / maxf(_rig.height_px, 1.0)))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not interactive_flight_controls or _rig == null:
		return
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


func _component_at(control_point: Vector2) -> String:
	var canvas_point := get_global_transform_with_canvas() * control_point
	var rig_local := _rig.get_global_transform_with_canvas().affine_inverse() * canvas_point
	return _rig.hit_test_flight_component(rig_local)


func _draw() -> void:
	if not show_background or size.x <= 0.0 or size.y <= 0.0:
		return
	var lunar := _body_id == "moon"
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0c1827") if lunar else Color("#10253b"))
	for index in 14:
		var x := fmod(float(index * 97 + 31), maxf(size.x - 20.0, 1.0)) + 10.0
		var y := fmod(float(index * 61 + 11), maxf(size.y * 0.65, 1.0)) + 8.0
		draw_circle(Vector2(x, y), 1.2, Color("#7fadc4"))
	if not show_launchpad:
		_draw_flight_body()
		return
	var pad_y := size.y * 0.84
	if lunar:
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, pad_y + 12), Vector2(size.x * 0.19, pad_y - 22),
			Vector2(size.x * 0.45, pad_y + 2), Vector2(size.x * 0.72, pad_y - 16),
			Vector2(size.x, pad_y + 10), size, Vector2(0, size.y),
		]), Color("#536078"))
		for x in [0.12, 0.68, 0.9]:
			draw_line(Vector2(size.x * x - 15, pad_y + 30), Vector2(size.x * x + 15, pad_y + 30), Color("#343e55"), 4)
	else:
		draw_rect(Rect2(0.0, pad_y + 18.0, size.x, size.y - pad_y), Color("#1b3940"))
		var tower_x := size.x * 0.22
		var tower_top := size.y * 0.20
		draw_line(Vector2(tower_x, pad_y), Vector2(tower_x, tower_top), Color("#476579"), 9)
		draw_line(Vector2(tower_x + 27, pad_y), Vector2(tower_x + 27, tower_top), Color("#476579"), 5)
		for index in 6:
			var y := lerpf(tower_top, pad_y, float(index) / 6.0)
			draw_line(Vector2(tower_x, y), Vector2(tower_x + 27, y + (pad_y - tower_top) / 6.0), Color("#476579"), 3)
	draw_rect(Rect2(size.x * 0.34, pad_y, size.x * 0.44, 16.0), Color("#81929a"))


## Normal view is deliberately cinematic rather than distance-scaled: the
## rocket keeps its fixed readable size while the active planet remains in the
## correct direction and recedes as altitude increases. This preserves a clear
## surface reference for launch and landing without turning this into the map.
func _draw_flight_body() -> void:
	if _telemetry == null or _rig == null:
		return
	var body_radius_m := _telemetry.moon_radius_m if _telemetry.body_id == "moon" else _telemetry.earth_radius_m
	if body_radius_m <= 0.0:
		return
	var to_body := _telemetry.central_body_position_m - _telemetry.position_m
	if to_body.is_zero_approx():
		to_body = Vector2.DOWN
	else:
		to_body = to_body.normalized()
	var short_side := minf(size.x, size.y)
	var altitude_ratio := maxf(_telemetry.altitude_m, 0.0) / body_radius_m
	var radius_px := clampf(short_side * 2.4 / (1.0 + altitude_ratio * 1.5), short_side * 0.13, short_side * 2.4)
	var rocket_half_height := _rig.height_px * _rig.scale.y * 0.5
	var surface_gap := minf(altitude_ratio * short_side * 0.42, short_side * 0.35)
	var center := size * 0.5 + to_body * (radius_px + rocket_half_height + 16.0 + surface_gap)
	var lunar := _telemetry.body_id == "moon"
	var fill := Color("#66738a") if lunar else Color("#1d638d")
	var rim := Color("#c5cfdd") if lunar else Color("#63d5ed")
	draw_circle(center, radius_px, fill)
	# A few broad land/shadow marks keep the reference body legible while
	# remaining abstract enough to work at every cinematic scale.
	if lunar:
		draw_circle(center + Vector2(-0.28, -0.36) * radius_px, maxf(radius_px * 0.08, 3.0), Color("#535f75"))
		draw_circle(center + Vector2(0.35, -0.52) * radius_px, maxf(radius_px * 0.055, 2.0), Color("#7b879b"))
	else:
		draw_circle(center + Vector2(-0.34, -0.58) * radius_px, maxf(radius_px * 0.16, 4.0), Color("#3f846d"))
		draw_circle(center + Vector2(0.28, -0.63) * radius_px, maxf(radius_px * 0.11, 3.0), Color("#4a9273"))
	draw_arc(center, radius_px, 0.0, TAU, 96, rim, 3.0, true)
