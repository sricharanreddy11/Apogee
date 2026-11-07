class_name FlightHud
extends Label


func update_from_telemetry(telemetry: FlightTelemetry) -> void:
	text = "Altitude %.1f km  |  Speed %.0f m/s  |  Fuel %.0f%%" % [
		telemetry.altitude_m / 1000.0, telemetry.speed_mps, telemetry.fuel_fraction * 100.0,
	]
