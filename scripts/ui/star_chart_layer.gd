extends Control
## Independent overscanned layers keep cursor parallax free of exposed edges.
@export_enum("Deep stars", "Nebula / dust", "Close stars") var layer: int = 0
const DEEP := preload("res://assets/mission_control/starfield.svg")
const NEBULA := preload("res://assets/mission_control/nebula.svg")
const SPEEDS := [5.0, 16.0, 32.0]
var _pointer := Vector2.ZERO
var _cursor_position := Vector2.ZERO
var _has_pointer := false
var _stars: Array[Vector3] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var rng := RandomNumberGenerator.new()
	rng.seed = 812904
	for index in 48:
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.65, 1.6)))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_cursor_position = get_global_transform_with_canvas().affine_inverse() * event.position
		_has_pointer = true

func _process(delta: float) -> void:
	var target := (_cursor_position / size.max(Vector2.ONE) - Vector2(0.5, 0.5)) * 2.0 if _has_pointer else Vector2.ZERO
	target = target.clamp(-Vector2.ONE, Vector2.ONE)
	_pointer = _pointer.lerp(target, 1.0 - exp(-delta * 4.0))
	queue_redraw()

func _draw() -> void:
	var shift := get_parallax_offset()
	var coverage := Rect2(Vector2(-40, -40) + shift, size + Vector2(80, 80))
	if layer < 2:
		draw_texture_rect(DEEP if layer == 0 else NEBULA, coverage, false)
		return
	for star in _stars:
		var point := coverage.position + Vector2(star.x, star.y) * coverage.size
		draw_circle(point, star.z * 2.8, Color(0.43, 0.78, 0.91, 0.035), true, -1, true)
		draw_circle(point, star.z, Color(0.7, 0.89, 1.0, 0.48), true, -1, true)

func get_parallax_offset() -> Vector2:
	return -_pointer * float(SPEEDS[layer])
