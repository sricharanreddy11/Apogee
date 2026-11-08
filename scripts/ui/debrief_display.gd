@tool
extends Control

const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Regular.res")
const GRID := Color(0.24, 0.38, 0.49, 0.28)
const ROUTE := Color("#7ee1e5")
const DIM := Color("#7495a4")
const SCREEN := Vector2(600, 380)

var progress := 1.0:
	set(value):
		progress = value
		queue_redraw()
var _mission := ""
var _accent := Color("#8ee8bd")


func configure(mission_id: String, accent: Color) -> void:
	_mission = mission_id
	_accent = accent
	queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var fit := minf(size.x / SCREEN.x, size.y / SCREEN.y)
	if fit <= 0.0:
		return
	draw_set_transform((size - SCREEN * fit) / 2.0, 0, Vector2.ONE * fit)
	for radius: float in [95.0, 140.0, 188.0, 237.0]:
		draw_arc(Vector2(300, 196), radius, deg_to_rad(207), deg_to_rad(342), 54, Color(_accent, 0.11), 1, true)
	for x in range(30, 600, 45):
		draw_line(Vector2(x, 64), Vector2(x, 338), GRID)
	for y in range(68, 339, 45):
		draw_line(Vector2(27, y), Vector2(573, y), GRID)
	match _mission:
		"M01":
			_ascent()
		"M02":
			_orbit()
		"M03":
			_flyby()
		"M04":
			_landing()
		_:
			_planet(Vector2(300, 197), 76, false)
			_label(Vector2(213, 315), "AWAITING FLIGHT RECORD", DIM)
	if progress < 1.0:
		var scan_y := lerpf(56.0, 338.0, progress)
		draw_rect(Rect2(28, scan_y - 12, 544, 12), Color(0.35, 0.90, 0.94, 0.055))
		draw_line(Vector2(28, scan_y), Vector2(572, scan_y), Color(0.50, 0.92, 0.96, 0.3), 1.4)
		draw_line(Vector2(197, 354), Vector2(403, 354), GRID, 2)
		draw_line(Vector2(197, 354), Vector2(197 + progress * 206, 354), _accent, 2)


func _ascent() -> void:
	var ground := PackedVector2Array([Vector2(27, 326), Vector2(130, 306), Vector2(238, 298), Vector2(365, 298), Vector2(479, 307), Vector2(573, 326)])
	var fill := ground.duplicate()
	fill.append(Vector2(573, 338))
	fill.append(Vector2(27, 338))
	draw_colored_polygon(fill, Color("#183649"))
	draw_polyline(ground, Color("#5093ad"), 2, true)
	draw_dashed_line(Vector2(31, 134), Vector2(570, 134), Color("#e1b76f"), 1.5, 9, true, true)
	_label(Vector2(39, 125), "100 KM  /  KÁRMÁN LINE", Color("#f1c67d"))
	_trace(_curve(Vector2(246, 297), Vector2(247, 197), Vector2(264, 115), Vector2(379, 77)))
	_label(Vector2(399, 82), "SPACE", DIM)


func _orbit() -> void:
	var earth := Vector2(302, 194)
	_planet(earth, 65, false)
	var points := PackedVector2Array()
	for index in 97:
		var angle := TAU * index / 96.0 - 1.8
		points.append(earth + Vector2(cos(angle) * 202.0, sin(angle) * 101.0).rotated(-0.27))
	_trace(points)
	_label(Vector2(365, 318), "ORBITAL FREE FALL", ROUTE)


func _flyby() -> void:
	_planet(Vector2(109, 219), 53, false)
	_planet(Vector2(458, 187), 32, true)
	var points := _curve(Vector2(151, 198), Vector2(289, 59), Vector2(484, 70), Vector2(505, 173))
	points.append_array(_curve(Vector2(505, 173), Vector2(541, 296), Vector2(282, 308), Vector2(145, 255)))
	_trace(points)
	_label(Vector2(60, 298), "EARTH", DIM)
	_label(Vector2(427, 240), "MOON", DIM)
	_label(Vector2(248, 322), "APOLLO 13  /  FREE RETURN", ROUTE)


