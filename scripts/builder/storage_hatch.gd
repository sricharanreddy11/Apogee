extends Button

const INK := Color("#b9cbd4")
const ACTIVE := Color("#8be6eb")
const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Regular.res")

var _part_icon: Texture2D
var _open := false
var _hinge := 0.0
var _motion: Tween


func _ready() -> void:
	_part_icon = icon
	icon = null
	accessibility_name = text + " storage"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for style: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		add_theme_stylebox_override(style, empty)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_disabled_color", &"font_focus_color", &"font_hover_pressed_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	add_theme_font_size_override("font_size", 1)
	for change: Signal in [mouse_entered, mouse_exited, focus_entered, focus_exited, resized]:
		change.connect(queue_redraw)


func set_open(open: bool) -> void:
	if open == _open:
		return
	_open = open
	if _motion != null:
		_motion.kill()
	_motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_method(_swing, _hinge, 1.0 if open else 0.0, 0.23)


func _swing(value: float) -> void:
	_hinge = value
	queue_redraw()


func _draw() -> void:
	var accent := INK.lerp(ACTIVE, _hinge)
	var seam := Color("#40515a").lerp(ACTIVE, _hinge)
	var lit := is_hovered() or has_focus()
	if lit or _hinge > 0.0:
		draw_colored_polygon(PackedVector2Array([
			Vector2(5, 2), Vector2(size.x - 8, 2), Vector2(size.x - 2, 8),
			Vector2(size.x - 2, size.y - 3), Vector2(1, size.y - 3), Vector2(1, 7),
		]), Color("#182f3b").lerp(Color("#204453"), _hinge * 0.7))
	var center := size.x * 0.5
	draw_line(Vector2(center - 7.0, size.y - 3), Vector2(center + 7.0, size.y - 3), seam, 1.2 + _hinge, true)
	if has_focus():
		draw_line(Vector2(4, 2), Vector2(size.x - 9, 2), Color("#ffca83"), 1.4)
	if _part_icon != null:
		draw_texture_rect(_part_icon, Rect2(center - 10.0 + 3.0 * _hinge, 5, 20, 20), false, Color.WHITE.lerp(ACTIVE, _hinge * 0.18))
	var legend := "ENG" if text == "Engines" and size.x < 55.0 else text.to_upper()
	draw_string(MONO, Vector2(0, 38), legend, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, accent)
