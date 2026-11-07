class_name PreflightPanel
extends PanelContainer

signal launch_requested
signal edit_requested

var _mission: MissionDefinition
var _config: RocketConfig
var _stats: Dictionary = {}
var _validation: Dictionary = {"valid": false, "errors": [], "warnings": []}
var _launch_sent: bool = false


func setup(mission: MissionDefinition, config: RocketConfig, stats: Dictionary, validation: Dictionary) -> void:
	_mission = mission
	_config = config.copy() if config != null else null
	_stats = stats.duplicate(true)
	_validation = validation.duplicate(true)
	_launch_sent = false
	if is_node_ready():
		_render()


func _ready() -> void:
	%LaunchButton.pressed.connect(_request_launch)
	%EditRocketButton.pressed.connect(_request_edit)
	_render()


func _render() -> void:
	var configured := _mission != null and _config != null and not _stats.is_empty()
	%LaunchButton.disabled = not configured or not bool(_validation.get("valid", false)) or _launch_sent
	%EditRocketButton.disabled = not configured
	if not configured:
		%ReadinessStatus.text = "NO ROCKET PREPARED"
		%ObjectiveLabel.text = "Select a mission and prepare a valid rocket in the builder."
		return
	%MissionName.text = "%s / %s" % [_mission.id, _mission.title]
	%ObjectiveLabel.text = _mission.objective_text
	%LocationLabel.text = "Start: %s" % _mission.starting_location
	%RocketName.text = _config.rocket_name
	%CostLabel.text = "Cost: %d / %d CR\nReward: %d CR" % [
		int(_stats.get("cost_credits", 0)), _mission.budget_credits, _mission.reward_credits,
	]
	%MassLabel.text = "Wet mass: %.0f kg\nFuel: %.0f kg  |  Stages: %d" % [
		float(_stats.get("wet_mass_kg", 0.0)), float(_stats.get("fuel_kg", 0.0)), _config.stages.size(),
	]
	var notices: Array[String] = []
	for message: String in _validation.get("errors", []):
		notices.append(message)
	for message: String in _validation.get("warnings", []):
		notices.append("Advice: %s" % message)
	%ValidationMessage.text = "\n".join(notices)
	if _launch_sent:
		%ReadinessStatus.text = "LAUNCH REQUESTED"
		%ReadinessStatus.modulate = Color("ffc35c")
		%LaunchButton.text = "Launch requested"
	else:
		%ReadinessStatus.text = "GO / READY" if _validation.get("valid", false) else "HOLD / CHECK ROCKET"
		%ReadinessStatus.modulate = Color("7de3b0") if _validation.get("valid", false) else Color("ffc35c")
		%LaunchButton.text = "LAUNCH"


func _request_launch() -> void:
	# Guard the signal handler too: disabled buttons alone are not validation.
	if not %LaunchButton.disabled:
		launch_requested.emit()


func _request_edit() -> void:
	if not %EditRocketButton.disabled:
		edit_requested.emit()


func mark_launch_requested() -> void:
	_launch_sent = true
	_render()


func show_validation_errors(errors: Array[String]) -> void:
	_validation = {"valid": false, "errors": errors, "warnings": []}
	_render()
