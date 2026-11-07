extends Control

signal build_requested
signal sandbox_requested
signal back_requested

var _mission: MissionDefinition


func setup(mission: MissionDefinition) -> void:
	_mission = mission


func _ready() -> void:
	%Primary.disabled = _mission == null
	%BuilderPreview.disabled = _mission == null
	if _mission != null:
		%Heading.text = "%s  /  %s" % [_mission.id, _mission.title]
		%Details.text = "%s\nBudget %d credits  |  Reward %d credits" % [
			_mission.objective_text, _mission.budget_credits, _mission.reward_credits,
		]
	%Primary.pressed.connect(func() -> void: sandbox_requested.emit())
	%BuilderPreview.pressed.connect(func() -> void: build_requested.emit())
	%Secondary.pressed.connect(func() -> void: back_requested.emit())
