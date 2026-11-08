extends Control

const CARD := preload("res://scripts/builder/part_card.gd")
const CATEGORIES := {"pod": "COMMAND PODS", "tank": "FUEL TANKS", "engine": "ENGINES", "kit": "ATTACHMENTS"}
const ROW_HEIGHT := 112.0
var impact_provider: Callable
var _cards: Dictionary = {"pod": [], "tank": [], "engine": [], "kit": []}
var _shelves: Array[float] = []

func _ready() -> void:
	for child in %Categories.get_children():
		child.hide()
	resized.connect(_layout)

func add_part(part: Dictionary, texture: Texture2D, spec: String) -> void:
	var category: String = part.type if _cards.has(part.type) else "kit"
	var card := CARD.new()
	card.configure(part, texture, spec)
	card.impact_provider = impact_provider
	%PartDiscs.add_child(card)
	_cards[category].append(card)
	_layout()

func _layout() -> void:
	_shelves.clear()
	var row := 0
	for category: String in CATEGORIES:
		if _cards[category].is_empty():
			continue
		var y := 150.0 + row * ROW_HEIGHT
		_shelves.append(y)
		var label := %Categories.get_node_or_null(category) as Label
		if label == null:
			label = Label.new()
			label.name = category
			label.add_theme_font_size_override("font_size", 13)
			label.add_theme_color_override("font_color", Color("e6d9bd"))
			%Categories.add_child(label)
		label.text = CATEGORIES[category]
		label.position = Vector2(16, y)
		for index in _cards[category].size():
			var card: Button = _cards[category][index]
			card.position = Vector2(18 + index * 108, y + 24)
		row += 1
	queue_redraw()

func _draw() -> void:
	# A single cabinet matches the opposing analysis panel; no nested card plaques.
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("172329")
	frame.border_color = Color("566567")
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(12)
	draw_style_box(frame, Rect2(0, 92, 350, 528))
	draw_line(Vector2(16, 136), Vector2(334, 136), Color("3f5056"), 1)
	for y in _shelves:
		# Thin timber deck and metal brackets keep the shelf silhouette compact.
		draw_colored_polygon(PackedVector2Array([Vector2(18, y + 65), Vector2(332, y + 65), Vector2(338, y + 71), Vector2(12, y + 71)]), Color("a3855f"))
		draw_rect(Rect2(12, y + 71, 326, 5), Color("71583f"))
		draw_line(Vector2(12, y + 71), Vector2(338, y + 71), Color("c2a076"), 1)
		for x in [16.0, 330.0]:
			draw_line(Vector2(x, y + 76), Vector2(x, y + 100), Color("586669"), 3)
			draw_circle(Vector2(x, y + 82), 1.5, Color("aab1a2"))
