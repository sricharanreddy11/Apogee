extends Control

signal part_dropped(slot: String, part_id: String)
signal part_removed(slot: String)

const CYAN := Color("#69d9f6")
const GREEN := Color("#78f2b6")
const RED := Color("#ff7e89")

var accepts_part: Callable
var _mounts: Array[Dictionary] = []
var _artwork: Dictionary = {}
var _pieces: Dictionary = {}
var _rects: Dictionary = {}
var _auxiliary: Dictionary = {}
var _legs_available := false
var _legs_id := ""
var _drag_id := ""
var _drag_texture: Texture2D
var _hover := ""
var _snap_tween: Tween
var _test_tween: Tween


func _ready() -> void:
	set_process(false)
	resized.connect(_layout)


func show_assembly(mounts: Array[Dictionary], artwork: Dictionary, legs_available: bool, legs_id: String) -> void:
	_stop_test()
	_mounts = mounts
	_artwork = artwork
	_legs_available = legs_available or not legs_id.is_empty()
	_legs_id = legs_id
	_layout()


func _layout() -> void:
	_rects.clear()
	_auxiliary.clear()
	var heights: Array[float] = []
	var total := 0.0
	for mount in _mounts:
		var texture: Texture2D = _artwork.get(mount.id)
		var height := 64.0
		if texture != null:
			height = texture.get_height() * 1.25
		elif mount.get("spare", false) or mount.kind == "payload":
			height = 0.0
		elif mount.kind == "decoupler":
			height = 28.0
		heights.append(height)
		total += height
	var fit := minf(1.0, size.y * 0.56 / maxf(total, 1.0))
	var axis := size.x * 0.50
	%Pad.position = Vector2(axis, size.y * 0.752)
	var y := size.y * 0.752 - total * fit
	for index in _mounts.size():
		var mount := _mounts[index]
		var height := heights[index] * fit
		var width := 84.0 * fit
		if is_zero_approx(height):
			var direction := 1.0 if mount.kind == "payload" else -1.0
			_rects[mount.key] = Rect2(axis + direction * 83.0 - 18.0, y - 15.0, 36.0, 30.0)
			_auxiliary[mount.key] = true
		else:
			_rects[mount.key] = Rect2(axis - width * 0.5, y, width, height)
			y += height
	if _legs_available:
		var leg_anchor: Rect2 = _rects.get("engine_1", _rects.get("engine", Rect2()))
		_rects["legs"] = Rect2(leg_anchor.end.x + 8.0, leg_anchor.position.y - 8.0, 45.0, 51.0)
		_auxiliary["legs"] = true
	_sync_sprites()
	queue_redraw()


func _sync_sprites() -> void:
	if _snap_tween != null:
		_snap_tween.kill()
		_snap_tween = null
	for child in %Assembly.get_children():
		%Assembly.remove_child(child)
		child.queue_free()
	_pieces.clear()
	for mount in _mounts:
		var texture: Texture2D = _artwork.get(mount.id)
		if texture != null:
			_add_piece(mount.key, texture, _rects[mount.key])
	var legs: Texture2D = _artwork.get(_legs_id)
	if legs != null:
		var base: Rect2 = _rects.get("engine_1", _rects.get("engine", Rect2()))
		var rect := Rect2(base.get_center().x - base.size.x * 0.9, base.position.y - base.size.y * 0.36, base.size.x * 1.8, base.size.y * 1.3)
		_add_piece("legs", legs, rect)


