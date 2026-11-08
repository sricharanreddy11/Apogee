class_name FlightHud
extends Label


func update_from_telemetry(telemetry: FlightTelemetry) -> void:
	var status_names := ["READY", "FLYING", "LANDED", "CRASHED"]
	var status_text: String = status_names[telemetry.status]
	var altitude := "%.1f m" % telemetry.altitude_m if absf(telemetry.altitude_m) < 1000.0 else "%.1f km" % (telemetry.altitude_m / 1000.0)
	text = "ALT    %s\nVEL    %.0f m/s\nFUEL   %.0f%%\nSTAGE  %d\nT+     %.1f s\n%s" % [
		altitude, telemetry.speed_mps,
		clampf(telemetry.fuel_fraction, 0.0, 1.0) * 100.0,
		telemetry.active_stage + 1, telemetry.elapsed_time_s, status_text,
	]
	if telemetry.has_bound_orbit:
		text += "\nAP     %.1f km\nPE     %.1f km" % [
			telemetry.apoapsis_altitude_m / 1000.0,
			telemetry.periapsis_altitude_m / 1000.0,
		]
