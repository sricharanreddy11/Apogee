class_name OrbitMap
extends Control

var _telemetry: FlightTelemetry


func update_from_telemetry(telemetry: FlightTelemetry) -> void:
	_telemetry = telemetry
	queue_redraw()


func set_prediction(_prediction: Dictionary) -> void:
	# TODO(Member 3): Draw the prediction received from the physics module.
	pass


func _draw() -> void:
	if _telemetry == null:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.32
	draw_circle(center, radius, Color("#264964"))
	# Placeholder projection. Replace with a meter-to-map transform when flight is live.
	draw_circle(center + _telemetry.position_m.normalized() * radius, 6.0, Color("#59c8e8"))
