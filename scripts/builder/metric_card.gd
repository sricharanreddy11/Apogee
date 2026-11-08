extends Control

## Shared visual grammar: colored fill = shown build, pale tick = before,
## diamond = mission threshold. Text and shapes both carry the comparison.
const INK := Color("e7f3fa")
const MUTED := Color("93afc0")
const TRACK := Color("20394a")
const GOAL := Color("ffd18a")
const ALERT := Color("ff8e96")
const GOOD := Color("8ee7b3")

var kind := "fuel"
var accent := Color("65d9ed")
var current := 0.0
var previous := 0.0
var maximum := 1.0
var target := 0.0
var dry_mass := 0.0
var has_previous := false
var _labels: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(144, 132)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_HELP
	for key: String in ["title", "value", "delta", "hint"]:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", INK if key == "value" else MUTED)
		label.add_theme_font_size_override("font_size", 21 if key == "value" else (11 if key == "hint" else 12))
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_child(label)
		_labels[key] = label
	resized.connect(_layout)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func present(metric: String, stats: Dictionary, before: Dictionary, goal: float, scale_max: float) -> void:
	kind = metric
	target = goal
	maximum = maxf(scale_max, 1.0)
	has_previous = not before.is_empty()
	var key: String = {"fuel": "fuel_kg", "mass": "wet_mass_kg", "thrust": "launch_twr", "range": "delta_v_mps"}[kind]
	current = float(stats[key])
	previous = float(before.get(key, current))
	dry_mass = float(stats.dry_mass_kg)
	accent = {"fuel": Color("65d9ed"), "mass": Color("b9a1f3"), "thrust": Color("ffa775"), "range": Color("92dfac")}[kind]
	_labels.title.text = {"fuel": "FUEL", "mass": "LIFTOFF MASS", "thrust": "THRUST / WEIGHT", "range": "DELTA-V"}[kind]
	_labels.title.add_theme_color_override("font_color", accent)
	_labels.value.text = _value(current)
	_labels.value.add_theme_font_size_override("font_size", 18 if kind == "range" else 21)
	var change := current - previous
	var unchanged := absf(change) < (0.005 if kind == "thrust" else 0.5)
	_labels.delta.text = "—" if not has_previous else ("= unchanged" if unchanged else ("↑ " if change > 0.0 else "↓ ") + _value(absf(change)))
	# Fuel and mass are tradeoffs, not intrinsically good or bad.
	var delta_color := MUTED if unchanged or not has_previous else accent
	if kind in ["thrust", "range"] and has_previous and not unchanged:
		delta_color = GOOD if change > 0.0 else ALERT
	_labels.delta.add_theme_color_override("font_color", delta_color)
	match kind:
		"fuel":
			_labels.hint.text = "Loaded propellant"
		"mass":
			_labels.hint.text = "■ dry   ▰ fuel"
		"thrust":
			_labels.hint.text = ("◆ > 1 to lift off" if target > 0.0 else "No liftoff target")
		"range":
			_labels.hint.text = "◆ %.2f km/s min*" % (target / 1000.0) if target > 0.0 else "No mission Δv target"
	var explanation: String = {
		"fuel": "Loaded propellant, not fuel remaining in flight. Scale: %.0f kg (up to three largest allowed tanks per fitted stage, expanded to include the previous build)." % maximum,
		"mass": "Total liftoff mass. The solid section is dry structure; the striped section is propellant. Dry: %.0f kg. Fuel: %.0f kg." % [dry_mass, stats.fuel_kg],
		"thrust": "Launch thrust divided by vehicle weight in this body's gravity. Surface launches need more than 1 to lift off.",
		"range": "Ideal velocity change from the fitted stages, not distance. *Mission minimum is an ideal energy estimate; gravity, drag and steering losses require margin. This does not guarantee mission success.",
	}[kind]
	tooltip_text = "%s\nCurrent: %s" % [explanation, _value(current)]
	if has_previous:
		tooltip_text += "\nBefore: %s\nChange: %s%s" % [_value(previous), "+" if change >= 0.0 else "−", _value(absf(change))]
	accessibility_name = "%s. %s" % [_labels.title.text, tooltip_text]
	_layout()
	queue_redraw()


