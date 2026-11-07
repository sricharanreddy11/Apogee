extends Control

signal mission_requested(mission_id: String)


func _ready() -> void:
	%Primary.pressed.connect(func() -> void: mission_requested.emit("M01"))
