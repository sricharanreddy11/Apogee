extends Button


var part_id: String
var part_name: String
var artwork: Texture2D
var _lift: Tween
var impact_provider: Callable


func _ready() -> void:
	mouse_entered.connect(_enlarge.bind(1.12))
	mouse_exited.connect(_enlarge.bind(1.0))
	button_down.connect(_enlarge.bind(1.25))
	button_up.connect(_enlarge.bind(1.0))


func _enlarge(amount: float) -> void:
	if _lift != null:
		_lift.kill()
	z_index = 2 if amount > 1.0 else 0
	_lift = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lift.tween_property(self, "scale", Vector2.ONE * amount, 0.12)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and is_node_ready():
		_enlarge(1.0)


func configure(part: Dictionary, texture: Texture2D, spec: String) -> void:
	part_id = String(part.id)
	part_name = String(part.name)
	artwork = texture
	name = part_id
	icon = texture
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = "%s   /   %s\nDrag onto the rocket to attach." % [part_name, spec]
	accessibility_name = "%s, %d credits" % [part_name, part.cost_credits]
	size = Vector2(94, 52)
	pivot_offset = size / 2.0
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	add_theme_constant_override("icon_max_width", 43)

	if artwork == null:
		text = part_id
	var caption := Label.new()
	caption.position = Vector2(-3, 53)
	caption.size = Vector2(100, 32)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.add_theme_constant_override("line_spacing", -2)
	caption.theme_type_variation = &"TelemetryLabel"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_color_override("font_color", Color("#b9cbd4"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.text = "%s\n%d CR" % [part_name, part.cost_credits]
	add_child(caption)


func _make_custom_tooltip(_for_text: String) -> Object:
	if not impact_provider.is_valid():
		return null
	var impact: Dictionary = impact_provider.call(part_id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 350
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101d29")
	style.border_color = Color("66868d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var title := Label.new()
	title.text = part_name
	title.add_theme_font_size_override("font_size", 18)
	content.add_child(title)
	var action := Label.new()
	action.text = String(impact.get("action", "No compatible mount available"))
	action.add_theme_font_size_override("font_size", 12)
	action.add_theme_color_override("font_color", Color("ffd18a"))
	content.add_child(action)
	if not impact.has("after"):
		return panel
	var stats: Dictionary = impact.after
	var before: Dictionary = impact.before
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	content.add_child(grid)
	for metric: String in ["fuel", "mass", "thrust", "range"]:
		var key: String = {"fuel": "fuel_kg", "mass": "wet_mass_kg", "thrust": "launch_twr", "range": "delta_v_mps"}[metric]
		var card := preload("res://scripts/builder/metric_card.gd").new()
		grid.add_child(card)
		var goal := float(impact.get("thrust_target" if metric == "thrust" else "range_target", 0.0)) if metric in ["thrust", "range"] else 0.0
		card.present(metric, stats, before, goal, maxf(goal, maxf(float(stats[key]), float(before[key]))) * 1.15)
	var cost := Label.new()
	var difference := int(stats.cost_credits) - int(before.cost_credits)
	cost.text = "%+d CR · %d / %d CR total" % [difference, stats.cost_credits, impact.budget]
	cost.add_theme_font_size_override("font_size", 12)
	content.add_child(cost)
	var note := Label.new()
	note.custom_minimum_size.x = 320
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 11)
	note.text = "│ current build   ↑↓ change if fitted\n" + String(impact.note)
	content.add_child(note)
	return panel


func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Control.new()
	_enlarge(1.25)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite := TextureRect.new()
	sprite.texture = artwork
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.modulate.a = 0.95
	sprite.position = Vector2(-44, -64)
	sprite.size = Vector2(88, 112)
	preview.add_child(sprite)
	set_drag_preview(preview)
	return {"apogee_part_id": part_id, "artwork": artwork}
