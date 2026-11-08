class_name RocketPreview
extends Control

var _config: RocketConfig
var _rig: RocketRig
var _body_id := "earth"
var _clock := 0.0
var _purge: Tween


func setup(config: RocketConfig) -> void:
	_config = config.copy() if config != null else null
	if is_node_ready():
		_rig.setup(_config)
		_layout_rig()
		_schedule_pressure_check()


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
	_schedule_pressure_check()


func _layout_rig() -> void:
	_rig.position = Vector2(size.x * 0.50, size.y * 0.79)
	_rig.scale = Vector2.ONE * minf(size.x / 210.0, size.y * 0.62 / maxf(_rig.height_px, 1.0))
	queue_redraw()


func _schedule_pressure_check() -> void:
	if _purge != null:
		_purge.kill()
	if _config != null:
		_purge = create_tween()
		_purge.tween_interval(0.40)
		_purge.tween_callback(_rig.purge_launchpad)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(700, 600))
	var moon := _body_id == "moon"
	var ink := Color("#a9c2ce")
	var cyan := Color("#79dce6")
	var amber := Color("#ffc17a")
	draw_rect(Rect2(0, 0, 700, 600), Color("#08121c"))
	draw_rect(Rect2(25, 25, 650, 449), Color("#060f19"))
	for index in 35:
		var x := 31.0 + fmod(index * 157.0 + 31.0, 638.0)
		var y := 32.0 + fmod(index * 79.0 + 11.0, 400.0)
		draw_circle(Vector2(x, y), 0.75 if index % 3 else 1.15, Color(0.60, 0.78, 0.86, 0.48))
	draw_circle(Vector2(350, 1330), 1000, Color("#243e4d") if not moon else Color("#333e4c"), true, -1.0, true)
	draw_arc(Vector2(350, 1330), 1000, PI * 1.385, PI * 1.615, 90, Color(cyan, 0.38), 2.0, true)

	draw_rect(Rect2(0, 476, 700, 124), Color("#15222c"))
	for x: float in [29.0, 116.0, 246.0, 454.0, 584.0, 671.0]:
		draw_line(Vector2(x, 600), Vector2(350 + (x - 350) * 0.73, 478), Color("#293e4c"), 1.4, true)
	for side: float in [-1.0, 1.0]:
		var x := 350.0 + side * 234.0
		draw_rect(Rect2(x - 9, 76, 18, 402), Color("#1b2c39"))
		draw_line(Vector2(x + side * 9, 83), Vector2(x + side * 9, 470), Color("#495b65"), 2)
		for index in 4:
			var y := 114.0 + index * 88.0
			draw_line(Vector2(x - 4, y), Vector2(x + 4, y), Color(cyan, 0.65), 2)
		var foot := Vector2(350 + side * 177, 511)
		for index in 6:
			var mark := foot + Vector2(side * index * 10, 0)
			draw_line(mark, mark + Vector2(side * 5, 5), Color(amber, 0.55), 2)
	var platform := PackedVector2Array([Vector2(216, 470), Vector2(484, 470), Vector2(510, 492), Vector2(190, 492)])
	draw_colored_polygon(platform, Color("#324653"))
	draw_polyline(platform, Color("#5b7380"), 2, true)
	draw_line(Vector2(199, 492), Vector2(501, 492), Color(cyan, 0.60 + 0.10 * sin(_clock * 2.2)), 2.5, true)
	var font := get_theme_default_font()
	draw_string(font, Vector2(64, 49), "01  /  PAD WINDOW", HORIZONTAL_ALIGNMENT_LEFT, 220, 15, ink)
	draw_string(font, Vector2(490, 49), "LUNAR PAD" if moon else "EARTH PAD", HORIZONTAL_ALIGNMENT_RIGHT, 140, 13, cyan)
	draw_circle(Vector2(69, 554), 3.8, amber if _config == null else cyan, true, -1.0, true)
	draw_string(font, Vector2(81, 559), "VEHICLE SECURED" if _config != null else "PAD CLEAR", HORIZONTAL_ALIGNMENT_LEFT, 230, 14, ink)
