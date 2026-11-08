extends SceneTree
var failures := 0
var checks := 0
const LAB := preload("res://scripts/builder/lab_atmosphere.gd")
const TUBES := preload("res://scripts/builder/neon_tube_sign.gd")
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	check(TUBES.letter_power(1, 0.07) < 0.2 and TUBES.letter_power(0, 0.07) > 0.8, "Selected starter letters blink independently while adjacent tubes remain lit.")
	check(TUBES.letter_power(1, 1.8) > 0.8 and TUBES.letter_power(9, 1.8) > 0.8, "All starters settle into a steady lit sign.")
	check(TUBES.letter_power(1, 2.04) < 0.2 and TUBES.letter_power(4, 2.04) > 0.8, "Occasional glitches affect a single tube instead of flashing the whole title.")
	check(TUBES.letter_power(4, 4.54) < 0.2 and TUBES.letter_power(1, 4.54) > 0.8, "Flickers recur every 2.5 seconds and rotate between letters.")
	check(TUBES.electrical_sound(true).get_length() > 1.0 and TUBES.electrical_sound(false).get_length() < 0.2, "Electrical startup and occasional crackle use bounded audio clips.")
	check(LAB.logo_opacity_at(0.05) < LAB.logo_opacity_at(0.15) and LAB.logo_opacity_at(0.25) < LAB.logo_opacity_at(0.15), "Startup softly brightens, dips, then stabilizes.")
	var gentle := true
	for frame in 1800:
		var t := 1.0 + frame / 60.0
		var opacity := LAB.logo_opacity_at(t)
		gentle = gentle and opacity >= 0.6 and opacity <= 0.96
		gentle = gentle and absf(opacity - LAB.logo_opacity_at(t + 1.0 / 60.0)) < 0.23
	check(gentle, "Idle and occasional flickers stay lit and avoid abrupt full-contrast flashes.")
	var manager := MissionManager.new()
	manager.load_mission("M01")
	var builder: BuilderController = load("res://scenes/builder/rocket_builder.tscn").instantiate()
	builder.setup(manager.definition)
	root.add_child(builder)
	await process_frame
	var lab: Control = builder.get_node("%LabAtmosphere")
	check(lab.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The decorative lab never intercepts building input.")
	check(lab.get_index() < builder.get_node("%RocketPreview").get_index(), "The neon sign and holograms render behind the rocket.")
	check(lab.get_node("NeonSign").accessibility_name.contains("APOGEE LABS"), "The sign uses the requested game name.")
	check(lab.fitted_parts == 0 and not lab.build_ready, "Holograms report an empty build accurately.")
	builder.install_part("pod", "POD_A")
	builder.install_part("tank", "TANK_L")
	builder.install_part("engine", "ENG_L")
	check(lab.fitted_parts == 3 and lab.build_ready, "Holograms reflect actual equipped components and validation.")
	var before := builder.calculate(builder.build_config())
	lab.call("_process", 11.1)
	check(builder.calculate(builder.build_config()) == before, "Ambient animations do not affect the configured rocket.")
	check(lab.get_node("FloorSteamLeft").amount + lab.get_node("FloorSteamRight").amount <= 40, "Floor steam has a fixed small particle budget.")
	builder.free()
	await process_frame
	print("Lab atmosphere: %d checks, %d failures." % [checks, failures])
	quit(0 if failures == 0 else 1)
