extends Control

signal part_dropped(slot: String, part_id: String)
signal part_removed(slot: String)

const SPACE := Color("#0a1320")
const GRID := Color("#162638")
const GUIDE := Color("#35546c")
const TEXT := Color("#90adc4")
const CYAN := Color("#69d9f6")
const GREEN := Color("#78f2b6")
const RED := Color("#ff7e89")
const SLOTS := ["pod", "tank", "engine"]
const SLOT_NAMES := ["COMMAND POD", "FUEL TANK", "ENGINE"]

var accepts_part: Callable
var _parts: Dictionary = {}
var _artwork: Dictionary = {}
var _drag_id := ""
var _drag_texture: Texture2D
var _flash_slot := ""
var _flash := 0.0
var _snap_tween: Tween


func _ready() -> void:
	set_process(false)
	resized.connect(queue_redraw)


func show_parts(parts: Dictionary, artwork: Dictionary) -> void:
	_parts = parts
	_artwork = artwork
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		_drag_id = _part_id(data)
		_drag_texture = data.get("artwork") if not _drag_id.is_empty() else null
		set_process(not _drag_id.is_empty())
		queue_redraw()
	elif what == NOTIFICATION_DRAG_END:
		_drag_id = ""
		_drag_texture = null
		set_process(false)
		queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _part_id(data: Variant) -> String:
	if data is Dictionary and data.get("apogee_part_id") is String:
		return data["apogee_part_id"]
	return ""


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return _fits(_slot_at(at_position), _part_id(data))


func _fits(slot: String, part_id: String) -> bool:
	return not slot.is_empty() and not part_id.is_empty() and accepts_part.is_valid() and accepts_part.call(slot, part_id)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var slot := _slot_at(at_position)
	var part_id := _part_id(data)
	if not _fits(slot, part_id):
		return
	part_dropped.emit(slot, part_id)
	if _snap_tween != null:
		_snap_tween.kill()
	_flash_slot = slot
	_set_flash(1.0)
	_snap_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_snap_tween.tween_method(_set_flash, 1.0, 0.0, 0.36)


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var slot := _slot_at(event.position, 12)
		if not slot.is_empty():
			part_removed.emit(slot)
			accept_event()


func _axis_x() -> float:
	return size.x * 0.52


func _slot_rects() -> Array[Rect2]:
	var tank: Dictionary = _parts.get("tank", {})
	var tank_height := 100.0 if float(tank.get("fuel_capacity_kg", 0)) < 1500.0 else 132.0
	var top := floorf((size.y - 84.0 - tank_height - 68.0) / 2.0) - 8.0
	var left := _axis_x() - 42.0
	return [
		Rect2(left, top, 84, 84),
		Rect2(left, top + 84, 84, tank_height),
		Rect2(left, top + 84 + tank_height, 84, 68),
	]


func _slot_at(point: Vector2, reach: float = 74.0) -> String:
	var rects := _slot_rects()
	for i in SLOTS.size():
		var hit_area := rects[i]
		hit_area.position.x -= reach
		hit_area.size.x += reach * 2.0
		if hit_area.has_point(point):
			return SLOTS[i]
	return ""


func _draw() -> void:
	var axis := _axis_x()
	draw_rect(Rect2(Vector2.ZERO, size), SPACE)
	for x in range(0, int(size.x), 28):
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID)
	for y in range(0, int(size.y), 28):
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID)
	var center := Vector2(axis, size.y * 0.46)
	draw_circle(center, 155, Color("#101e2e"))
	draw_arc(center, 155, 0.0, TAU, 80, Color("#234056"), 1.0, true)
	draw_arc(center, 174, 0.12, 1.19, 30, GUIDE, 1.0, true)
	draw_arc(center, 174, 3.26, 4.33, 30, GUIDE, 1.0, true)
	draw_dashed_line(Vector2(axis, 22), Vector2(axis, size.y - 46), GUIDE, 1.0, 6.0)

	var rects := _slot_rects()
	var hover := _slot_at(get_local_mouse_position()) if not _drag_id.is_empty() else ""
	for i in SLOTS.size():
		_draw_mount(SLOTS[i], SLOT_NAMES[i], rects[i], SLOTS[i] == hover)

	var message := "Drag a part close to the rocket"
	var tint := TEXT
	if not hover.is_empty():
		var fits := _fits(hover, _drag_id)
		message = "Release to attach" if fits else "That part connects at a different mount"
		tint = GREEN if fits else RED
	elif not _drag_id.is_empty():
		message = "Follow the highlighted mount"
	elif _flash > 0.0:
		message = "Attached"
		tint = GREEN
	var font := get_theme_default_font()
	draw_string(font, Vector2(axis - 200, size.y - 20), message, HORIZONTAL_ALIGNMENT_CENTER, 400, 16, tint)


func _draw_mount(slot: String, title: String, rect: Rect2, hovered: bool) -> void:
	var fits := _fits(slot, _drag_id)
	var color := GUIDE
	if hovered:
		color = GREEN if fits else RED
	elif fits:
		color = CYAN
	var center := rect.get_center()
	var texture: Texture2D = _artwork.get(slot)
	if hovered and fits:
		var pointer := get_local_mouse_position()
		var offset := pointer - center
		if offset.length() > 46.0:
			draw_dashed_line(pointer, center + offset.normalized() * 43.0, GREEN, 1.6, 6.0)
	if hovered and fits and _drag_texture != null:
		_draw_sprite(_drag_texture, rect, 1.0, Color(0.65, 1.0, 0.83, 0.86))
	elif texture != null:
		var bounce := _flash * 0.09 if slot == _flash_slot else 0.0
		_draw_sprite(texture, rect, 1.0 + bounce, Color.WHITE)
	else:
		draw_circle(center, 20, color, false, 1.4, true)
		draw_line(center - Vector2(7, 0), center + Vector2(7, 0), color, 1.2)
		draw_line(center - Vector2(0, 7), center + Vector2(0, 7), color, 1.2)

	var pin := Vector2(rect.end.x + 24, center.y)
	draw_line(Vector2(rect.end.x + 4, center.y), pin, color, 1.3)
	draw_circle(pin, 4.0 if hovered else 2.8, color, true, -1.0, true)
	if fits or hovered:
		draw_arc(pin, 10, 0.0, TAU, 28, color, 1.2, true)
	if slot == _flash_slot and _flash > 0.0:
		draw_arc(center, 25 + (1.0 - _flash) * 52, 0, TAU, 48, Color(GREEN, _flash), 1.8, true)
	var font := get_theme_default_font()
	draw_string(font, pin + Vector2(13, 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color.lightened(0.28))


func _draw_sprite(texture: Texture2D, rect: Rect2, scale_factor: float, tint: Color) -> void:
	var height := rect.size.y * scale_factor
	var width := height * texture.get_size().aspect()
	var draw_size := Vector2(width, height)
	draw_texture_rect(texture, Rect2(rect.get_center() - draw_size / 2.0, draw_size), false, tint)
