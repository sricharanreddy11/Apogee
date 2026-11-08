extends Node

## Cockpit hardware style for the ground stations' native Buttons.
var button: Button
var role := "secondary"
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
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, _style(role, state))
	var accent := _accent(role)
	button.add_theme_font_size_override("font_size", 18 if role in ["primary", "launch"] else 15)
	button.add_theme_color_override("font_color", accent.lightened(0.25))
	button.add_theme_color_override("font_hover_color", Color("#f3fbff"))
	button.add_theme_color_override("font_pressed_color", accent)
	button.add_theme_color_override("font_hover_pressed_color", accent)
	button.add_theme_color_override("font_disabled_color", Color("#72818a"))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func _accent(purpose: String) -> Color:
	return {
		"primary": Color("#8bdce4"), "launch": Color("#ffc27b"),
		"danger": Color("#efa2a0"), "preset": Color("#bfd0d8"),
	}.get(purpose, Color("#c6d5de"))


static func _style(purpose: String, state: String) -> StyleBoxFlat:
	var key := purpose + ":" + state
	if _styles.has(key):
		return _styles[key]
	var accent := _accent(purpose)
	var main_action := purpose in ["primary", "launch"]
	var pressed := state in ["pressed", "hover_pressed"]
	var plate := StyleBoxFlat.new()
	plate.set_corner_radius_all(5)
	plate.set_border_width_all(1)
	plate.border_width_bottom = 3 if not pressed else 1
	plate.content_margin_left = 12.0
	plate.content_margin_right = 12.0
	plate.content_margin_top = 7.0 if pressed else 6.0
	plate.content_margin_bottom = 5.0 if pressed else 6.0
	plate.bg_color = Color("#1c2933").lerp(accent, 0.10 if main_action else 0.02)
	plate.border_color = accent.darkened(0.40 if main_action else 0.61)
	match state:
		"hover":
			plate.bg_color = plate.bg_color.lerp(accent, 0.13)
			plate.border_color = accent.darkened(0.20)
		"pressed", "hover_pressed":
			plate.bg_color = Color("#102026")
			plate.border_color = accent.darkened(0.15)
		"disabled":
			plate.bg_color = Color("#141d25")
			plate.border_color = Color("#35424c")
		"focus":
			plate.draw_center = false
			plate.set_border_width_all(2)
			plate.border_color = Color("#f3ce89")
	_styles[key] = plate
	return plate
