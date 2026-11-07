extends Control

signal retry_requested
signal menu_requested

var _result: MissionResult


func setup(result: MissionResult) -> void:
	_result = result


func _ready() -> void:
	if _result != null:
		match _result.outcome:
			MissionResult.Outcome.SUCCESS:
				%Heading.text = "Mission success"
				%Details.text = _result.reason
			MissionResult.Outcome.FAILURE:
				%Heading.text = "Mission failed"
				%Details.text = _result.reason
			MissionResult.Outcome.IN_PROGRESS:
				%Details.text = "%s preview. No result recorded." % _result.mission_id
	%Primary.pressed.connect(func() -> void: retry_requested.emit())
	%Secondary.pressed.connect(func() -> void: menu_requested.emit())
