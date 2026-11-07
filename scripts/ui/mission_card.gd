class_name MissionCard
extends Control

signal mission_selected(mission_id: String)
signal signal_focused(mission_id: String)


var mission_id: String = ""
var is_selectable: bool = false
var _mission: MissionDefinition
var _completed: bool = false
var _best_score: int = 0
var _unlock_text: String = ""
var _selected: bool = false
var _hover_tween: Tween


func setup(mission: MissionDefinition, unlocked: bool, completed: bool,
		best_score: int = 0, unlock_text: String = "") -> void:
	_mission = mission
	mission_id = "" if mission == null else mission.id
	_completed = completed
	is_selectable = mission != null and (unlocked or completed)
	_best_score = clampi(best_score, 0, 100)
	_unlock_text = unlock_text
	if is_node_ready():
		_refresh()


func _ready() -> void:
	%SelectButton.pressed.connect(_on_select_button_pressed)
	%SelectButton.mouse_entered.connect(_set_hovered.bind(true))
	%SelectButton.mouse_exited.connect(_set_hovered.bind(false))
	%SelectButton.focus_entered.connect(_set_hovered.bind(true))
	%SelectButton.focus_exited.connect(_set_hovered.bind(false))
	_refresh()


func set_selected(selected: bool) -> void:
	_selected = selected
	%SelectedRing.visible = selected


func _refresh() -> void:
	%SelectButton.disabled = not is_selectable
	if _mission == null:
		return
	%MissionID.text = mission_id
	%MissionName.text = _mission.title
	%SelectButton.accessibility_name = "%s, %s" % [mission_id, _mission.title]
	%SelectButton.tooltip_text = "Open briefing" if is_selectable else _unlock_text
	if _completed:
		%StatusLabel.text = "COMPLETED · %d/100" % _best_score
	elif is_selectable:
		%StatusLabel.text = "AVAILABLE"
	else:
		%StatusLabel.text = "LOCKED"
	%StatusLabel.add_theme_color_override("font_color", get_theme_color("font_color", &"SuccessLabel" if _completed else (&"EyebrowLabel" if is_selectable else &"MutedLabel")))
	%Beacon.self_modulate = get_theme_color("font_color", &"SuccessLabel") if _completed else (Color.WHITE if is_selectable else Color("#8292a8"))
	%Lock.visible = not is_selectable


func _set_hovered(hovered: bool) -> void:
	if hovered:
		signal_focused.emit(mission_id)
	if _hover_tween != null:
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(%Visual, "scale", Vector2.ONE * (1.14 if hovered else 1.0), 0.18)
	%SelectedRing.visible = hovered or _selected


func _on_select_button_pressed() -> void:
	if is_selectable and not %SelectButton.disabled:
		mission_selected.emit(mission_id)
