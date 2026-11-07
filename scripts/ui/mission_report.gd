extends Control

signal retry_requested
signal menu_requested

var _result: MissionResult
var _is_sandbox: bool = false


func setup(result: MissionResult, is_sandbox: bool = false) -> void:
	_result = result
	_is_sandbox = is_sandbox


func _ready() -> void:
	%Primary.disabled = _result == null
	if _result != null:
		match _result.outcome:
			MissionResult.Outcome.SUCCESS:
				%Heading.text = "Mission success"
				%Heading.add_theme_color_override("font_color", get_theme_color("font_color", &"SuccessLabel"))
				%Details.text = _result.reason
			MissionResult.Outcome.FAILURE:
				%Heading.text = "Mission failed"
				%Heading.add_theme_color_override("font_color", get_theme_color("font_color", &"ErrorLabel"))
				%Details.text = _result.reason
			MissionResult.Outcome.IN_PROGRESS:
				%Details.text = "%s preview. No result recorded." % _result.mission_id
		if _is_sandbox:
			%Heading.text = "Mock flight report"
			%Heading.add_theme_color_override("font_color", get_theme_color("font_color", &"WarningLabel"))
			%Details.text = "%s\n%s\n\nSample altitude: %.1f km\nSample speed: %.0f m/s\nSample time: %.1f s\n\nSimulated data · No mission evaluated, score, or reward." % [
				_result.mission_id, _result.reason, _result.max_altitude_m / 1000.0,
				_result.peak_speed_mps, _result.flight_time_s,
			]
			%Primary.text = "Retry sandbox"
	%Primary.pressed.connect(func() -> void: retry_requested.emit())
	%Secondary.pressed.connect(func() -> void: menu_requested.emit())
