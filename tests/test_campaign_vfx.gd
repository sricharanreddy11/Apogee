extends SceneTree
## Run with -- --capture to also verify the real Compatibility renderer.
var _checks := 0
var _failures := 0
var _capture := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	var game := root.get_node("GameManager")
	game.completed_missions.clear()
	game.agency_credits = 0
	game.current_rocket_config = null
	game.show_main_menu()
	await _settle()
	var menu := current_scene
	var hologram := menu.get_node("%CampaignHologram")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(1100, 600)
	motion.global_position = motion.position
	root.push_input(motion, true)
	await create_timer(0.4).timeout
	var deep := menu.get_node("DeepStars").get_parallax_offset() as Vector2
	var dust := menu.get_node("NebulaDust").get_parallax_offset() as Vector2
	var near := menu.get_node("CloseStars").get_parallax_offset() as Vector2
	_check(deep.length() > 0.1 and deep.x < 0, "Cursor movement shifts the background in the opposite direction.")
	_check(deep.length() < dust.length() and dust.length() < near.length(), "Deep stars, dust, and close stars move at progressively faster speeds.")
	_check(absf(near.x) <= 32 and absf(near.y) <= 32, "Parallax movement remains within overscanned coverage.")
	_check(hologram._routes.all(func(route: Dictionary) -> bool: return not route.completed), "Fresh campaigns have no completed-route pulses.")
	_check(menu.get_node("%RocketTurntable").get_config() == null, "An empty hangar never displays a fabricated equipped rocket.")
	for id: String in ["M01", "M02", "M03", "M04"]:
		var card: MissionCard = menu.get_mission_card(id)
		_check(card.get_node("%Beacon").state == ("available" if id == "M01" else "locked"), "Fresh campaign state: " + id)
	await _snapshot("fresh-campaign")

	# Use in-memory progress only. This test never writes the player's campaign save.
	game.completed_missions.assign(["M01", "M02", "M03"])
	var config := RocketConfig.new()
	config.rocket_name = "Pioneer / Survey"
	config.command_pod_id = "POD_A"
	var stage := StageConfig.new()
	stage.engine_id = "ENG_L"
	stage.tank_ids.assign(["TANK_L"])
	config.stages.append(stage)
	config.attachment_ids.assign(["PROBE"])
	game.current_rocket_config = config
	game.show_main_menu()
	await _settle()
	menu = current_scene
	hologram = menu.get_node("%CampaignHologram")
	var preview := menu.get_node("%RocketTurntable")
	var detached: RocketConfig = preview.get_config()
	detached.stages[0].tank_ids.clear()
	_check(preview.get_config().stages[0].tank_ids == ["TANK_L"], "Rocket preview owns a detached copy of the equipped build.")
	_check(preview._rig.height_px > 0, "Equipped parts produce a visible rocket stack.")
	_check(preview._rig.get_meta("config_stages")[0].engine_id == "ENG_L", "The preview renders the real equipped engine.")
	for route: Dictionary in hologram._routes:
		_check(route.completed == (route.id != "M04"), "Only completed branches carry energy: " + route.id)
		var card: MissionCard = menu.get_mission_card(route.id)
		var beacon := card.get_node("%Visual") as Node2D
		var endpoint: Vector2 = hologram.to_global(route.curve.sample_baked(route.curve.get_baked_length()))
		_check(endpoint.distance_to(beacon.global_position) < 0.5, "Projected route and clickable beacon align: " + route.id)
		_check(card.get_node("%Beacon").state == ("available" if route.id == "M04" else "completed"), "Progressed campaign state: " + route.id)
	var earth := menu.get_node("%Earth") as Sprite2D
	var rotation_before := earth.rotation
	await create_timer(0.08).timeout
	_check(earth.rotation > rotation_before, "Earth rotates over time.")
	var card: MissionCard = menu.get_mission_card("M03")
	card.get_node("%SelectButton").mouse_entered.emit()
	await create_timer(0.35).timeout
	_check(card.get_node("ObjectivePreview").modulate.a > 0.99, "Hover reveals the payload wireframe.")
	_check(absf(menu.get_node("%SignalHousing").position.y) < 0.1, "Briefing slide settles into its layout slot.")
	_check(absf(menu.get_node("%SignalHousing").position.x) < 0.1, "Briefing preserves its left layout margin after unfolding.")
	_check(is_equal_approx(menu.get_node("%SignalHousing").size.x, menu.get_node("%SignalHousing").get_parent().size.x), "Briefing stays within the screen width.")
	_check(menu.get_node("%SignalTitle").text == "Lunar Encounter", "The holographic briefing shows the focused mission.")
	await _snapshot("progressed-hover")
	card.get_node("%SelectButton").mouse_exited.emit()
	await create_timer(0.25).timeout
	_check(not card.get_node("ObjectivePreview").visible, "Leaving a node removes its preview.")
	var button := menu.get_mission_card("M04").get_node("%SelectButton") as Button
	button.grab_focus()
	await create_timer(0.25).timeout
	_check(menu.get_mission_card("M04").get_node("ObjectivePreview").visible, "Keyboard focus also reveals the objective.")
	for dimensions: Vector2i in [Vector2i(960, 540), Vector2i(1920, 1080)]:
		root.size = dimensions
		await _settle()
		for route: Dictionary in hologram._routes:
			var beacon := menu.get_mission_card(route.id).get_node("%Visual") as Node2D
			var endpoint: Vector2 = hologram.to_global(route.curve.sample_baked(route.curve.get_baked_length()))
			_check(endpoint.distance_to(beacon.global_position) < 0.5, "Beacon hit layout survives resize: %s / %s" % [dimensions, route.id])
		await _snapshot("campaign-%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	game.select_mission("M03")
	await _settle()
	await create_timer(0.35).timeout
	_check(is_equal_approx(current_scene.get_node("%BriefingPanel").scale.y, 1.0), "Clicking a mission settles the briefing unfold.")
	await _snapshot("clicked-briefing")
	print("Campaign VFX: %d checks, %d failures." % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _snapshot(label: String) -> void:
	if not _capture:
		return
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var folder := "res://exports/qa/campaign-vfx"
	DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder.path_join(label + ".png")) == OK, "Rendered capture: " + label)

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
