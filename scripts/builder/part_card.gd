extends Button

const CYAN := Color("#69d9f6")
const INK := Color("#122436")

var part_id: String
var part_name: String
var artwork: Texture2D


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
	size = Vector2(76, 76)
	pivot_offset = size / 2.0
	add_theme_constant_override("icon_max_width", 43)
	add_theme_stylebox_override("normal", _disc_style(INK, CYAN.darkened(0.60)))
	add_theme_stylebox_override("hover", _disc_style(Color("#23435c"), CYAN))
	add_theme_stylebox_override("pressed", _disc_style(Color("#1d3045"), CYAN))
	add_theme_stylebox_override("focus", _disc_style(Color.TRANSPARENT, CYAN))

	if artwork == null:
		text = part_id
	var caption := Label.new()
	caption.position = Vector2(-32, 80)
	caption.size.x = 140
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 14)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.text = "%s\n%d CR" % [part_name, part.cost_credits]
	add_child(caption)


func _disc_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(38)
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	style.content_margin_left = 9
	style.content_margin_right = 9
	return style


func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite := TextureRect.new()
	sprite.texture = artwork
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.modulate.a = 0.76
	sprite.position = Vector2(12, -32)
	sprite.size = Vector2(48, 64)
	preview.add_child(sprite)
	set_drag_preview(preview)
	return {"apogee_part_id": part_id, "artwork": artwork}
