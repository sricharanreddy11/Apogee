class_name FlightHud
extends Label


func update_from_telemetry(telemetry: FlightTelemetry) -> void:
	text = "Altitude %.1f km  |  Speed %.0f m/s  |  Fuel %.0f%%\nStage %d  |  Time %.1f s" % [
		telemetry.altitude_m / 1000.0, telemetry.speed_mps,
		clampf(telemetry.fuel_fraction, 0.0, 1.0) * 100.0,
		telemetry.active_stage + 1, telemetry.elapsed_time_s,
	]
