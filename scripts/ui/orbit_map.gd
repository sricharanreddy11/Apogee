class_name OrbitMap
extends Control

const MIN_ZOOM := 0.25
const MAX_ZOOM := 10.0
const ROCKET_MARKER_SIZE_PX := 10.0
const TRAIL_LIMIT := 360
const MAX_PAN_DISTANCE_M := 12000000.0

var show_landing_site := false
var _telemetry: FlightTelemetry
var _prediction: TrajectoryPrediction
var _zoom := 1.0
var _pan_offset_m := Vector2.ZERO
var _dragging := false
var _auto_frame_enabled := false
var _trail := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func update_from_telemetry(telemetry: FlightTelemetry) -> void:
	_telemetry = telemetry
	if _trail.is_empty() or _trail[-1].distance_squared_to(telemetry.position_m) > 400.0:
		_trail.append(telemetry.position_m)
		if _trail.size() > TRAIL_LIMIT:
			_trail.remove_at(0)
	queue_redraw()


func set_prediction(prediction: TrajectoryPrediction) -> void:
	_prediction = prediction
	if _auto_frame_enabled:
		call_deferred("_frame_prediction")
	queue_redraw()


func set_auto_frame_enabled(enabled: bool) -> void:
	_auto_frame_enabled = enabled
	if enabled and _prediction != null:
		call_deferred("_frame_prediction")


func reset_path() -> void:
	_trail.clear()
	_prediction = null
	reset_camera()
	queue_redraw()


func get_zoom() -> float:
	return _zoom


func get_pan_offset_m() -> Vector2:
	return _pan_offset_m


func reset_camera() -> void:
	_pan_offset_m = Vector2.ZERO
	_dragging = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_auto_frame_enabled = false
			_zoom_at(event.position, 1.2)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_auto_frame_enabled = false
			_zoom_at(event.position, 1.0 / 1.2)
			accept_event()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			if event.pressed:
				_auto_frame_enabled = false
			_dragging = event.pressed
			mouse_default_cursor_shape = Control.CURSOR_DRAG if _dragging else Control.CURSOR_ARROW
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			reset_camera()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		pan_by_screen_delta(event.relative)
		accept_event()


func _frame_prediction() -> void:
	if not _auto_frame_enabled or _telemetry == null or _prediction == null \
		or not _prediction.valid or size.x <= 0.0 or size.y <= 0.0:
		return
	var earth_padding := Vector2.ONE * _telemetry.earth_radius_m
	var moon_padding := Vector2.ONE * _telemetry.moon_radius_m
	var minimum := _telemetry.earth_position_m - earth_padding
	var maximum := _telemetry.earth_position_m + earth_padding
	minimum = minimum.min(_telemetry.moon_position_m - moon_padding)
	maximum = maximum.max(_telemetry.moon_position_m + moon_padding)
	minimum = minimum.min(_telemetry.position_m)
	maximum = maximum.max(_telemetry.position_m)
	for point in _prediction.positions_m:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	var span := maximum - minimum
	if span.x <= 0.0 or span.y <= 0.0:
		return
	var available := size * 0.82
	var fitted_scale := minf(available.x / span.x, available.y / span.y)
	_zoom = clampf(fitted_scale / _meters_to_pixels(), MIN_ZOOM, MAX_ZOOM)
	var center := (minimum + maximum) * 0.5
	_pan_offset_m = (center - _telemetry.central_body_position_m).limit_length(MAX_PAN_DISTANCE_M)
	queue_redraw()


func pan_by_screen_delta(delta_px: Vector2) -> void:
	if _telemetry == null:
		return
	var scale := _meters_to_pixels() * _zoom
	if scale <= 0.0:
		return
	_pan_offset_m -= delta_px / scale
	_pan_offset_m = _pan_offset_m.limit_length(MAX_PAN_DISTANCE_M)
	queue_redraw()


func _zoom_at(screen_position: Vector2, factor: float) -> void:
	if _telemetry == null:
		_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
		queue_redraw()
		return
	var old_scale := _meters_to_pixels() * _zoom
	var old_focus := _camera_focus()
	var world_under_cursor := old_focus + (screen_position - size * 0.5) / old_scale
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	var new_scale := _meters_to_pixels() * _zoom
	var desired_focus := world_under_cursor - (screen_position - size * 0.5) / new_scale
	_pan_offset_m = (desired_focus - _telemetry.central_body_position_m).limit_length(MAX_PAN_DISTANCE_M)
	queue_redraw()


func _draw() -> void:
	if _telemetry == null or size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#07111f"))
	var focus := _camera_focus()
	var scale := _meters_to_pixels() * _zoom
	_draw_moon_orbit(focus, scale)
	_draw_path(_trail, focus, scale, Color(0.35, 0.78, 0.91, 0.34), 1.5)
	if _prediction != null and _prediction.valid:
		_draw_path(_prediction.positions_m, focus, scale, Color("#f5c96b"), 2.25)
	_draw_body(_telemetry.earth_position_m, _telemetry.earth_radius_m, focus, scale, Color("#245f88"), Color("#59c8e8"))
	_draw_body(_telemetry.moon_position_m, _telemetry.moon_radius_m, focus, scale, Color("#758095"), Color("#cad2df"))
	_draw_mission_markers(focus, scale)
	_draw_rocket_marker(_world_to_screen(_telemetry.position_m, focus, scale))
	var font := get_theme_default_font()
	var framing := " AUTO" if _auto_frame_enabled else ""
	draw_string(font, Vector2(16.0, 25.0), "ORBIT%s  ×%.2f" % [framing, _zoom], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("#b9d5e5"))


