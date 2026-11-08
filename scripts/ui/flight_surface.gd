extends Node2D

const DETAIL_SPACING_M := 24.0
const DETAIL_COUNT := 40

var _craters: Array[Sprite2D] = []


func _ready() -> void:
	var texture := load("res://assets/mission_control/lunar_crater.svg") as Texture2D
	for index in DETAIL_COUNT:
		var crater := Sprite2D.new()
		crater.texture = texture
		%Detail.add_child(crater)
		_craters.append(crater)


func update_surface(radius_m: float, altitude_m: float, longitude_rad: float, view_m: Vector2, camera_y: float, lunar: bool, landing: bool) -> void:
	%Terrain.visible = radius_m > 0.0
	%Horizon.visible = %Terrain.visible
	%Detail.visible = false
	%ContactMark.visible = false
	if radius_m <= 0.0:
		return
	%Terrain.color = Color("#526077") if lunar else Color("#214c64")
	%Horizon.default_color = Color("#a3aec3") if lunar else Color("#5dd0ed")
	%Horizon.width = view_m.y / 410.0
	var outline := PackedVector2Array()
	var fill := PackedVector2Array()
	var span := view_m.x * 0.56
	if span >= radius_m * 0.88:
		for index in 181:
			var angle := TAU * float(index) / 180.0
			outline.append(Vector2(sin(angle) * radius_m, altitude_m + (1.0 - cos(angle)) * radius_m))
		fill = outline.slice(0, outline.size() - 1)
	else:
		for index in 49:
			var x := lerpf(-span, span, float(index) / 48.0)
			outline.append(Vector2(x, altitude_m + _sagitta(x, radius_m)))
		fill = outline.duplicate()
		var bottom := maxf(camera_y + view_m.y, fill[-1].y + 1.0)
		fill.append(Vector2(span, bottom))
		fill.append(Vector2(-span, bottom))
	%Horizon.points = outline
	%Terrain.polygon = fill
	if lunar and view_m.x <= DETAIL_SPACING_M * (DETAIL_COUNT - 4):
		_place_craters(radius_m, altitude_m, longitude_rad)
	if landing and altitude_m < 160.0:
		%ContactMark.visible = true
		%ContactMark.position = Vector2(0.0, altitude_m)
		%ContactMark.scale = Vector2.ONE * (view_m.y / 440.0)


func _place_craters(radius_m: float, altitude_m: float, longitude_rad: float) -> void:
	%Detail.visible = true
	var track_m := longitude_rad * radius_m
	var first := floori(track_m / DETAIL_SPACING_M) - (DETAIL_COUNT >> 1)
	for index in _craters.size():
		var cell := first + index
		var offset := (float(cell) + 0.5) * DETAIL_SPACING_M - track_m
		var angle := offset / radius_m
		var x := sin(angle) * radius_m
		var crater := _craters[index]
		crater.position = Vector2(x, altitude_m + _sagitta(x, radius_m) + 3.0 + float(posmod(cell * 7, 9)))
		crater.rotation = angle
		crater.scale = Vector2.ONE * (0.08 + float(posmod(cell * 19, 8)) * 0.013)


func _sagitta(x: float, radius: float) -> float:
	# Rationalized form stays precise even when the ground is only meters away.
	return x * x / (radius + sqrt(maxf(0.0, radius * radius - x * x)))
