extends Control

signal edit_requested
signal menu_requested
signal launch_requested(config: RocketConfig)

enum SessionPhase { PREFLIGHT, LAUNCH_REQUESTED }

var session_phase: SessionPhase = SessionPhase.PREFLIGHT
var last_error: String = ""
var _mission: MissionDefinition
var _config: RocketConfig
var _stats: Dictionary = {}
var _validation: Dictionary = {}


func setup(mission: MissionDefinition, config: RocketConfig) -> bool:
	_mission = mission
	_config = config.copy() if config != null else null
	session_phase = SessionPhase.PREFLIGHT
	if not _check_configuration():
		return false
	if is_node_ready():
		_render()
	return true


func _ready() -> void:
	%PreflightPanel.launch_requested.connect(_request_launch)
	%PreflightPanel.edit_requested.connect(_edit)
	%MainMenu.pressed.connect(_menu)
	if _mission == null:
		# Direct F6 run: use Rocket Lab's default craft and the shared rocket schema.
		var catalog := MissionCatalog.new()
		var mission := catalog.load_mission("M01")
		if mission != null:
			var builder := BuilderController.new()
			builder.setup(mission)
			var reference := builder.build_config()
			builder.free()
			setup(mission, reference)
		else:
			last_error = catalog.last_error
	if _mission == null or _config == null or not last_error.is_empty():
		%SessionNote.text = "Cannot prepare launch: %s" % last_error
		return
	_render()


func _check_configuration() -> bool:
	last_error = ""
	if _mission == null:
		last_error = "No mission selected."
		return false
	var verifier := BuilderController.new()
	verifier.setup(_mission)
	_validation = verifier.validate(_config, _mission)
	if _validation.valid:
		_stats = verifier.calculate(_config)
	verifier.free()
	if not _validation.valid:
		last_error = "\n".join(_validation.errors)
	return _validation.valid


func _render() -> void:
	%RocketPreview.setup(_config)
	%RocketPreview.set_body(String(_mission.scenario.get("body_id", "earth")))
	%PreflightPanel.setup(_mission, _config, _stats, _validation)
	%SessionNote.text = "Preflight preview · Your rocket stays on the pad until Launch."


func _request_launch() -> void:
	if session_phase != SessionPhase.PREFLIGHT:
		return
	# Revalidate at the controller boundary; the panel's labels are presentation.
	if not _check_configuration():
		var errors: Array[String] = []
		errors.assign(_validation.get("errors", [last_error]))
		%PreflightPanel.show_validation_errors(errors)
		return
	session_phase = SessionPhase.LAUNCH_REQUESTED
	%PreflightPanel.mark_launch_requested()
	%SessionNote.text = "Launch committed · Opening active flight."
	# GameManager preserves this integration event, then opens active flight.
	launch_requested.emit(_config.copy())


func get_config() -> RocketConfig:
	return _config.copy() if _config != null else null


func _edit() -> void:
	if _mission == null or _config == null:
		_menu()
		return
	if edit_requested.get_connections().is_empty():
		GameManager.edit_rocket(_config.copy(), _mission.id)
	else:
		edit_requested.emit()


func _menu() -> void:
	if menu_requested.get_connections().is_empty():
		GameManager.show_main_menu()
	else:
		menu_requested.emit()
