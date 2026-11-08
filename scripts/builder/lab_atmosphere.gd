extends Control

## Decorative lab layer: no input, physics, configuration, or navigation ownership.
const CYAN := Color("62dbef")
const PURPLE := Color("a083e5")
var clock := 0.0
var fitted_parts := 0
var build_ready := false
var _sign: Control
var _steam: Array[GPUParticles2D] = []

static func logo_opacity_at(seconds: float) -> float:
	if seconds < 0.12:
		return 0.3
	if seconds < 0.22:
		return 0.62
	if seconds < 0.32:
		return 0.44
	if seconds < 0.44:
		return 0.78
	if seconds < 0.54:
		return 0.63
	var idle := 0.88 + sin(seconds * TAU / 5.5) * 0.07
	# A single shallow dip every eleven seconds, never a full blackout.
	if seconds > 5.0 and fmod(seconds, 11.0) < 0.12:
		idle *= 0.78
	return idle

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sign = preload("res://scripts/builder/neon_tube_sign.gd").new()
	_sign.name = "NeonSign"
	add_child(_sign)
	for side in [-1, 1]:
		var steam := GPUParticles2D.new()
		steam.name = "FloorSteamLeft" if side < 0 else "FloorSteamRight"
		steam.amount = 18
		steam.lifetime = 4.0
		steam.preprocess = 2.0
		steam.local_coords = true
		steam.visibility_rect = Rect2(-140, -70, 280, 140)
		var material := ParticleProcessMaterial.new()
		material.particle_flag_disable_z = true
		material.direction = Vector3(side, -0.12, 0)
		material.spread = 16
		material.gravity = Vector3(0, -1, 0)
		material.initial_velocity_min = 5
		material.initial_velocity_max = 12
		material.scale_min = 3
		material.scale_max = 7
		var colors := Gradient.new()
		colors.offsets = PackedFloat32Array([0, 0.25, 1])
		colors.colors = PackedColorArray([Color(0.4, 0.7, 0.9, 0), Color(0.4, 0.7, 0.9, 0.13), Color(0.5, 0.5, 0.8, 0)])
		var ramp := GradientTexture1D.new()
		ramp.gradient = colors
		material.color_ramp = ramp
		steam.process_material = material
		steam.texture = preload("res://scripts/effects/component_effect.gd")._soft_texture()
		add_child(steam)
		_steam.append(steam)
	resized.connect(_layout)
	_layout()

func set_build_state(count: int, ready: bool) -> void:
	fitted_parts = count
	build_ready = ready
	queue_redraw()

func _layout() -> void:
	var ratio := size / Vector2(1280, 720)
	_sign.position = Vector2(430, 182) * ratio
	_sign.scale = ratio
	for index in _steam.size():
		_steam[index].position = Vector2(530 if index == 0 else 750, 568) * ratio
		_steam[index].scale = ratio

func _process(delta: float) -> void:
	clock += delta
	_sign.advance(clock)
	queue_redraw()

func _draw() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(1280, 720))
	var neon := logo_opacity_at(clock)
	# The sign frame remains behind the actual assembly; broad strokes supply soft bloom.
	var sign := Rect2(436, 177, 408, 75)
	for width in [8.0, 3.0, 1.0]:
		draw_rect(sign, Color(CYAN, neon * (0.025 if width > 3 else 0.15)), false, width)
	draw_line(Vector2(455, 258), Vector2(825, 258), Color(PURPLE, 0.22), 1, true)
	var font := get_theme_default_font()
	draw_string(font, Vector2(534, 274), "O R B I T A L   E N G I N E E R I N G", HORIZONTAL_ALIGNMENT_LEFT, 220, 10, Color(CYAN, 0.42))
	# Low-contrast, non-interactive holograms use the real assembly count/readiness.
	_hologram(Rect2(441, 344, 112, 108), CYAN)
	draw_string(font, Vector2(451, 363), "ASSEMBLY BUS", HORIZONTAL_ALIGNMENT_LEFT, 94, 10, Color(CYAN, 0.7))
	draw_string(font, Vector2(451, 381), "%02d PARTS FITTED" % fitted_parts, HORIZONTAL_ALIGNMENT_LEFT, 94, 10, Color(CYAN, 0.6))
	for index in 5:
		var y := 395.0 + index * 9
		draw_line(Vector2(451, y), Vector2(458 + fmod(index * 19 + fitted_parts * 8, 76), y), Color(CYAN, 0.25), 2)
	_hologram(Rect2(746, 346, 104, 100), PURPLE)
	draw_string(font, Vector2(757, 365), "SYSTEM LINK", HORIZONTAL_ALIGNMENT_LEFT, 83, 10, Color(PURPLE, 0.7))
	draw_string(font, Vector2(757, 383), "READY" if build_ready else "ASSEMBLING", HORIZONTAL_ALIGNMENT_LEFT, 83, 10, Color(PURPLE, 0.6))
	var points := PackedVector2Array()
	for index in 24:
		points.append(Vector2(757 + index * 3.5, 414 + sin(index * 0.5 - clock * 1.2) * 7))
	draw_polyline(points, Color(PURPLE, 0.4), 1, true)
	# Gentle segmented platform illumination.
	for side in [-1, 1]:
		var center := Vector2(640, 553)
		var start := 0.18 if side > 0 else PI + 0.18
		var points_arc := PackedVector2Array()
		for index in 28:
			var angle := start + index * 0.032
			points_arc.append(center + Vector2(cos(angle) * 145, sin(angle) * 25))
		draw_polyline(points_arc, Color(CYAN if side < 0 else PURPLE, 0.3 + sin(clock * 1.2) * 0.05), 2, true)

func _hologram(rect: Rect2, tint: Color) -> void:
	draw_rect(rect, Color(0.025, 0.08, 0.13, 0.62))
	draw_rect(rect, Color(tint, 0.25), false, 1)
	draw_line(rect.position, rect.position + Vector2(22, 0), Color(tint, 0.7), 2)
	var y := rect.position.y + fmod(clock * 12, rect.size.y)
	draw_line(Vector2(rect.position.x + 2, y), Vector2(rect.end.x - 2, y), Color(tint, 0.07), 1)
