extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var projection: Control = load("res://scenes/missions/mission_projection.tscn").instantiate()
	root.add_child(projection)
	for id: String in ["M01", "M02", "M03", "M04"]:
		projection.show_mission(id)
		var visible := 0
		for route in projection.get_node("%ProjectionWorld").get_children():
			if route.visible: visible += 1
		check(visible == 1 and projection.get_node("ProjectionWorld/" + id).visible, "%s selects exactly its own route." % id)
		projection.get_node("%AnimationPlayer").seek(4.0, true)
		projection.call("_process", 0.0)
		var traveler: PathFollow2D = projection.get_node("ProjectionWorld/" + id + "/FlightTrack/Traveler")
		check(is_equal_approx(traveler.progress_ratio, 0.5), "%s keeps the authored route animation." % id)
		var track: AnimationPlayer = projection.get_node("%AnimationPlayer")
		track.seek(7.9, true)
		track.advance(0.2)
		check(traveler.progress_ratio < 0.1, "%s loops automatically without controls." % id)
	check(projection.get_node_or_null("%Replay") == null and projection.get_node_or_null("ReplayFooter") == null, "Projection omits the replay bar and button.")
	projection.show_mission("UNKNOWN")
	check(projection._route == null and not projection.get_node("%AnimationPlayer").is_playing(), "Unknown routes clear the track and stop playback.")
	projection.free()
	await process_frame
	print("Projection visuals: %d checks, %d failures." % [checks, failures])
	quit(0 if failures == 0 else 1)
