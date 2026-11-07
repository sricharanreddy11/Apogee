extends Control

signal report_requested(result: MissionResult)
signal back_requested
signal menu_requested

var _mission: MissionDefinition
var _latest: FlightTelemetry
var _max_altitude_m: float = 0.0
var _peak_speed_mps: float = 0.0

@onready var _mock: MockTelemetry = %MockTelemetry


func setup(mission: MissionDefinition) -> void:
	_mission = mission


func _ready() -> void:
	# F6 can run this scene directly, without navigating through GameManager first.
	if _mission == null:
		var catalog := MissionCatalog.new()
		_mission = catalog.load_mission("M01")
		if _mission == null:
			_show_error(catalog.last_error)
			return
	%Heading.text = "%s / %s · UI sandbox" % [_mission.id, _mission.title]
	%Details.text = _mission.objective_text
	_mock.telemetry_updated.connect(_on_telemetry)
	%Primary.pressed.connect(_open_sample_report)
	%Pause.pressed.connect(_toggle_pause)
	%Restart.pressed.connect(_restart)
	%Secondary.pressed.connect(_back)
	%MainMenu.pressed.connect(_menu)
	if not _mock.initialize(_mission.scenario):
		_show_error(_mock.last_error)
		return
	_update_playback_note()


func _on_telemetry(telemetry: FlightTelemetry) -> void:
	_latest = telemetry
	_max_altitude_m = maxf(_max_altitude_m, telemetry.altitude_m)
	_peak_speed_mps = maxf(_peak_speed_mps, telemetry.speed_mps)
	%HUD.update_from_telemetry(telemetry)
	%FuelBar.value = clampf(telemetry.fuel_fraction, 0.0, 1.0) * 100.0
	if is_node_ready():
		_update_playback_note()


func _update_playback_note() -> void:
	var state := "Playing"
	if _mock.paused:
		state = "Paused"
	elif _latest != null and _latest.elapsed_time_s >= _mock.total_duration_s:
		state = "Sample finished · Restart to replay"
	%Playback.text = "%s  |  %.1f× playback  |  %.0f s sample" % [
		state, _mock.playback_speed, _mock.total_duration_s,
	]


func _toggle_pause() -> void:
	_mock.paused = not _mock.paused
	%Pause.text = "Resume" if _mock.paused else "Pause"
	_update_playback_note()


func _restart() -> void:
	_max_altitude_m = 0.0
	_peak_speed_mps = 0.0
	_mock.paused = false
	%Pause.text = "Pause"
	_mock.restart()
	_update_playback_note()


func _open_sample_report() -> void:
	if _latest == null:
		return
	var result := MissionResult.new()
	result.mission_id = _mission.id
	result.reason = "UI preview from scripted telemetry."
	result.flight_time_s = _latest.elapsed_time_s
	result.max_altitude_m = _max_altitude_m
	result.peak_speed_mps = _peak_speed_mps
	# The sample never changes the real mission outcome or awards progression.
	if report_requested.get_connections().is_empty():
		# Direct F6 runs have no selected mission in GameManager. Return here on Retry.
		GameManager.show_report(result, true)
	else:
		report_requested.emit(result)


func _back() -> void:
	if back_requested.get_connections().is_empty():
		GameManager.show_main_menu()
	else:
		back_requested.emit()


func _menu() -> void:
	if menu_requested.get_connections().is_empty():
		GameManager.show_main_menu()
	else:
		menu_requested.emit()


func _show_error(message: String) -> void:
	_mock.set_process(false)
	%Details.text = "Sandbox could not start: %s" % message
	%Primary.disabled = true
	%Pause.disabled = true
	%Restart.disabled = true
	if not %Secondary.pressed.is_connected(_back):
		%Secondary.pressed.connect(_back)
	if not %MainMenu.pressed.is_connected(_menu):
		%MainMenu.pressed.connect(_menu)
