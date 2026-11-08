@tool
extends Control

const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Regular.res")
const CYAN := Color("#77e2e8")
const AMBER := Color("#ffc67d")
const MINT := Color("#a9f5ad")
const INK := Color("#e7edf1")
const MUTED := Color("#8b9ca7")
const DARK := Color("#0a1118")
const DIGITS := [0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f]
const SEGMENTS := [
	Vector4(3, 2, 15, 2), Vector4(17, 4, 17, 14), Vector4(17, 18, 17, 28),
	Vector4(3, 30, 15, 30), Vector4(1, 18, 1, 28), Vector4(1, 4, 1, 14),
	Vector4(3, 16, 15, 16),
]

var _flight: FlightTelemetry
var _needle_mps := 0.0


func _ready() -> void:
	resized.connect(queue_redraw)


func update_from_telemetry(telemetry: FlightTelemetry) -> void:
	if _flight == null:
		_needle_mps = telemetry.speed_mps
	_flight = telemetry
	queue_redraw()


func _process(delta: float) -> void:
	if _flight == null or is_equal_approx(_needle_mps, _flight.speed_mps):
		return
	_needle_mps = lerpf(_needle_mps, _flight.speed_mps, 1.0 - exp(-12.0 * delta))
	queue_redraw()


func _draw() -> void:
	var layout := Vector2(900, 214)
	var scale_factor := minf(size.x / layout.x, size.y / layout.y)
	if scale_factor <= 0.0:
		return
	draw_set_transform((size - layout * scale_factor) * 0.5, 0.0, Vector2.ONE * scale_factor)
	_draw_altimeter()
	_draw_velocity()
	_draw_systems()


func _draw_altimeter() -> void:
	var altitude := _flight.altitude_m if _flight != null else 0.0
	var radial := _flight.radial_speed_mps if _flight != null else 0.0
	var body := _flight.body_id.to_upper() if _flight != null else "EARTH"
	_plate(Rect2(2, 3, 276, 208), "01   /   ALTIMETER", CYAN)
	draw_rect(Rect2(19, 39, 95, 153), Color("#08141b"))
	var step := _altitude_step(altitude)
	var tick_base := floorf(altitude / step)
	for offset in range(-3, 5):
		var tick := (tick_base + offset) * step
		var y := 116.0 + (altitude - tick) / step * 22.0
		if tick < 0.0 or y < 50.0 or y > 183.0:
			continue
		draw_line(Vector2(95, y), Vector2(112, y), Color("#527782"), 1.0)
		draw_line(Vector2(103, y - 11), Vector2(112, y - 11), Color("#314d57"), 1.0)
		var label := "%.1f" % (tick / 1000.0) if step >= 100.0 else "%.0f" % tick
		_text(Vector2(27, y + 4.0), label, 13, MUTED, 63.0)
	draw_colored_polygon(PackedVector2Array([Vector2(102, 116), Vector2(119, 106), Vector2(119, 126)]), CYAN)
	_text(Vector2(130, 75), "%s  /  SURFACE" % body, 13, MUTED)
	var distance := altitude / 1000.0 if altitude >= 1000.0 else altitude
	_text(Vector2(128, 119), "%.1f" % distance, 32 if distance < 10000.0 else 23, INK)
	_text(Vector2(130, 144), "KILOMETERS" if altitude >= 1000.0 else "METERS", 13, CYAN)
	draw_line(Vector2(130, 155), Vector2(253, 155), Color("#304550"))
	_text(Vector2(130, 178), "%+.1f m/s" % radial, 14, CYAN)


func _altitude_step(altitude: float) -> float:
	if altitude < 100.0:
		return 5.0
	if altitude < 1000.0:
		return 25.0
	if altitude < 10000.0:
		return 500.0
	return 10000.0 if altitude < 100000.0 else 50000.0


func _draw_velocity() -> void:
	_plate(Rect2(288, 3, 235, 208), "02   /   VELOCITY", AMBER)
	var hub := Vector2(406, 112)
	draw_circle(hub, 76.0, Color("#0b1116"), true, -1.0, true)
	draw_arc(hub, 77.0, 0, TAU, 80, Color("#465059"), 2.0, true)
	draw_arc(hub, 66.0, deg_to_rad(145), deg_to_rad(395), 60, Color("#775a3d"), 2.0, true)
	for index in range(0, 26):
		var axis := Vector2.from_angle(deg_to_rad(145 + index * 10))
		draw_line(hub + axis * 63.0, hub + axis * 66.0, MUTED, 1.0, true)
	for mark: int in [0, 100, 500, 2000, 5000]:
		var axis := Vector2.from_angle(_speed_angle(mark))
		draw_line(hub + axis * 56.0, hub + axis * 66.0, AMBER, 1.8, true)
		var mark_pos := hub + axis * 45.0
		var label := "%dk" % (mark / 1000) if mark >= 1000 else str(mark)
		_text(mark_pos + Vector2(-18, 4), label, 11, MUTED, 36, HORIZONTAL_ALIGNMENT_CENTER)
	var direction := Vector2.from_angle(_speed_angle(_needle_mps))
	draw_line(hub - direction * 10.0, hub + direction * 57.0, AMBER, 3.0, true)
	draw_circle(hub, 5.5, INK, true, -1.0, true)
	draw_rect(Rect2(343, 157, 126, 30), Color("#201a14"))
	_text(Vector2(343, 179), "%.0f m/s" % (_flight.speed_mps if _flight != null else 0.0), 16, AMBER, 126, HORIZONTAL_ALIGNMENT_CENTER)


