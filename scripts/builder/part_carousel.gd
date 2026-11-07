extends Control

const CARD := preload("res://scripts/builder/part_card.gd")
const CATEGORIES := {"pod": "Pods", "tank": "Fuel", "engine": "Engines"}
const ARC_RADIUS := 152.0
const DIM_LINE := Color("#253f55")
const ACTIVE_LINE := Color("#42718b")

var _buttons: Dictionary = {}
var _cards: Dictionary = {"pod": [], "tank": [], "engine": []}
var _open := ""
var _sweep: Tween


func _ready() -> void:
	for category: String in CATEGORIES:
		var button := Button.new()
		button.name = CATEGORIES[category]
		button.text = CATEGORIES[category]
		button.toggle_mode = true
		button.size = Vector2(105, 44)
		button.pressed.connect(_toggle_category.bind(category))
		%Categories.add_child(button)
		_buttons[category] = button
	resized.connect(_layout)


func add_part(part: Dictionary, texture: Texture2D, spec: String) -> void:
	var category: String = part.type
	if not _cards.has(category):
		return
	var card := CARD.new()
	card.configure(part, texture, spec)
	card.hide()
	%PartDiscs.add_child(card)
	_cards[category].append(card)


func _toggle_category(category: String) -> void:
	if _sweep != null:
		_sweep.kill()
	_open = "" if _open == category else category
	for key: String in CATEGORIES:
		_buttons[key].set_pressed_no_signal(key == _open)
		for card: Button in _cards[key]:
			card.visible = key == _open
	_layout()
	if _open.is_empty():
		return
	_sweep = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for card: Button in _cards[_open]:
		var target := card.position
		card.position = _hinge().lerp(target + card.size / 2.0, 0.48) - card.size / 2.0
		card.scale = Vector2.ONE * 0.64
		card.modulate.a = 0.15
		_sweep.tween_property(card, "position", target, 0.25)
		_sweep.tween_property(card, "scale", Vector2.ONE, 0.25)
		_sweep.tween_property(card, "modulate:a", 1.0, 0.20)


func _layout() -> void:
	if _sweep != null and _sweep.is_running():
		_sweep.kill()
	var y := _hinge().y - 76.0
	for key: String in CATEGORIES:
		var button: Button = _buttons[key]
		button.position = Vector2(12, y)
		y += 54
	if not _open.is_empty():
		var cards: Array = _cards[_open]
		var spread := minf(1.12, 0.48 * float(cards.size() - 1))
		for i in cards.size():
			var fraction := float(i) / float(maxi(1, cards.size() - 1))
			var angle := lerpf(-spread, spread, fraction)
			var card: Button = cards[i]
			card.position = _hinge() + Vector2.from_angle(angle) * ARC_RADIUS - card.size / 2.0
			card.scale = Vector2.ONE
			card.modulate.a = 1.0
	queue_redraw()


func _hinge() -> Vector2:
	return Vector2(112, size.y * 0.49)


func _draw() -> void:
	var hinge := _hinge()
	var arc_color := DIM_LINE if _open.is_empty() else ACTIVE_LINE
	draw_arc(hinge, ARC_RADIUS, -1.19, 1.19, 42, arc_color, 1.4, true)
	draw_arc(hinge, ARC_RADIUS + 12, -1.19, 1.19, 42, DIM_LINE, 1.0, true)
	for angle: float in [-1.19, -0.79, -0.39, 0.0, 0.39, 0.79, 1.19]:
		var direction := Vector2.from_angle(angle)
		draw_line(hinge + direction * (ARC_RADIUS + 7), hinge + direction * (ARC_RADIUS + 13), arc_color)
	if _open.is_empty():
		var font := get_theme_default_font()
		draw_string(font, hinge + Vector2(32, -9), "CHOOSE A", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ACTIVE_LINE.lightened(0.35))
		draw_string(font, hinge + Vector2(32, 11), "CATEGORY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ACTIVE_LINE.lightened(0.35))
