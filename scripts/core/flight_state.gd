class_name FlightState
extends RefCounted

enum Status { READY, FLYING, LANDED, CRASHED }

var position_m: Vector2 = Vector2.ZERO
var velocity_mps: Vector2 = Vector2.ZERO
## Zero is up. Positive angles turn clockwise.
var heading_rad: float = 0.0
var throttle: float = 0.0
var elapsed_time_s: float = 0.0
var active_stage: int = 0
var mass_kg: float = 0.0
var stage_fuel_kg: Array[float] = []
var status: Status = Status.READY
var pod_intact: bool = true
var legs_deployed: bool = false
