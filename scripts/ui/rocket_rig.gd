class_name RocketRig
extends Node2D

const MANIFEST := "res://assets/rockets/manifest.json"
const COMPONENT_FX := preload("res://scripts/effects/component_effect.gd")

var _catalog: Dictionary
var _textures: Dictionary = {}
var _stages: Array[Node2D] = []
var _flames: Array[Sprite2D] = []
var _legs: Sprite2D
var _legs_stowed_y := 0.0
var _legs_deployed := false
var _active := 0
var _throttle := 0.0
var _clock := 0.0
var height_px := 0.0
@export var effect_context := "flight"
var _effects: Array[Node2D] = []


func setup(config: RocketConfig) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_stages.clear()
	_effects.clear()
	_flames.clear()
	_legs = null
	_legs_deployed = false
	_active = 0
	_throttle = 0.0
	height_px = 0.0
	set_meta("config_stages", config.stages.duplicate() if config != null else [])
	if _catalog.is_empty():
		_catalog = JsonData.read_object(MANIFEST).get("parts", {})
	if config == null:
		return
	var cursor := 0.0
	for stage_index in config.stages.size():
		var stage_config := config.stages[stage_index]
		var stage_art := Node2D.new()
		stage_art.name = "Stage%d" % (stage_index + 1)
		stage_art.position.y = cursor
		add_child(stage_art)
		_stages.append(stage_art)
		var engine_id := "" if stage_config == null else stage_config.engine_id
		_flames.append(_add_flame(stage_art, engine_id))
		if stage_config == null:
			continue
		var upper := stage_index == config.stages.size() - 1
		var local_y := _stack_part(stage_art, engine_id, 0.0)
		if upper and config.attachment_ids.has("LEGS"):
			_legs = _sprite(stage_art, "res://assets/rockets/legs_folded.svg")
			_legs_stowed_y = local_y
			_legs.position.y = _legs_stowed_y
			_add_effect(_legs, "LEGS", true, stage_index)
		for tank_id in stage_config.tank_ids:
			local_y = _stack_part(stage_art, tank_id, local_y)
		if stage_index == 0 and config.stages.size() > 1 and config.attachment_ids.has("DECOUPLER"):
			local_y = _stack_part(stage_art, "DECOUPLER", local_y)
		cursor += local_y
	if config.attachment_ids.has("PROBE"):
		cursor = _stack_part(self, "PROBE", cursor)
	cursor = _stack_part(self, config.command_pod_id, cursor)
	height_px = -cursor
	_apply_flame()
	update_effects(1.0, true)


## Length of the surviving stack, measured along its centerline.
func get_active_stack_height_px() -> float:
	var base_y := _stages[_active].position.y if not _stages.is_empty() else 0.0
	return height_px + base_y


func get_active_stack_center() -> Vector2:
	return Vector2(0.0, -height_px + get_active_stack_height_px() * 0.5)


## Furthest-down point in the local surface frame, relative to the stack midpoint.
func get_contact_depth_px(heading: float) -> float:
	var pivot := get_active_stack_center()
	var base_y := _stages[_active].position.y if not _stages.is_empty() else 0.0
	var depth := 0.0
	for x: float in [-27.0, 27.0]:
		depth = maxf(depth, (Vector2(x, base_y) - pivot).rotated(heading).y)
		depth = maxf(depth, (Vector2(x, -height_px) - pivot).rotated(heading).y)
	if _legs_deployed:
		for x: float in [-53.0, 53.0]:
			var foot := Vector2(x, _stages[-1].position.y + _legs.position.y + 31.0)
			depth = maxf(depth, (foot - pivot).rotated(heading).y)
	return depth


func _stack_part(parent: Node2D, part_id: String, y: float) -> float:
	var definition: Dictionary = _catalog.get(part_id, {})
	if definition.is_empty():
		return y
	var texture := _texture(String(definition.sprite))
	if texture == null:
		return y
	var top: Array = definition.attachment_top_px
	var bottom: Array = definition.attachment_bottom_px
	var sprite := _sprite(parent, String(definition.sprite))
	sprite.centered = false
	sprite.position = Vector2(-float(bottom[0]), y - float(bottom[1]))
	_add_effect(sprite, part_id, false, _stages.find(parent))
	return sprite.position.y + float(top[1])


func _add_effect(sprite: Sprite2D, part_id: String, centered: bool, stage_index: int) -> void:
	if effect_context == "cockpit" or sprite.texture == null:
		return
	var effect := COMPONENT_FX.new()
	var kind := COMPONENT_FX.kind_for(part_id)
	if kind.is_empty():
		effect.free()
		return
	effect.configure(kind, part_id, sprite.texture.get_size(), effect_context, COMPONENT_FX.power_for(part_id))
	if not centered:
		effect.position = sprite.texture.get_size() * 0.5
	effect.set_meta("home", effect.position)
	effect.set_meta("stage", stage_index)
	sprite.add_child(effect)
	_effects.append(effect)


func update_effects(fuel: float, in_atmosphere: bool, enabled: bool = true) -> void:
	for effect in _effects:
		var stage_index := int(effect.get_meta("stage", -1))
		var retained := stage_index < 0 or stage_index >= _active
		var firing := _throttle if stage_index == _active else 0.0
		effect.set_state(firing if fuel > 0.0 else 0.0, fuel, in_atmosphere, enabled and retained, stage_index == _active)


