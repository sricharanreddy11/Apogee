extends Control
var mission_id := ""
const CYAN := Color("8be5ef")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.025, 0.065, 0.1, 0.95)
	frame.border_color = Color(CYAN, 0.4)
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(5)
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	draw_set_transform(Vector2(size.x * 0.5, 31))
	if mission_id == "M03":
		draw_rect(Rect2(-9, -9, 18, 18), Color(CYAN, 0.12))
		draw_rect(Rect2(-9, -9, 18, 18), CYAN, false, 1)
		for side: float in [-1, 1]:
			draw_rect(Rect2(side * 21 - 9, -6, 18, 12), Color(CYAN, 0.65), false, 1)
			draw_line(Vector2(side * 9, 0), Vector2(side * 12, 0), CYAN, 1)
		draw_line(Vector2(0, -9), Vector2(8, -20), CYAN, 1)
	elif mission_id == "M04":
		draw_polyline(PackedVector2Array([Vector2(-12, 5), Vector2(-10, -9), Vector2(0, -17), Vector2(10, -9), Vector2(12, 5), Vector2(-12, 5)]), CYAN, 1.2, true)
		for side: float in [-1, 1]:
			draw_line(Vector2(side * 9, 1), Vector2(side * 23, 17), CYAN, 1.2)
			draw_line(Vector2(side * 18, 17), Vector2(side * 28, 17), CYAN, 1.2)
	else:
		draw_polyline(PackedVector2Array([Vector2(-7, 17), Vector2(-7, -8), Vector2(0, -21), Vector2(7, -8), Vector2(7, 17), Vector2(-7, 17)]), CYAN, 1.2, true)
		if mission_id == "M02":
			draw_arc(Vector2.ZERO, 25, 0.2, 5.5, 40, Color(CYAN, 0.45), 1, true)
		else:
			draw_line(Vector2(17, 14), Vector2(17, -14), Color(CYAN, 0.7), 1)
			draw_line(Vector2(17, -14), Vector2(13, -8), CYAN, 1)
	draw_set_transform(Vector2.ZERO)
	var captions := {"M01": "100 KM ASCENT", "M02": "STABLE ORBIT", "M03": "SCIENCE PAYLOAD", "M04": "LANDING LEGS"}
	draw_string(get_theme_font("font", "Label"), Vector2(0, 71), captions.get(mission_id, "OBJECTIVE"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, CYAN)
