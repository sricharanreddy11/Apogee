extends Control

const MODES := {"M01": "ASCENT", "M02": "EARTH ORBIT", "M03": "LUNAR FLYBY", "M04": "LUNAR DESCENT"}
const CYAN := Color("66e1ef")
const PURPLE := Color("b19ae8")
var _route: Node2D
var _clock := 0.0

func _ready() -> void:
	get_node("Field").hide()
	for route: Node2D in %ProjectionWorld.get_children():
		var trace := route.get_node("FlightTrackTrace") as Line2D
		trace.default_color = Color(CYAN, 0.2)
		trace.width = 1.4
		for child in route.get_children():
			if child is Sprite2D:
				child.modulate = Color(0.65, 0.83, 1, 0.8)
	resized.connect(_fit_projection)
	_fit_projection()
	show_mission("M01")

func show_mission(id: String) -> void:
	_route = null
	for route: Node2D in %ProjectionWorld.get_children():
		route.visible = route.name == id
		if route.visible:
			_route = route
	var mode := String(MODES.get(id, "TRACK UNAVAILABLE"))
	%ProjectionMode.text = "%s / MISSION ROUTE" % mode if MODES.has(id) else mode
	if _route == null:
		%AnimationPlayer.stop()
	else:
		_replay()

func _fit_projection() -> void:
	var fit := minf((size.x - 48) / 590.0, (size.y - 120) / 480.0)
	%ProjectionWorld.scale = Vector2.ONE * maxf(0.1, fit)
	%ProjectionWorld.position = Vector2((size.x - 590 * fit) * 0.5, 80)
	queue_redraw()

func _replay() -> void:
	%AnimationPlayer.play("track")
	%AnimationPlayer.seek(0.0, true)
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("0b1424")
	panel.border_color = Color("345466")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(10)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	for x in range(24, int(size.x - 20), 34):
		draw_line(Vector2(x, 82), Vector2(x, size.y - 24), Color(0.23, 0.47, 0.62, 0.07), 1)
	for y in range(82, int(size.y - 24), 34):
		draw_line(Vector2(20, y), Vector2(size.x - 20, y), Color(0.23, 0.47, 0.62, 0.07), 1)
	draw_line(Vector2(22, 72), Vector2(size.x - 22, 72), Color(CYAN, 0.25), 1)
	draw_line(Vector2(22, 1), Vector2(118, 1), Color(CYAN, 0.75), 2)
	draw_line(Vector2(size.x - 114, size.y - 1), Vector2(size.x - 22, size.y - 1), Color(PURPLE, 0.6), 2)
	if _route == null:
		return
	var track := _route.get_node("FlightTrack") as Path2D
	var traveler := track.get_node("Traveler") as PathFollow2D
	var length := track.curve.get_baked_length()
	var flown := length * traveler.progress_ratio
	var points := PackedVector2Array()
	for index in 65:
		points.append(%ProjectionWorld.transform * track.curve.sample_baked(flown * float(index) / 64.0))
	if flown > 0.1:
		draw_polyline(points, Color(CYAN, 0.04), 11, true)
		draw_polyline(points, Color(CYAN, 0.13), 5, true)
		draw_polyline(points, Color(CYAN, 0.9), 1.8, true)
	var start: Vector2 = %ProjectionWorld.transform * track.curve.sample_baked(0)
	var finish: Vector2 = %ProjectionWorld.transform * track.curve.sample_baked(length)
	var marker: Vector2 = %ProjectionWorld.transform * traveler.position
	draw_circle(start, 3, Color(CYAN, 0.8), false, 1, true)
	draw_circle(finish, 6, Color(PURPLE, 0.8), false, 1, true)
	draw_circle(marker, 9 + sin(_clock * 3) * 2, Color(CYAN, 0.25), false, 1, true)
	draw_circle(marker, 3, CYAN, true, -1, true)
