extends Control

## Monoline glass tubing, with independent failing starters on P, E, and B.
const TITLE := "APOGEE LABS"
const FLICKER_LETTERS := [1, 4, 9]
const FLICKER_INTERVAL := 2.5
const FLICKER_START := 2.0
const CYAN := Color("5de6fa")
const GLYPHS := {
	"A": [[[0,40],[10,0],[14,0],[24,40]], [[5,25],[19,25]]],
	"P": [[[0,40],[0,0],[17,0],[24,7],[24,15],[17,21],[0,21]]],
	"O": [[[7,0],[17,0],[24,7],[24,33],[17,40],[7,40],[0,33],[0,7],[7,0]]],
	"G": [[[24,8],[17,0],[7,0],[0,7],[0,33],[7,40],[17,40],[24,33],[24,22],[14,22]]],
	"E": [[[24,0],[0,0],[0,40],[24,40]], [[0,20],[19,20]]],
	"L": [[[0,0],[0,40],[24,40]]],
	"B": [[[0,40],[0,0],[16,0],[24,7],[24,14],[17,20],[0,20]], [[17,20],[24,26],[24,33],[17,40],[0,40]]],
	"S": [[[24,5],[17,0],[7,0],[0,7],[0,14],[7,20],[17,20],[24,26],[24,33],[17,40],[7,40],[0,35]]],
}
var elapsed := 0.0
var _starter: AudioStreamPlayer
var _last_cycle := -1
static var _audio: Dictionary = {}

static func letter_power(index: int, seconds: float) -> float:
	var stable := 0.9 + sin(seconds * TAU / 5.5) * 0.05
	if index in FLICKER_LETTERS:
		var delay: float = [0.05, 0.3, 0.6][FLICKER_LETTERS.find(index)]
		var local := seconds - float(delay)
		if local < 0.12: return 0.12
		if local < 0.25: return 0.8
		if local < 0.34: return 0.16
		if local < 0.5: return 0.95
		if local < 0.6: return 0.2
		if seconds >= FLICKER_START:
			var cycle := int((seconds - FLICKER_START) / FLICKER_INTERVAL)
			var phase := fmod(seconds - FLICKER_START, FLICKER_INTERVAL)
			if index == FLICKER_LETTERS[cycle % FLICKER_LETTERS.size()] and phase < 0.16:
				return 0.18 if phase < 0.06 or phase > 0.11 else 0.8
	return stable

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	accessibility_name = "APOGEE LABS neon tube sign"
	_starter = AudioStreamPlayer.new()
	_starter.volume_db = -24
	add_child(_starter)
	if DisplayServer.get_name() != "headless":
		_starter.stream = electrical_sound(true)
		_starter.play()

func advance(seconds: float) -> void:
	elapsed = seconds
	if seconds >= FLICKER_START:
		var cycle := int((seconds - FLICKER_START) / FLICKER_INTERVAL)
		if cycle != _last_cycle:
			_last_cycle = cycle
			if DisplayServer.get_name() != "headless":
				_starter.stream = electrical_sound(false)
				_starter.play()
	queue_redraw()

func _exit_tree() -> void:
	_starter.stop()
	_starter.stream = null

func _draw() -> void:
	var x := 30.0
	for index in TITLE.length():
		var character := TITLE.substr(index, 1)
		if character == " ":
			x += 20
			continue
		var power := letter_power(index, elapsed)
		for stroke in GLYPHS[character]:
			var points := PackedVector2Array()
			for point in stroke:
				points.append(Vector2(x + point[0], 9 + point[1]))
			# Dark glass remains visible when a starter briefly fails.
			draw_polyline(points, Color("0a1724"), 6, true)
			draw_polyline(points, Color("264856"), 3, true)
			for width in [12.0, 7.0, 4.0]:
				draw_polyline(points, Color(CYAN, power * (0.025 if width > 7 else 0.07)), width, true)
			draw_polyline(points, Color(CYAN, power * 0.9), 2.6, true)
			draw_polyline(points, Color(0.8, 0.99, 1.0, power), 0.9, true)
			for end in [points[0], points[-1]]:
				draw_circle(end, 1.3, Color(CYAN, power * 0.8), true, -1, true)
		# Small dark mounting clips make these read as physical tubes on a wall.
		draw_line(Vector2(x + 4, 7), Vector2(x + 4, 11), Color("50616a"), 2)
		x += 35

static func electrical_sound(startup: bool) -> AudioStreamWAV:
	if _audio.has(startup):
		return _audio[startup]
	var duration := 1.3 if startup else 0.16
	var rate := 22050
	var data := PackedByteArray()
	data.resize(int(rate * duration) * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 8482
	for sample in int(rate * duration):
		var t := float(sample) / rate
		var gate := 0.0
		for onset in ([0.05, 0.18, 0.3, 0.43, 0.6, 0.73, 0.85, 1.1] if startup else [0.0, 0.11]):
			if t >= onset:
				gate += exp(-(t - float(onset)) * 65.0)
		var buzz := sin(TAU * 120 * t) * 0.12 + sin(TAU * 720 * t) * 0.08
		var noise := random.randf_range(-1, 1) * 0.4
		var envelope := minf(t / 0.008, 1.0) * minf((duration - t) / 0.05, 1.0)
		var value := (noise + buzz) * minf(gate, 1.0) * envelope
		data.encode_s16(sample * 2, int(clampf(value, -1, 1) * 32767))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = data
	_audio[startup] = sound
	return sound
