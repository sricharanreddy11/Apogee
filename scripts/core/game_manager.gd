extends Node

signal navigation_error(message: String)
## Emitted once when a validated build is committed to flight.
signal flight_launch_requested(config: RocketConfig, mission_id: String)

const MENU := preload("res://scenes/ui/main_menu.tscn")
const SANDBOX := preload("res://scenes/ui/ui_sandbox.tscn")
const BRIEFING := preload("res://scenes/missions/mission_select.tscn")
const BUILDER := preload("res://scenes/builder/rocket_builder.tscn")
const PREFLIGHT := preload("res://scenes/flight/launchpad_preview.tscn")
const FLIGHT := preload("res://scenes/flight/flight.tscn")
const REPORT := preload("res://scenes/missions/mission_report.tscn")
const BGM := preload("res://assets/audio/apogee_theme_loop.wav")
const UI_BUTTON_SWIPE := preload("res://assets/audio/ui_button_swipe.wav")
const BGM_VOLUME_DB := -12.0
const UI_CLICK_VOLUME_DB := 12.0
const UI_CLICK_EXCLUDED_META := &"skip_ui_click_sound"
const UI_CLICK_REGISTERED_META := &"_ui_click_sound_registered"

## Session data survives scene changes. The simulator stays inside the Flight scene.
var selected_mission_id: String = ""
var current_rocket_config: RocketConfig
var last_result: MissionResult
## In-memory view of the persisted campaign.
var agency_credits: int = 0
var completed_missions: Array[String] = []
var best_scores: Dictionary = {}
var discovered_ids: Array[String] = []
var _campaign_save := CampaignSave.new()
var last_navigation_error: String = ""
var _mission: MissionDefinition
var _builder_draft: RocketConfig
var _bgm_player: AudioStreamPlayer
var _ui_click_player: AudioStreamPlayer


func _ready() -> void:
	_start_bgm()
	_start_ui_clicks()
	var progress := _campaign_save.load_progress()
	if progress.is_empty():
		return
	agency_credits = int(progress.agency_credits)
	completed_missions.assign(progress.completed_missions)
	best_scores = progress.best_scores
	discovered_ids.assign(progress.discovered_ids)


func _start_bgm() -> void:
	var music := BGM.duplicate() as AudioStreamWAV
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.loop_begin = 0
	music.loop_end = maxi(roundi(music.get_length() * float(music.mix_rate)) - 1, 0)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BackgroundMusic"
	_bgm_player.stream = music
	_bgm_player.volume_db = BGM_VOLUME_DB
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bgm_player)
	_bgm_player.play()


func _start_ui_clicks() -> void:
	_ui_click_player = AudioStreamPlayer.new()
	_ui_click_player.name = "UIButtonSwipe"
	_ui_click_player.stream = UI_BUTTON_SWIPE
	_ui_click_player.volume_db = UI_CLICK_VOLUME_DB
	_ui_click_player.max_polyphony = 8
	_ui_click_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_click_player)
	get_tree().node_added.connect(_register_ui_button)
	_register_ui_buttons(get_tree().root)


func _register_ui_buttons(node: Node) -> void:
	_register_ui_button(node)
	for child in node.get_children():
		_register_ui_buttons(child)


func _register_ui_button(node: Node) -> void:
	if not node is BaseButton:
		return
	var button := node as BaseButton
	if button.has_meta(UI_CLICK_REGISTERED_META):
		return
	button.set_meta(UI_CLICK_REGISTERED_META, true)
	button.pressed.connect(_play_ui_click.bind(button))


func _play_ui_click(button: BaseButton) -> void:
	if button.get_meta(UI_CLICK_EXCLUDED_META, false):
		return
	_ui_click_player.play()


func _record_success(result: MissionResult) -> String:
	result.awarded_credits = 0
	if not completed_missions.has(result.mission_id):
		completed_missions.append(result.mission_id)
		result.awarded_credits = _mission.reward_credits
		agency_credits += result.awarded_credits
	best_scores[result.mission_id] = maxi(int(best_scores.get(result.mission_id, 0)), result.score)
	var new_discoveries: Array[String] = []
	for id in result.discovery_ids:
		if not discovered_ids.has(id):
			discovered_ids.append(id)
			new_discoveries.append(id)
	result.discovery_ids = new_discoveries
	var error := _campaign_save.save_progress({
		"agency_credits": agency_credits,
		"completed_missions": completed_missions,
		"best_scores": best_scores,
		"discovered_ids": discovered_ids,
	})
	return "" if error == OK else "Campaign progress could not be saved. It is available for this session."


