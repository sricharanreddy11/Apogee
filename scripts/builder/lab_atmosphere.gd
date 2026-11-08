extends Control

## Decorative bay lighting, with the assembly left clear for drag and drop.
const NEON := preload("res://scripts/builder/neon_tube_sign.gd")

var _clock := 0.0
var _sign: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sign = NEON.new()
	_sign.name = "NeonSign"
	add_child(_sign)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var ratio := size / Vector2(1280, 720)
	_sign.position = Vector2(483, 16) * ratio
	_sign.scale = ratio * 0.75
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	_sign.advance(_clock)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(1280, 720))
	var pulse := 0.34 + 0.06 * sin(_clock * 1.35)
	draw_rect(Rect2(495, 16, 290, 43), Color(0.035, 0.072, 0.109, 0.78))
	draw_rect(Rect2(495, 16, 290, 43), Color("#344f60"), false, 1.0)
	for side: float in [-1.0, 1.0]:
		var rail := Vector2(640.0 + side * 249.0, 176.0)
		draw_line(rail, rail + Vector2(0, 265), Color(0.36, 0.76, 0.83, 0.13), 5.0, true)
		draw_line(rail, rail + Vector2(0, 265), Color(0.48, 0.82, 0.85, pulse), 1.0, true)
		for notch in 3:
			var foot := Vector2(640.0 + side * (126 + notch * 15), 509)
			draw_line(foot, foot + Vector2(side * 7, 6), Color("#9b7849"), 2.0, true)
