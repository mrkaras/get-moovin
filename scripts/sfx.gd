# Retro sound effects synthesised at startup, so the game needs no audio files.
extends Node

const RATE := 22050
const VOICES := 8

var sounds: Dictionary = {}
var players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sounds["jump"] = _tone(260.0, 620.0, 0.14, 0.35, 0.0, true)
	sounds["double_jump"] = _tone(480.0, 1000.0, 0.14, 0.3, 0.0, true)
	sounds["land"] = _tone(120.0, 60.0, 0.08, 0.4, 0.6)
	sounds["smash"] = _tone(220.0, 50.0, 0.3, 0.6, 0.85)
	sounds["bawk"] = _tone(950.0, 520.0, 0.18, 0.35, 0.15, true)
	sounds["hay"] = _tone(880.0, 1400.0, 0.1, 0.3)
	sounds["hurt"] = _tone(200.0, 70.0, 0.4, 0.45, 0.2, true)
	sounds["charge"] = _tone(90.0, 380.0, 0.25, 0.4, 0.4)
	sounds["thunder"] = _tone(70.0, 25.0, 1.1, 0.7, 0.95)
	sounds["gameover"] = _tone(420.0, 90.0, 0.9, 0.4, 0.05, true)
	sounds["start"] = _tone(300.0, 900.0, 0.3, 0.35, 0.0, true)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func play(sound: String, pitch_jitter: float = 0.05) -> void:
	if not sounds.has(sound):
		return
	for p in players:
		if not p.playing:
			p.stream = sounds[sound]
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return


func _tone(f0: float, f1: float, duration: float, volume: float, noise: float = 0.0, square: bool = false) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var held_noise := 0.0
	for i in n:
		var k := float(i) / n
		phase += lerpf(f0, f1, k) / RATE
		var s := sin(phase * TAU)
		if square:
			s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		if i % 3 == 0:
			held_noise = randf_range(-1.0, 1.0)
		s = lerpf(s, held_noise, noise)
		var env := (1.0 - k) * (1.0 - k) * minf(1.0, i / 100.0)
		data.encode_s16(i * 2, int(clampf(s * env * volume, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
