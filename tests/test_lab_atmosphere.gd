extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var mission := MissionCatalog.new().load_mission("M01")
	var builder: BuilderController = load("res://scenes/builder/rocket_builder.tscn").instantiate()
	builder.setup(mission)
	root.add_child(builder)
	await process_frame
	var lab: Control = builder.get_node("%LabAtmosphere")
	var preview: Control = builder.get_node("%RocketPreview")
	check(lab.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Bay lighting leaves drag and drop unobstructed.")
	var sign := lab.get_node("NeonSign") as Control
	check(lab.get_index() < preview.get_index() and lab.get_child_count() == 1, "Only the neon sign appears on the ambient layer behind the rocket.")
	check(sign.accessibility_name.contains("APOGEE LABS") and sign.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The original neon sign is restored without blocking the assembly.")
	check(sign.position.y < lab.size.y * 0.10, "The sign sits above tall rocket stacks.")
	var tubes := preload("res://scripts/builder/neon_tube_sign.gd")
	check(tubes.letter_power(1, 2.04) < 0.2 and tubes.letter_power(4, 2.04) > 0.8, "An individual tube still blinks while its neighbors stay lit.")
	check(preview.get_node("%Pad").position.y < preview.size.y * 0.72, "The assembly platform sits higher in the bay.")
	builder.get_node("%Reset").pressed.emit()
	var engine: Node2D = preview._pieces.engine.get_node("ComponentFX")
	check(not engine.vapor.emitting, "Loading a preset does not trigger an installation purge.")
	var before := builder.calculate(builder.build_config())
	lab.call("_process", 11.1)
	check(builder.calculate(builder.build_config()) == before, "Bay lighting does not affect the configured rocket.")
	builder.free()
	await process_frame
	print("Lab atmosphere: %d checks, %d failures." % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
