class_name FlightTelemetry
extends RefCounted

## Detached value snapshot. Views and mission rules treat each instance as read-only.
var position_m: Vector2 = Vector2.ZERO
var velocity_mps: Vector2 = Vector2.ZERO
var heading_rad: float = 0.0
var angular_velocity_rad_s: float = 0.0
var throttle: float = 0.0
var elapsed_time_s: float = 0.0
var active_stage: int = 0
var mass_kg: float = 0.0
var fuel_remaining_kg: float = 0.0
var fuel_fraction: float = 0.0
var body_id: String = ""
var altitude_m: float = 0.0
var speed_mps: float = 0.0
var radial_speed_mps: float = 0.0
var tangential_speed_mps: float = 0.0
## Read apoapsis/periapsis only when this is true; zero otherwise is a placeholder.
var has_bound_orbit: bool = false
var apoapsis_altitude_m: float = 0.0
var periapsis_altitude_m: float = 0.0
var predicted_impact: bool = false
var status: FlightState.Status = FlightState.Status.READY
var pod_intact: bool = true
var legs_deployed: bool = false
## Earth-centered positions shared by both flight views. The active body's
## position and velocity define the frame for altitude and orbital readouts.
var central_body_position_m: Vector2 = Vector2.ZERO
var central_body_velocity_mps: Vector2 = Vector2.ZERO
var earth_position_m: Vector2 = Vector2.ZERO
var moon_position_m: Vector2 = Vector2.ZERO
var earth_radius_m: float = 0.0
var moon_radius_m: float = 0.0

var fuel_burned_kg: float = 0.0
var contact_body_id: String = ""
var impact_radial_speed_mps: float = 0.0
var impact_tangential_speed_mps: float = 0.0
var impact_tilt_rad: float = 0.0
var apoapsis_position_m: Vector2 = Vector2.ZERO
var periapsis_position_m: Vector2 = Vector2.ZERO