func purge_launchpad() -> void:
	for effect in _effects:
		if effect.kind == "engine" and int(effect.get_meta("stage", -1)) == _active:
			effect.pulse(true)


func _add_flame(parent: Node2D, engine_id: String) -> Sprite2D:
	var flame := _sprite(parent, "res://assets/rockets/flame.svg")
	flame.offset.y = 48.0
	flame.visible = false
	# Keep the legacy exhaust anchor for hit tests and integration contracts.
	# The component's AnimatedSprite2D supplies the visible flame.
	if effect_context != "cockpit":
		flame.self_modulate.a = 0.0
	var engine: Dictionary = _catalog.get(engine_id, {})
	var exhaust: Array = engine.get("exhaust_origin_px", [])
	var attachment: Array = engine.get("attachment_bottom_px", [])
	if not exhaust.is_empty():
		flame.position = Vector2(float(exhaust[0]) - float(attachment[0]), float(exhaust[1]) - float(attachment[1]))
	flame.set_meta("fitted", not exhaust.is_empty())
	return flame


func _texture(path: String) -> Texture2D:
	if not _textures.has(path) and ResourceLoader.exists(path):
		_textures[path] = load(path)
	return _textures.get(path) as Texture2D


func _sprite(parent: Node2D, path: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _texture(path)
	sprite.set_meta("asset_path", path)
	parent.add_child(sprite)
	return sprite


## Returns the interactive flight component under a point in rig-local space.
## Only the active engine and the separator are controls; artwork remains passive.
func hit_test_flight_component(local_point: Vector2) -> String:
	if _active >= 0 and _active < _stages.size() and _config_stage_exists(_active):
		var stage_config: StageConfig = get_meta("config_stages")[_active]
		var definition: Dictionary = _catalog.get(stage_config.engine_id, {})
		var engine_path := String(definition.get("sprite", ""))
		if not engine_path.is_empty() and _point_hits_asset(_stages[_active], local_point, engine_path):
			return "engine"
	if _active == 0 and _point_hits_asset(_stages[0] if not _stages.is_empty() else null, local_point, "res://assets/rockets/decoupler.svg"):
		return "stage"
	return ""


func _config_stage_exists(index: int) -> bool:
	var stages: Array = get_meta("config_stages", [])
	return index >= 0 and index < stages.size() and stages[index] != null


func _point_hits_asset(parent: Node2D, local_point: Vector2, asset_path: String) -> bool:
	if parent == null:
		return false
	var point_in_stage := local_point - parent.position
	for child in parent.get_children():
		if child is Sprite2D and child.get_meta("asset_path", "") == asset_path:
			var sprite := child as Sprite2D
			if sprite.texture == null:
				continue
			var sprite_size := sprite.texture.get_size() * sprite.scale
			var top_left := sprite.position - (sprite_size * 0.5 if sprite.centered else Vector2.ZERO)
			if Rect2(top_left, sprite_size).grow(8.0).has_point(point_in_stage):
				return true
	return false


## Presentation only. The caller supplies the active stage, throttle and leg state.
func apply_flight(active_stage: int, throttle: float, legs_deployed: bool) -> void:
	if active_stage < 0 or active_stage >= _stages.size():
		return
	if active_stage < _active:
		return
	for index in range(_active, active_stage):
		_drop_stage(_stages[index])
	_active = active_stage
	_throttle = clampf(throttle, 0.0, 1.0)
	if _legs != null:
		_legs_deployed = legs_deployed
		_legs.position.y = -25.0 if legs_deployed else _legs_stowed_y
		_legs.texture = _texture("res://assets/rockets/legs.svg" if legs_deployed else "res://assets/rockets/legs_folded.svg")
	_apply_flame()
	update_effects(1.0, true)


func _drop_stage(stage_art: Node2D) -> void:
	if not is_inside_tree():
		stage_art.hide()
		return
	var sparks := CPUParticles2D.new()
	sparks.one_shot = true
	sparks.emitting = false
	sparks.amount = 16
	sparks.lifetime = 0.33
	sparks.explosiveness = 0.88
	sparks.spread = 180.0
	sparks.gravity = Vector2(0, 100)
	sparks.initial_velocity_min = 42.0
	sparks.initial_velocity_max = 110.0
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 4.0
	sparks.color = Color("#ffc875")
	sparks.position.y = _stages[_active + 1].position.y
	add_child(sparks)
	sparks.finished.connect(sparks.queue_free)
	sparks.emitting = true
	var tween := create_tween().set_parallel()
	tween.tween_property(stage_art, "position", stage_art.position + Vector2(46, 135), 0.62).set_ease(Tween.EASE_IN)
	tween.tween_property(stage_art, "rotation", 0.25, 0.62)
	tween.tween_property(stage_art, "modulate:a", 0.0, 0.62)
	tween.chain().tween_callback(stage_art.hide)


func _process(delta: float) -> void:
	if _throttle > 0.0:
		_clock += delta
		_apply_flame()


func _apply_flame() -> void:
	for index in _flames.size():
		var flame := _flames[index]
		flame.visible = index == _active and _throttle > 0.0 and flame.get_meta("fitted")
		if flame.visible:
			flame.scale = Vector2(0.5 + _throttle * 0.45, (0.3 + _throttle * 0.7) * (0.9 + sin(_clock * 71.0) * 0.10))
