extends Control
## A lit sprite turntable of the real fitted parts; no placeholder equipped craft.
const CYAN := Color("6ce7ed")
var _config: RocketConfig
var _rig: RocketRig
var _pivot: Node2D
var _clock := 0.0
var _fit := 1.0

func setup(config: RocketConfig) -> void:
	_config = config.copy() if config != null else null
	if is_node_ready():
		_rig.setup(_config)
		_apply_material(_rig)
		_layout()

func get_config() -> RocketConfig:
	return _config.copy() if _config != null else null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_pivot = Node2D.new()
	add_child(_pivot)
	_rig = RocketRig.new()
	_rig.name = "EquippedRocket"
	_rig.effect_context = "cockpit"
	var light := ShaderMaterial.new()
	light.shader = preload("res://assets/ui/rocket_turntable.gdshader")
	_rig.material = light
	_pivot.add_child(_rig)
	_rig.setup(_config)
	_apply_material(_rig)
	resized.connect(_layout)
	_layout()

func _apply_material(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			child.use_parent_material = true
		_apply_material(child)

func _layout() -> void:
	if _rig == null:
		return
	_fit = minf((size.x - 80) / 110.0, (size.y - 180) / maxf(_rig.height_px, 1.0))
	_fit = maxf(_fit, 0.1)
	_pivot.position = Vector2(size.x * 0.5, size.y * 0.5)
	_rig.position.y = _rig.height_px * _fit * 0.5
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	if _rig != null:
		# Sprite yaw plus moving light gives the supplied 2D artwork a slow turn.
		_rig.scale = Vector2(_fit * (0.85 + 0.15 * cos(_clock * 0.3)), _fit)
		_pivot.position.y = size.y * 0.5 + sin(_clock * 0.65) * 3.0
	queue_redraw()

func _draw() -> void:
	if size.x < 1:
		return
	var font := get_theme_font("font", "Label")
	var muted := Color("7d9daa")
	draw_line(Vector2(0, 26), Vector2(0, size.y - 26), Color(CYAN, 0.18), 1)
	draw_string(font, Vector2(24, 40), "VEHICLE / LIVE", HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 12, CYAN)
	draw_circle(Vector2(size.x - 24, 35), 2.5, Color(CYAN, 0.6 + sin(_clock * 2) * 0.25), true, -1, true)
	var base := Vector2(size.x * 0.5, size.y - 72)
	for ring in 3:
		draw_set_transform(base, 0, Vector2(1, 0.24))
		draw_arc(Vector2.ZERO, 45 + ring * 17, 0, TAU, 72, Color(CYAN, 0.19 - ring * 0.04), 1, true)
	draw_set_transform(Vector2.ZERO)
	if _config == null:
		draw_string(font, Vector2(12, size.y * 0.48), "NO ROCKET EQUIPPED", HORIZONTAL_ALIGNMENT_CENTER, size.x - 24, 13, muted)
		draw_string(font, Vector2(12, size.y * 0.48 + 23), "Assemble in Rocket Lab", HORIZONTAL_ALIGNMENT_CENTER, size.x - 24, 12, muted)
	else:
		draw_string(font, Vector2(12, size.y - 36), _config.rocket_name, HORIZONTAL_ALIGNMENT_CENTER, size.x - 24, 15, CYAN)
		draw_string(font, Vector2(12, size.y - 16), "%d STAGE%s / EQUIPPED" % [_config.stages.size(), "S" if _config.stages.size() != 1 else ""], HORIZONTAL_ALIGNMENT_CENTER, size.x - 24, 11, muted)
