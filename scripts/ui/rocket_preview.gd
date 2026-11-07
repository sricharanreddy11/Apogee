class_name RocketPreview
extends Control

## Visual of the supplied design, not a physics body or a second simulator.
@export var show_launchpad: bool = true

var _config: RocketConfig
var _artwork: Dictionary = {}


func setup(config: RocketConfig) -> void:
	_config = _copy_config(config)
	_load_artwork()
	queue_redraw()


func _load_artwork() -> void:
	if _config == null:
		return
	var ids: Array[String] = [_config.command_pod_id]
	for stage_config in _config.stages:
		if stage_config != null:
			ids.append(stage_config.engine_id)
			ids.append_array(stage_config.tank_ids)
	for part_id in ids:
		if part_id.is_empty() or _artwork.has(part_id):
			continue
		var path := "res://assets/rockets/%s.svg" % part_id.to_lower()
		if ResourceLoader.exists(path):
			var texture := load(path) as Texture2D
			if texture != null:
				_artwork[part_id] = texture


func get_config() -> RocketConfig:
	return _copy_config(_config)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _copy_config(config: RocketConfig) -> RocketConfig:
	if config == null:
		return null
	var result := RocketConfig.new()
	result.rocket_name = config.rocket_name
	result.command_pod_id = config.command_pod_id
	for stage_config in config.stages:
		result.stages.append(stage_config.copy() if stage_config != null else null)
	result.attachment_ids.assign(config.attachment_ids)
	result.cosmetic_order.assign(config.cosmetic_order)
	return result


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#10253b"))
	# Fixed stars keep this drawing deterministic and independent of flight.
	for index in 28:
		var x := fmod(float(index * 97 + 31), maxf(size.x - 20.0, 1.0)) + 10.0
		var y := fmod(float(index * 61 + 11), maxf(size.y * 0.65, 1.0)) + 8.0
		draw_circle(Vector2(x, y), 1.2, Color("#7fadc4"))
	var platform_y := size.y * 0.84
	if show_launchpad:
		draw_rect(Rect2(0.0, platform_y + 18.0, size.x, size.y - platform_y), Color("#1b3940"))
		draw_rect(Rect2(size.x * 0.18, platform_y, size.x * 0.64, 18.0), Color("#81929a"))
		var tower_x := size.x * 0.22
		var tower_top := size.y * 0.2
		draw_line(Vector2(tower_x, platform_y), Vector2(tower_x, tower_top), Color("#476579"), 10.0)
		draw_line(Vector2(tower_x + 30.0, platform_y), Vector2(tower_x + 30.0, tower_top), Color("#476579"), 6.0)
		for index in 6:
			var y := lerpf(tower_top, platform_y, float(index) / 6.0)
			draw_line(Vector2(tower_x, y), Vector2(tower_x + 30.0, y + (platform_y - tower_top) / 6.0), Color("#476579"), 3.0)
		draw_line(Vector2(tower_x, tower_top), Vector2(size.x * 0.51, tower_top), Color("#476579"), 6.0)
	if _config == null:
		return
	var height_units := 0.0
	if not _config.command_pod_id.is_empty():
		height_units += _part_height(_config.command_pod_id, 42.0)
	for stage_config in _config.stages:
		if stage_config == null:
			continue
		if not stage_config.engine_id.is_empty():
			height_units += _part_height(stage_config.engine_id, 24.0)
		for tank_id in stage_config.tank_ids:
			height_units += _tank_height(tank_id)
	var scale_factor := minf(size.x / 260.0, size.y * 0.62 / maxf(height_units, 1.0))
	var center_x := size.x * 0.57
	var cursor_y := platform_y
	# Stage zero is physical bottom: draw engine then tanks upward.
	for stage_config in _config.stages:
		if stage_config == null:
			continue
		if not stage_config.engine_id.is_empty():
			_draw_engine(Vector2(center_x, cursor_y), scale_factor, stage_config.engine_id)
			cursor_y -= _part_height(stage_config.engine_id, 24.0) * scale_factor
		for tank_id in stage_config.tank_ids:
			var height := _tank_height(tank_id) * scale_factor
			_draw_tank(Rect2(center_x - 21.0 * scale_factor, cursor_y - height, 42.0 * scale_factor, height), tank_id, scale_factor)
			cursor_y -= height
	if not _config.command_pod_id.is_empty():
		_draw_pod(Vector2(center_x, cursor_y), scale_factor, _config.command_pod_id)
	if not _config.attachment_ids.is_empty():
		for side in [-1.0, 1.0]:
			draw_line(Vector2(center_x + side * 20.0 * scale_factor, platform_y - 50.0 * scale_factor), Vector2(center_x + side * 38.0 * scale_factor, platform_y), Color("#aabac3"), 4.0 * scale_factor)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(16.0, size.y - 14.0), _config.rocket_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32.0, 18, Color("#dceaf3"))


