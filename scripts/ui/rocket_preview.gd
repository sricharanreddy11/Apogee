class_name RocketPreview
extends Control

@export var show_launchpad: bool = true
@export var show_background: bool = true

var _config: RocketConfig
var _rig: RocketRig
var _body_id := "earth"
var _landed := false


func setup(config: RocketConfig) -> void:
	_config = config.copy() if config != null else null
	_landed = false
	if is_node_ready():
		_rig.setup(_config)
		_layout_rig()


func get_config() -> RocketConfig:
	return _config.copy() if _config != null else null


func set_body(body_id: String) -> void:
	_body_id = body_id
	queue_redraw()


func update_visuals(telemetry: FlightTelemetry) -> void:
	if _rig == null:
		return
	_rig.apply_flight(telemetry.active_stage, telemetry.throttle, telemetry.legs_deployed)
	_rig.rotation = telemetry.heading_rad
	if not _landed and telemetry.status == FlightState.Status.LANDED:
		_landed = true
		if telemetry.body_id == "moon":
			_rig.lunar_touchdown()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig = RocketRig.new()
	_rig.name = "RocketRig"
	add_child(_rig)
	_rig.setup(_config)
	resized.connect(_layout_rig)
	_layout_rig()


func _layout_rig() -> void:
	_rig.position = Vector2(size.x * 0.56, size.y * 0.84)
	_rig.scale = Vector2.ONE * minf(size.x / 210.0, size.y * 0.62 / maxf(_rig.height_px, 1.0))
	queue_redraw()


func _draw() -> void:
	if not show_background or size.x <= 0.0 or size.y <= 0.0:
		return
	var lunar := _body_id == "moon"
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0c1827") if lunar else Color("#10253b"))
	for index in 28:
		var x := fmod(float(index * 97 + 31), maxf(size.x - 20.0, 1.0)) + 10.0
		var y := fmod(float(index * 61 + 11), maxf(size.y * 0.65, 1.0)) + 8.0
		draw_circle(Vector2(x, y), 1.2, Color("#7fadc4"))
	if not show_launchpad:
		return
	var pad_y := size.y * 0.84
	if lunar:
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, pad_y + 12), Vector2(size.x * 0.19, pad_y - 22),
			Vector2(size.x * 0.45, pad_y + 2), Vector2(size.x * 0.72, pad_y - 16),
			Vector2(size.x, pad_y + 10), size, Vector2(0, size.y),
		]), Color("#536078"))
		for x in [0.12, 0.68, 0.9]:
			draw_line(Vector2(size.x * x - 15, pad_y + 30), Vector2(size.x * x + 15, pad_y + 30), Color("#343e55"), 4)
	else:
		draw_rect(Rect2(0.0, pad_y + 18.0, size.x, size.y - pad_y), Color("#1b3940"))
		var tower_x := size.x * 0.22
		var tower_top := size.y * 0.20
		draw_line(Vector2(tower_x, pad_y), Vector2(tower_x, tower_top), Color("#476579"), 9)
		draw_line(Vector2(tower_x + 27, pad_y), Vector2(tower_x + 27, tower_top), Color("#476579"), 5)
		for index in 6:
			var y := lerpf(tower_top, pad_y, float(index) / 6.0)
			draw_line(Vector2(tower_x, y), Vector2(tower_x + 27, y + (pad_y - tower_top) / 6.0), Color("#476579"), 3)
	draw_rect(Rect2(size.x * 0.34, pad_y, size.x * 0.44, 16.0), Color("#81929a"))
