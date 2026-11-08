extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := root.get_node("GameManager")
	var tutorial := root.get_node("TutorialManager")
	game.completed_missions.clear()
	game.show_main_menu()
	await _settle()
	_check(current_scene.get_node_or_null("%Tutorial") != null, "Main menu exposes the guided tutorial.")
	current_scene.get_node("%Tutorial").pressed.emit()
	await _settle()
	_check(tutorial.active and current_scene.name == "RocketBuilder", "Tutorial opens Rocket Lab without selecting a campaign mission.")
	_check(game.selected_mission_id == "TUTORIAL", "Tutorial uses its isolated mission definition.")
	_check(_overlay(tutorial).visible, "Persistent tutorial overlay is visible.")
	_check(_overlay(tutorial).get_node("%DimTop").mouse_filter == Control.MOUSE_FILTER_STOP, "Tutorial dimmers block off-target input.")

	_next(tutorial)
	await _settle()
	_check(_step(tutorial) == "open_pods", "Welcome advances to the first interactive builder step.")
	current_scene.find_child("Pods", true, false).pressed.emit()
	await _settle()
	_check(_step(tutorial) == "fit_pod", "Opening Pods advances to the pod drag step.")
	var pod_card := current_scene.find_child("POD_A", true, false) as Control
	_check(pod_card != null and pod_card.mouse_filter == Control.MOUSE_FILTER_STOP, "The highlighted pod remains draggable.")
	_check(not _overlay(tutorial).get_node("%FocusBlocker").visible, "Drag steps leave the source and rocket drop area interactive.")
	_check(_overlay(tutorial).get_node("%Card").mouse_filter == Control.MOUSE_FILTER_IGNORE, "The tutorial card background cannot intercept a drag.")
	var builder := current_scene as BuilderController
	var preview := current_scene.get_node("%RocketPreview")
	_check(builder.install_part("pod", "POD_A"), "Tutorial pod can be installed.")
	preview.part_dropped.emit("pod", "POD_A")
	await _settle()
	current_scene.find_child("Fuel", true, false).pressed.emit()
	await _settle()
	_check(builder.install_part("tank", "TANK_L"), "Tutorial tank can be installed.")
	preview.part_dropped.emit("tank", "TANK_L")
	await _settle()
	current_scene.find_child("Engines", true, false).pressed.emit()
	await _settle()
	_check(builder.install_part("engine", "ENG_L"), "Tutorial engine can be installed.")
	preview.part_dropped.emit("engine", "ENG_L")
	await _settle()
	_check(_step(tutorial) == "builder_metrics", "All required drag steps reach the engineering explanation.")
	_check(_overlay(tutorial).get_node("%Body").text.contains("Delta-v"), "Builder tutorial explains delta-v and engineering metrics.")
	_next(tutorial)
	await _settle()
	_check(not current_scene.get_node("%Primary").disabled, "Guided rocket is valid before preparation.")
	current_scene.get_node("%Primary").pressed.emit()
	await _settle()
	_check(current_scene.name == "LaunchpadPreview" and _step(tutorial) == "preflight_review", "Prepare Launch advances the tutorial across scenes.")
	_check(_overlay(tutorial).get_node("%FocusBlocker").visible, "Informational focus areas cannot pass clicks through.")
	_next(tutorial)
	await _settle()
	current_scene.find_child("LaunchButton", true, false).pressed.emit()
	await _settle()
	_check(current_scene.name == "Flight" and _step(tutorial) == "orbit_map", "Launch opens the guided flight deck.")
	_check(_overlay(tutorial).visible and _overlay(tutorial).get_node("%Title").text == "Orbit is continuous free fall", "Flight-deck tutorial content binds after the simulation scene is ready.")
	var telemetry: FlightTelemetry = current_scene.get("_simulator").get_telemetry()
	_check(telemetry.has_bound_orbit and telemetry.periapsis_altitude_m > 100000.0, "Guided flight starts in a safe bound Earth orbit.")
	_next(tutorial)
	await _settle()
	_check(_overlay(tutorial).get_node("%Body").text.contains("Apogee") and _overlay(tutorial).get_node("%Body").text.contains("perigee"), "Orbit tutorial explains apogee and perigee.")
	_next(tutorial)
	await _settle()
	current_scene.get_node("%EngineButton").pressed.emit()
	await _settle()
	_check(_step(tutorial) == "adjust_throttle", "Ignition advances to throttle control.")
	var throttle := current_scene.get_node("%Throttle") as VSlider
	throttle.value = 55.0
	await _settle()
	_check(_step(tutorial) == "steering", "Moving throttle advances to steering guidance.")
	_next(tutorial)
	await _settle()
	current_scene.get_node("%EngineButton").pressed.emit()
	await _settle()
	current_scene.get_node("%Warp5").pressed.emit()
	await _settle()
	_check(is_equal_approx(current_scene.get_time_warp(), 5.0), "Tutorial demonstrates 5x time warp after cutoff.")
	current_scene.get_node("%PauseFlight").pressed.emit()
	await _settle()
	current_scene.get_node("%PauseFlight").pressed.emit()
	await _settle()
	_check(_step(tutorial) == "mission_parameters", "Pause and resume lead to mission-parameter guidance.")
	_next(tutorial)
	await _settle()
	_check(_step(tutorial) == "complete", "Tutorial reaches its completion summary.")
	_next(tutorial)
	await _settle()
	_check(not tutorial.active and tutorial.completed and current_scene.name == "MainMenu", "Finishing records completion and returns to the star chart.")
	_check(not game.completed_missions.has("TUTORIAL"), "Tutorial completion does not alter campaign mission progress.")

	current_scene.get_node("%Tutorial").pressed.emit()
	await _settle()
	_overlay(tutorial).get_node("%Exit").pressed.emit()
	await _settle()
	_check(not tutorial.active and current_scene.name == "MainMenu", "Exit Tutorial safely returns to the main menu at any time.")

	if _failures == 0:
		print("Tutorial flow tests passed.")
	quit(0 if _failures == 0 else 1)


func _overlay(tutorial: Node) -> TutorialOverlay:
	return tutorial.get_node("TutorialOverlay") as TutorialOverlay


func _step(tutorial: Node) -> String:
	var steps: Array = tutorial.get("_steps")
	return String(steps[int(tutorial.get("_index"))].id)


func _next(tutorial: Node) -> void:
	_overlay(tutorial).get_node("%Next").pressed.emit()


func _settle() -> void:
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
