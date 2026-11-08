extends Node

const ENDPOINT := "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
const PROMPT := """You are Apogee's mission coach. Diagnose this attempt in at most two short sentences.
Use only the supplied flight record. The confirmed result and reason are authoritative.
Peak altitude, fuel and speed alone cannot establish when the pilot cut thrust, steered or crashed.
Distinguish a hypothesis from an observed cause. On a successful run, describe what worked.
For an orbit mission, use the last recorded bound Earth orbit and longest continuous in-band hold.
Peak altitude is not apoapsis. A bound trajectory may still intersect Earth.
Choose exactly one next_action from the supplied options. Compare the current build with available alternatives before recommending a tank change. Cite exactly one evidence key.
Do not include part advice in the diagnosis. The game displays the selected action and evidence itself."""
const EVIDENCE := {
	"peak_altitude_km": "Peak altitude · %.1f km",
	"peak_speed_mps": "Peak speed · %.0f m/s",
	"fuel_left_kg": "Fuel remaining · %.1f kg",
	"fuel_used_kg": "Fuel used · %.1f kg",
	"flight_time_s": "Flight time · %.1f s",
	"last_bound_periapsis_km": "Last bound Earth periapsis · %.1f km",
	"last_bound_apoapsis_km": "Last bound Earth apoapsis · %.1f km",
	"longest_orbit_hold_s": "Longest hold inside the target band · %.2f s",
}


static func snapshot(result: MissionResult) -> Dictionary:
	var flight := {
		"outcome": "Success" if result.outcome == MissionResult.Outcome.SUCCESS else "Failed",
		"reason": result.reason,
		"peak_altitude_km": snappedf(result.max_altitude_m / 1000.0, 0.1),
		"peak_speed_mps": roundf(result.peak_speed_mps),
		"fuel_left_kg": snappedf(result.fuel_remaining_kg, 0.1),
		"fuel_used_kg": snappedf(result.fuel_used_kg, 0.1),
		"flight_time_s": snappedf(result.flight_time_s, 0.1),
		"stages_used": result.stages_used,
	}
	if result.mission_id == "M02":
		flight["longest_orbit_hold_s"] = result.longest_orbit_hold_s
		flight.merge(result.last_earth_orbit_km)
	return flight


static func compare(previous: Dictionary, current: Dictionary) -> String:
	if previous.is_empty():
		return ""
	if current.has("longest_orbit_hold_s"):
		return "ORBIT HOLD COMPARISON\nPrevious (%s)   %.2f s in band\nCurrent (%s)      %.2f s in band" % [
			previous.outcome, previous.longest_orbit_hold_s, current.outcome, current.longest_orbit_hold_s,
		]
	return "ATTEMPT COMPARISON\nPrevious (%s)   %.1f km · %.1f kg fuel left\nCurrent (%s)      %.1f km · %.1f kg fuel left" % [
		previous.outcome, previous.peak_altitude_km, previous.fuel_left_kg,
		current.outcome, current.peak_altitude_km, current.fuel_left_kg,
	]


static func _api_key() -> String:
	var key := OS.get_environment("GEMINI_API_KEY").strip_edges()
	if not key.is_empty() or not OS.has_feature("editor"):
		return key
	if not FileAccess.file_exists("res://.env"):
		return ""
	for line: String in FileAccess.get_file_as_string("res://.env").split("\n"):
		var separator := line.find("=")
		if separator < 0 or line.left(separator).strip_edges() != "GEMINI_API_KEY":
			continue
		key = line.substr(separator + 1).strip_edges()
		if key.length() >= 2 and ((key.begins_with('"') and key.ends_with('"')) or (key.begins_with("'") and key.ends_with("'"))):
			key = key.substr(1, key.length() - 2)
		return key.strip_edges()
	return ""


