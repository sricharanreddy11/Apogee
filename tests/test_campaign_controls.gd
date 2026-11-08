extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var game := root.get_node("GameManager")
	var tutorial := root.get_node("TutorialManager")
	var save: CampaignSave = game._campaign_save
	var original_path := save.path
	var original_tutorial_path: String = tutorial.progress_path
	var prefix := "user://campaign-controls-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	save.path = prefix + ".json"
	tutorial.progress_path = prefix + "-tutorial.json"
	game.agency_credits = 5500
	game.completed_missions.assign(["M01"])
	game.best_scores = {"M01": 85}
	game.discovered_ids.assign(["SPACE_BOUNDARY"])
	game.mod_enabled = false
	tutorial.completed = true
	check(tutorial._save_progress() == OK, "Tutorial fixture uses its own save path.")
	check(save.save_progress(game._campaign_progress()) == OK, "Campaign fixture uses its own save path.")
	game.show_main_menu()
	await settle()
	check(current_scene.get_node("%ResetCampaign").text == "Reset", "The mission menu exposes Reset.")
	check(current_scene.get_node("%ModCampaign").text == "Mod", "The mission menu exposes Mod.")
	current_scene.get_node("%ResetCampaign").pressed.emit()
	await settle()
	check(current_scene.get_node("%ResetDialog").visible, "Reset first shows a confirmation.")
	check(game.agency_credits == 5500 and game.completed_missions == ["M01"], "Opening Reset does not erase progress.")
	current_scene.get_node("%ResetDialog").canceled.emit()
	current_scene.get_node("%ResetDialog").hide()
	check(game.agency_credits == 5500, "Canceling Reset keeps the campaign.")
	await snapshot("normal-menu")
	current_scene.get_node("%ModCampaign").pressed.emit()
	await settle()
	check(game.mod_enabled and game.agency_credits == 1000000, "Mod grants one million credits and activates its separate unlock flag.")
	check(game.completed_missions == ["M01"] and game.best_scores == {"M01": 85}, "Mod preserves genuine completions and scores.")
	check(game.discovered_ids == ["SPACE_BOUNDARY"], "Mod does not fabricate discoveries.")
	check(current_scene.get_node("%AgencyCredits").text == "1000000 CR", "The displayed reserve updates immediately.")
	check(current_scene.get_node("%ModCampaign").disabled and current_scene.get_node("%ModCampaign").text == "Mod: ON", "The menu visibly marks active Mod mode.")
	for id: String in ["M01", "M02", "M03", "M04"]:
		check(game.is_mission_unlocked(id) and not current_scene.get_mission_card(id).get_node("%SelectButton").disabled, "Mod unlocks the actual mission and its beacon: " + id)
	check(current_scene.get_mission_card("M04").get_node("%StatusLabel").text == "AVAILABLE", "A Mod-unlocked mission is not mislabeled as completed.")
	await snapshot("mod-menu")
	var persisted := save.load_progress()
	check(persisted.mod_enabled and int(persisted.agency_credits) == 1000000, "Mod state and credits are persisted.")
	game.mod_enabled = false
	game.agency_credits = 0
	game._load_campaign_progress()
	check(game.mod_enabled and game.agency_credits == 1000000 and game.is_mission_unlocked("M04"), "Reloading the campaign retains Mod and its unlocks.")
	var full := RocketConfig.new()
	full.command_pod_id = "POD_A"
	full.rocket_name = "Full catalog test"
	full.attachment_ids.assign(["DECOUPLER", "LEGS", "PROBE"])
	for index in 2:
		var stage := StageConfig.new()
		stage.engine_id = "ENG_L"
		stage.tank_ids.assign(["TANK_L", "TANK_L", "TANK_L"])
		full.stages.append(stage)
	check(game.select_mission("M01"), "Mod can select an early mission with expanded build rules.")
	await settle()
	var mission: MissionDefinition = game.get_selected_mission()
	check(mission.budget_credits == 1000000 and mission.allowed_part_ids.is_empty(), "Mod expands real mission budgets and exposes the entire parts catalog.")
	var verifier := BuilderController.new()
	verifier.setup(mission)
	var stats := verifier.calculate(full)
	check(int(stats.cost_credits) == 5750 and game.agency_credits >= int(stats.cost_credits), "Mod credits cover the most expensive legal current two-stage stack.")
	check(verifier.validate(full, mission).valid, "All parts and six tanks validate within the actual Mod mission budget.")
	verifier.free()
	check(MissionCatalog.new().load_mission("M01").budget_credits == 2000, "Mod never edits the mission catalog on disk.")
	game.show_builder()
	await settle()
	check(current_scene.get_node("%Pioneer").visible and current_scene._is_allowed("ENG_V") and current_scene._is_allowed("LEGS"), "The real early-mission builder exposes multi-stage rockets and all part types.")
	check(game.prepare_launch(full), "The real preflight boundary accepts the complete Mod build.")
	await settle()
	check(current_scene.name == "LaunchpadPreview", "Mod applies beyond UI labels and reaches launch control.")
	game.agency_credits = 1500000
	check(game.enable_mod(), "Enabling Mod again remains safe.")
	await settle()
	check(game.agency_credits == 1500000, "Mod never reduces a larger existing reserve.")
	var result := MissionResult.new()
	result.mission_id = "M02"
	result.outcome = MissionResult.Outcome.SUCCESS
	result.score = 90
	game._mission = MissionCatalog.new().load_mission("M02")
	check(game._record_success(result).is_empty(), "Ordinary mission success still saves correctly in Mod mode.")
	check(save.load_progress().mod_enabled, "A later ordinary save does not drop Mod state.")
	game.current_rocket_config = full
	game._builder_draft = full.copy()
	game.selected_mission_id = "M04"
	game.last_result = result
	current_scene.get_node("%ResetCampaign").pressed.emit()
	await settle()
	await snapshot("reset-confirmation")
	current_scene.get_node("%ResetDialog").confirmed.emit()
	await settle()
	check(game.agency_credits == 0 and not game.mod_enabled, "Reset restores zero credits and turns Mod off.")
	check(game.completed_missions.is_empty() and game.best_scores.is_empty() and game.discovered_ids.is_empty(), "Reset clears completions, scores, and discoveries.")
	check(game.current_rocket_config == null and game._builder_draft == null and game.last_result == null and game._mission == null and game.selected_mission_id.is_empty(), "Reset clears confirmed builds, drafts, selected missions, and reports.")
	check(not tutorial.completed and not tutorial.active, "Reset restores the initial tutorial state.")
	tutorial.completed = true
	tutorial._load_progress()
	check(not tutorial.completed, "Tutorial reset survives a reload.")
	for id: String in ["M01", "M02", "M03", "M04"]:
		check(game.is_mission_unlocked(id) == (id == "M01"), "Reset leaves only Level 1 available: " + id)
	check(current_scene.get_node("%AgencyCredits").text == "0 CR" and not current_scene.get_node("%ModCampaign").disabled, "Reset immediately refreshes the reserve and Mod button.")
	await snapshot("reset-menu")
	var primary := FileAccess.open(save.path, FileAccess.WRITE)
	primary.store_string('{"version":0}')
	primary.close()
	persisted = save.load_progress()
	check(not persisted.is_empty() and not persisted.mod_enabled and int(persisted.agency_credits) == 0 and persisted.completed_missions.is_empty(), "A damaged reset save recovers fresh state, not old Mod progress, from its backup.")
	game._load_campaign_progress()
	check(game.is_mission_unlocked("M01") and not game.is_mission_unlocked("M02"), "Backup recovery cannot restore old unlocks after reset.")
	check(game.select_mission("M01"), "Level 1 can still be selected after reset.")
	await settle()
	mission = game.get_selected_mission()
	check(mission.budget_credits == 2000 and not mission.allowed_part_ids.is_empty(), "Reset restores ordinary mission budgets and part restrictions.")
	game.show_main_menu()
	await settle()
	var actual_path := save.path
	save.path = prefix + "/missing/campaign.json"
	game.agency_credits = 777
	check(not game.reset_campaign() and game.agency_credits == 777, "A failed reset save preserves the current session.")
	check(not game.enable_mod() and not game.mod_enabled and game.agency_credits == 777, "A failed Mod save cannot silently change credits or unlocks.")
	check(not current_scene.get_node("%ErrorMessage").text.is_empty(), "Save failures produce a visible menu error.")
	save.path = actual_path
	var legacy := {"agency_credits": 42, "completed_missions": [], "best_scores": {}, "discovered_ids": []}
	check(save.replace_progress(legacy) == OK, "Legacy campaign records can still be saved.")
	game.mod_enabled = true
	game._load_campaign_progress()
	check(not game.mod_enabled and game.agency_credits == 42, "Legacy saves default to ordinary mode.")
	legacy.mod_enabled = "true"
	check(save.replace_progress(legacy) == OK and save.load_progress().is_empty(), "A non-boolean Mod flag is rejected on load.")
	for path: String in [actual_path, actual_path + ".previous", actual_path + ".tmp", actual_path + ".previous.tmp", tutorial.progress_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	save.path = original_path
	tutorial.progress_path = original_tutorial_path
	print("Campaign controls: %d checks, %d failures." % [checks, failures])
	quit(0 if failures == 0 else 1)

func settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func snapshot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var folder := "res://exports/qa/campaign-controls"
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join(label + ".png"))
