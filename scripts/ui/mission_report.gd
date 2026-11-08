extends Control

signal retry_requested
signal menu_requested
signal next_requested(id: String)

var _result: MissionResult
var _is_sandbox: bool = false
var _next: MissionDefinition
var _save_notice := ""
var _scan: Tween


func setup(result: MissionResult, is_sandbox: bool = false, next: MissionDefinition = null, save_notice: String = "") -> void:
	_result = result
	_is_sandbox = is_sandbox
	_next = next
	_save_notice = save_notice


func _ready() -> void:
	%Primary.disabled = _result == null
	%Next.visible = _next != null
	if _next != null:
		%Next.text = "Next · " + _next.title
	if _result != null:
		if _is_sandbox:
			_render_sandbox()
		else:
			_render_result()
	%Primary.pressed.connect(func() -> void: retry_requested.emit())
	%Secondary.pressed.connect(func() -> void: menu_requested.emit())
	%Next.pressed.connect(func() -> void: next_requested.emit(_next.id))
	%ReplayFact.pressed.connect(_replay_fact)
	%LogButton.toggled.connect(_toggle_log)


func _render_sandbox() -> void:
	%Heading.text = "Mock flight report"
	%Stamp.text = "SIMULATED RECORD"
	_set_heading_color(&"WarningLabel")
	%Details.text = "%s\n%s\n\nSample altitude: %.1f km\nSample speed: %.0f m/s\nSample time: %.1f s\n\nSimulated data · No mission evaluated, score, or reward." % [
		_result.mission_id, _result.reason, _result.max_altitude_m / 1000.0,
		_result.peak_speed_mps, _result.flight_time_s,
	]
	%Primary.text = "Retry sandbox"


func _render_result() -> void:
	var success := _result.outcome == MissionResult.Outcome.SUCCESS
	var accent := Color("#8ee8bd") if success else Color("#ff9984")
	%Heading.text = "Mission success" if success else "Mission failed"
	_set_heading_color(&"SuccessLabel" if success else &"ErrorLabel")
	%Eyebrow.text = "APOGEE   /   FLIGHT RECORDER   /   " + _result.mission_id
	%Stamp.text = "[ OBJECTIVE MET ]" if success else "[ ATTEMPT CLOSED ]"
	%Stamp.modulate = accent
	%Details.text = _result.reason
	%LogButton.show()
	%Stats.show()
	%Stats.text = "ALT MAX  %.1f km     SPEED MAX  %.0f m/s\nTIME     %.1f s      STAGES     %d\nBURNED   %.1f kg     FUEL LEFT  %.1f kg\nCOST     %d CR" % [
		_result.max_altitude_m / 1000.0, _result.peak_speed_mps, _result.flight_time_s, _result.stages_used,
		_result.fuel_used_kg, _result.fuel_remaining_kg, _result.launch_cost_credits,
	]
	if not _result.contact_body_id.is_empty():
		%Stats.text += "\nCONTACT  V %.1f m/s · H %.1f m/s · %.1f° tilt" % [
			_result.touchdown_vertical_mps, _result.touchdown_horizontal_mps, _result.touchdown_tilt_deg,
		]
	var messages: Array[String] = []
	if not _result.advice.is_empty():
		messages.append(_result.advice)
	if _result.awarded_credits > 0:
		messages.append("+%d Agency Credits" % _result.awarded_credits)
	if not _save_notice.is_empty():
		messages.append(_save_notice)
	%Advice.text = "\n".join(messages)
	%Advice.visible = not messages.is_empty()
	_render_discovery()
	%Display.configure(_result.mission_id, accent)
	_render_fact()
	%Score.show()
	%ScoreLabel.text = "FLIGHT SCORE  /  %02d OF 100" % _result.score
	%ScoreLabel.modulate = accent
	%ScoreMeter.modulate = accent
	var arrival := create_tween().set_parallel(true)
	%Stamp.modulate.a = 0.0
	arrival.tween_property(%Stamp, "modulate:a", 1.0, 0.22)
	arrival.tween_property(%ScoreMeter, "value", float(_result.score), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _render_fact() -> void:
	var facts := JsonData.read_object("res://data/mission_facts.json")
	var record: Dictionary = facts.get(_result.mission_id, {})
	if record.is_empty():
		return
	%FactTitle.text = record.title
	%FactText.text = record.fact
	%FactSource.text = record.source
	%FactSource.uri = record.url
	%FactSlot.show()
	_replay_fact()


func _replay_fact() -> void:
	if _scan != null:
		_scan.kill()
	%Display.progress = 0.0
	%FactLabel.text = "DECODING TRANSMISSION"
	%FactTitle.modulate.a = 0.0
	%FactText.visible_ratio = 0.0
	_scan = create_tween().set_parallel(true)
	_scan.tween_property(%Display, "progress", 1.0, 2.35).set_trans(Tween.TRANS_SINE)
	_scan.tween_property(%FactTitle, "modulate:a", 1.0, 0.25).set_delay(0.3)
	_scan.tween_property(%FactText, "visible_ratio", 1.0, 0.8).set_delay(0.5)
	_scan.chain().tween_callback(func() -> void: %FactLabel.text = "ARCHIVE TRANSMISSION")


func _toggle_log(open: bool) -> void:
	%Log.visible = open
	%LogButton.text = "Close log" if open else "Flight log"


func _render_discovery() -> void:
	if _result.discovery_ids.is_empty():
		return
	var discoveries := JsonData.read_object("res://data/discoveries.json")
	var record: Dictionary = discoveries.get(_result.discovery_ids[0], {})
	if record.is_empty():
		return
	%Discovery.show()
	%Stamp.text += "   ·   DISCOVERY UNLOCKED"
	var title := "DISCOVERY  /  " + String(record.title)
	%DiscoveryText.text = "%s\n%s" % [title, record.fact]
	if record.has("subtitle"):
		%DiscoveryText.text += "\n%s\n“%s”" % [record.speaker, record.subtitle]
		%AstronautFrame.show()
		%Astronaut.play("wave")
	%Source.visible = record.has("source_url")
	%Source.uri = String(record.get("source_url", ""))


func _set_heading_color(variation: StringName) -> void:
	%Heading.add_theme_color_override("font_color", get_theme_color("font_color", variation))
