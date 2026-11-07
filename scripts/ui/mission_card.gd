class_name MissionCard
extends PanelContainer

signal mission_selected(mission_id: String)

const CYAN := Color("#59c8e8")
const AMBER := Color("#ffc25c")
const GREEN := Color("#69d6a1")
const MUTED := Color("#8ba4b7")

var mission_id: String = ""
var is_selectable: bool = false
var _mission: MissionDefinition
var _completed: bool = false
var _best_score: int = 0
var _unlock_text: String = ""
var _selected: bool = false


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
	_refresh()


func set_selected(selected: bool) -> void:
	_selected = selected
	if is_node_ready():
		_update_style()


func _refresh() -> void:
	if _mission == null:
		%MissionName.text = "Mission unavailable"
		%SelectButton.disabled = true
		return
	%MissionID.text = _mission.id
	%MissionName.text = _mission.title
	%MissionDescription.text = _mission.objective_text
	%BudgetLabel.text = "BUDGET  %s CR" % _format_credits(_mission.budget_credits)
	%RewardLabel.text = "REWARD  +%s CR" % _format_credits(_mission.reward_credits)
	%RouteLabel.text = "%s  →  %s" % [_mission.starting_location, _mission.destination]
	%SelectButton.disabled = not is_selectable
	%UnlockLabel.visible = not is_selectable
	%UnlockLabel.text = _unlock_text if not _unlock_text.is_empty() else "Complete the preceding mission to unlock"
	if _completed:
		%StatusLabel.text = "COMPLETED · BEST %d/100" % _best_score
		%StatusLabel.add_theme_color_override("font_color", GREEN)
		%SelectButton.text = "Replay mission"
	elif is_selectable:
		%StatusLabel.text = "AVAILABLE"
		%StatusLabel.add_theme_color_override("font_color", CYAN)
		%SelectButton.text = "Select mission"
	else:
		%StatusLabel.text = "LOCKED"
		%StatusLabel.add_theme_color_override("font_color", AMBER)
		%SelectButton.text = "Locked"
	_update_style()


func _update_style() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#10283a") if _selected else Color("#0c1e2e")
	panel.border_color = CYAN if is_selectable else Color("#273a49")
	if _completed:
		panel.border_color = GREEN
	panel.set_border_width_all(2 if _selected else 1)
	panel.border_width_left = 4
	panel.set_corner_radius_all(9)
	panel.content_margin_left = 22.0
	panel.content_margin_right = 22.0
	panel.content_margin_top = 14.0
	panel.content_margin_bottom = 14.0
	add_theme_stylebox_override("panel", panel)
	%MissionID.add_theme_color_override("font_color", CYAN if is_selectable else MUTED)
	%MissionName.add_theme_color_override("font_color", Color("#e1eef6") if is_selectable else Color("#aabcc9"))
	var button := StyleBoxFlat.new()
	button.bg_color = Color("#164b60") if is_selectable else Color("#152532")
	button.border_color = CYAN if is_selectable else Color("#314554")
	button.set_border_width_all(1)
	button.set_corner_radius_all(5)
	button.content_margin_left = 20.0
	button.content_margin_right = 20.0
	button.content_margin_top = 10.0
	button.content_margin_bottom = 10.0
	%SelectButton.add_theme_stylebox_override("normal", button)
	%SelectButton.add_theme_stylebox_override("disabled", button)
	var hover := button.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#21627a")
	%SelectButton.add_theme_stylebox_override("hover", hover)
	%SelectButton.add_theme_stylebox_override("pressed", hover)
	%SelectButton.add_theme_color_override("font_color", Color("#e5f7ff"))
	%SelectButton.add_theme_color_override("font_disabled_color", MUTED)


func _on_select_button_pressed() -> void:
	# The disabled appearance and this guard both prevent direct pressed.emit() bypass.
	if not is_selectable or %SelectButton.disabled or _mission == null:
		return
	mission_selected.emit(mission_id)


func _format_credits(value: int) -> String:
	var digits := str(value)
	var result := ""
	for index in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result
