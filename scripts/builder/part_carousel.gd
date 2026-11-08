extends Control

const CARD := preload("res://scripts/builder/part_card.gd")
const TABS := {"pod": "Pods", "tank": "Fuel", "engine": "Engines", "kit": "Kit"}
const TRAY_TOP := 220.0
const TRAY_HEIGHT := 142.0
var impact_provider: Callable
var _cards := {"pod": [], "tank": [], "engine": [], "kit": []}
var _open := ""
var _tray: Tween
var _extension := 0.0


func _ready() -> void:
	for category: String in TABS:
		var button: Button = %Categories.get_node(TABS[category])
		button.pressed.connect(_toggle_category.bind(category))
	resized.connect(_layout)
	_layout()


func add_part(part: Dictionary, texture: Texture2D, spec: String) -> void:
	var category: String = part.type if _cards.has(part.type) else "kit"
	var card := CARD.new()
	card.configure(part, texture, spec)
	card.impact_provider = impact_provider
	%PartDiscs.add_child(card)
	_cards[category].append(card)
	_layout()


func _toggle_category(category: String) -> void:
	if _cards[category].is_empty():
		return
	var switching := not _open.is_empty() and _open != category
	_open = "" if _open == category else category
	if _tray != null:
		_tray.kill()
	if switching:
		_extension = minf(_extension, 0.25)
	_layout()
	var target := 0.0 if _open.is_empty() else 1.0
	_tray = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tray.tween_method(_extend, _extension, target, 0.28)


func _layout() -> void:
	var tab_width := (size.x - 36.0) * 0.5
	var tab_index := 0
	for category: String in TABS:
		var button: Button = %Categories.get_node(TABS[category])
		var cards: Array = _cards[category]
		button.visible = not cards.is_empty()
		var active := category == _open
		button.set_pressed_no_signal(active)
		button.set_open(active)
		if button.visible:
			button.position = Vector2(14.0 + (tab_index % 2) * (tab_width + 8.0), 132.0 + floorf(tab_index / 2.0) * 43.0)
			button.size = Vector2(tab_width, 35.0)
			tab_index += 1
		for index in cards.size():
			var card: Button = cards[index]
			card.visible = active
			var lane := size.x / maxf(1.0, cards.size())
			var lean := absf(index - (cards.size() - 1) * 0.5)
			card.position = Vector2(lane * (index + 0.5) - card.size.x * 0.5, 18.0 + lean * 8.0)
	%PartDiscs.position = Vector2(0, TRAY_TOP)
	_extend(_extension)


func _extend(amount: float) -> void:
	_extension = amount
	%PartDiscs.size = Vector2(size.x, TRAY_HEIGHT * amount)
	queue_redraw()


func _draw() -> void:
	var opening := TRAY_HEIGHT * _extension
	var cabinet := Rect2(0, 92, size.x, maxf(145.0, TRAY_TOP + opening + 12.0 - 92.0))
	draw_rect(cabinet, Color("#101c25"))
	draw_rect(cabinet.grow(-1.0), Color("#405260"), false, 1.0)
	draw_rect(Rect2(1, 93, size.x - 2, 30), Color("#202e39"))
	draw_line(Vector2(1, 123), Vector2(size.x - 1, 123), Color("#3c515e"))
	for bolt in [Vector2(8, 101), Vector2(size.x - 8, 101), Vector2(8, cabinet.end.y - 8), Vector2(size.x - 8, cabinet.end.y - 8)]:
		draw_circle(bolt, 2.0, Color("#71818a"))
	if opening > 0.0:
		var lip := TRAY_TOP + opening
		draw_rect(Rect2(9, TRAY_TOP, size.x - 18, opening), Color("#0a141d"))
		for x: float in [12.0, size.x - 12.0]:
			draw_line(Vector2(x, TRAY_TOP), Vector2(x, lip), Color("#3a5d6b"), 2)
		if opening >= 75.0:
			draw_line(Vector2(14, TRAY_TOP + 73), Vector2(size.x - 14, TRAY_TOP + 73), Color("#71808a"), 2)
			draw_line(Vector2(14, TRAY_TOP + 76), Vector2(size.x - 14, TRAY_TOP + 76), Color("#293f4b"), 3)
		draw_line(Vector2(9, lip), Vector2(size.x - 9, lip), Color("#527584"), 3)
		var latch := Vector2(size.x * 0.5, lip + 4.0)
		draw_line(latch - Vector2(12, 0), latch + Vector2(12, 0), Color("#8fe5e7"), 1.4)
