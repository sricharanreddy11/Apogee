class_name RocketPreview
extends Control

var _config: RocketConfig
var _rig: RocketRig
var _body_id := "earth"
var _clock := 0.0


func setup(config: RocketConfig) -> void:
	_config = config.copy() if config != null else null
	if is_node_ready():
		_rig.setup(_config)
		_layout_rig()


func get_config() -> RocketConfig:
	return _config.copy() if _config != null else null


func set_body(body_id: String) -> void:
	_body_id = body_id
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_rig = RocketRig.new()
	_rig.name = "RocketRig"
	_rig.effect_context = "launchpad"
	add_child(_rig)
	_rig.setup(_config)
	resized.connect(_layout_rig)
	_layout_rig()


func _layout_rig() -> void:
	_rig.position = Vector2(size.x * 0.56, size.y * 0.84)
	_rig.scale = Vector2.ONE * minf(size.x / 210.0, size.y * 0.62 / maxf(_rig.height_px, 1.0))
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(600, 600))
	var cyan := Color("65deee")
	var purple := Color("a486e9")
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("081321")
	panel.border_color = Color("345062")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(12)
	draw_style_box(panel, Rect2(0, 0, 600, 600))
	# A metal observation bay with the same cyan/purple service-light grammar as Rocket Lab.
	var window := PackedVector2Array([Vector2(42, 53), Vector2(558, 53), Vector2(580, 77), Vector2(580, 482), Vector2(20, 482), Vector2(20, 77)])
	draw_colored_polygon(window, Color("0c192d"))
	draw_polyline(PackedVector2Array([Vector2(20, 482), Vector2(20, 77), Vector2(42, 53), Vector2(558, 53), Vector2(580, 77), Vector2(580, 482)]), Color("2b4155"), 3, true)
	for index in 28:
		var x := 42.0 + fmod(index * 97.0 + 31, 510)
		var y := 82.0 + fmod(index * 61.0 + 11, 350)
		draw_circle(Vector2(x, y), 0.7 if index % 3 else 1.1, Color(0.5, 0.74, 0.86, 0.55))
	# Off-axis fixtures leave the equipped rocket's silhouette unobstructed.
	for side in [-1, 1]:
		var x: float = 300.0 + side * 260
		draw_line(Vector2(x, 99), Vector2(x, 465), Color("24394c"), 8)
		draw_line(Vector2(x, 120), Vector2(x, 286), Color(cyan if side < 0 else purple, 0.65), 2)
		draw_line(Vector2(x + side * 9, 110), Vector2(x + side * 9, 451), Color("111e30"), 4)
		for y in [155.0, 307.0, 441.0]:
			draw_rect(Rect2(x - 7, y, 14, 5), Color("506276"))
	# Small bridgework and monitor on the left, a service conduit on the right.
	draw_line(Vector2(111, 504), Vector2(111, 159), Color("355263"), 7)
	draw_line(Vector2(135, 504), Vector2(135, 159), Color("283c50"), 4)
	for index in 7:
		var y := 170.0 + index * 46
		draw_line(Vector2(111, y), Vector2(135, y + 38), Color("3e5c70"), 2)
	draw_line(Vector2(109, 175), Vector2(109, 310), Color(cyan, 0.45), 1.5)
	draw_rect(Rect2(59, 335, 99, 65), Color("102536"))
	draw_rect(Rect2(59, 335, 99, 65), Color(cyan, 0.3), false, 1)
	for index in 5:
		var width := 35.0 + fmod(index * 23.0, 45)
		draw_line(Vector2(70, 349 + index * 9), Vector2(70 + width, 349 + index * 9), Color(cyan, 0.35), 2)
	var font := get_theme_default_font()
	draw_string(font, Vector2(24, 28), "APOGEE / LAUNCH BAY", HORIZONTAL_ALIGNMENT_LEFT, 350, 13, Color(cyan, 0.8))
	draw_string(font, Vector2(449, 28), "MOON" if _body_id == "moon" else "EARTH", HORIZONTAL_ALIGNMENT_RIGHT, 125, 11, Color(purple, 0.8))
	draw_line(Vector2(24, 41), Vector2(576, 41), Color(cyan, 0.2), 1)
	# Perspective deck, cyan platform ring, purple edge lights and warning paint.
	draw_rect(Rect2(1, 484, 598, 115), Color("0d192a"))
	for y in [520.0, 556.0, 589.0]:
		draw_line(Vector2(2, y), Vector2(598, y), Color("20344a"), 1)
	for x in [70.0, 175.0, 460.0, 565.0]:
		draw_line(Vector2(x, 598), Vector2(336 + (x - 336) * 0.5, 484), Color("20344a"), 1)
	for width in [8.0, 1.5]:
		var ring := PackedVector2Array()
		for index in 65:
			var angle := index * TAU / 64
			ring.append(Vector2(336 + cos(angle) * 174, 520 + sin(angle) * 29))
		draw_polyline(ring, Color(cyan, 0.035 if width > 2 else 0.45 + sin(_clock * 1.2) * 0.07), width, true)
	draw_rect(Rect2(204, 504, 264, 16), Color("263c4c"))
	draw_line(Vector2(204, 505), Vector2(468, 505), Color(cyan, 0.9), 2)
	draw_line(Vector2(213, 519), Vector2(459, 519), Color(purple, 0.5), 2)
	for side in [-1, 1]:
		for index in 4:
			var x: float = 336 + side * (130 + index * 12)
			draw_line(Vector2(x, 556), Vector2(x + side * 7, 561), Color("9d8c58"), 3)
	draw_string(font, Vector2(24, 578), "VEHICLE / DOCKED" if _config != null else "AWAITING VEHICLE", HORIZONTAL_ALIGNMENT_LEFT, 300, 11, Color(cyan, 0.5))