func analyze(result: MissionResult, config: RocketConfig, mission: MissionDefinition) -> Dictionary:
	var key := _api_key()
	if key.is_empty():
		return {"error": "Copy .env.example to .env beside project.godot and enter your Gemini API key, or set GEMINI_API_KEY in the environment."}
	var flight := snapshot(result)
	var options := {
		"vertical_ascent": {"tip": "Keep the rocket pointed up during powered ascent, then compare peak altitude."},
		"continue_to_apogee": {"tip": "Let the flight continue until the rocket reaches peak altitude or Mission Control closes the attempt."},
		"repeat_build": {"tip": "Keep this build and repeat the flight to see whether you can reproduce the result."},
	}
	if mission.objective_type == "stable_orbit":
		options.erase("vertical_ascent")
		options.erase("continue_to_apogee")
		options.merge({
			"raise_periapsis": {"tip": "Near apoapsis, burn along your direction of travel and watch periapsis rise toward the 100 km floor."},
			"control_apoapsis": {"tip": "Watch the apoapsis marker during ascent. Ease off thrust before the projected apoapsis passes the 350 km ceiling."},
			"coast_in_band": {"tip": "Once both orbit markers are in the target band, cut thrust and coast for the full two-second hold."},
			"build_sideways_speed": {"tip": "Gradually pitch toward the horizon during ascent to build sideways speed. Watch for a bound track on the orbit display."},
		})
	var build := _build_options(config, mission, options)
	var evidence_keys: Array[String] = []
	for field: String in EVIDENCE:
		if flight.has(field):
			evidence_keys.append(field)
	var input := {
		"objective": mission.objective_text,
		"budget_credits": mission.budget_credits,
		"flight": flight,
		"current_build": build,
		"next_action_options": options,
	}
	var payload := {
		"systemInstruction": {"parts": [{"text": PROMPT}]},
		"contents": [{"parts": [{"text": JSON.stringify(input)}]}],
		"generationConfig": {
			"responseMimeType": "application/json",
			"responseSchema": {
				"type": "OBJECT",
				"required": ["diagnosis", "evidence", "next_action"],
				"properties": {
					"diagnosis": {"type": "STRING"},
					"evidence": {"type": "STRING", "enum": evidence_keys},
					"next_action": {"type": "STRING", "enum": options.keys()},
				},
			},
			"maxOutputTokens": 350,
			"thinkingConfig": {"thinkingBudget": 0},
		},
	}
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	var error := http.request(ENDPOINT, ["Content-Type: application/json", "x-goog-api-key: " + key],
		HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		http.queue_free()
		return {"error": "Could not start the Gemini request. Try again."}
	var response: Array = await http.request_completed
	http.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Gemini could not be reached. Check the connection and try again."}
	match int(response[1]):
		200:
			var body: PackedByteArray = response[3]
			return _format_reply(body.get_string_from_utf8(), flight, options)
		400, 401, 403:
			return {"error": "Gemini rejected the request. Check that the API key has Gemini access."}
		429:
			return {"error": "Gemini is rate limited or out of quota. Try again later."}
	return {"error": "Gemini returned HTTP %d. Try again." % response[1]}


func _build_options(config: RocketConfig, mission: MissionDefinition, options: Dictionary) -> Dictionary:
	if config == null or config.stages.is_empty() or config.stages[0] == null:
		return {}
	var builder := BuilderController.new()
	builder.setup(mission)
	var original := builder.calculate(config)
	var tank_names := {"TANK_S": "Small Tank", "TANK_L": "Large Tank"}
	for tank_id: String in tank_names:
		var candidate := config.copy()
		var tank_ids := candidate.stages[0].tank_ids
		var opposite := "TANK_L" if tank_id == "TANK_S" else "TANK_S"
		var slot := tank_ids.find(opposite)
		var tip: String
		if slot >= 0:
			tank_ids[slot] = tank_id
			tip = "Replace one %s with a %s in Rocket Lab." % [tank_names[opposite], tank_names[tank_id]]
		else:
			tank_ids.append(tank_id)
			tip = "Add one %s in Rocket Lab." % tank_names[tank_id]
		if not builder.validate(candidate, mission).valid:
			continue
		var stats := builder.calculate(candidate)
		if float(stats.launch_twr) <= 1.0:
			continue
		options[tank_id] = {
			"tip": "%s Build estimate · %d CR · %.0f kg wet · %.2f TWR · %.0f m/s ideal Δv." % [
				tip, stats.cost_credits, stats.wet_mass_kg, stats.launch_twr, stats.delta_v_mps,
			],
			"estimated_metrics": stats,
		}
	builder.free()
	var stages: Array[Dictionary] = []
	for installed: StageConfig in config.stages:
		if installed != null:
			stages.append({"engine": installed.engine_id, "tanks": installed.tank_ids})
	return {"stages": stages, "metrics": original}


func _format_reply(body: String, flight: Dictionary, options: Dictionary) -> Dictionary:
	var invalid := {"error": "Gemini did not return a usable analysis. Try again."}
	var envelope: Variant = JSON.parse_string(body)
	if not envelope is Dictionary:
		return invalid
	var candidates: Variant = envelope.get("candidates")
	if not candidates is Array or candidates.is_empty() or not candidates[0] is Dictionary:
		return invalid
	var content: Variant = candidates[0].get("content")
	if not content is Dictionary:
		return invalid
	var parts: Variant = content.get("parts")
	if not parts is Array or parts.is_empty() or not parts[0] is Dictionary:
		return invalid
	var reply: Variant = JSON.parse_string(str(parts[0].get("text", "")))
	if not reply is Dictionary or not reply.get("diagnosis") is String:
		return invalid
	var diagnosis: String = reply.diagnosis.strip_edges()
	var evidence := str(reply.get("evidence", ""))
	var action := str(reply.get("next_action", ""))
	if diagnosis.is_empty() or diagnosis.length() > 450 or not EVIDENCE.has(evidence) or not flight.has(evidence) or not options.has(action):
		return invalid
	return {
		"diagnosis": diagnosis,
		"evidence": EVIDENCE[evidence] % flight[evidence],
		"next_step": options[action].tip,
	}
