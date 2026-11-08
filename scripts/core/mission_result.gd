class_name MissionResult
extends RefCounted

enum Outcome { IN_PROGRESS, SUCCESS, FAILURE }

var mission_id: String = ""
var outcome: Outcome = Outcome.IN_PROGRESS
var reason: String = ""
var flight_time_s: float = 0.0
var max_altitude_m: float = 0.0
var peak_speed_mps: float = 0.0
var fuel_used_kg: float = 0.0
var fuel_remaining_kg: float = 0.0
var launch_cost_credits: int = 0
var stages_used: int = 0
var score: int = 0
var awarded_credits: int = 0
var discovery_ids: Array[String] = []

var advice: String = ""
var closest_approach_m: float = -1.0
var contact_body_id: String = ""
var touchdown_vertical_mps: float = 0.0
var touchdown_horizontal_mps: float = 0.0
var touchdown_tilt_deg: float = 0.0
