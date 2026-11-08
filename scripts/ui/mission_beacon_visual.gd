extends Node2D
var state := "locked"
var _clock := 0.0
const CYAN := Color("6ce7ed")

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	var active := state != "locked"
	var color := CYAN if active else Color("64727f")
	var breath := 0.5 + 0.5 * sin(_clock * 2.1)
	var radius := 27.0 + (breath * 2.2 if state == "available" else 0.0)
	for halo in 3:
		draw_circle(Vector2.ZERO, radius + 6 + halo * 5, Color(color, (0.025 + breath * 0.012) if active else 0.008), true, -1, true)
	draw_circle(Vector2.ZERO, radius, Color("0b1e2c"), true, -1, true)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(color, 0.75 if active else 0.3), 1.5, true)
	if state == "completed":
		draw_circle(Vector2.ZERO, 11, CYAN, true, -1, true)
		draw_circle(Vector2.ZERO, 4, Color("d9ffff"), true, -1, true)
		for segment in 3:
			var angle := _clock * 0.28 + segment * TAU / 3.0
			draw_arc(Vector2.ZERO, 36, angle, angle + 1.3, 24, Color(CYAN, 0.75), 2, true)
	elif state == "available":
		draw_circle(Vector2.ZERO, 8 + breath * 2, Color(CYAN, 0.55 + breath * 0.4), true, -1, true)
		draw_arc(Vector2.ZERO, 35 + breath * 4, 0, TAU, 64, Color(CYAN, 0.12 + breath * 0.2), 1, true)
	else:
		# Low-contrast interference stays inside the dim node, away from its labels.
		for row in 7:
			var y := -18.0 + row * 6.0
			var jitter := sin(floor(_clock * 8.0) * 4.1 + row * 7.3)
			draw_line(Vector2(-17 + jitter * 3, y), Vector2(17 + jitter * 2, y), Color(color, 0.08 + absf(jitter) * 0.1), 1)
