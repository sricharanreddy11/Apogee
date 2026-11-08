extends Node2D

## Presentation-only component layer. It never changes the RocketConfig or physics.
var kind := ""
var part_id := ""
var context := "builder"
var extent := Vector2(64, 64)
var strength := 1.0
var throttle := 0.0
var fuel_fraction := 1.0
var atmospheric := true
var operational := true
var engine_active := true
var clock := 0.0
var pulse_level := 0.0
var tint := Color("75dfff")
var vapor: GPUParticles2D
var burst: GPUParticles2D
var sparks: GPUParticles2D
var light: PointLight2D
var flame: AnimatedSprite2D
var heat: ColorRect
var fuel_vents: Array[GPUParticles2D] = []
var installation_smoke_remaining := 0.0
const INSTALLATION_SMOKE_SECONDS := 0.8
var _pulse_tween: Tween
var _sound: AudioStreamPlayer
static var _frames: SpriteFrames
static var _click: AudioStreamWAV
static var _parts: Dictionary = {}
static var _soft: GradientTexture2D
static var _sounds: Dictionary = {}

static func _soft_texture() -> GradientTexture2D:
	if _soft == null:
		_soft = GradientTexture2D.new()
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
		_soft.gradient = gradient
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1, 0.5)
		_soft.width = 8
		_soft.height = 8
	return _soft

static func _part(id: String) -> Dictionary:
	if _parts.is_empty():
		for row in JsonData.read_object("res://data/parts.json").get("parts", []):
			_parts[String(row.id)] = row
	return _parts.get(id, {})

static func kind_for(id: String) -> String:
	return String(_part(id).get("type", ""))

static func power_for(id: String) -> float:
	var part := _part(id)
	if part.has("fx_strength"):
		return float(part.fx_strength)
	match String(part.get("type", "")):
		"engine": return float(part.get("thrust_n", 145000)) / 145000.0
		"tank": return float(part.get("fuel_capacity_kg", 900)) / 900.0
	return 1.0

func configure(component: String, id: String, bounds: Vector2, mode: String = "builder", power: float = 1.0) -> void:
	kind = component
	part_id = id
	extent = bounds
	context = mode
	strength = clampf(power, 0.2, 2.5)
	tint = {"pod": Color("70cfff"), "tank": Color("95eaff") if id == "TANK_S" else Color("c7c0ff"), "engine": Color("ffb35c"), "payload": Color("7ff4c2"), "legs": Color("c5b3ff"), "decoupler": Color("ffda81")}.get(kind, Color("80e7db"))
	name = "ComponentFX"

func _ready() -> void:
	burst = _particles("EquipBurst", 18, 0.55, tint, 42, 2.0, true)
	burst.position = Vector2.ZERO
	if kind == "tank":
		burst.position.x = extent.x * 0.4
		burst.process_material.direction = Vector3(1, -0.2, 0)
		burst.process_material.spread = 25
		burst.process_material.scale_min = 0.3
		burst.process_material.scale_max = 0.7
	elif kind == "engine":
		burst.position.y = extent.y * 0.5
	light = PointLight2D.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	texture.width = 64
	texture.height = 64
	light.texture = texture
	light.texture_scale = 1.3
	light.color = tint
	add_child(light)
	if kind == "tank":
		for side in [-1, 1]:
			var vent := _particles("InstallVentLeft" if side < 0 else "InstallVentRight", 42, 1.1, Color(0.94, 0.97, 1.0, 0.85), 90, 25, true)
			vent.position = Vector2(side * extent.x * 0.4, -extent.y * 0.1)
			vent.process_material.direction = Vector3(side, -0.1, 0)
			vent.process_material.spread = 25
			vent.process_material.gravity = Vector3(0, -8, 0)
			fuel_vents.append(vent)
		vapor = _particles("FuelVapor", 18, 0.9, Color(0.85, 0.94, 1.0, 0.4).lerp(tint, 0.15), 20, 8.0)
		vapor.position = Vector2(extent.x * 0.39, -extent.y * 0.1)
		vapor.process_material.direction = Vector3(1, -0.3, 0)
		vapor.process_material.gravity = Vector3(0, -5, 0)
		vapor.amount_ratio = clampf(strength / 2.5, 0.25, 1.0)
	if kind == "engine":
		sparks = _particles("EngineSparks", 3, 0.65, tint, 65, 1.3)
		sparks.position.y = extent.y * 0.44
		vapor = _particles("EngineSmoke", 38, 1.3, Color(0.72, 0.78, 0.82, 0.48), 42, 24)
		vapor.position.y = extent.y * 0.75
		vapor.process_material.direction = Vector3(0, 1, 0)
		vapor.process_material.spread = 55
		vapor.process_material.gravity = Vector3(0, -9, 0)
		heat = ColorRect.new()
		heat.name = "HeatShimmer"
		heat.position = Vector2(-20, extent.y * 0.5)
		heat.size = Vector2(40, 75)
		heat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := ShaderMaterial.new()
		shader.shader = preload("res://scripts/effects/heat_shimmer.gdshader")
		heat.material = shader
		add_child(heat)
		flame = AnimatedSprite2D.new()
		flame.name = "AnimatedExhaust"
		flame.sprite_frames = _flame_frames()
		flame.position.y = extent.y * 0.5 + 28
		flame.play()
		add_child(flame)
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -21
	add_child(_sound)
	_update_emission()

