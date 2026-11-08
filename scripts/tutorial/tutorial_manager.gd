extends Node

const FLOW_PATH := "res://data/tutorials/orbit_basics.json"
const PROGRESS_PATH := "user://tutorial_progress.json"
const OVERLAY := preload("res://scenes/tutorial/tutorial_overlay.tscn")

var active := false
var completed := false
var progress_path := PROGRESS_PATH
var _steps: Array[Dictionary] = []
var _index := 0
var _overlay: TutorialOverlay
var _watched_object: Object
var _watched_signal := &""
var _watched_callable: Callable
var _step_token := 0


func _ready() -> void:
	_load_progress()
	_overlay = OVERLAY.instantiate() as TutorialOverlay
	add_child(_overlay)
	_overlay.next_requested.connect(_advance)
	_overlay.back_requested.connect(_back)
	_overlay.exit_requested.connect(exit_tutorial)
	get_tree().scene_changed.connect(_on_scene_changed)


func start_tutorial() -> void:
	if not _load_flow():
		push_error("Tutorial flow could not be loaded from %s." % FLOW_PATH)
		return
	_clear_watch()
	active = true
	_index = 0
	_step_token += 1
	GameManager.start_tutorial()


func exit_tutorial() -> void:
	if not active:
		return
	active = false
	_clear_watch()
	_overlay.dismiss()
	GameManager.close_tutorial_to_menu()


func complete_tutorial() -> void:
	if not active:
		return
	completed = true
	active = false
	_clear_watch()
	_overlay.dismiss()
	_save_progress()
	GameManager.close_tutorial_to_menu()


func _load_flow() -> bool:
	var file := FileAccess.open(FLOW_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("steps") is Array:
		return false
	_steps.clear()
	for entry: Variant in parsed.steps:
		if entry is Dictionary and entry.has("id") and entry.has("scene"):
			_steps.append(entry.duplicate(true))
	return not _steps.is_empty()


func _load_progress() -> void:
	if not FileAccess.file_exists(progress_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(progress_path))
	if parsed is Dictionary:
		completed = bool(parsed.get("completed", false))


func _save_progress() -> Error:
	var file := FileAccess.open(progress_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var written := file.store_string(JSON.stringify({"version": 1, "completed": completed}))
	file.flush()
	var error := file.get_error()
	file.close()
	return error if written else ERR_FILE_CANT_WRITE


func reset_progress() -> Error:
	active = false
	completed = false
	_clear_watch()
	_overlay.dismiss()
	return _save_progress()


func _on_scene_changed() -> void:
	if not active or _steps.is_empty():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var step := _steps[_index]
	if String(step.get("advance", "")) == "scene" and scene.name == String(step.get("next_scene", "")):
		_index += 1
		_step_token += 1
		if _index >= _steps.size():
			complete_tutorial()
			return
	call_deferred("_present_current")


func _present_current() -> void:
	_present_current_ready()


func _present_current_ready() -> void:
	if not active or _index < 0 or _index >= _steps.size():
		return
	_clear_watch()
	var scene := get_tree().current_scene
	var step := _steps[_index]
	if scene == null or scene.name != String(step.scene):
		_overlay.dismiss()
		return
	var primary := _resolve_control(String(step.get("target", "")))
	var secondary := _resolve_control(String(step.get("secondary_target", "")))
	var expected_target := String(step.get("target", ""))
	if not expected_target.is_empty() and primary == null:
		_retry_missing_target(_step_token, expected_target, String(scene.name))
	var can_back := _index > 0 and String(_steps[_index - 1].scene) == String(step.scene)
	_overlay.present(step, _index, _steps.size(), primary, secondary, can_back)
	_bind_completion(step, primary)


func _retry_missing_target(token: int, target_name: String, scene_name: String) -> void:
	# Complex simulation scenes may finish adding their nested controls one frame
	# after SceneTree.scene_changed. Retry once without letting stale steps reappear.
	await get_tree().process_frame
	if active and token == _step_token and get_tree().current_scene != null and get_tree().current_scene.name == scene_name:
		if _resolve_control(target_name) != null:
			_present_current_ready()
		else:
			push_warning("Tutorial target '%s' was not found in scene '%s'." % [target_name, scene_name])


func _resolve_control(node_name: String) -> Control:
	if node_name.is_empty() or get_tree().current_scene == null:
		return null
	return get_tree().current_scene.find_child(node_name, true, false) as Control


func _bind_completion(step: Dictionary, primary: Control) -> void:
	var advance := String(step.get("advance", "next"))
	var token := _step_token
	match advance:
		"press":
			if primary is BaseButton:
				_watch(primary, &"pressed", _on_action_completed.bind(token))
		"part_drop":
			var preview := _resolve_control("RocketPreview")
			if preview != null:
				_watch(preview, &"part_dropped", _on_part_dropped.bind(String(step.get("part_id", "")), token))
		"slider_change":
			if primary is Range:
				_watch(primary, &"value_changed", _on_slider_changed.bind(token))


func _watch(object: Object, signal_name: StringName, callable: Callable) -> void:
	if object == null or not object.has_signal(signal_name):
		return
	_watched_object = object
	_watched_signal = signal_name
	_watched_callable = callable
	object.connect(signal_name, callable)


func _clear_watch() -> void:
	if _watched_object != null and is_instance_valid(_watched_object) and not _watched_signal.is_empty():
		if _watched_object.is_connected(_watched_signal, _watched_callable):
			_watched_object.disconnect(_watched_signal, _watched_callable)
	_watched_object = null
	_watched_signal = &""
	_watched_callable = Callable()


func _on_action_completed(token: int) -> void:
	if active and token == _step_token:
		call_deferred("_advance")


func _on_part_dropped(_slot: String, part_id: String, expected: String, token: int) -> void:
	if active and token == _step_token and part_id == expected:
		call_deferred("_advance")


func _on_slider_changed(_value: float, token: int) -> void:
	if active and token == _step_token:
		call_deferred("_advance")


func _advance() -> void:
	if not active or _steps.is_empty():
		return
	var step := _steps[_index]
	if String(step.get("advance", "")) == "complete":
		complete_tutorial()
		return
	_index += 1
	_step_token += 1
	if _index >= _steps.size():
		complete_tutorial()
		return
	_present_current()


func _back() -> void:
	if not active or _index <= 0:
		return
	if String(_steps[_index - 1].scene) != String(_steps[_index].scene):
		return
	_index -= 1
	_step_token += 1
	_present_current()
