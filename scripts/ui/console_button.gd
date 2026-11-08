extends Node

## Adds presentation to existing native Buttons; input and action ownership stay native.
var button: Button
var role := "secondary"
var _hover_tween: Tween
static var _styles: Dictionary = {}

static func apply(target: Button, purpose: String = "secondary") -> void:
	if target.get_node_or_null("ConsoleButtonSkin") != null:
		return
	var feedback := load("res://scripts/ui/console_button.gd").new() as Node
	feedback.name = "ConsoleButtonSkin"
	feedback.button = target
	feedback.role = purpose
	target.add_child(feedback)

func _ready() -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, _style(role, state))
	var main_action := role in ["primary", "launch"]
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if main_action:
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 54)
	button.add_theme_font_size_override("font_size", 22 if role == "launch" else (20 if role == "primary" else 15))
	button.add_theme_color_override("font_color", Color("e5f4fa"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("c8f7ff"))
	button.add_theme_color_override("font_disabled_color", Color("6e8291"))
	if main_action:
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, Color("071925"))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(_highlight.bind(true))
	button.mouse_exited.connect(_highlight.bind(false))
	button.focus_entered.connect(_highlight.bind(true))
	button.focus_exited.connect(_highlight.bind(false))

func _highlight(active: bool) -> void:
	if _hover_tween != null:
		_hover_tween.kill()
	_hover_tween = create_tween()
	var tint := Color(1.08, 1.1, 1.12) if active and not button.disabled else Color.WHITE
	_hover_tween.tween_property(button, "self_modulate", tint, 0.12)

static func _style(purpose: String, state: String) -> StyleBoxTexture:
	var key := purpose + ":" + state
	if _styles.has(key):
		return _styles[key]
	var accent: Color = {"primary": Color("67e7ec"), "launch": Color("ffbc74"), "danger": Color("e391a4"), "preset": Color("b39cea"), "utility": Color("7ec8ed")}.get(purpose, Color("829dac"))
	var base: Color = {"primary": Color("153842"), "launch": Color("3a2c27"), "danger": Color("2d2331"), "preset": Color("25273c")}.get(purpose, Color("172938"))
	var main_action := purpose in ["primary", "launch"]
	if main_action:
		base = Color("57dce6")
		accent = Color("b8f5fa")
	if state == "hover":
		base = base.lerp(accent, 0.17)
		accent = accent.lightened(0.15)
	elif state == "pressed":
		base = base.darkened(0.3)
	elif state == "disabled":
		base = Color("121e29")
		accent = Color("364855")
	var face_y := 4 if state == "pressed" else 1
	var outline := "M10 %d H229 L239 11 V45 L229 52 H10 L1 45 V11 Z" % face_y
	var svg: String
	if state == "focus":
		svg = '<svg xmlns="http://www.w3.org/2000/svg" width="240" height="56"><path d="M12 3H227L237 13V43L227 50H12L3 43V13Z" fill="none" stroke="#f5e9ad" stroke-width="2" stroke-dasharray="6 4"/></svg>'
	elif main_action and state != "disabled":
		svg = '<svg xmlns="http://www.w3.org/2000/svg" width="240" height="56"><path d="M10 5H229L239 15V48L229 55H10L1 48V15Z" fill="#0a3745"/><path d="%s" fill="#%s" stroke="#%s" stroke-width="1.5"/><path d="M7 18V37M226 18l5 5m-5 8 5 5" stroke="#123e4c" stroke-width="2"/></svg>' % [outline, base.to_html(false), accent.to_html(false)]
	else:
		svg = '<svg xmlns="http://www.w3.org/2000/svg" width="240" height="56"><defs><linearGradient id="plate" x2="0" y2="1"><stop stop-color="#%s"/><stop offset="1" stop-color="#%s"/></linearGradient></defs><path d="M10 5H229L239 15V48L229 55H10L1 48V15Z" fill="#080f1b"/><path d="%s" fill="url(#plate)" stroke="#%s" stroke-width="1.5"/><path d="M15 48H225" stroke="#%s" stroke-width="2" opacity=".45"/><path d="M20 7H215" stroke="#d2f0fc" opacity=".13"/><path d="M7 18V37" stroke="#%s" stroke-width="2"/><path d="M226 18l5 5m-5 8 5 5" stroke="#%s" opacity=".5"/></svg>' % [base.lightened(0.08).to_html(false), base.to_html(false), outline, accent.to_html(false), accent.to_html(false), accent.to_html(false), accent.to_html(false)]
	var image := Image.new()
	image.load_svg_from_string(svg)
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	# Fixed corner slices preserve the angled silhouette on compact and wide controls.
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_texture_margin(side, 12.0 if side in [SIDE_LEFT, SIDE_RIGHT] else 8.0)
	style.set_content_margin(SIDE_LEFT, 14)
	style.set_content_margin(SIDE_RIGHT, 14)
	style.set_content_margin(SIDE_TOP, 10 if state == "pressed" else 8)
	style.set_content_margin(SIDE_BOTTOM, 6 if state == "pressed" else 8)
	_styles[key] = style
	return style
