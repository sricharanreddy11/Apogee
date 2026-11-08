class_name TrajectoryPrediction
extends RefCounted

## Detached output from Member 1's unpowered-coast predictor.
## All positions use the same Earth-centered inertial frame as FlightTelemetry.
## Times are absolute elapsed simulation seconds, not offsets from this snapshot.
var body_id: String = ""
var elapsed_time_s: float = 0.0
var positions_m: PackedVector2Array = PackedVector2Array()
var sample_times_s: PackedFloat64Array = PackedFloat64Array()
## When true, both arrays have equal lengths and strictly increasing sample times.
## Consumers must ignore the arrays while false.
var valid: bool = false
