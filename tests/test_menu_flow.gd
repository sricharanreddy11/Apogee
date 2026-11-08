extends SceneTree

var _failures: int = 0
var _launch_requests: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := root.get_node("GameManager")
	game.completed_missions.clear()
	game.best_scores.clear()
	game.agency_credits = 0
	game.show_main_menu()
	await _settle()
	_check(current_scene.name == "MainMenu", "T01: Game opens on the mission-selecting main menu.")
	_check(current_scene.get_node_or_null("%RocketTurntable") == null, "Mission Control omits the Vehicle/Live panel.")
	_check(current_scene.find_child("HeaderGlass", true, false) == null, "Settings icon has no surrounding glass box.")
	_check(current_scene.get_node("%Settings").get_theme_stylebox("focus") is StyleBoxEmpty, "Settings icon has no focus border.")
	var signal_style := current_scene.get_node("%SignalHousing").get_theme_stylebox("panel") as StyleBoxFlat
	_check(signal_style.content_margin_left >= 30.0 and signal_style.content_margin_top >= 18.0, "Mission Control briefing box has comfortable inner padding.")
	_check(current_scene.get_node_or_null("%SignalGlass") == null, "Mission Control briefing box uses the clean mission-card treatment.")
	_check(current_scene.get_node("%MissionList").get_child_count() == 4, "M01 through M04 have data-backed beacons.")
	for id: String in ["M01", "M02", "M03", "M04"]:
		var card := _card(id)
		_check(card != null, "%s is visible." % id)
		_check(not card.get_node("%SelectButton").disabled if id == "M01" else card.get_node("%SelectButton").disabled,
			"Initial unlock state for %s." % id)
	_card("M02").get_node("%SelectButton").mouse_entered.emit()
	_check(current_scene.get_node("%SignalDetails").text == "Complete First Flight to unlock", "A locked beacon previews its prerequisite.")
	_card("M02").get_node("%SelectButton").pressed.emit()
	await _settle()
	_check(current_scene.name == "MainMenu", "T03: A locked card cannot navigate even if pressed is emitted.")
	game.agency_credits = 100000
	_check(not game.is_mission_unlocked("M02"), "Agency credits cannot unlock a mission.")
	_check(not game.select_mission("M02"), "Navigation API also rejects locked missions.")
	_check(current_scene.name == "MainMenu", "Direct locked selection stays in the menu.")
	_check(not game.select_mission("not_a_mission"), "Unknown mission is rejected.")
	_check(not current_scene.get_node("%ErrorMessage").text.is_empty(), "Menu shows readable navigation errors.")
	game.agency_credits = 0
	_card("M01").get_node("%SelectButton").pressed.emit()
	await _settle()
	_check(current_scene.name == "MissionBriefing", "T02: M01 opens the briefing before the builder.")
	var briefing_style := current_scene.get_node("%BriefingPanel").get_theme_stylebox("panel") as StyleBoxFlat
	_check(briefing_style.content_margin_left >= 30.0 and briefing_style.content_margin_top >= 26.0, "Mission description and build card has comfortable inner padding.")
	_check(current_scene.get_node_or_null("%BriefingGlass") == null, "Mission description uses the clean mission-card treatment.")
	_check(game.selected_mission_id == "M01", "Selected mission survives navigation.")
	_check(current_scene.get_node("%Details").text.contains("100 km"), "Briefing shows the mission objective.")
	_check(current_scene.get_node("%Route").text.contains("Earth surface"), "Briefing shows the mission route.")
	_check(current_scene.get_node("%Budget").text == "2000 CR", "Briefing shows the budget before building.")
	_check(current_scene.get_node("%Reward").text == "1000 CR", "Briefing shows the reward before building.")
	var projection := current_scene.get_node("%Projection")
	var track := projection.get_node("%AnimationPlayer") as AnimationPlayer
	var ascent := projection.get_node("ProjectionWorld/M01") as Node2D
	var orbit := projection.get_node("ProjectionWorld/M02") as Node2D
	_check(ascent.visible and not orbit.visible, "First Flight displays only the ascent projection.")
	track.seek(2.0, true)
	_check(ascent.get_node("FlightTrack/Traveler").progress_ratio > 0.0, "The animation moves the probe along the authored path.")
	_check(projection.get_node_or_null("%Replay") == null, "The automatic projection has no replay button.")
	_check(game.current_rocket_config == null, "Reading the briefing does not confirm a rocket.")
	current_scene.get_node("%Secondary").pressed.emit()
	await _settle()
	_check(current_scene.name == "MainMenu", "Briefing can return to the mission list.")
	_card("M01").get_node("%SelectButton").pressed.emit()
	await _settle()
	current_scene.get_node("%Primary").pressed.emit()
	await _settle()
	_check(current_scene.name == "RocketBuilder", "Build rocket opens Rocket Lab from the briefing.")
	_check(current_scene.get_node("%BudgetValue").text.contains("2000"), "T04: Builder keeps the selected budget visible.")
	var draft_name := current_scene.get_node("%RocketName") as LineEdit
	draft_name.text = "Briefing draft"
	draft_name.text_changed.emit(draft_name.text)
	current_scene.get_node("%RocketPreview").part_removed.emit("tank")
	current_scene.get_node("%Secondary").pressed.emit()
	await _settle()
	_check(current_scene.name == "MissionBriefing", "The builder returns to the same mission briefing.")
	_check(game.current_rocket_config == null, "An incomplete draft is not treated as a confirmed rocket.")
	current_scene.get_node("%Primary").pressed.emit()
	await _settle()
	_check(current_scene.build_config().rocket_name == "Briefing draft", "Reopening the builder preserves the draft name.")
	_check(current_scene.build_config().stages[0].tank_ids.is_empty(), "Reopening the builder preserves an incomplete draft.")
	current_scene.get_node("%Reset").pressed.emit()
	var builder := current_scene as BuilderController
	var config := builder.build_config()
	var missing_engine := config.copy()
	missing_engine.stages[0].engine_id = ""
	_check(not game.prepare_launch(missing_engine), "T05: Missing engine blocks preparation.")
	_check(current_scene.name == "RocketBuilder", "Invalid rocket stays in builder.")
	var expensive := config.copy()
	expensive.stages[0].tank_ids.append("TANK_L")
	_check(not game.prepare_launch(expensive), "T06: Over-budget build cannot reach the pad.")
	_check(not game.prepare_launch(null), "Null handoff cannot reach the pad.")
	var wrong_type := config.copy()
	wrong_type.command_pod_id = "ENG_L"
	_check(not game.prepare_launch(wrong_type), "Wrong part type cannot bypass validation.")
	var missing_stage := config.copy()
	missing_stage.stages[0] = null
	_check(not game.prepare_launch(missing_stage), "Missing stage is rejected without a copy error.")
	var malformed_pad: Node = load("res://scenes/flight/launchpad_preview.tscn").instantiate()
	_check(not malformed_pad.setup(game.get_selected_mission(), missing_stage), "Preflight setup also rejects a missing stage safely.")
	malformed_pad.free()
	# Reconfirm the valid current design through the real builder signal handler.
	current_scene.get_node("%RocketName").text = "My Sparrow"
	current_scene.get_node("%Primary").pressed.emit()
	await _settle()
	_check(current_scene.name == "LaunchpadPreview", "T07/T08: Prepare Launch opens preflight.")
	_check(game.current_rocket_config.rocket_name == "My Sparrow", "Confirmed config is stored before scene change.")
	var pad := current_scene
	var rocket: Node = pad.get_node("%RocketPreview")
	_check(rocket.get_config().command_pod_id == "POD_A", "T09: Preview uses the configured pod.")
	_check(rocket.get_config().stages[0].tank_ids[0] == "TANK_L", "Preview uses the actual configured tank.")
	var panel := pad.get_node("%PreflightPanel")
	_check(panel.get_node("%MissionName").text.contains("First Flight"), "Preflight shows selected mission.")
	_check(panel.get_node("%RocketName").text == "My Sparrow", "Preflight shows chosen rocket name.")
	_check(panel.get_node("%CostLabel").text.contains("1600 / 2000"), "Preflight uses calculated cost and mission budget.")
	_check(not panel.get_node("%LaunchButton").disabled, "Valid rocket is ready to launch.")
	_check(pad.session_phase == 0, "Rocket starts in preflight, with no automatic launch.")
	panel.get_node("%EditRocketButton").pressed.emit()
	await _settle()
	_check(current_scene.name == "RocketBuilder", "T10: Edit Rocket returns to builder.")
	_check(current_scene.build_config().rocket_name == "My Sparrow", "Edit preserves the chosen rocket name.")
	_check(current_scene.build_config().stages[0].tank_ids[0] == "TANK_L", "Edit preserves the assembled parts.")
	# A caller cannot mutate the stored design through a detached builder result.
	var detached: RocketConfig = current_scene.build_config()
	detached.stages[0].tank_ids.clear()
	_check(current_scene.build_config().stages[0].tank_ids.size() == 1, "Builder returns a detached config.")
	current_scene.get_node("%Primary").pressed.emit()
	await _settle()
	pad = current_scene
	game.flight_launch_requested.connect(_on_launch)
	pad.get_node("%PreflightPanel").get_node("%LaunchButton").pressed.emit()
	await _settle()
	_check(_launch_requests == 1, "Launch reaches the agreed integration signal once.")
	_check(current_scene.name == "Flight", "Launch opens the authoritative flight simulation.")
	_check(current_scene.get_node("%FlightArtwork") != null and current_scene.get_node("%Map") != null, "Flight provides normal and orbit views.")
	_check(current_scene.get_node("%Warp1") != null and current_scene.get_node("%Warp50") != null, "Flight exposes the 1x through 50x simulation controls.")
	current_scene._set_time_warp(50.0)
	_check(is_equal_approx(current_scene.get_time_warp(), 50.0), "The 50x control selects a true simulation multiplier.")
	var orbit_map := current_scene.get_node("%Map") as OrbitMap
	orbit_map.pan_by_screen_delta(Vector2(30.0, -20.0))
	_check(not orbit_map.get_pan_offset_m().is_zero_approx(), "Orbit view can pan away from the active body.")
	orbit_map.reset_camera()
	_check(orbit_map.get_pan_offset_m().is_zero_approx(), "Orbit view can recenter on the active body.")
	current_scene.get_node("%EndFlight").pressed.emit()
	await _settle()
	_check(current_scene.name == "MissionReport", "Ending flight opens the mission report.")
	current_scene.get_node("%Secondary").pressed.emit()
	await _settle()
	_check(current_scene.name == "MainMenu", "T11: Missions returns to the menu safely.")
	_check(game.selected_mission_id == "M01", "Returning to menu retains selected mission.")
	game.completed_missions.assign(["M01"])
	game.best_scores["M01"] = 84
	game.show_main_menu()
	await _settle()
	_check(_card("M01").get_node("%StatusLabel").text.contains("COMPLETED"), "T12: Completed card shows completion.")
	_check(not _card("M01").get_node("%SelectButton").disabled, "Completed missions remain replayable.")
	_check(not _card("M02").get_node("%SelectButton").disabled, "Completing M01 unlocks M02.")
	_check(_card("M03").get_node("%SelectButton").disabled, "Lunar missions still require M02.")
	game.completed_missions.append("M02")
	_check(game.is_mission_unlocked("M03") and game.is_mission_unlocked("M04"), "M02 unlocks both lunar missions.")
	game.completed_missions.assign(["M02"])
	_check(game.is_mission_unlocked("M02"), "An already completed mission stays replayable.")
	# The UI milestone must not actually award campaign progress.
	_check(game.agency_credits == 0, "Preview flights never award agency credits.")
	if _failures == 0:
		print("Milestone 1 menu flow tests passed.")
	quit(0 if _failures == 0 else 1)


func _card(id: String) -> Node:
	return current_scene.get_node("%MissionList").get_node_or_null(id)


func _on_launch(_config: RocketConfig, _mission_id: String) -> void:
	_launch_requests += 1


func _settle() -> void:
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