func _add_piece(key: String, texture: Texture2D, rect: Rect2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = rect.get_center()
	sprite.scale = Vector2.ONE * (rect.size.y / texture.get_height())
	sprite.name = key
	%Assembly.add_child(sprite)
	_pieces[key] = sprite


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		_drag_id = _part_id(data)
		_drag_texture = data.get("artwork") as Texture2D if not _drag_id.is_empty() else null
		set_process(not _drag_id.is_empty())
		queue_redraw()
	elif what == NOTIFICATION_DRAG_END:
		_drag_id = ""
		_drag_texture = null
		_hover = ""
		for sprite: Sprite2D in _pieces.values():
			sprite.modulate = Color.WHITE
		set_process(false)
		queue_redraw()


func _process(_delta: float) -> void:
	_hover = _slot_at(get_local_mouse_position())
	for key: String in _pieces:
		var sprite: Sprite2D = _pieces[key]
		sprite.modulate = Color.WHITE if key != _hover else (Color(0.65, 1.0, 0.75, 0.28) if _fits(key, _drag_id) else RED)
	queue_redraw()


func _part_id(data: Variant) -> String:
	if data is Dictionary and data.get("apogee_part_id") is String:
		return data["apogee_part_id"]
	return ""


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return _test_tween == null and _fits(_slot_at(at_position), _part_id(data))


func _fits(slot: String, part_id: String) -> bool:
	return not slot.is_empty() and not part_id.is_empty() and accepts_part.is_valid() and accepts_part.call(slot, part_id)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	var slot := _slot_at(at_position)
	var rect: Rect2 = _rects[slot]
	part_dropped.emit(slot, _part_id(data))
	%SnapSparks.position = rect.get_center()
	%SnapSparks.restart()
	%SnapSparks.emitting = true
	var sprite: Sprite2D = _pieces.get(slot)
	if sprite != null:
		if _snap_tween != null:
			_snap_tween.kill()
		var fitted_scale := sprite.scale
		sprite.scale *= 1.13
		_snap_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_snap_tween.tween_property(sprite, "scale", fitted_scale, 0.28)


func _gui_input(event: InputEvent) -> void:
	if _test_tween == null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var slot := _slot_at(event.position, 12)
		if not slot.is_empty():
			part_removed.emit(slot)
			accept_event()


func _slot_at(point: Vector2, reach: float = 64.0) -> String:
	for key: String in _auxiliary:
		if _rects[key].has_point(point):
			return key
	for mount in _mounts:
		if _auxiliary.has(mount.key):
			continue
		var hit: Rect2 = _rects[mount.key]
		hit.position.x -= reach
		hit.size.x += reach * 2.0
		if hit.has_point(point):
			return mount.key
	return ""


func _draw() -> void:
	if _test_tween != null:
		return
	for key: String in _rects:
		var rect: Rect2 = _rects[key]
		var matches := _fits(key, _drag_id)
		var hovered := key == _hover
		if (_pieces.has(key) or _auxiliary.has(key)) and not hovered and not matches:
			continue
		var color := GREEN if hovered and matches else (RED if hovered else (CYAN if matches else Color("#567683")))
		var center := rect.get_center()
		draw_circle(center, 11.0 if hovered else 6.0, color, false, 1.4, true)
		draw_line(center - Vector2(3, 0), center + Vector2(3, 0), color, 1.0)
		draw_line(center - Vector2(0, 3), center + Vector2(0, 3), color, 1.0)
		if hovered and matches and _drag_texture != null:
			var preview_size := Vector2(1.0 / float(_drag_texture.get_height()), 1) * rect.size.y
			preview_size.x *= _drag_texture.get_width()
			draw_texture_rect(_drag_texture, Rect2(center - preview_size * 0.5, preview_size), false, Color(0.54, 1.0, 0.76, 0.75))


func fire_test(config: RocketConfig) -> void:
	if _test_tween != null:
		return
	%TestRig.setup(config)
	%TestRig.position = Vector2(size.x * 0.50, size.y * 0.752)
	%TestRig.scale = Vector2.ONE * minf(1.25, size.y * 0.56 / maxf(1.0, %TestRig.height_px))
	%TestRig.show()
	%Assembly.hide()
	%TestRig.apply_flight(0, 0.9, false)
	_test_tween = create_tween()
	_test_tween.tween_interval(0.82)
	if config.stages.size() == 2:
		_test_tween.tween_callback(func() -> void: %TestRig.apply_flight(1, 0.65, true))
		_test_tween.tween_interval(0.90)
	else:
		_test_tween.tween_callback(func() -> void: %TestRig.apply_flight(0, 0.0, true))
		_test_tween.tween_interval(0.48)
	_test_tween.tween_callback(_stop_test)
	queue_redraw()


func _stop_test() -> void:
	if _test_tween != null:
		_test_tween.kill()
		_test_tween = null
		%TestRig.setup(null)
	%TestRig.hide()
	%Assembly.show()
	queue_redraw()