func _tank_height(part_id: String) -> float:
	return _part_height(part_id, 66.0 if part_id == "TANK_L" else 40.0)


func _part_height(part_id: String, fallback: float) -> float:
	var texture: Texture2D = _artwork.get(part_id)
	return 42.0 / texture.get_size().aspect() if texture != null else fallback


func _draw_artwork(part_id: String, rect: Rect2) -> bool:
	var texture: Texture2D = _artwork.get(part_id)
	if texture == null:
		return false
	draw_texture_rect(texture, rect, false)
	return true


func _draw_tank(rect: Rect2, part_id: String, scale_factor: float) -> void:
	if _draw_artwork(part_id, rect):
		return
	var color := Color("#dbe9ee") if part_id == "TANK_L" else Color("#9fc9d5")
	draw_rect(rect, color)
	draw_rect(rect, Color("#6d99a6"), false, 2.0 * scale_factor)
	draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y * 0.25), Vector2(rect.size.x, 8.0 * scale_factor)), Color("#2a627a"))
	draw_line(rect.position + Vector2(8.0 * scale_factor, 0.0), rect.position + Vector2(8.0 * scale_factor, rect.size.y), Color("#ffffff"), 2.0 * scale_factor)


func _draw_engine(base: Vector2, scale_factor: float, part_id: String) -> void:
	var height := _part_height(part_id, 24.0) * scale_factor
	if _draw_artwork(part_id, Rect2(base - Vector2(21.0 * scale_factor, height), Vector2(42.0 * scale_factor, height))):
		return
	var points := PackedVector2Array([
		base + Vector2(-22.0, 0.0) * scale_factor,
		base + Vector2(22.0, 0.0) * scale_factor,
		base + Vector2(12.0, -19.0) * scale_factor,
		base + Vector2(-12.0, -19.0) * scale_factor,
	])
	draw_colored_polygon(points, Color("#708a99"))
	draw_rect(Rect2(base + Vector2(-20.0, -24.0) * scale_factor, Vector2(40.0, 7.0) * scale_factor), Color("#d3dfe5"))


func _draw_pod(base: Vector2, scale_factor: float, part_id: String) -> void:
	var height := _part_height(part_id, 42.0) * scale_factor
	if _draw_artwork(part_id, Rect2(base - Vector2(21.0 * scale_factor, height), Vector2(42.0 * scale_factor, height))):
		return
	var points := PackedVector2Array([
		base + Vector2(-21.0, 0.0) * scale_factor,
		base + Vector2(21.0, 0.0) * scale_factor,
		base + Vector2(13.0, -26.0) * scale_factor,
		base + Vector2(0.0, -42.0) * scale_factor,
		base + Vector2(-13.0, -26.0) * scale_factor,
	])
	draw_colored_polygon(points, Color("#e7f0f1"))
	draw_circle(base + Vector2(0.0, -19.0) * scale_factor, 7.0 * scale_factor, Color("#48b9d7"))
	draw_arc(base + Vector2(0.0, -19.0) * scale_factor, 7.0 * scale_factor, 0.0, TAU, 24, Color("#27495e"), 2.0 * scale_factor)
