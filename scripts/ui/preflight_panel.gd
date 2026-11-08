class_name PreflightPanel
extends PanelContainer

signal launch_requested
signal edit_requested

var _mission: MissionDefinition
var _config: RocketConfig
var _stats: Dictionary = {}
var _validation: Dictionary = {"valid": false, "errors": [], "warnings": []}
var _launch_sent := false

func setup(mission: MissionDefinition, config: RocketConfig, stats: Dictionary, validation: Dictionary) -> void:
	_mission = mission
	_config = config.copy() if config != null else null
	_stats = stats.duplicate(true)
	_validation = validation.duplicate(true)
	_launch_sent = false
	if is_node_ready():
		_render()

func _ready() -> void:
	preload("res://scripts/ui/console_button.gd").apply(%LaunchButton, "launch")
	preload("res://scripts/ui/console_button.gd").apply(%EditRocketButton)
	%LaunchButton.pressed.connect(_request_launch)
	%EditRocketButton.pressed.connect(_request_edit)
	_render()

func _render() -> void:
	var configured := _mission != null and _config != null and not _stats.is_empty()
	%LaunchButton.disabled = not configured or not bool(_validation.get("valid", false)) or _launch_sent
	%EditRocketButton.disabled = not configured
	get_node("Stack/Scroll").visible = configured
	if not configured:
		%ReadinessStatus.text = "NO ROCKET PREPARED"
		%ObjectiveLabel.text = "Select a mission and prepare a valid rocket in the builder."
		return
	%MissionName.text = "%s / %s" % [_mission.id, _mission.title]
	%ObjectiveLabel.text = _mission.objective_text
	%LocationLabel.text = "Start: %s" % _mission.starting_location
	%RocketName.text = _config.rocket_name
	%CostLabel.text = "BUDGET   %d / %d CR" % [int(_stats.get("cost_credits", 0)), _mission.budget_credits]
	_render_metrics()
	var notices: Array[String] = []
	for message: String in _validation.get("errors", []):
		notices.append(message)
	for message: String in _validation.get("warnings", []):
		notices.append("Advice: %s" % message)
	%ValidationMessage.text = "\n".join(notices)
	%ValidationMessage.visible = not notices.is_empty()
	if _launch_sent:
		%ReadinessStatus.text = "LAUNCH REQUESTED"
		%ReadinessStatus.theme_type_variation = &"WarningLabel"
		%LaunchButton.text = "Launch requested"
	else:
		%ReadinessStatus.text = "GO / READY" if _validation.get("valid", false) else "HOLD / CHECK ROCKET"
		%ReadinessStatus.theme_type_variation = &"SuccessLabel" if _validation.get("valid", false) else &"WarningLabel"
		%LaunchButton.text = "LAUNCH ›"

func _render_metrics() -> void:
	var verifier := BuilderController.new()
	verifier.setup(_mission)
	var goal: float = verifier.call("_minimum_delta_v", _mission)
	verifier.free()
	var largest_tank := 1.0
	for part in JsonData.read_object("res://data/parts.json").get("parts", []):
		if part.get("type") == "tank" and (_mission.allowed_part_ids.is_empty() or _mission.allowed_part_ids.has(String(part.id))):
			largest_tank = maxf(largest_tank, float(part.get("fuel_capacity_kg", 0)))
	%FuelMetric.present("fuel", _stats, {}, 0, maxf(float(_stats.fuel_kg), largest_tank * 3 * maxi(1, _config.stages.size())))
	%MassMetric.present("mass", _stats, {}, 0, maxf(1, float(_stats.wet_mass_kg)))
	%ThrustMetric.present("thrust", _stats, {}, 1.0 if _mission.scenario.get("spawn_profile") == "surface_north" else 0.0, maxf(2, float(_stats.launch_twr)) * 1.15)
	%RangeMetric.present("range", _stats, {}, goal, maxf(1, maxf(goal, float(_stats.delta_v_mps))) * 1.15)
	%BudgetBar.max_value = maxi(1, _mission.budget_credits)
	%BudgetBar.value = int(_stats.cost_credits)
	%BudgetBar.theme_type_variation = &"OverBudget" if int(_stats.cost_credits) > _mission.budget_credits else &""
	var balance := _mission.budget_credits - int(_stats.cost_credits)
	%BudgetHint.text = "%d STAGE%s · %d CR %s · ◆ mission minimum" % [_config.stages.size(), "S" if _config.stages.size() != 1 else "", absi(balance), "left" if balance >= 0 else "over"]
	%MissionName.tooltip_text = %LocationLabel.text

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