func _value(value: float) -> String:
	if kind == "thrust":
		return "%.2f×" % value
	if kind == "range":
		return "%.2f km/s" % (value / 1000.0)
	return "%.0f kg" % value


func _layout() -> void:
	if _labels.is_empty():
		return
	_labels.title.position = Vector2(13, 8)
	_labels.value.position = Vector2(49, 35)
	_labels.delta.position = Vector2(49, 64)
	_labels.hint.position = Vector2(13, 111)
	for key: String in _labels:
		_labels[key].size = Vector2(size.x - _labels[key].position.x - 10, 25 if key == "value" else 18)


func _draw() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("101f2e")
	panel.border_color = accent if has_focus() else Color("2b4355")
	panel.set_border_width_all(2 if has_focus() else 1)
	panel.set_corner_radius_all(9)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	draw_line(Vector2(13, 1), Vector2(43, 1), accent, 2.0)
	_draw_icon(Vector2(27, 56))
	var bar := Rect2(14, 96, size.x - 28, 8)
	draw_style_box(_pill(TRACK), bar)
	var ratio := clampf(current / maximum, 0.0, 1.0)
	if kind == "mass" and current > 0.0:
		var dry_width := bar.size.x * clampf(dry_mass / maximum, 0.0, ratio)
		draw_rect(Rect2(bar.position, Vector2(dry_width, 8)), accent)
		draw_rect(Rect2(bar.position + Vector2(dry_width, 0), Vector2(bar.size.x * ratio - dry_width, 8)), Color("65d9ed"))
		for x in range(int(dry_width) + 4, int(bar.size.x * ratio), 6):
			draw_line(bar.position + Vector2(x, 7), bar.position + Vector2(x + 3, 1), TRACK, 1.0)
	else:
		draw_style_box(_pill(accent), Rect2(bar.position, Vector2(bar.size.x * ratio, 8)))
	if has_previous:
		var x := bar.position.x + bar.size.x * clampf(previous / maximum, 0.0, 1.0)
		draw_line(Vector2(x, 92), Vector2(x, 108), INK, 2.0)
	if target > 0.0:
		var x := bar.position.x + bar.size.x * clampf(target / maximum, 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 88), Vector2(x + 4, 92), Vector2(x, 96), Vector2(x - 4, 92)]), GOAL)
		if current < target or (kind == "thrust" and current <= target):
			draw_circle(Vector2(size.x - 14, 17), 3, ALERT)


func _pill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style


func _draw_icon(center: Vector2) -> void:
	match kind:
		"fuel":
			var tank := Rect2(center - Vector2(9, 16), Vector2(18, 32))
			draw_style_box(_pill(TRACK), tank)
			var fill := clampf(current / maximum, 0.0, 1.0) * 28.0
			draw_style_box(_pill(accent), Rect2(center + Vector2(-6, 14 - fill), Vector2(12, fill)))
			draw_rect(tank, accent, false, 1.5)
			draw_line(center + Vector2(-4, -19), center + Vector2(4, -19), accent, 2)
		"mass":
			draw_circle(center - Vector2(0, 13), 4, accent, false, 2, true)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-7, -7), center + Vector2(7, -7), center + Vector2(13, 13), center + Vector2(-13, 13)]), accent)
			draw_line(center + Vector2(-5, 6), center + Vector2(5, 6), TRACK, 2)
		"thrust":
			draw_arc(center + Vector2(0, 5), 16, PI, TAU, 32, TRACK, 4, true)
			draw_arc(center + Vector2(0, 5), 16, PI, PI + PI * clampf(current / maximum, 0.01, 1.0), 32, accent, 4, true)
			var angle := PI + PI * clampf(current / maximum, 0, 1)
			draw_line(center + Vector2(0, 5), center + Vector2(0, 5) + Vector2.from_angle(angle) * 12, INK, 2, true)
			draw_circle(center + Vector2(0, 5), 3, accent)
		"range":
			draw_arc(center + Vector2(-6, 10), 22, -PI * 0.55, -0.1, 20, accent, 2, true)
			draw_line(center + Vector2(15, 8), center + Vector2(10, 1), accent, 2)
			draw_line(center + Vector2(15, 8), center + Vector2(7, 8), accent, 2)
			draw_circle(center + Vector2(-7, 11), 3, accent)
