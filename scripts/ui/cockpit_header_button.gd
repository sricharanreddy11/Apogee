@tool
extends Button

enum Kind { HOLD, HELP, END, SETTINGS }

@export var kind := Kind.HOLD
var active := false:
	set(value):
		active = value
		queue_redraw()


func _ready() -> void:
	var empty := StyleBoxEmpty.new()
	for key: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		add_theme_stylebox_override(key, empty)


func _draw() -> void:
	var center := size * 0.5
	var ink := Color("#b9cdd6")
	if disabled:
		ink = Color("#4f5f68")
	elif get_draw_mode() != BaseButton.DRAW_NORMAL:
		draw_circle(center, 17, Color("#293d48"), true, -1, true)
		ink = Color("#f3fcff")
	match kind:
		Kind.HOLD:
			if active:
				draw_colored_polygon(PackedVector2Array([center + Vector2(-5, -8), center + Vector2(8, 0), center + Vector2(-5, 8)]), Color("#ffca7d"))
			else:
				draw_rect(Rect2(center - Vector2(6, 7), Vector2(4, 14)), ink)
				draw_rect(Rect2(center + Vector2(2, -7), Vector2(4, 14)), ink)
		Kind.HELP:
			draw_arc(center, 9.0, 0, TAU, 28, ink, 1.4, true)
			draw_string(get_theme_default_font(), center + Vector2(-4.7, 4.7), "?", HORIZONTAL_ALIGNMENT_CENTER, 9.4, 13, ink)
		Kind.END:
			draw_rect(Rect2(center - Vector2(8, 8), Vector2(16, 16)), ink, false, 1.4)
			draw_rect(Rect2(center - Vector2(4, 4), Vector2(8, 8)), ink)
		Kind.SETTINGS:
			draw_arc(center, 8.0, 0, TAU, 32, ink, 3.2, true)
			for tooth in 8:
				var axis := Vector2.from_angle(tooth * TAU / 8.0)
				draw_line(center + axis * 8.0, center + axis * 12.0, ink, 3.6, true)
