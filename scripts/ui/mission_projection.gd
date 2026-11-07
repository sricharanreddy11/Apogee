extends Control

const MODES := {
	"M01": "ASCENT",
	"M02": "EARTH ORBIT",
	"M03": "LUNAR FLYBY",
	"M04": "LUNAR DESCENT",
}


func _ready() -> void:
	resized.connect(_fit_projection)
	%Replay.pressed.connect(_replay)
	_fit_projection()


func show_mission(id: String) -> void:
	for route: Node2D in %ProjectionWorld.get_children():
		route.visible = route.name == id
	var mode := String(MODES.get(id, "TRACK UNAVAILABLE"))
	%ProjectionMode.text = "%s  /  SCHEMATIC" % mode if MODES.has(id) else mode
	%Replay.disabled = not MODES.has(id)
	_replay()


func _fit_projection() -> void:
	%ProjectionWorld.scale = size / Vector2(590, 500)


func _replay() -> void:
	%AnimationPlayer.play("track")
	%AnimationPlayer.seek(0.0, true)
