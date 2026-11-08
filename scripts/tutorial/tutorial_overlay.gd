class_name TutorialOverlay
extends CanvasLayer

signal next_requested
signal back_requested
signal exit_requested

var _primary: Control
var _secondary: Control
var _mode := "explain"
var _block_focus_input := true
var _ghost_tween: Tween
var _last_ghost_key := ""


func _ready() -> void:
	%Next.pressed.connect(func() -> void: next_requested.emit())
	%Back.pressed.connect(func() -> void: back_requested.emit())
	%Exit.pressed.connect(func() -> void: exit_requested.emit())
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func present(step: Dictionary, index: int, total: int, primary: Control, secondary: Control, can_back: bool) -> void:
	_primary = primary
	_secondary = secondary
	_mode = String(step.get("presentation", "explain"))
	%Progress.text = "GUIDED ORBIT  ·  STEP %d OF %d" % [index + 1, total]
	%Title.text = String(step.get("title", "Tutorial"))
	%Body.text = String(step.get("body", ""))
	var advance := String(step.get("advance", "next"))
	_block_focus_input = advance not in ["press", "part_drop", "slider_change", "scene"]
	%Next.visible = advance in ["next", "complete"]
	%Next.text = "Finish tutorial" if advance == "complete" else "Continue ›"
	%ActionHint.visible = not %Next.visible
	%ActionHint.text = String(step.get("hint", "Complete the highlighted action to continue."))
	%Back.disabled = not can_back
	%Back.visible = can_back
	%PrimaryHighlight.visible = primary != null
	%SecondaryHighlight.visible = secondary != null
	%FocusBlocker.visible = _block_focus_input and (primary != null or secondary != null)
	%Ghost.visible = _mode == "drag_demo" and primary != null and secondary != null
	_last_ghost_key = ""
	show()
	call_deferred("_update_layout")


func dismiss() -> void:
	_primary = null
	_secondary = null
	if _ghost_tween != null:
		_ghost_tween.kill()
		_ghost_tween = null
	hide()


func _process(_delta: float) -> void:
	if visible:
		_update_layout()


func _update_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var primary_rect := _control_rect(_primary)
	var secondary_rect := _control_rect(_secondary)
	var focus_rect := primary_rect
	if focus_rect.size == Vector2.ZERO:
		focus_rect = secondary_rect
	elif secondary_rect.size != Vector2.ZERO:
		focus_rect = focus_rect.merge(secondary_rect)
	_layout_dimmers(focus_rect, viewport_size)
	_layout_focus_blocker(focus_rect)
	_layout_highlight(%PrimaryHighlight, primary_rect)
	_layout_highlight(%SecondaryHighlight, secondary_rect)
	_layout_card(focus_rect, viewport_size)
	_layout_ghost(primary_rect, secondary_rect)


func _control_rect(control: Control) -> Rect2:
	if control == null or not is_instance_valid(control) or not control.is_visible_in_tree():
		return Rect2()
	return control.get_global_rect().grow(7.0)


func _layout_dimmers(focus: Rect2, viewport_size: Vector2) -> void:
	if focus.size == Vector2.ZERO:
		_set_rect(%DimTop, Rect2(Vector2.ZERO, viewport_size))
		for dimmer in [%DimBottom, %DimLeft, %DimRight]:
			_set_rect(dimmer, Rect2())
		return
	var clipped := focus.intersection(Rect2(Vector2.ZERO, viewport_size))
	_set_rect(%DimTop, Rect2(0, 0, viewport_size.x, maxf(0.0, clipped.position.y)))
	_set_rect(%DimBottom, Rect2(0, clipped.end.y, viewport_size.x, maxf(0.0, viewport_size.y - clipped.end.y)))
	_set_rect(%DimLeft, Rect2(0, clipped.position.y, maxf(0.0, clipped.position.x), clipped.size.y))
	_set_rect(%DimRight, Rect2(clipped.end.x, clipped.position.y, maxf(0.0, viewport_size.x - clipped.end.x), clipped.size.y))


func _layout_highlight(highlight: Control, rect: Rect2) -> void:
	highlight.visible = rect.size != Vector2.ZERO
	if highlight.visible:
		_set_rect(highlight, rect)


func _layout_focus_blocker(rect: Rect2) -> void:
	%FocusBlocker.visible = _block_focus_input and rect.size != Vector2.ZERO
	if %FocusBlocker.visible:
		_set_rect(%FocusBlocker, rect)


func _layout_card(focus: Rect2, viewport_size: Vector2) -> void:
	var card_size := Vector2(minf(540.0, viewport_size.x - 32.0), minf(238.0, viewport_size.y - 32.0))
	%Card.size = card_size
	var x := 22.0
	if focus.size != Vector2.ZERO and focus.get_center().x < viewport_size.x * 0.5:
		x = viewport_size.x - card_size.x - 22.0
	var y := viewport_size.y - card_size.y - 22.0
	if focus.size != Vector2.ZERO and focus.get_center().y > viewport_size.y * 0.57:
		y = 22.0
	%Card.position = Vector2(clampf(x, 16.0, viewport_size.x - card_size.x - 16.0), clampf(y, 16.0, viewport_size.y - card_size.y - 16.0))


func _layout_ghost(from_rect: Rect2, to_rect: Rect2) -> void:
	if not %Ghost.visible or from_rect.size == Vector2.ZERO or to_rect.size == Vector2.ZERO:
		return
	var key := "%s:%s" % [from_rect.get_center(), to_rect.get_center()]
	if key == _last_ghost_key:
		return
	_last_ghost_key = key
	if _ghost_tween != null:
		_ghost_tween.kill()
	var start: Vector2 = from_rect.get_center() - Vector2(%Ghost.size) * 0.5
	var finish: Vector2 = to_rect.get_center() - Vector2(%Ghost.size) * 0.5
	%Ghost.position = start
	_ghost_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ghost_tween.tween_property(%Ghost, "position", finish, 1.15)
	_ghost_tween.tween_interval(0.28)
	_ghost_tween.tween_property(%Ghost, "position", start, 0.01)
	_ghost_tween.tween_interval(0.38)


func _set_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
