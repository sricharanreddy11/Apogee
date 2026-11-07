extends Control


func _ready() -> void:
	%Primary.pressed.connect(_open_m01.bind(false))
	%BuildRocket.pressed.connect(_open_m01.bind(true))


func _open_m01(open_builder: bool) -> void:
	var game := get_node_or_null("/root/GameManager")
	if game == null or not game.select_mission("M01", open_builder):
		%Details.text = "Could not open First Flight. Check the Godot Output panel."