func _speed_angle(speed: float) -> float:
	return deg_to_rad(145.0 + 250.0 * log(1.0 + clampf(speed, 0.0, 5000.0) / 150.0) / log(1.0 + 5000.0 / 150.0))


func _draw_systems() -> void:
	_plate(Rect2(533, 3, 365, 208), "03   /   FLIGHT SYSTEMS", MINT)
	var fuel := clampf(_flight.fuel_fraction, 0.0, 1.0) if _flight != null else 0.0
	var fuel_color := AMBER if fuel < 0.2 else MINT
	_text(Vector2(550, 63), "PROPELLANT", 13, MUTED)
	_text(Vector2(814, 64), "%.0f%%" % (fuel * 100.0), 19, fuel_color, 67)
	for index in range(20):
		var cell := Rect2(550 + index * 16.4, 73, 13.0, 16.0)
		draw_rect(cell, Color("#26352f"))
		cell.size.x *= clampf(fuel * 20.0 - index, 0.0, 1.0)
		draw_rect(cell, fuel_color)
	_text(Vector2(550, 115), "MISSION ELAPSED", 12, MUTED)
	_draw_clock(Vector2(550, 124), _flight.elapsed_time_s if _flight != null else 0.0)
	var state: String = ["READY", "IN FLIGHT", "LANDED", "CRASHED"][_flight.status] if _flight != null else "READY"
	var stage := _flight.active_stage + 1 if _flight != null else 1
	_text(Vector2(735, 138), "STAGE  %02d" % stage, 15, INK)
	_text(Vector2(735, 158), state, 13, MUTED)
	if _flight != null and _flight.has_bound_orbit:
		_text(Vector2(550, 191), "AP %.1f km    PE %.1f km" % [
			_flight.apoapsis_altitude_m / 1000.0, _flight.periapsis_altitude_m / 1000.0,
		], 14, CYAN)


func _draw_clock(origin: Vector2, elapsed: float) -> void:
	draw_rect(Rect2(origin - Vector2(6, 5), Vector2(177, 43)), Color("#080406"))
	var second := int(elapsed)
	var clock := _clock_digits(second)
	var previous := _clock_digits(maxi(0, second - 1))
	var pulse := smoothstep(0.0, 0.10, fposmod(elapsed, 1.0))
	var cursor := origin + Vector2(5, 0)
	for digit_index in clock.length():
		var character := clock[digit_index]
		if character == ":":
			draw_circle(cursor + Vector2(4, 10), 2.0, Color("#ff4a59"), true, -1.0, true)
			draw_circle(cursor + Vector2(4, 22), 2.0, Color("#ff4a59"), true, -1.0, true)
			cursor.x += 10.0
			continue
		var mask: int = DIGITS[character.to_int()]
		var previous_mask: int = DIGITS[previous[digit_index].to_int()]
		for index in SEGMENTS.size():
			var segment: Vector4 = SEGMENTS[index]
			var start := cursor + Vector2(segment.x, segment.y)
			var end := cursor + Vector2(segment.z, segment.w)
			var lit := (mask & (1 << index)) != 0
			var was_lit := (previous_mask & (1 << index)) != 0
			var brightness := (1.0 if was_lit else lerpf(0.68, 1.0, pulse)) if lit else 0.0
			draw_line(start, end, Color(0.44, 0.09, 0.14, brightness), 5.5, true)
			draw_line(start, end, Color("#351119").lerp(Color("#ff4a59"), brightness), 2.7, true)
		cursor.x += 22.0


func _clock_digits(seconds: int) -> String:
	return "%02d:%02d:%02d" % [int(seconds / 3600) % 100, int(seconds / 60) % 60, seconds % 60]


func _plate(rect: Rect2, title: String, accent: Color) -> void:
	draw_rect(rect, Color("#202a33"))
	draw_rect(rect.grow(-2.0), DARK)
	draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, 31)), Color("#19242d"))
	draw_line(rect.position + Vector2(2, 34), rect.position + Vector2(rect.size.x - 2, 34), Color("#354551"))
	_text(rect.position + Vector2(17, 23), title, 14, accent)
	for corner in [Vector2(9, 9), Vector2(rect.size.x - 9, 9), Vector2(9, rect.size.y - 9), Vector2(rect.size.x - 9, rect.size.y - 9)]:
		draw_circle(rect.position + corner, 2.4, Color("#53606a"), true, -1.0, true)


func _text(at: Vector2, value: String, font_size: int, color: Color, width := -1.0, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(MONO, at, value, alignment, width, font_size, color)