func _next_mission(after_id: String) -> MissionDefinition:
	var passed_current := false
	for mission in MissionCatalog.new().get_mission_list():
		if passed_current and _definition_is_unlocked(mission):
			return mission
		if mission.id == after_id:
			passed_current = true
	return null


func select_mission(id: String) -> bool:
	if not _load_mission(id):
		return false
	_show_mission_briefing()
	return true


func _load_mission(id: String) -> bool:
	var catalog := MissionCatalog.new()
	var mission := catalog.load_mission(id)
	if mission == null:
		_fail_navigation(catalog.last_error)
		return false
	if not _definition_is_unlocked(mission):
		_fail_navigation("%s is locked. Complete its prerequisite mission first." % mission.title)
		return false
	_mission = mission
	selected_mission_id = mission.id
	current_rocket_config = null
	_builder_draft = null
	last_result = null
	last_navigation_error = ""
	return true


func show_mission_select() -> void:
	# Compatibility entry point: mission selection now lives on the main menu.
	show_main_menu()


func is_mission_unlocked(id: String) -> bool:
	var catalog := MissionCatalog.new()
	var mission := catalog.load_mission(id)
	return mission != null and _definition_is_unlocked(mission)


func _definition_is_unlocked(mission: MissionDefinition) -> bool:
	return mission.released and (
		completed_missions.has(mission.id) or mission.unlock_requirement.is_empty()
		or completed_missions.has(mission.unlock_requirement)
	)


func get_selected_mission() -> MissionDefinition:
	return _mission


func open_sandbox_for_mission(id: String = "M01") -> bool:
	if not _load_mission(id):
		return false
	show_ui_sandbox()
	return true


func show_ui_sandbox() -> void:
	if _mission == null:
		show_main_menu()
		return
	last_result = null
	var screen := SANDBOX.instantiate()
	screen.setup(_mission)
	screen.report_requested.connect(_show_sandbox_report)
	screen.back_requested.connect(show_main_menu)
	screen.menu_requested.connect(show_main_menu)
	_switch_screen(screen)


func _show_mission_briefing() -> void:
	var screen := BRIEFING.instantiate()
	screen.setup(_mission)
	screen.build_requested.connect(show_builder)
	screen.back_requested.connect(show_main_menu)
	_switch_screen(screen)


func _return_to_briefing(builder: BuilderController) -> void:
	_builder_draft = builder.build_config()
	_show_mission_briefing()


func show_workshop() -> void:
	var workshop := MissionDefinition.new()
	workshop.id = "WORKSHOP"
	workshop.title = "Workshop"
	workshop.budget_credits = 10000
	workshop.scenario = {"body_id": "earth"}
	var screen := BUILDER.instantiate() as BuilderController
	screen.setup(workshop, true)
	screen.back_requested.connect(show_main_menu)
	_switch_screen(screen)


func start_tutorial() -> void:
	_mission = _tutorial_mission()
	selected_mission_id = _mission.id
	current_rocket_config = null
	_builder_draft = null
	last_result = null
	last_navigation_error = ""
	var screen := BUILDER.instantiate() as BuilderController
	screen.setup(_mission)
	screen.configuration_confirmed.connect(prepare_launch)
	screen.back_requested.connect(show_main_menu)
	_switch_screen(screen)


func close_tutorial_to_menu() -> void:
	selected_mission_id = ""
	current_rocket_config = null
	_builder_draft = null
	last_result = null
	_mission = null
	_switch_screen(MENU.instantiate())


func _tutorial_mission() -> MissionDefinition:
	var mission := MissionDefinition.new()
	mission.id = "TUTORIAL"
	mission.title = "Guided Orbit"
	mission.objective_text = "Build a simple rocket, learn the flight instruments, and explore a safe Earth orbit."
	mission.objective_type = "stable_orbit"
	mission.budget_credits = 2500
	mission.reward_credits = 0
	mission.scenario = {"body_id": "earth", "spawn_profile": "tutorial_orbit"}
	mission.allowed_part_ids.assign(["POD_A", "TANK_L", "ENG_L"])
	mission.required_part_ids.assign(["POD_A"])
	mission.win_conditions = {"min_periapsis_m": 100000.0, "max_apoapsis_m": 350000.0, "hold_duration_s": 86400.0}
	mission.starting_location = "Rocket Lab"
	mission.destination = "Guided Earth orbit"
	return mission


