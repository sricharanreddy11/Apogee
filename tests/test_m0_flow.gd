extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := root.get_node_or_null("GameManager")
	_check(game != null, "GameManager autoload is available.")
	if game == null:
		quit(1)
		return
	game.show_main_menu()
	await _settle()
	if not await _press("%Sandbox", "UISandbox"):
		return
	_check(game.get_selected_mission().budget_credits == 2000, "Mission budget comes from JSON.")
	_check(game.selected_mission_id == "M01", "Sandbox preserves the selected mission.")
	_check(game.current_rocket_config == null, "Sandbox starts without a builder or rocket.")
	var mock := current_scene.get_node("%MockTelemetry") as MockTelemetry
	mock.set_process(false)
	current_scene.get_node("%Restart").pressed.emit()
	var initial_hud: String = current_scene.get_node("%HUD").text
	mock.step(2.0)
	_check(current_scene.get_node("%HUD").text != initial_hud, "HUD responds to changing mock telemetry.")
	_check(current_scene.get_node("%HUD").text.contains("5.0 km"), "HUD converts 5000 meters to 5.0 km.")
	_check(current_scene.get_node("%HUD").text.contains("Stage 1"), "HUD converts stage index 0 to Stage 1.")
	_check(is_equal_approx(current_scene.get_node("%FuelBar").value, 85.0), "Fuel bar shows 85 percent.")
	current_scene.get_node("%Pause").pressed.emit()
	var frozen_time := mock.get_telemetry().elapsed_time_s
	mock.step(2.0)
	_check(mock.get_telemetry().elapsed_time_s == frozen_time, "Pause freezes the mock clock.")
	current_scene.get_node("%Pause").pressed.emit()
	mock.step(1000.0)
	_check(mock.get_telemetry().elapsed_time_s == 60.0, "Sample holds at 60 simulation seconds.")
	_check(current_scene.name == "UISandbox", "Mock target altitude does not trigger real mission success.")
	if not await _press("%Primary", "MissionReport"):
		return
	_check(game.last_result.outcome == MissionResult.Outcome.IN_PROGRESS, "Sample report is explicitly not a mission outcome.")
	_check(game.last_result.awarded_credits == 0 and game.last_result.score == 0, "Demo never awards credits or a score.")
	_check(game.last_result.max_altitude_m == 100000.0, "Report receives the measured mock maximum.")
	_check(current_scene.get_node("%Heading").text == "Mock flight report", "Report labels the simulated data.")
	if not await _press("%Primary", "UISandbox"):
		return
	mock = current_scene.get_node("%MockTelemetry") as MockTelemetry
	mock.set_process(false)
	_check(mock.get_telemetry().elapsed_time_s < 1.0, "Retry creates a fresh clock.")
	_check(game.last_result == null, "Retry clears the old report.")
	if not await _press("%Secondary", "MainMenu"):
		return

	# Run the sandbox on its own, like F6 in the editor, with no session selection.
	game.selected_mission_id = ""
	game.set("_mission", null)
	_check(change_scene_to_file("res://scenes/ui/ui_sandbox.tscn") == OK, "Sandbox opens directly.")
	await _settle()
	_check(current_scene.get_node("%HUD").text.contains("Altitude"), "Direct sandbox loads M01 and feeds the HUD.")
	if not await _press("%Primary", "MissionReport"):
		return
	_check(game.selected_mission_id == "M01", "Direct report establishes the session for Retry.")
	if not await _press("%Primary", "UISandbox"):
		return
	if not await _press("%MainMenu", "MainMenu"):
		return

	# A broken demo file must leave useful diagnostics and working navigation.
	var broken: Node = load("res://scenes/ui/ui_sandbox.tscn").instantiate()
	broken.get_node("%MockTelemetry").sample_path = "res://data/mocks/missing.json"
	_check(change_scene_to_node(broken) == OK, "Invalid-data sandbox can be opened safely.")
	await _settle()
	_check(current_scene.get_node("%Details").text.contains("Cannot open mock data"), "Broken sample shows a readable error on screen.")
	_check(current_scene.get_node("%Primary").disabled, "Broken sample cannot generate a report.")
	if not await _press("%MainMenu", "MainMenu"):
		return
	if _failures == 0:
		print("Milestone 0 flow tests passed.")
	quit(0 if _failures == 0 else 1)


func _press(path: String, expected: String) -> bool:
	var button := current_scene.get_node_or_null(path) as Button
	if button == null or button.disabled:
		_check(false, "Enabled navigation button %s exists." % path)
		quit(1)
		return false
	button.pressed.emit()
	await _settle()
	var arrived := current_scene != null and current_scene.name == expected
	_check(arrived, "Navigate to %s." % expected)
	if not arrived:
		quit(1)
	return arrived


func _settle() -> void:
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error(description)
