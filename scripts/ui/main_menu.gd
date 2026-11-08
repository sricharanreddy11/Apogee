extends Control

const MISSION_CARD := preload("res://scenes/menus/mission_card.tscn")
const CONSOLE := preload("res://scripts/ui/console_button.gd")
const CHART_SIZE := Vector2(1184, 500)
const HOLOGRAM := preload("res://scripts/ui/campaign_hologram.gd")

var _cards: Dictionary = {}
var _signals: Dictionary = {}
var _active_signal := ""
var _signal_tween: Tween


func _ready() -> void:
	%AgencyCredits.text = "%d CR" % GameManager.agency_credits
	%AgencyCredits.accessibility_name = "%d agency credits" % GameManager.agency_credits
	%Chart.resized.connect(_fit_chart)
	_fit_chart()
	%Settings.pressed.connect(func() -> void: %SettingsDialog.popup_centered(Vector2i(460, 230)))
	%Exit.pressed.connect(func() -> void: get_tree().quit())
	CONSOLE.apply(%Tutorial, "primary")
	CONSOLE.apply(%Workshop, "primary")
	CONSOLE.apply(%Showcase)
	CONSOLE.apply(%Exit)
	CONSOLE.apply(%SettingsDialog.get_ok_button())
	%Showcase.pressed.connect(GameManager.show_moon_flyby_showcase)
	%Workshop.pressed.connect(GameManager.show_workshop)
	%Tutorial.pressed.connect(TutorialManager.start_tutorial)
	%MasterVolume.value = db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0
	%VolumeValue.text = "%d%%" % roundi(%MasterVolume.value)
	%MasterVolume.value_changed.connect(_set_master_volume)
	GameManager.navigation_error.connect(_show_error)
	_build_mission_beacons()
	%RocketTurntable.setup(GameManager.current_rocket_config)
	_reveal_beacons()


func _fit_chart() -> void:
	var fit := minf(%Chart.size.x / CHART_SIZE.x, %Chart.size.y / CHART_SIZE.y)
	%ChartWorld.scale = Vector2.ONE * fit
	%ChartWorld.position = (%Chart.size - CHART_SIZE * fit) * 0.5
	%Earth.position = HOLOGRAM.project(Vector2(245, 112))
	%Moon.position = HOLOGRAM.project(Vector2(910, 126))


func _reveal_beacons() -> void:
	if _cards.is_empty():
		return
	var reveal := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var delay := 0.0
	for card: MissionCard in _cards.values():
		card.modulate.a = 0.4
		reveal.tween_property(card, "modulate:a", 1.0, 0.32).set_delay(delay)
		delay += 0.09


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
	var released := missions.filter(func(mission: MissionDefinition) -> bool: return mission.released)
	var points: Dictionary = {}
	for mission: MissionDefinition in released:
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
		var index := _cards.size()
		var progress := float(index) / maxi(released.size() - 1, 1)
		var point: Vector2 = HOLOGRAM.project(Vector2(lerpf(0.14, 0.86, progress), 0.66 if index % 2 == 0 else 0.44) * CHART_SIZE) / CHART_SIZE
		points[mission.id] = point * CHART_SIZE
		card.anchor_left = point.x
		card.anchor_right = point.x
		card.anchor_top = point.y
		card.anchor_bottom = point.y
		card.offset_left = -102.0
		card.offset_right = 102.0
		card.offset_top = -40.0
		card.offset_bottom = 112.0
		_cards[mission.id] = card
		_signals[mission.id] = {
			"title": mission.title,
			"details": mission.objective_text if card.is_selectable else unlock_text,
		}
	%CampaignHologram.configure(released, points, GameManager.completed_missions)
	if not _cards.is_empty():
		var active := GameManager.selected_mission_id
		_show_signal(active if _cards.has(active) else _cards.keys()[0])


## Public lookup for navigation tests and future menu refreshes.
func get_mission_card(id: String) -> MissionCard:
	return _cards.get(id) as MissionCard


func _show_signal(id: String) -> void:
	if id == _active_signal:
		return
	_active_signal = id
	for mission_id: String in _cards:
		_cards[mission_id].set_selected(mission_id == id)
	var briefing: Dictionary = _signals[id]
	%SignalID.text = "%s  /  BRIEFING" % id
	%SignalTitle.text = briefing.title
	%SignalDetails.text = briefing.details
	_animate_signal.call_deferred()


func _animate_signal() -> void:
	if _signal_tween != null:
		_signal_tween.kill()
	%SignalDetails.modulate.a = 0.55
	%SignalLight.modulate.a = 1.0
	# Wait for the layout before changing offsets: the initial minimum size can
	# otherwise become permanent negative margins on an anchored panel.
	%SignalHousing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	%SignalHousing.position = Vector2(0, 22)
	%SignalHousing.modulate.a = 0.45
	var glass := %SignalGlass.material as ShaderMaterial
	glass.set_shader_parameter("reveal", 0.0)
	_signal_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_signal_tween.tween_property(%SignalHousing, "position:y", 0.0, 0.26)
	_signal_tween.tween_property(%SignalHousing, "modulate:a", 1.0, 0.20)
	_signal_tween.tween_method(func(value: float) -> void: glass.set_shader_parameter("reveal", value), 0.0, 1.0, 0.24)
	_signal_tween.tween_property(%SignalDetails, "modulate:a", 1.0, 0.22)
	_signal_tween.tween_property(%SignalLight, "modulate:a", 0.45, 0.45)


func _on_mission_selected(id: String) -> void:
	%ErrorMessage.text = ""
	%ErrorMessage.hide()
	if not GameManager.select_mission(id) and %ErrorMessage.text.is_empty():
		_show_error("This mission could not be opened. Check its unlock requirement and mission data.")


func _show_error(message: String) -> void:
	%ErrorMessage.text = message
	%ErrorMessage.visible = not message.is_empty()


func _set_master_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value / 100.0, 0.0001)))
	%VolumeValue.text = "%d%%" % roundi(value)


func _process(delta: float) -> void:
	%Earth.rotation += delta * 0.018
	%Moon.rotation += delta * 0.009