func show_moon_flyby_showcase() -> void:
	var screen := FLIGHT.instantiate()
	screen.setup_showcase()
	screen.showcase_exit_requested.connect(show_main_menu)
	_switch_screen(screen)


func show_builder() -> void:
	if _mission == null:
		show_main_menu()
		return
	var screen := BUILDER.instantiate() as BuilderController
	screen.setup(_mission)
	var config := _builder_draft if _builder_draft != null else current_rocket_config
	if config != null:
		screen.load_config(config)
	screen.configuration_confirmed.connect(prepare_launch)
	screen.back_requested.connect(_return_to_briefing.bind(screen))
	_switch_screen(screen)


func prepare_launch(config: RocketConfig) -> bool:
	if _mission == null or not _definition_is_unlocked(_mission):
		_fail_navigation("Select an available mission before preparing a rocket.")
		return false
	var verifier := BuilderController.new()
	verifier.setup(_mission)
	var validation := verifier.validate(config, _mission)
	verifier.free()
	if not validation.valid:
		_fail_navigation("\n".join(validation.errors))
		var screen := get_tree().current_scene
		if screen != null and screen.has_method("show_validation_errors"):
			screen.show_validation_errors(validation.errors, validation.warnings)
		return false
	current_rocket_config = config.copy()
	_builder_draft = null
	last_result = null
	last_navigation_error = ""
	return show_preflight()


func edit_rocket(config: RocketConfig, mission_id: String) -> bool:
	if config == null:
		return false
	if _mission == null or selected_mission_id != mission_id:
		if not _load_mission(mission_id):
			return false
	current_rocket_config = config.copy()
	_builder_draft = null
	show_builder()
	return true


func show_preflight() -> bool:
	if _mission == null or current_rocket_config == null:
		_fail_navigation("Prepare a valid rocket in the builder before opening the launchpad.")
		return false
	if not _definition_is_unlocked(_mission):
		_fail_navigation("This mission is locked.")
		return false
	var screen := PREFLIGHT.instantiate()
	if not screen.setup(_mission, current_rocket_config.copy()):
		_fail_navigation(screen.last_error)
		screen.free()
		return false
	screen.edit_requested.connect(show_builder)
	screen.menu_requested.connect(show_main_menu)
	screen.launch_requested.connect(_relay_launch_request)
	_switch_screen(screen)
	return true


func _relay_launch_request(config: RocketConfig) -> void:
	flight_launch_requested.emit(config.copy(), selected_mission_id)
	# The signal remains available to analytics/tests, then the authoritative flight
	# scene takes ownership of one copied configuration on the next idle turn.
	call_deferred("start_flight", config.copy())


func start_flight(config: RocketConfig) -> void:
	if _mission == null or config == null:
		return
	current_rocket_config = config.copy()
	_builder_draft = null
	last_result = null
	var screen := FLIGHT.instantiate()
	screen.setup(current_rocket_config.copy(), selected_mission_id, _mission)
	screen.report_requested.connect(show_report)
	_switch_screen(screen)


func _show_sandbox_report(result: MissionResult) -> void:
	show_report(result, true)


func show_report(result: MissionResult, retry_in_sandbox: bool = false) -> void:
	if result == null:
		return
	if selected_mission_id == "TUTORIAL":
		TutorialManager.exit_tutorial()
		return
	# Running the sandbox with F6 has not selected a mission through the menu.
	if _mission == null or selected_mission_id != result.mission_id:
		if not _load_mission(result.mission_id):
			return
	if last_result == result:
		return
	last_result = result
	var next: MissionDefinition
	var save_notice := ""
	if not retry_in_sandbox and result.outcome == MissionResult.Outcome.SUCCESS:
		save_notice = _record_success(result)
		next = _next_mission(result.mission_id)
	var screen := REPORT.instantiate()
	screen.setup(result, retry_in_sandbox, next, save_notice)
	screen.next_requested.connect(select_mission)
	if retry_in_sandbox:
		screen.retry_requested.connect(show_ui_sandbox)
	else:
		screen.retry_requested.connect(show_builder)
	screen.menu_requested.connect(show_main_menu)
	_switch_screen(screen)


func show_main_menu() -> void:
	if TutorialManager.active:
		TutorialManager.exit_tutorial()
		return
	_switch_screen(MENU.instantiate())


func _switch_screen(screen: Node) -> void:
	var error := get_tree().change_scene_to_node(screen)
	if error != OK:
		screen.free()
		_fail_navigation("Could not change screen (error %s)." % error)


func _fail_navigation(message: String) -> void:
	last_navigation_error = message
	navigation_error.emit(message)
