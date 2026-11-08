@tool
extends Button

enum Kind { IGNITION, STAGE, GEAR, UTILITY }

const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Regular.res")
const STEEL := Color("#8d9ba3")
const AMBER := Color("#ffbf67")
const GREEN := Color("#9bf2b2")

@export var kind := Kind.UTILITY
var active := false:
	set(value):
		if active != value:
			active = value
			queue_redraw()


func _ready() -> void:
	var empty := StyleBoxEmpty.new()
	for style: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		add_theme_stylebox_override(style, empty)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_disabled_color", &"font_focus_color", &"font_hover_pressed_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)


func _draw() -> void:
	var pushed := get_draw_mode() == BaseButton.DRAW_PRESSED
	var hovered := get_draw_mode() == BaseButton.DRAW_HOVER
	var ink := Color("#79858e") if disabled else Color("#f1ece0")
	draw_style_box(_socket(hovered), Rect2(Vector2.ZERO, size))
	if kind == Kind.UTILITY:
		var face := Rect2(4, 3 + (2 if pushed else 0), size.x - 8, size.y - 8)
		var trim := AMBER if active else Color("#5b6d76")
		draw_style_box(_cap(Color("#283841") if hovered else Color("#232f38"), trim), face)
		_legend(Vector2(0, size.y * 0.5 + 4), size.x, trim.lightened(0.25) if active else ink, HORIZONTAL_ALIGNMENT_CENTER)
		return

	var center := Vector2(26, size.y * 0.5)
	if kind == Kind.IGNITION:
		_draw_ignition(center, pushed, hovered)
	else:
		_draw_toggle(center, pushed)
	_legend(Vector2(51, center.y + 4.5), size.x - 55, ink, HORIZONTAL_ALIGNMENT_LEFT)


func _draw_ignition(center: Vector2, pushed: bool, hovered: bool) -> void:
	draw_circle(center, 17, Color("#03070b"), true, -1, true)
	draw_arc(center, 16, 0, TAU, 32, STEEL, 1.5, true)
	var cap := center + Vector2(0, 2 if pushed else -1)
	var red := Color("#ce4c39") if active or hovered else Color("#922f2d")
	draw_circle(cap, 12, red.darkened(0.55), true, -1, true)
	draw_circle(cap - Vector2(0, 1), 10, red, true, -1, true)
	draw_arc(cap, 8.5, PI, TAU, 20, red.lightened(0.4), 1.6, true)
	draw_circle(cap, 3, Color("#ffb69c") if active else Color("#ed715b"), true, -1, true)


func _draw_toggle(center: Vector2, pushed: bool) -> void:
	var accent := AMBER if kind == Kind.STAGE else GREEN
	var socket := Rect2(center - Vector2(17, 12), Vector2(34, 24))
	draw_style_box(_cap(Color("#0b131a"), Color("#3b4954")), socket)
	var pivot := center + Vector2(-3, 1)
	var tip := pivot + Vector2(8 if active or pushed else -6, -6 if active or pushed else 6)
	draw_line(pivot, tip + Vector2(0, 1), Color("#05080a"), 10, true)
	draw_line(pivot, tip, STEEL.darkened(0.45) if disabled else STEEL, 6, true)
	draw_circle(tip, 4.7, accent.darkened(0.5) if disabled else accent, true, -1, true)
	draw_line(tip + Vector2(-2, -1), tip + Vector2(1, -2), accent.lightened(0.55) if not disabled else STEEL, 1.2, true)
	draw_circle(center + Vector2(11, 7), 2.2, accent if active else Color("#3d4a48"), true, -1, true)


func _legend(at: Vector2, width: float, ink: Color, alignment: HorizontalAlignment) -> void:
	draw_string(MONO, at, text, alignment, width, 13, ink)


func _socket(hovered: bool) -> StyleBoxFlat:
	var fill := Color("#1d2c36") if hovered else Color("#111b23")
	return _cap(fill, Color("#40515d"))


func _cap(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.border_width_bottom = 2
	box.set_corner_radius_all(4)
	return box
