@tool
extends Control

signal detent_requested(index: int)

const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Regular.res")
const DETENTS := [214.0, 252.0, 288.0, 326.0]
const READOUTS := ["1×", "5×", "25×", "50×"]
const PANEL := Vector2(136, 180)
const CENTER := Vector2(68, 108)
const KNOB_RADIUS := 36.0
const AMBER := Color("#ffca78")

var _angle := deg_to_rad(DETENTS[0])
var _selected := 0
var _rotation_tween: Tween
@onready var _detent_buttons: Array[Button] = [%Warp1, %Warp5, %Warp25, %Warp50]


func _ready() -> void:
	resized.connect(_layout_detents)
	_layout_detents()


func set_detent(index: int) -> void:
	_selected = index
	var angle := deg_to_rad(DETENTS[index])
	if _rotation_tween != null:
		_rotation_tween.kill()
	_rotation_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_rotation_tween.tween_method(_turn, _angle, angle, 0.16)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var center := _knob_center()
	if event.position.distance_to(center) > (KNOB_RADIUS + 4.0) * _panel_scale():
		return
	var direction := 0
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			direction = -1 if event.position.x < center.x else 1
		MOUSE_BUTTON_WHEEL_UP:
			direction = 1
		MOUSE_BUTTON_WHEEL_DOWN:
			direction = -1
	if direction != 0:
		detent_requested.emit(clampi(_selected + direction, 0, DETENTS.size() - 1))
		accept_event()


func _turn(angle: float) -> void:
	_angle = angle
	queue_redraw()


func _panel_scale() -> float:
	return minf(size.x / PANEL.x, size.y / PANEL.y)


func _panel_origin() -> Vector2:
	return (size - PANEL * _panel_scale()) * 0.5


func _knob_center() -> Vector2:
	return _panel_origin() + CENTER * _panel_scale()


func _layout_detents() -> void:
	var fit := _panel_scale()
	for index in _detent_buttons.size():
		var button := _detent_buttons[index]
		var axis := Vector2.from_angle(deg_to_rad(DETENTS[index]))
		button.size = Vector2(31, 25) * fit
		button.position = _knob_center() + axis * (63.0 * fit) - button.size * 0.5
	queue_redraw()


func _draw() -> void:
	var fit := _panel_scale()
	if fit <= 0.0:
		return
	draw_set_transform(_panel_origin(), 0.0, Vector2.ONE * fit)
	draw_string(MONO, Vector2(0, 18), "SIM RATE", HORIZONTAL_ALIGNMENT_CENTER, PANEL.x, 15, Color("#d0dbe0"))
	draw_arc(CENTER, 48, deg_to_rad(211), deg_to_rad(329), 44, Color("#52646e"), 1.0, true)
	for index in DETENTS.size():
		var axis := Vector2.from_angle(deg_to_rad(DETENTS[index]))
		draw_line(CENTER + axis * 45, CENTER + axis * 52, AMBER if index == _selected else Color("#8c9ba3"), 1.8, true)
	draw_circle(CENTER + Vector2(0, 4), KNOB_RADIUS + 2, Color("#080c11"), true, -1, true)
	draw_circle(CENTER, KNOB_RADIUS, Color("#58666e"), true, -1, true)
	for index in 32:
		var axis := Vector2.from_angle(TAU * index / 32.0)
		draw_line(CENTER + axis * 31, CENTER + axis * 35, Color("#839098"), 1.2, true)
	draw_circle(CENTER, 30, Color("#25333e"), true, -1, true)
	draw_arc(CENTER, 30, PI, TAU, 38, Color("#98a7ae"), 1.4, true)
	draw_arc(CENTER, 28, 0, PI, 38, Color("#151f28"), 1.4, true)
	var pointer := Vector2.from_angle(_angle)
	draw_line(CENTER + pointer * 9, CENTER + pointer * 26, AMBER, 3.5, true)
	draw_rect(Rect2(39, 155, 58, 24), Color("#090f15"))
	draw_string(MONO, Vector2(39, 173), READOUTS[_selected], HORIZONTAL_ALIGNMENT_CENTER, 58, 16, AMBER)