func _landing() -> void:
	var ground := PackedVector2Array([Vector2(28, 301), Vector2(116, 290), Vector2(185, 300), Vector2(215, 313), Vector2(270, 313), Vector2(302, 298), Vector2(416, 298), Vector2(489, 288), Vector2(571, 300)])
	var fill := ground.duplicate()
	fill.append(Vector2(571, 338))
	fill.append(Vector2(28, 338))
	draw_colored_polygon(fill, Color("#293844"))
	draw_polyline(ground, DIM, 2, true)
	for rock: Vector2 in [Vector2(141, 293), Vector2(168, 297), Vector2(185, 301), Vector2(207, 308)]:
		draw_circle(rock - Vector2(0, 4), 6, Color("#60717a"), true, -1, true)
	_label(Vector2(90, 331), "BOULDER FIELD", DIM, 11)
	_label(Vector2(337, 326), "CLEAR GROUND", ROUTE, 11)
	var points := _curve(Vector2(121, 76), Vector2(216, 103), Vector2(329, 199), Vector2(374, 275))
	_trace(points, true)
	draw_line(Vector2(346, 298), Vector2(402, 298), ROUTE, 2)
	if progress > 0.92:
		var dust := clampf((progress - 0.92) / 0.08, 0, 1)
		for direction: float in [-1.0, 1.0]:
			draw_arc(Vector2(374, 299), 18.0 + dust * 28.0, PI if direction < 0 else -0.5, PI + 0.5 if direction < 0 else 0.0, 12, Color(0.65, 0.79, 0.81, 1.0 - dust), 2, true)


func _planet(center: Vector2, radius: float, moon: bool) -> void:
	var base := Color("#435563") if moon else Color("#153e55")
	var rim := Color("#94a8b1") if moon else Color("#74b8d1")
	draw_circle(center, radius + 5, Color(rim, 0.1), true, -1, true)
	draw_circle(center, radius, base, true, -1, true)
	draw_arc(center, radius, 0, TAU, 64, rim, 1.8, true)
	if moon:
		for offset: Vector2 in [Vector2(-0.28, -0.26), Vector2(0.24, 0.21), Vector2(-0.28, 0.37)]:
			draw_circle(center + offset * radius, radius * 0.19, base.darkened(0.3), true, -1, true)
	else:
		for row: float in [-0.55, 0.0, 0.55]:
			var width := sqrt(1.0 - row * row) * radius
			draw_line(center + Vector2(-width, row * radius), center + Vector2(width, row * radius), Color(rim, 0.25), 1)
		draw_arc(center, radius * 0.65, -1.2, 1.2, 22, Color(rim, 0.3), 1.4, true)


func _curve(from: Vector2, first: Vector2, second: Vector2, to: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 49:
		points.append(from.bezier_interpolate(first, second, to, index / 48.0))
	return points


func _trace(points: PackedVector2Array, lander := false) -> void:
	draw_polyline(points, Color("#375762"), 1.6, true)
	var index := mini(roundi(progress * (points.size() - 1)), points.size() - 1)
	if index > 0:
		var trail := points.slice(0, index + 1)
		draw_polyline(trail, Color(ROUTE, 0.16), 7, true)
		draw_polyline(trail, ROUTE, 2, true)
	var spot := points[index]
	var heading := Vector2.UP if lander else (points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]).normalized()
	var wing := heading.orthogonal()
	draw_circle(spot, 19, Color(ROUTE, 0.12), true, -1, true)
	draw_colored_polygon(PackedVector2Array([spot + heading * 13, spot - heading * 8 + wing * 8, spot - heading * 4, spot - heading * 8 - wing * 8]), Color("#ebfbfc"))
	if lander:
		draw_polyline(PackedVector2Array([spot + Vector2(-11, 15), spot + Vector2(-8, 8), spot + Vector2(8, 8), spot + Vector2(11, 15)]), Color("#ffc67d"), 2, true)


func _label(at: Vector2, value: String, ink: Color, font_size := 14) -> void:
	draw_string(MONO, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
