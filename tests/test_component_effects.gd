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
	var mission := MissionDefinition.new()
	mission.budget_credits = 10000
	mission.scenario = {"body_id": "earth"}
	var builder: BuilderController = load("res://scenes/builder/rocket_builder.tscn").instantiate()
	builder.setup(mission, true)
	root.add_child(builder)
	builder.install_part("pod", "POD_A")
	builder.install_part("tank", "TANK_L")
	builder.install_part("engine", "ENG_L")
	var preview: Control = builder.get_node("%RocketPreview")
	var pod: Node2D = preview._pieces.pod.get_node("ComponentFX")
	check(pod.kind == "pod" and pod.pulse_level > 0.0, "Equipping a pod produces its own energy pulse.")
	check(not preview._system_ready, "Three categories do not trigger the four-category activation.")
	var tank: Node2D = preview._pieces.tank.get_node("ComponentFX")
	check(tank.fuel_vents.size() == 2 and tank.fuel_vents[0].emitting and tank.fuel_vents[1].emitting, "Fuel installation releases gas from both valves.")
	check(tank.fuel_vents[0].process_material.direction.x < 0 and tank.fuel_vents[1].process_material.direction.x > 0, "Fuel plumes travel outward on opposite sides.")
	var engine: Node2D = preview._pieces.engine.get_node("ComponentFX")
	check(not engine.flame.visible and not engine.sparks.emitting and not engine.burst.emitting and engine.vapor.emitting, "Installing an engine produces smoke without flame or sparks.")
	await create_timer(0.35).timeout
	check(not engine.flame.visible and engine.vapor.emitting, "The engine smoke purge remains visible during installation.")
	await create_timer(0.6).timeout
	check(not engine.vapor.emitting and not engine.flame.visible, "Engine smoke emission stops within one second without igniting.")
	var door := preload("res://scripts/effects/component_effect.gd")._installation_sound("pod")
	var gas := preload("res://scripts/effects/component_effect.gd")._installation_sound("tank")
	var hiss := preload("res://scripts/effects/component_effect.gd")._installation_sound("engine")
	check(is_equal_approx(hiss.get_length(), engine.INSTALLATION_SMOKE_SECONDS) and hiss.data != gas.data, "Engine purge has a distinct hiss synchronized to the smoke.")
	check(audio_energy(hiss, 0.2, 0.3) > 0.01 and audio_energy(hiss, 0.75, 0.8) < audio_energy(hiss, 0.2, 0.3), "Engine hiss sustains the purge and fades at cutoff.")
	check(door.get_length() > 1.0 and gas.get_length() > 0.8 and door.data != gas.data, "Pod door and fuel hiss use distinct timed audio clips.")
	check(audio_energy(door, 0.1, 0.2) > 0.01 and audio_energy(door, 0.55, 0.65) > 0.01, "Pod audio contains both opening and closing movements.")
	check(audio_energy(door, 0.36, 0.46) < 0.001, "Door opening and closing are separated by a short pause.")
	builder.install_part("payload", "PROBE")
	check(preview._system_ready, "Fitting all four categories triggers system activation.")
	var original := builder.calculate(builder.build_config())
	var retained: Sprite2D = preview._pieces.pod
	builder.call("_on_name_changed", "Effects do not change physics")
	check(preview._pieces.pod == retained, "Renaming preserves effect instances and does not replay installation.")
	check(builder.calculate(builder.build_config()) == original, "Effect animation never changes mass, fuel, cost, or thrust.")
	builder.remove_part("payload")
	check(not preview._system_ready and not preview._pieces.has("payload"), "Removing the kit removes its effect and rearms activation.")
	builder.get_node("%Pioneer").pressed.emit()
	var config := builder.build_config()
	config.attachment_ids.append("LEGS")
	config.attachment_ids.append("PROBE")
	var rig := RocketRig.new()
	rig.setup(config)
	root.add_child(rig)
	rig.apply_flight(0, 1.0, false)
	rig.update_effects(1.0, true)
	var engines: Array = rig._effects.filter(func(fx): return fx.kind == "engine")
	var tanks: Array = rig._effects.filter(func(fx): return fx.kind == "tank")
	check(engines[0].flame.visible and not engines[1].flame.visible, "Only the active engine emits fire.")
	check(engines[0].strength > engines[1].strength, "Catalog thrust scales engine brightness and exhaust length.")
	check(engines[0].heat.visible, "Powered flight enables local heat distortion.")
	check(tanks[0].vapor.emitting, "Atmospheric powered flight vents fuel vapor.")
	rig.update_effects(1.0, false)
	check(not tanks[0].vapor.emitting and not engines[0].vapor.emitting, "Vacuum flight suppresses vapor trails and ambient smoke.")
	rig.apply_flight(1, 0.8, true)
	rig.update_effects(0.5, true)
	check(not engines[0].operational and engines[1].flame.visible, "Staging shuts down discarded effects and powers the retained engine.")
	rig.update_effects(0.0, true)
	check(not engines[1].flame.visible and not engines[1].sparks.emitting, "Empty fuel cuts fire and sparks.")
	rig.update_effects(0.5, true, false)
	check(not engines[1].operational and not engines[1].light.enabled, "Landing and crashes disable component effects.")
	rig.free()
	var pad := RocketRig.new()
	pad.effect_context = "launchpad"
	pad.setup(config)
	root.add_child(pad)
	var pad_engines: Array = pad._effects.filter(func(fx): return fx.kind == "engine")
	check(not pad_engines[0].vapor.emitting, "Launchpad stays clear before its pressure check.")
	pad.purge_launchpad()
	check(not pad_engines[0].flame.visible and pad_engines[0].vapor.emitting and not pad_engines[0].burst.emitting, "The launchpad pressure check briefly vents the active engine.")
	check(not pad_engines[1].flame.visible, "Launchpad does not ignite upper stages.")
	pad.free()
	var flight_view: Control = load("res://scenes/flight/flight_view.tscn").instantiate()
	flight_view.setup(config)
	root.add_child(flight_view)
	var cockpit_rig: RocketRig = flight_view.get_node("%RocketRig")
	var vehicle_rig: RocketRig = flight_view.get_node("%VehicleRig")
	cockpit_rig.apply_flight(0, 0.8, false)
	check(cockpit_rig._effects.is_empty() and vehicle_rig._effects.is_empty(), "Both cockpit rigs exclude the ground-station component effects.")
	var exhaust: Sprite2D = cockpit_rig.get_node("Stage1").get_child(0)
	check(exhaust.visible and is_equal_approx(exhaust.self_modulate.a, 1.0), "The cockpit uses the original exhaust sprite.")
	flight_view.free()
	builder.free()
	await process_frame
	await process_frame
	print("Component effects: %d checks, %d failures." % [checks, failures])
	quit(0 if failures == 0 else 1)

func audio_energy(sound: AudioStreamWAV, start: float, finish: float) -> float:
	var energy := 0.0
	for sample in range(int(start * sound.mix_rate), int(finish * sound.mix_rate)):
		energy += absf(float(sound.data.decode_s16(sample * 2)) / 32767.0)
	return energy / ((finish - start) * sound.mix_rate)
