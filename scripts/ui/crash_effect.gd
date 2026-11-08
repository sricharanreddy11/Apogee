extends Node2D

signal finished

const DURATION := 2.15

var _progress := 0.0
var _sequence: Tween


func play_at(impact_point: Vector2) -> void:
	position = impact_point
	_advance(0.0)
	show()
	for emitter: CPUParticles2D in [$Sparks, $Debris, $Vapor]:
		emitter.restart()
		emitter.emitting = true
	$ImpactAudio.play()
	_sequence = create_tween()
	_sequence.tween_method(_advance, 0.0, 1.0, DURATION)
	_sequence.tween_callback(finished.emit)


func reset() -> void:
	if _sequence != null:
		_sequence.kill()
	$ImpactAudio.stop()
	for emitter: CPUParticles2D in [$Sparks, $Debris, $Vapor]:
		emitter.emitting = false
	hide()


func _advance(progress: float) -> void:
	_progress = progress
	queue_redraw()


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.3, 0), Vector2(-3.0, -1.1), Vector2(-1.5, -1.4), Vector2(-0.9, -0.55),
		Vector2(0.8, -1.7), Vector2(1.75, -1.45), Vector2(2.9, -0.25), Vector2(4.5, 0),
	]), Color("#18222c"))
	draw_line(Vector2(-3.0, -1.1), Vector2(-1.5, -1.4), Color("#95a0a8"), 0.16, true)
	draw_line(Vector2(0.8, -1.7), Vector2(1.75, -1.45), Color("#d28a4c"), 0.15, true)
	var heat := clampf(1.0 - _progress * 4.5, 0.0, 1.0)
	if heat <= 0.0:
		return
	draw_circle(Vector2(0, -0.65), 3.5 * heat, Color(1, 0.52, 0.2, heat * 0.55), true, -1, true)
	draw_circle(Vector2(0, -0.65), 1.8 * heat, Color(1, 0.93, 0.68, heat), true, -1, true)
	draw_arc(Vector2.ZERO, 1.0 + _progress * 55.0, PI, TAU, 26, Color(1, 0.78, 0.47, heat), 0.22, true)
