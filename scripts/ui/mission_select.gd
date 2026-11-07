extends Control

signal build_requested
signal back_requested

var _mission: MissionDefinition


func setup(mission: MissionDefinition) -> void:
	_mission = mission


func _ready() -> void:
	%Primary.disabled = _mission == null
	if _mission != null:
		%Section.text = "MISSION BRIEFING  /  %s" % _mission.id
		%Heading.text = _mission.title
		%Details.text = _mission.objective_text
		%Route.text = "%s  →  %s" % [_mission.starting_location, _mission.destination]
		%Budget.text = "%d CR" % _mission.budget_credits
		%Reward.text = "%d CR" % _mission.reward_credits
		%Projection.show_mission(_mission.id)
		%Primary.grab_focus()
	%Primary.pressed.connect(func() -> void: build_requested.emit())
	%Secondary.pressed.connect(func() -> void: back_requested.emit())
