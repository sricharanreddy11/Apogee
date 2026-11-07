extends Control

const MISSION_CARD := preload("res://scenes/menus/mission_card.tscn")

var _cards: Dictionary = {}


func _ready() -> void:
	%AgencyCredits.text = "AGENCY CREDITS\n%d CR" % GameManager.agency_credits
	%Progression.set_progress(GameManager.completed_missions)
	%Settings.pressed.connect(func() -> void: %SettingsDialog.popup_centered(Vector2i(460, 230)))
	%Credits.pressed.connect(func() -> void: %CreditsDialog.popup_centered(Vector2i(460, 230)))
	%Exit.pressed.connect(func() -> void: get_tree().quit())
	%Sandbox.pressed.connect(_open_sandbox)
	%MasterVolume.value = db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0
	%VolumeValue.text = "%d%%" % roundi(%MasterVolume.value)
	%MasterVolume.value_changed.connect(_set_master_volume)
	GameManager.navigation_error.connect(_show_error)
	_build_mission_cards()


func _build_mission_cards() -> void:
	var catalog := MissionCatalog.new()
	var missions: Array[MissionDefinition] = catalog.get_mission_list()
	if not catalog.last_error.is_empty():
		_show_error(catalog.last_error)
	if missions.is_empty():
		if catalog.last_error.is_empty():
			_show_error("No missions are available. Check the mission catalog data.")
		return
	var titles: Dictionary = {}
	for mission in missions:
		titles[mission.id] = mission.title
	for mission in missions:
		if not mission.released:
			continue
		var card := MISSION_CARD.instantiate() as MissionCard
		card.name = mission.id
		var prerequisite: String = mission.unlock_requirement
		var unlock_text := ""
		if not prerequisite.is_empty():
			unlock_text = "Complete %s to unlock" % String(titles.get(prerequisite, prerequisite))
		card.setup(mission, GameManager.is_mission_unlocked(mission.id),
			GameManager.completed_missions.has(mission.id),
			int(GameManager.best_scores.get(mission.id, 0)), unlock_text)
		card.mission_selected.connect(_on_mission_selected)
		%MissionList.add_child(card)
		card.set_selected(mission.id == GameManager.selected_mission_id)
		_cards[mission.id] = card
	if _cards.has(GameManager.selected_mission_id):
		%MissionScroll.call_deferred("ensure_control_visible", _cards[GameManager.selected_mission_id])


## Public lookup for navigation tests and future menu refreshes.
func get_mission_card(id: String) -> MissionCard:
	return _cards.get(id) as MissionCard


func _on_mission_selected(id: String) -> void:
	%ErrorMessage.text = ""
	%ErrorMessage.hide()
	if not GameManager.select_mission(id) and %ErrorMessage.text.is_empty():
		_show_error("This mission could not be opened. Check its unlock requirement and mission data.")


func _open_sandbox() -> void:
	%ErrorMessage.text = ""
	%ErrorMessage.hide()
	GameManager.open_sandbox_for_mission("M01")


func _show_error(message: String) -> void:
	%ErrorMessage.text = message
	%ErrorMessage.visible = not message.is_empty()


func _set_master_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value / 100.0, 0.0001)))
	%VolumeValue.text = "%d%%" % roundi(value)
