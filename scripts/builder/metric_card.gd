extends Control

## Shared visual grammar: colored fill = shown build, pale tick = before,
## diamond = mission threshold. Text and shapes both carry the comparison.
const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Regular.res")
const INK := Color("#e7edf1")
const MUTED := Color("#a3b4be")
const TRACK := Color("#263743")
const SIGNAL := Color("#77cbd3")
const GOAL := Color("#ffc67d")
const ALERT := Color("#ff9984")

var kind := "fuel"
var current := 0.0
var previous := 0.0
var maximum := 1.0
var target := 0.0
var dry_mass := 0.0
var has_previous := false
var _labels: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(125, 106)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_HELP
	for key: String in ["title", "value", "delta"]:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", MONO)
		label.add_theme_color_override("font_color", INK if key == "value" else MUTED)
		label.add_theme_font_size_override("font_size", 17 if key == "value" else 11)
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
	_labels.title.text = {"fuel": "FUEL", "mass": "LIFTOFF MASS", "thrust": "THRUST / WEIGHT", "range": "DELTA-V"}[kind]
	_labels.value.text = _value(current)
	var change := current - previous
	var unchanged := absf(change) < (0.005 if kind == "thrust" else 0.5)
	_labels.delta.text = "" if not has_previous or unchanged else ("↑ " if change > 0.0 else "↓ ") + _value(absf(change))
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
	_labels.title.position = Vector2(10, 7)
	_labels.value.position = Vector2(11, 30)
	_labels.delta.position = Vector2(11, 55)
	for key: String in _labels:
		_labels[key].size = Vector2(size.x - _labels[key].position.x - 10, 25 if key == "value" else 18)


func _draw() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#0a1119")
	panel.border_color = SIGNAL if has_focus() else Color("#40515c")
	panel.set_border_width_all(2 if has_focus() else 1)
	panel.set_corner_radius_all(4)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(2, 2, size.x - 4, 23), Color("#18242d"))
	draw_rect(Rect2(7, 29, size.x - 14, 29), Color("#060c12"))
	draw_line(Vector2(8, 69), Vector2(size.x - 8, 69), Color("#21303a"))
	var bar := Rect2(11, 83, size.x - 22, 8)
	draw_style_box(_pill(TRACK), bar)
	var ratio := clampf(current / maximum, 0.0, 1.0)
	if kind == "mass" and current > 0.0:
		var dry_width := bar.size.x * clampf(dry_mass / maximum, 0.0, ratio)
		draw_rect(Rect2(bar.position, Vector2(dry_width, 8)), Color("#a0b0bc"))
		draw_rect(Rect2(bar.position + Vector2(dry_width, 0), Vector2(bar.size.x * ratio - dry_width, 8)), SIGNAL)
		for x in range(int(dry_width) + 4, int(bar.size.x * ratio), 6):
			draw_line(bar.position + Vector2(x, 7), bar.position + Vector2(x + 3, 1), TRACK, 1.0)
	else:
		draw_style_box(_pill(SIGNAL), Rect2(bar.position, Vector2(bar.size.x * ratio, 8)))
	if has_previous:
		var x := bar.position.x + bar.size.x * clampf(previous / maximum, 0.0, 1.0)
		draw_line(Vector2(x, 81), Vector2(x, 95), INK, 1.4)
	if target > 0.0:
		var x := bar.position.x + bar.size.x * clampf(target / maximum, 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 89), Vector2(x + 4, 93), Vector2(x, 97), Vector2(x - 4, 93)]), GOAL)
		if current < target or (kind == "thrust" and current <= target):
			draw_circle(Vector2(size.x - 14, 17), 3, ALERT)


func _pill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style
