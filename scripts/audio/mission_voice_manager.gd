extends Node
## Offline-only narrator. The exported game has no API client or credentials.
signal subtitle_changed(text: String)
signal speaking_changed(speaking: bool)
signal clip_started(id: String)

const MANIFEST := "res://data/mission_voiceover.json"
const CLIP_FOLDER := "res://assets/audio/voiceover/"
const MAX_QUEUE := 6
var rules := MissionVoiceRules.new()
var _clips: Dictionary = {}
var _streams: Dictionary = {}
var _queue: Array[Dictionary] = []
var _played: Dictionary = {}
var _player: AudioStreamPlayer
var _clock := 0.0
var _current := ""
var _priority := -1
var _subtitle := ""
var _flight_active := false
var _hold := false
var _next_allowed := 0.0

func _ready() -> void:
	_clips = JsonData.read_object(MANIFEST).get("clips", {})
	_player = AudioStreamPlayer.new()
	_player.name = "MissionControlNarrator"
	_player.volume_db = -1.0
	add_child(_player)
	_player.finished.connect(_on_finished)
	for id: String in _clips:
		var path := CLIP_FOLDER + id + ".radio.wav"
		if ResourceLoader.exists(path):
			_streams[id] = load(path)

func begin_preflight() -> void:
	stop_all()
	_played.clear()
	announce("control_online")
	announce("preflight_ready")

func begin_attempt(mission: MissionDefinition, config: RocketConfig, initial: FlightTelemetry) -> void:
	stop_all()
	_played.clear()
	rules.begin(mission, config, initial)
	_flight_active = true
	announce("launch_committed")
	announce(mission.id + "_intro")

func observe(t: FlightTelemetry) -> void:
	if not _flight_active:
		return
	for id in rules.observe(t):
		announce(id)
	_discard_stale()

func announce_result(result: MissionResult) -> void:
	var id := MissionVoiceRules.result_clip(result)
	if id.is_empty():
		return
	if _current == id:
		_flight_active = false
		_queue.clear()
		set_hold(false)
		return
	if _played.has(id):
		stop_all()
		return
	stop_all()
	announce(id)

func announce(id: String) -> bool:
	if not _clips.has(id) or not _streams.has(id) or _played.has(id) or _queue.any(func(item: Dictionary) -> bool: return item.id == id):
		return false
	if _flight_active and not rules.is_current(id):
		return false
	var definition: Dictionary = _clips[id]
	var priority := int(definition.priority)
	var item := {"id": id, "priority": priority, "expires": _clock + float(definition.ttl)}
	if not _hold and (_current.is_empty() or priority > _priority):
		if priority >= 85:
			_queue = _queue.filter(func(queued: Dictionary) -> bool: return int(queued.priority) >= 85)
		_start(item)
	else:
		_queue.append(item)
		_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.priority) > int(b.priority))
		if _queue.size() > MAX_QUEUE:
			_queue.resize(MAX_QUEUE)
	return true

func _start(item: Dictionary) -> void:
	_player.stop()
	_current = item.id
	_priority = item.priority
	_played[_current] = true
	_player.stream = _streams[_current]
	_subtitle = String(_clips[_current].text)
	subtitle_changed.emit(_subtitle)
	speaking_changed.emit(true)
	clip_started.emit(_current)
	_player.play()

func _on_finished() -> void:
	_current = ""
	_priority = -1
	_subtitle = ""
	_next_allowed = _clock + 0.35
	subtitle_changed.emit("")
	speaking_changed.emit(false)

func _discard_stale() -> void:
	_queue = _queue.filter(func(item: Dictionary) -> bool: return float(item.expires) >= _clock and (not _flight_active or rules.is_current(item.id)))
	if _flight_active and not _current.is_empty() and not rules.is_current(_current):
		_player.stop()
		_on_finished()

func _process(delta: float) -> void:
	if _hold:
		return
	_clock += delta
	_discard_stale()
	if _current.is_empty() and _clock >= _next_allowed and not _queue.is_empty():
		_start(_queue.pop_front())

func set_hold(hold: bool) -> void:
	_hold = hold
	_player.stream_paused = hold

func get_subtitle() -> String:
	return _subtitle

func stop_all() -> void:
	_flight_active = false
	_hold = false
	_queue.clear()
	if _player != null:
		_player.stop()
		_player.stream_paused = false
	_current = ""
	_priority = -1
	_subtitle = ""
	_next_allowed = 0.0
	subtitle_changed.emit("")
	speaking_changed.emit(false)
