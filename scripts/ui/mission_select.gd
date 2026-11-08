extends Control

signal build_requested
signal back_requested

var _mission: MissionDefinition


func setup(mission: MissionDefinition) -> void:
	_mission = mission


func _ready() -> void:
	preload("res://scripts/ui/console_button.gd").apply(%Primary, "primary")
	preload("res://scripts/ui/console_button.gd").apply(%Secondary)
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
	_unfold_panel.call_deferred()


func _unfold_panel() -> void:
	var panel := %BriefingPanel
	panel.pivot_offset = Vector2(0, panel.size.y)
	panel.scale.y = 0.92
	panel.modulate.a = 0.3
	var unfold := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	unfold.tween_property(panel, "scale:y", 1.0, 0.28)
	unfold.tween_property(panel, "modulate:a", 1.0, 0.22)
	var glass := %BriefingGlass.material as ShaderMaterial
	unfold.tween_method(func(value: float) -> void: glass.set_shader_parameter("reveal", value), 0.0, 1.0, 0.28)
