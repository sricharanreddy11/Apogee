@tool
extends Control

const AMBER := Color("#ffca7d")
var _angle := 0.0


func _process(delta: float) -> void:
	_angle = fposmod(_angle + delta * 1.1, TAU)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 18, Color("#1b2933"), true, -1, true)
	draw_circle(center, 13.5, Color("#4b3b2a"), true, -1, true)
	draw_arc(center, 14, 0, TAU, 42, AMBER, 1.5, true)
	draw_arc(center, 10.8, 0, TAU, 36, Color("#876a46"), 1.0, true)
	var insignia := PackedVector2Array()
	for index in 8:
		var radius := 7.0 if index % 2 == 0 else 2.6
		insignia.append(center + Vector2.from_angle(-PI * 0.5 + index * TAU / 8.0) * radius)
	draw_colored_polygon(insignia, AMBER)
	var orbit := PackedVector2Array()
	for index in 49:
		orbit.append(center + _orbit_point(index * TAU / 48.0))
	draw_polyline(orbit, Color(0.91, 0.73, 0.49, 0.62), 1.0, true)
	draw_circle(center + _orbit_point(_angle), 2.5, Color("#fff0c9"), true, -1, true)


func _orbit_point(angle: float) -> Vector2:
	return Vector2(cos(angle) * 25.0, sin(angle) * 8.5).rotated(-0.45)
