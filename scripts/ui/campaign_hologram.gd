extends Node2D
## Shared projection keeps route endpoints and interactive beacons aligned.
const FIELD := Vector2(1184, 500)
const CYAN := Color("6ce7ed")
var _routes: Array[Dictionary] = []
var _clock := 0.0

static func project(point: Vector2) -> Vector2:
	var depth := point.y / FIELD.y
	var perspective := lerpf(0.86, 1.04, depth)
	return Vector2(FIELD.x * 0.5 + (point.x - FIELD.x * 0.5) * perspective,
		54.0 + point.y * 0.79)

func configure(missions: Array[MissionDefinition], points: Dictionary, completed: Array[String]) -> void:
	_routes.clear()
	var distances: Dictionary = {}
	for mission in missions:
		var start: Vector2 = points.get(mission.unlock_requirement, project(Vector2(245, 112)))
		var finish: Vector2 = points[mission.id]
		var curve := Curve2D.new()
		var bend := (finish - start) * 0.32
		curve.add_point(start, Vector2.ZERO, Vector2(bend.x, 0))
		curve.add_point(finish, Vector2(-bend.x, 0), Vector2.ZERO)
		var offset := float(distances.get(mission.unlock_requirement, 0.0))
		distances[mission.id] = offset + curve.get_baked_length()
		_routes.append({"curve": curve, "completed": completed.has(mission.id),
			"id": mission.id, "offset": offset})
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	for x in range(30, 1185, 64):
		draw_line(project(Vector2(x, 40)), project(Vector2(x, 460)), Color(CYAN, 0.045), 1, true)
	for y in range(40, 461, 42):
		draw_line(project(Vector2(30, y)), project(Vector2(1154, y)), Color(CYAN, 0.055), 1, true)
	var base_left := project(Vector2(30, 460))
	var base_right := project(Vector2(1154, 460))
	draw_line(base_left, base_right, Color(CYAN, 0.18), 1.5, true)
	draw_line(base_left + Vector2(0, 9), base_right + Vector2(0, 9), Color(CYAN, 0.045), 3, true)
	for route in _routes:
		var curve := route.curve as Curve2D
		var length := curve.get_baked_length()
		var points := curve.get_baked_points()
		if not route.completed:
			for segment in range(0, int(length), 14):
				draw_line(curve.sample_baked(segment), curve.sample_baked(minf(segment + 5, length)), Color(0.4, 0.53, 0.63, 0.25), 1, true)
			continue
		draw_polyline(points, Color(CYAN, 0.035), 13, true)
		draw_polyline(points, Color(CYAN, 0.13), 5, true)
		draw_polyline(points, Color(CYAN, 0.5), 1.4, true)
		# One phase measured from Earth, including the length of predecessor routes.
		var phase := fposmod(_clock * 105.0 - float(route.offset), 180.0)
		for packet in range(-1, int(length / 180) + 1):
			var head := phase + packet * 180.0
			for tail in 12:
				var distance := head - tail * 3.0
				if distance >= 0 and distance <= length:
					var alpha := (1.0 - float(tail) / 12.0)
					var point := curve.sample_baked(distance)
					draw_circle(point, 5.0, Color(CYAN, alpha * 0.065), true, -1, true)
					draw_circle(point, 1.6, Color(CYAN, alpha * 0.9), true, -1, true)
	var earth := project(Vector2(245, 112))
	for radius: float in [67, 70, 75]:
		draw_arc(earth, radius, 0, TAU, 96, Color(CYAN, 0.12 if radius == 67 else 0.045), 2, true)
	var satellite := earth + Vector2(cos(_clock * 0.17) * 92, sin(_clock * 0.17) * 26)
	draw_set_transform(earth, 0, Vector2(1, 26.0 / 92.0))
	draw_arc(Vector2.ZERO, 92, 0, TAU, 80, Color(CYAN, 0.12), 1, true)
	draw_set_transform(Vector2.ZERO)
	draw_circle(satellite, 2.4, Color("c8f7ff"), true, -1, true)
	draw_line(satellite - Vector2(9, 0), satellite + Vector2(9, 0), Color(CYAN, 0.8), 2, true)
