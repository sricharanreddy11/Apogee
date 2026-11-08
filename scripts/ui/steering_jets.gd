extends Node2D


func set_turn(turn: float) -> void:
	# Exhaust points away from the side the pilot is steering toward.
	$Left.emitting = turn > 0.01
	$Right.emitting = turn < -0.01
