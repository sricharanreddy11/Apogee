@tool
extends Control

const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Regular.res")
const AP := Color("#ffca7d")
const PE := Color("#79e0e8")
const CENTER := Vector2(83, 101)
const SEMI_MAJOR := 45.0

var _telemetry: FlightTelemetry
var _phase := 0.0


func _ready() -> void:
	resized.connect(queue_redraw)


func update_from_telemetry(telemetry: FlightTelemetry) -> void:
	_telemetry = telemetry
	queue_redraw()


func _process(delta: float) -> void:
	if _telemetry != null and _telemetry.has_bound_orbit:
		_phase = fposmod(_phase + delta * 1.15, TAU)
		queue_redraw()


func _draw() -> void:
	var layout := Vector2(166, 197)
	var fit := minf(size.x / layout.x, size.y / layout.y)
	if fit <= 0.0:
		return
	draw_set_transform((size - layout * fit) * 0.5, 0, Vector2.ONE * fit)
	draw_rect(Rect2(Vector2.ZERO, layout), Color("#202a33"))
	draw_rect(Rect2(2, 2, 162, 193), Color("#09131b"))
	draw_rect(Rect2(2, 2, 162, 29), Color("#19242d"))
	_label(21, "04 / ORBIT PROFILE", 13, PE)
	var available := _telemetry != null and _telemetry.has_bound_orbit
	var eccentricity := 0.32
	if available:
		var radius := _telemetry.moon_radius_m if _telemetry.body_id == "moon" else _telemetry.earth_radius_m
		var near_radius := radius + _telemetry.periapsis_altitude_m
		var far_radius := radius + _telemetry.apoapsis_altitude_m
		eccentricity = clampf((far_radius - near_radius) / maxf(far_radius + near_radius, 1.0), 0.10, 0.77)
	var minor := SEMI_MAJOR * sqrt(1.0 - eccentricity * eccentricity)
	var orbit := PackedVector2Array()
	for index in 65:
		orbit.append(_orbit_point(index * TAU / 64.0, minor))
	draw_polyline(orbit, Color("#4c7181") if available else Color("#304552"), 1.5, true)
	var planet := CENTER + Vector2(0.0, SEMI_MAJOR * eccentricity)
	draw_circle(planet, 13, Color("#214659"), true, -1, true)
	draw_arc(planet, 13, 0, TAU, 32, Color("#5c92a5"), 1, true)
	draw_arc(planet, 8, -2.55, -0.55, 12, Color("#5690a0"), 1, true)
	if not available:
		_label(176, "AWAITING ORBIT", 12, Color("#8097a3"))
		return
	draw_circle(CENTER - Vector2(0, SEMI_MAJOR), 3.5, AP, true, -1, true)
	draw_circle(CENTER + Vector2(0, SEMI_MAJOR), 3.5, PE, true, -1, true)
	var tracer := _orbit_point(_phase, minor)
	draw_circle(tracer, 7.0, Color(0.64, 0.90, 1.0, 0.19), true, -1, true)
	draw_circle(tracer, 2.8, Color("#e2faff"), true, -1, true)
	_label(47, "AP  %.1f km" % (_telemetry.apoapsis_altitude_m / 1000.0), 13, AP)
	_label(173, "PE  %.1f km" % (_telemetry.periapsis_altitude_m / 1000.0), 13, PE)


func _orbit_point(angle: float, minor: float) -> Vector2:
	return CENTER + Vector2(sin(angle) * minor, -cos(angle) * SEMI_MAJOR)


func _label(y: float, value: String, font_size: int, color: Color) -> void:
	draw_string(MONO, Vector2(0, y), value, HORIZONTAL_ALIGNMENT_CENTER, 166, font_size, color)
