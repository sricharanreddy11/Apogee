extends Control

const CARD := preload("res://scripts/builder/part_card.gd")
const CATEGORIES := {"pod": "Pods", "tank": "Fuel", "engine": "Engines", "kit": "Kit"}
const ARC_RADIUS := 152.0
const DIM_LINE := Color("#253f55")
const ACTIVE_LINE := Color("#42718b")

var _buttons: Dictionary = {}
var _cards: Dictionary = {"pod": [], "tank": [], "engine": [], "kit": []}
var _open := ""
var _sweep: Tween


func _ready() -> void:
	for category: String in CATEGORIES:
		var button := %Categories.get_node(CATEGORIES[category]) as Button
		button.pressed.connect(_toggle_category.bind(category))
		_buttons[category] = button
		button.hide()
	resized.connect(_layout)


func add_part(part: Dictionary, texture: Texture2D, spec: String) -> void:
	var category: String = part.type if _cards.has(part.type) else "kit"
	var card := CARD.new()
	card.configure(part, texture, spec)
	card.hide()
	%PartDiscs.add_child(card)
	_cards[category].append(card)
	_buttons[category].show()
	_layout()


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
		button.position = Vector2(0, y)
		if button.visible:
			y += 55
	if not _open.is_empty():
		var cards: Array = _cards[_open]
		var spread := minf(1.12, 0.52 * float(cards.size() - 1))
		for i in cards.size():
			var fraction := float(i) / float(maxi(1, cards.size() - 1))
			var angle := lerpf(-spread, spread, fraction)
			var card: Button = cards[i]
			card.position = _hinge() + Vector2.from_angle(angle) * ARC_RADIUS - card.size / 2.0
			card.scale = Vector2.ONE
			card.modulate.a = 1.0
	queue_redraw()


func _hinge() -> Vector2:
	return Vector2(112, size.y * 0.44)


func _draw() -> void:
	if _open.is_empty():
		return
	var hinge := _hinge()
	draw_arc(hinge, ARC_RADIUS, -1.19, 1.19, 42, ACTIVE_LINE, 1.4, true)
	draw_arc(hinge, ARC_RADIUS + 12, -1.19, 1.19, 42, DIM_LINE, 1.0, true)
