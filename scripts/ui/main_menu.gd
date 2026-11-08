extends Control

const MISSION_CARD := preload("res://scenes/menus/mission_card.tscn")
const CHART_SIZE := Vector2(1184, 500)

var _cards: Dictionary = {}
var _signals: Dictionary = {}


func _ready() -> void:
	%AgencyCredits.text = "AGENCY CREDITS\n%d CR" % GameManager.agency_credits
	%Chart.resized.connect(_fit_chart)
	_fit_chart()
	%Settings.pressed.connect(func() -> void: %SettingsDialog.popup_centered(Vector2i(460, 230)))
	%Credits.pressed.connect(func() -> void: %CreditsDialog.popup_centered(Vector2i(460, 230)))
	%Exit.pressed.connect(func() -> void: get_tree().quit())
	%Sandbox.pressed.connect(_open_sandbox)
	%Showcase.pressed.connect(GameManager.show_moon_flyby_showcase)
	%Workshop.pressed.connect(GameManager.show_workshop)
	%MasterVolume.value = db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0
	%VolumeValue.text = "%d%%" % roundi(%MasterVolume.value)
	%MasterVolume.value_changed.connect(_set_master_volume)
	GameManager.navigation_error.connect(_show_error)
	_build_mission_beacons()


func _fit_chart() -> void:
	%ChartWorld.scale = %Chart.size / CHART_SIZE


func _build_mission_beacons() -> void:
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
		var unlock_text := ""
		if not mission.unlock_requirement.is_empty():
			unlock_text = "Complete %s to unlock" % String(titles.get(mission.unlock_requirement, mission.unlock_requirement))
		card.setup(mission, GameManager.is_mission_unlocked(mission.id),
			GameManager.completed_missions.has(mission.id),
			int(GameManager.best_scores.get(mission.id, 0)), unlock_text)
		card.mission_selected.connect(_on_mission_selected)
		card.signal_focused.connect(_show_signal)
		%MissionList.add_child(card)
		var marker := %MissionAnchors.get_node_or_null(mission.id) as Control
		var point := Vector2(marker.anchor_left, marker.anchor_top) if marker != null else Vector2(0.14 + float(_cards.size() % 4) * 0.23, 0.10)
		card.anchor_left = point.x
		card.anchor_right = point.x
		card.anchor_top = point.y
		card.anchor_bottom = point.y
		card.offset_left = -102.0
		card.offset_right = 102.0
		card.offset_top = -40.0
		card.offset_bottom = 112.0
		_cards[mission.id] = card
		_signals[mission.id] = mission.objective_text if card.is_selectable else unlock_text
	if not _cards.is_empty():
		var active := GameManager.selected_mission_id
		_show_signal(active if _cards.has(active) else _cards.keys()[0])


## Public lookup for navigation tests and future menu refreshes.
func get_mission_card(id: String) -> MissionCard:
	return _cards.get(id) as MissionCard


func _show_signal(id: String) -> void:
	for mission_id: String in _cards:
		_cards[mission_id].set_selected(mission_id == id)
	%SignalID.text = "SIGNAL / %s" % id
	%SignalDetails.text = _signals[id]


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