func _draw_mission_markers(focus: Vector2, scale: float) -> void:
	if _telemetry.has_bound_orbit and _telemetry.altitude_m > 0.0:
		if _telemetry.apoapsis_altitude_m >= 0.0:
			_draw_marker(_telemetry.apoapsis_position_m, "AP", focus, scale, Color("#81dbf1"))
		if _telemetry.periapsis_altitude_m >= 0.0:
			_draw_marker(_telemetry.periapsis_position_m, "PE", focus, scale, Color("#81dbf1"))
	if show_landing_site:
		var site := _telemetry.moon_position_m + Vector2.UP * _telemetry.moon_radius_m
		_draw_marker(site, "LANDING ZONE", focus, scale, Color("#83edba"))
	if _prediction == null or not _prediction.valid:
		return
	if not _prediction.impact_body_id.is_empty():
		_draw_marker(_prediction.positions_m[-1], "IMPACT", focus, scale, Color("#ff8a91"))
	if _prediction.lunar_closest_altitude_m < 350000.0 and _prediction.lunar_closest_time_s - _prediction.elapsed_time_s > 2.0:
		var label := "MOON CA %.1f km" % (_prediction.lunar_closest_altitude_m / 1000.0)
		_draw_marker(_prediction.lunar_closest_position_m, label, focus, scale, Color("#ffbd71"))
		var future := _world_to_screen(_prediction.lunar_future_position_m, focus, scale)
		draw_arc(future, maxf(4.0, _telemetry.moon_radius_m * scale), 0, TAU, 40, Color(0.95, 0.76, 0.52, 0.40), 1.0, true)


func _draw_marker(world: Vector2, label: String, focus: Vector2, scale: float, color: Color) -> void:
	var point := _world_to_screen(world, focus, scale)
	if not Rect2(Vector2.ZERO, size).grow(-6.0).has_point(point):
		return
	var font := get_theme_font("font", &"TelemetryLabel")
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var x := clampf(point.x + 9.0, 4.0, maxf(4.0, size.x - width - 5.0))
	var y := maxf(18.0, point.y - 8.0)
	draw_circle(point, 4.0, color, false, 1.5, true)
	draw_rect(Rect2(x - 3.0, y - 14.0, width + 6.0, 18.0), Color("#07111f"))
	draw_string(font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, color)


func _draw_moon_orbit(focus: Vector2, scale: float) -> void:
	var orbit_radius_m := _telemetry.moon_position_m.distance_to(_telemetry.earth_position_m)
	if orbit_radius_m <= 0.0:
		return
	var center := _world_to_screen(_telemetry.earth_position_m, focus, scale)
	var radius_px := orbit_radius_m * scale
	draw_arc(center, radius_px, 0.0, TAU, 192, Color(0.74, 0.82, 0.91, 0.18), 1.25, true)


func _draw_path(points: PackedVector2Array, focus: Vector2, scale: float, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	var screen_points := PackedVector2Array()
	for point in points:
		screen_points.append(_world_to_screen(point, focus, scale))
	draw_polyline(screen_points, color, width, true)


func _draw_body(position: Vector2, radius_m: float, focus: Vector2, scale: float, fill: Color, outline: Color) -> void:
	if radius_m <= 0.0:
		return
	var center := _world_to_screen(position, focus, scale)
	var radius_px := maxf(radius_m * scale, 3.0)
	if center.x + radius_px < 0.0 or center.x - radius_px > size.x or center.y + radius_px < 0.0 or center.y - radius_px > size.y:
		return
	draw_circle(center, radius_px, fill)
	draw_arc(center, radius_px, 0.0, TAU, 64, outline, 2.0, true)


func _draw_rocket_marker(position: Vector2) -> void:
	var forward := Vector2.UP.rotated(_telemetry.heading_rad)
	var right := forward.rotated(PI * 0.5)
	var points := PackedVector2Array([
		position + forward * ROCKET_MARKER_SIZE_PX,
		position - forward * ROCKET_MARKER_SIZE_PX * 0.65 + right * ROCKET_MARKER_SIZE_PX * 0.62,
		position - forward * ROCKET_MARKER_SIZE_PX * 0.65 - right * ROCKET_MARKER_SIZE_PX * 0.62,
	])
	draw_colored_polygon(points, Color("#ffffff"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color("#0b2234"), 1.5, true)


func _meters_to_pixels() -> float:
	var half_extent_m := 2200000.0
	return minf(size.x, size.y) * 0.46 / half_extent_m


func _camera_focus() -> Vector2:
	return _telemetry.central_body_position_m + _pan_offset_m


func _world_to_screen(world_position: Vector2, focus: Vector2, scale: float) -> Vector2:
	return size * 0.5 + (world_position - focus) * scale
