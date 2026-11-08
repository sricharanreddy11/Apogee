extends Control

const CARD := preload("res://scripts/builder/part_card.gd")
const TABS := {"pod": "Pods", "tank": "Fuel", "engine": "Engines", "kit": "Kit"}
const BAY_INSET := 8.0
const TRAY_TOP := 182.0
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
	var count := 0
	for cards: Array in _cards.values():
		if not cards.is_empty():
			count += 1
	var tab_width := (size.x - 2.0 * BAY_INSET) / maxf(1.0, count)
	var bay := _bay_size()
	var tab_index := 0
	for category: String in TABS:
		var button: Button = %Categories.get_node(TABS[category])
		var cards: Array = _cards[category]
		button.visible = not cards.is_empty()
		var active := category == _open
		button.set_pressed_no_signal(active)
		button.set_open(active)
		if button.visible:
			button.position = Vector2(BAY_INSET + tab_index * tab_width, 127.0)
			button.size = Vector2(tab_width, 48.0)
			tab_index += 1
		for index in cards.size():
			var card: Button = cards[index]
			card.visible = active
			var stacked := cards.size() > 2
			var columns := mini(cards.size(), 2)
			var x := bay.x * (float(index) + 0.5) / columns if index < 2 else bay.x * 0.5
			var y := bay.y * (0.30 if index < 2 else 0.62) if stacked else bay.y * 0.42
			card.position = Vector2(x, y) - card.size * 0.5
	%PartDiscs.position = Vector2(BAY_INSET, TRAY_TOP)
	_extend(_extension)


func _bay_size() -> Vector2:
	return Vector2(maxf(0.0, size.x - 2.0 * BAY_INSET), maxf(0.0, size.y - TRAY_TOP - 10.0))


func _extend(amount: float) -> void:
	_extension = amount
	var bay := _bay_size()
	%PartDiscs.size = Vector2(bay.x * amount, bay.y)
	queue_redraw()


func _draw() -> void:
	var bay := Rect2(Vector2(BAY_INSET, TRAY_TOP), _bay_size())
	var cabinet := Rect2(0, 92, size.x, maxf(32.0, size.y - 92.0))
	draw_rect(cabinet, Color("#101c25"))
	draw_rect(cabinet.grow(-1.0), Color("#405260"), false, 1.0)
	draw_rect(Rect2(1, 93, size.x - 2, 30), Color("#202e39"))
	draw_line(Vector2(1, 123), Vector2(size.x - 1, 123), Color("#3c515e"))
	for bolt in [Vector2(8, 101), Vector2(size.x - 8, 101), Vector2(8, cabinet.end.y - 8), Vector2(size.x - 8, cabinet.end.y - 8)]:
		draw_circle(bolt, 2.0, Color("#71818a"))
	draw_rect(bay, Color("#0a141d"))
	var shutter := bay.position.x + bay.size.x * _extension
	if _extension < 1.0:
		draw_rect(Rect2(shutter, bay.position.y, bay.end.x - shutter, bay.size.y), Color("#192631"))
		for seam in range(1, 5):
			var x := lerpf(shutter, bay.end.x, seam / 5.0)
			draw_line(Vector2(x, bay.position.y + 8), Vector2(x, bay.end.y - 8), Color("#263742"), 1)
	if _extension > 0.0:
		draw_line(Vector2(shutter, bay.position.y), Vector2(shutter, bay.end.y), Color("#527584"), 2)
	var grip := Vector2(shutter, bay.get_center().y)
	draw_line(grip - Vector2(0, 13), grip + Vector2(0, 13), Color("#82b2bc"), 2)
