extends Control

@export var progression_only: bool = false
var _progress_stage: int = 0


func _ready() -> void:
	resized.connect(queue_redraw)


func set_progress(completed: Array[String]) -> void:
	_progress_stage = 2 if completed.has("M02") else (1 if completed.has("M01") else 0)
	queue_redraw()


func _draw() -> void:
	if progression_only:
		_draw_progression()
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#071321"))
	draw_rect(Rect2(Vector2(0.0, size.y * 0.64), Vector2(size.x, size.y * 0.36)), Color("#091829"))
	for index in 48:
		var point := Vector2(fmod(float(index * 173 + 37), maxf(size.x, 1.0)),
			fmod(float(index * 97 + 19), maxf(size.y, 1.0)))
		draw_circle(point, 1.0 if index % 5 else 1.8, Color(0.32, 0.52, 0.66, 0.28))
	draw_arc(Vector2(size.x * 0.94, size.y * 1.22), size.y * 0.6,
		PI, TAU, 80, Color(0.2, 0.5, 0.65, 0.12), 2.0, true)


func _draw_progression() -> void:
	var points: Array[Vector2] = [Vector2(size.x * 0.16, 23.0),
		Vector2(size.x * 0.5, 23.0), Vector2(size.x * 0.84, 23.0)]
	for index in 2:
		var color := Color("#59c8e8") if _progress_stage > index else Color("#263f50")
		draw_dashed_line(points[index] + Vector2(28, 0), points[index + 1] - Vector2(28, 0), color, 1.5, 8.0)
	draw_circle(points[0], 18.0, Color("#174d70"))
	draw_circle(points[0] + Vector2(-4, -3), 9.0, Color("#3a947e"))
	draw_circle(points[0] + Vector2(7, 9), 5.0, Color("#3a947e"))
	draw_arc(points[0], 18.0, 0, TAU, 32, Color("#59c8e8"), 1.0, true)
	draw_arc(points[1], 21.0, 0, TAU, 40, Color("#486375"), 1.2, true)
	draw_circle(points[1], 9.0, Color("#174d70"))
	draw_circle(points[1] + Vector2(14, -15), 3.5, Color("#ffc25c"))
	draw_circle(points[2], 16.0, Color("#8295a7"))
	draw_circle(points[2] + Vector2(-5, -4), 4.0, Color("#61798c"))
	draw_circle(points[2] + Vector2(6, 6), 5.0, Color("#61798c"))
	var labels: Array[String] = ["EARTH", "ORBIT", "MOON"]
	var font := get_theme_default_font()
	for index in 3:
		var label_color := Color("#74d8e7") if _progress_stage >= index else Color("#70899c")
		var width := font.get_string_size(labels[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, points[index] + Vector2(-width * 0.5, 38), labels[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)