func _particles(label: String, count: int, life: float, color: Color, speed: float, particle_size: float, once: bool = false) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.name = label
	particles.emitting = false
	particles.amount = count
	particles.lifetime = life
	particles.one_shot = once
	particles.texture = _soft_texture()
	particles.explosiveness = 1.0 if once else 0.0
	particles.visibility_rect = Rect2(-180, -160, 360, 420)
	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.direction = Vector3(1, 0, 0)
	material.spread = 180
	material.gravity = Vector3.ZERO
	material.initial_velocity_min = speed * 0.4
	material.initial_velocity_max = speed
	material.scale_min = particle_size * 0.5 / 8.0
	material.scale_max = particle_size / 8.0
	var colors := Gradient.new()
	colors.colors = PackedColorArray([color, Color(color, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = colors
	material.color_ramp = ramp
	particles.process_material = material
	add_child(particles)
	return particles

func _exit_tree() -> void:
	if _sound != null:
		_sound.stop()
		_sound.stream = null

func pulse(sound: bool = false) -> void:
	if not is_node_ready():
		return
	if _pulse_tween != null:
		_pulse_tween.kill()
	pulse_level = 1.0
	if kind == "tank":
		for vent in fuel_vents:
			vent.restart()
			vent.emitting = true
	elif kind != "engine" or context != "builder":
		burst.restart()
		burst.emitting = true
	if sound and kind == "engine" and context == "builder":
		installation_smoke_remaining = INSTALLATION_SMOKE_SECONDS
		_update_emission()
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "pulse_level", 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if sound and DisplayServer.get_name() != "headless":
		_sound.stream = _installation_sound(kind)
		_sound.volume_db = -12 if kind == "engine" else (-13 if kind in ["tank", "pod"] else -21)
		_sound.play()

func set_state(power: float, fuel: float, in_atmosphere: bool, enabled: bool, active: bool = true) -> void:
	throttle = clampf(power, 0, 1)
	fuel_fraction = clampf(fuel, 0, 1)
	atmospheric = in_atmosphere
	operational = enabled
	engine_active = active
	if kind == "engine" and (power <= 0.0 or not enabled):
		var sprite := get_parent() as Sprite2D
		if sprite != null:
			sprite.offset.x = 0.0
	_update_emission()

func _update_emission() -> void:
	if not is_node_ready():
		return
	var installation := context == "builder" and installation_smoke_remaining > 0.0
	var firing := operational and engine_active and throttle > 0.0
	if flame != null:
		flame.visible = firing
		var power := throttle
		flame.scale = Vector2(0.65 + power * 0.35, (0.18 + power * 0.9) * strength)
		flame.position.y = extent.y * 0.5 + 32.0 * flame.scale.y
		heat.visible = firing and context != "launchpad"
		heat.material.set_shader_parameter("intensity", power)
	if sparks != null:
		sparks.emitting = firing
	if vapor != null:
		vapor.emitting = operational and ((kind == "tank" and fuel_fraction > 0 and (context == "launchpad" or (context == "flight" and throttle > 0 and atmospheric))) or (kind == "engine" and ((firing and atmospheric) or installation or context == "launchpad")))
	light.enabled = operational

func _process(delta: float) -> void:
	clock += delta
	if installation_smoke_remaining > 0.0:
		installation_smoke_remaining = maxf(0.0, installation_smoke_remaining - delta)
		_update_emission()
	if not operational or not is_visible_in_tree():
		return
	if kind == "engine":
		var sprite := get_parent() as Sprite2D
		if sprite != null:
			sprite.offset.x = sin(clock * 83) * throttle * 0.35
	var glow := 0.08 if kind == "pod" else 0.025
	light.energy = (glow + 0.015 * sin(clock * 3) + pulse_level * 0.18) * minf(strength, 1.4)
	if kind == "engine" and flame != null and flame.visible:
		# Move the effect layer only; collision geometry and component sprites stay stable.
		position.x = Vector2(get_meta("home", Vector2.ZERO)).x + sin(clock * 83) * throttle * 0.3
	queue_redraw()

func _draw() -> void:
	if not operational:
		return
	var half := extent * 0.5
	var alpha := 0.18 + pulse_level * 0.55
	if pulse_level > 0:
		draw_arc(Vector2.ZERO, half.x + (1 - pulse_level) * 32, 0, TAU, 48, Color(tint, pulse_level * 0.65), 1.5, true)
	match kind:
		"pod":
			var cockpit := Vector2(0, extent.y * 0.05)
			draw_rect(Rect2(cockpit - Vector2(9, 4), Vector2(18, 8)), Color(tint, 0.35 + 0.2 * sin(clock * 3)))
			draw_arc(Vector2(0, -half.y * 0.5), half.x * 0.92, PI * 1.05, TAU * 1.48, 48, Color(tint, alpha), 1.5, true)
			for side in [-1, 1]:
				draw_circle(Vector2(side * half.x * 0.65, half.y * 0.65), 1.6, Color(tint, 0.95 if fmod(clock + side * 0.5, 1.4) < 0.25 else 0.15))
		"tank":
			for index in 4:
				var angle := clock * 1.1 + index * TAU / 4
				draw_circle(Vector2(cos(angle) * (half.x + 5), sin(angle) * half.y * 0.7), 1.2, Color(tint, 0.55))
			draw_rect(Rect2(-3, -half.y * 0.2, 6, half.y * 0.5), Color("183442"))
			draw_rect(Rect2(-2, half.y * 0.3 - half.y * 0.5 * fuel_fraction, 4, half.y * 0.5 * fuel_fraction), Color(tint, 0.65 + sin(clock * 3) * 0.15))
		"engine":
			if flame != null and flame.visible:
				for index in 3:
					var y := half.y + 8 + index * 12
					draw_arc(Vector2(sin(clock * 13 + index) * 2, y), 9 + index * 2, 0, PI, 12, Color(tint, 0.12), 1, true)
		"payload", "decoupler", "legs":
			var phase := fmod(clock * 0.35, 1.0)
			if kind == "payload":
				draw_arc(Vector2.ZERO, 14 + phase * 46, 0, TAU, 48, Color(tint, (1 - phase) * 0.3), 1, true)
				var beam := Vector2.from_angle(clock * 0.6) * 55
				draw_line(Vector2.ZERO, beam, Color(tint, 0.24), 1, true)
			elif kind == "decoupler":
				draw_arc(Vector2.ZERO, half.x + 8 + sin(clock * 2) * 2, 0, TAU, 48, Color(tint, 0.2), 1, true)
			else:
				for side in [-1, 1]:
					draw_line(Vector2(side * half.x * 0.5, 0), Vector2(side * (half.x * 0.5 + 8 + sin(clock * 5) * 3), 6), Color(tint, 0.35), 2, true)
			for index in 3:
				var pos := Vector2.from_angle(clock + index * TAU / 3) * (half.x + 12)
				draw_rect(Rect2(pos - Vector2(1.5, 1.5), Vector2(3, 3)), Color(tint, 0.65))

static func _flame_frames() -> SpriteFrames:
	if _frames != null:
		return _frames
	_frames = SpriteFrames.new()
	_frames.set_animation_speed("default", 18)
	for frame in 6:
		var image := Image.create(24, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			var ratio := float(y) / 64
			var width := (1 - ratio) * (8 + sin(y * 0.45 + frame * 1.7) * 1.5)
			for x in 24:
				var offset := absf(x - 11.5 + sin(y * 0.18 + frame) * ratio * 2)
				if offset < width:
					image.set_pixel(x, y, Color("fff4c1") if offset < width * 0.4 else (Color("ffd17b") if offset < width * 0.7 else Color("ff854e")))
		_frames.add_frame("default", ImageTexture.create_from_image(image))
	return _frames

static func _installation_sound(component: String = "kit") -> AudioStreamWAV:
	if component in ["pod", "tank", "engine"]:
		if _sounds.has(component):
			return _sounds[component]
		var rate := 22050
		var duration := INSTALLATION_SMOKE_SECONDS if component == "engine" else (1.05 if component == "pod" else 0.85)
		var data := PackedByteArray()
		data.resize(int(rate * duration) * 2)
		var random := RandomNumberGenerator.new()
		random.seed = 7249
		var smooth := 0.0
		for sample in int(rate * duration):
			var t := float(sample) / rate
			var noise := random.randf_range(-1, 1)
			smooth = lerpf(smooth, noise, 0.16)
			var value := 0.0
			if component == "tank":
				# Fast valve opening, sustained air hiss, soft pressure decay.
				var envelope := minf(t / 0.025, 1) * pow(maxf(0, 1 - t / duration), 0.7)
				value = (noise - smooth) * envelope * 0.42
			elif component == "engine":
				# Pressurized nozzle purge: a short airy hiss, with no combustion tone.
				var envelope := minf(t / 0.025, 1.0) * minf((duration - t) / 0.18, 1.0)
				value = (noise - smooth * 0.7) * 0.34 * envelope
			else:
				# Two distinct servo motions, then a short metallic closing latch.
				var opening := sin(PI * clampf(t / 0.34, 0, 1)) if t < 0.34 else 0.0
				var closing := sin(PI * clampf((t - 0.48) / 0.34, 0, 1)) if t >= 0.48 and t < 0.82 else 0.0
				value = opening * (sin(TAU * (380 * t - 140 * t * t)) * 0.18 + smooth * 0.22)
				value += closing * (sin(TAU * (220 * t + 90 * t * t)) * 0.2 + smooth * 0.22)
				if t >= 0.82:
					value += (sin(TAU * 1250 * (t - 0.82)) * 0.32 + noise * 0.1) * exp(-(t - 0.82) * 38)
			data.encode_s16(sample * 2, int(clampf(value, -1, 1) * 32767))
		var sound := AudioStreamWAV.new()
		sound.format = AudioStreamWAV.FORMAT_16_BITS
		sound.mix_rate = rate
		sound.data = data
		_sounds[component] = sound
		return sound
	if _click != null:
		return _click
	var data := PackedByteArray()
	var rate := 22050
	for sample in int(rate * 0.14):
		var t := float(sample) / rate
		var value := (sin(TAU * 1450 * t) + 0.4 * sin(TAU * 2330 * t)) * exp(-t * 45) * 0.25
		data.append(0)
		data.append(0)
		data.encode_s16(sample * 2, int(clampf(value, -1, 1) * 32767))
	_click = AudioStreamWAV.new()
	_click.format = AudioStreamWAV.FORMAT_16_BITS
	_click.mix_rate = rate
	_click.data = data
	return _click
