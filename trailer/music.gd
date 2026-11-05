# Synthesises the trailer soundtrack: a stormy intro, a 140 BPM stomp-rock
# section under the gameplay, and a final hit for the end card.
extends RefCounted

const RATE := 32000
const BPM := 140.0
const E2 := 82.41
const G2 := 98.0
const A2 := 110.0
const D2 := 73.42
const B2 := 123.47

var buf := PackedFloat32Array()


func build(length: float, beat_start: float, beat_end: float, fast_from: float, thunder_times: Array) -> AudioStreamWAV:
	buf.resize(int(length * RATE))
	buf.fill(0.0)
	_intro(beat_start, thunder_times)
	_groove(beat_start, beat_end, fast_from)
	_finale(beat_end)
	return _to_wav()


func _intro(beat_start: float, thunder_times: Array) -> void:
	# Low droning E that swells towards the drop.
	var n := int(beat_start * RATE)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var swell := minf(1.0, t / 3.0) * (0.5 + 0.5 * t / beat_start)
		var s := _saw(t * E2) * 0.6 + _saw(t * E2 * 1.005) * 0.4
		lp += (s - lp) * 0.04
		buf[i] += lp * 0.35 * swell
	for th in thunder_times:
		_boom(th, 0.9)
	# Riser and snare roll into the drop.
	_riser(beat_start - 1.6, 1.6)
	var roll := beat_start - 0.9
	var step := 0.9 / 12.0
	for i in 12:
		_snare(roll + i * step, 0.25 + 0.5 * i / 12.0)


func _groove(start: float, stop: float, fast_from: float) -> void:
	var beat := 60.0 / BPM
	var riff := [E2, E2, G2, E2, A2, E2, G2, D2, E2, E2, G2, E2, B2, A2, G2, D2]
	var b := 0
	var t := start
	while t < stop - 0.01:
		var in_bar := b % 4
		var fast := t >= fast_from
		_kick(t, 1.0)
		if in_bar == 1 or in_bar == 3:
			_snare(t, 0.8)
		if in_bar == 2:
			_kick(t + beat * 0.5, 0.7)
		var hats := 4 if fast else 2
		for h in hats:
			_hat(t + h * beat / hats, 0.25 if h % 2 == 0 else 0.15)
		for e in 2:
			var note: float = riff[(b * 2 + e) % riff.size()]
			_bass(t + e * beat * 0.5, beat * 0.45, note)
		if b % 8 == 0:
			_power_chord(t, beat * 3.5, E2 * 2.0, 0.22)
			_crash(t, 0.35 if b == 0 else 0.2)
		elif b % 8 == 4:
			_power_chord(t, beat * 3.5, (G2 if b % 16 == 4 else A2) * 2.0, 0.2)
		b += 1
		t = start + b * beat


func _finale(at: float) -> void:
	_kick(at, 1.2)
	_boom(at, 0.7)
	_crash(at, 0.6)
	_power_chord(at, 3.8, E2 * 2.0, 0.35)
	_bass(at, 3.0, E2)


# --- Instruments -------------------------------------------------------------

func _add(t: float, sample: float, i_offset: int) -> void:
	var i := int(t * RATE) + i_offset
	if i >= 0 and i < buf.size():
		buf[i] += sample


func _kick(t: float, vol: float) -> void:
	var n := int(0.25 * RATE)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		phase += lerpf(140.0, 45.0, sqrt(k)) / RATE
		_add(t, sin(phase * TAU) * (1.0 - k) * (1.0 - k) * vol * 0.9, i)


func _snare(t: float, vol: float) -> void:
	var n := int(0.18 * RATE)
	for i in n:
		var k := float(i) / n
		var s := randf_range(-1.0, 1.0) * 0.7 + sin(i * TAU * 190.0 / RATE) * 0.3
		_add(t, s * pow(1.0 - k, 3.0) * vol * 0.55, i)


func _hat(t: float, vol: float) -> void:
	var n := int(0.05 * RATE)
	var prev := 0.0
	for i in n:
		var k := float(i) / n
		var noise := randf_range(-1.0, 1.0)
		_add(t, (noise - prev) * pow(1.0 - k, 4.0) * vol * 0.4, i)
		prev = noise


func _crash(t: float, vol: float) -> void:
	var n := int(1.6 * RATE)
	var prev := 0.0
	for i in n:
		var k := float(i) / n
		var noise := randf_range(-1.0, 1.0)
		_add(t, (noise - prev) * pow(1.0 - k, 2.5) * vol * 0.35, i)
		prev = noise


func _bass(t: float, dur: float, freq: float) -> void:
	var n := int(dur * RATE)
	var lp := 0.0
	for i in n:
		var k := float(i) / n
		var s := _saw(i * freq / RATE)
		lp += (s - lp) * 0.12
		var env := minf(1.0, i / 80.0) * (1.0 - k * 0.6)
		_add(t, tanh(lp * 2.0) * env * 0.32, i)


func _power_chord(t: float, dur: float, root: float, vol: float) -> void:
	# Root + fifth + octave, overdriven, like a palm-muted guitar stab.
	var n := int(dur * RATE)
	var lp := 0.0
	for i in n:
		var k := float(i) / n
		var x := float(i) / RATE
		var s := _saw(x * root) + _saw(x * root * 1.498) + _saw(x * root * 2.003) * 0.6
		s = tanh(s * 3.0)
		lp += (s - lp) * 0.25
		_add(t, lp * pow(1.0 - k, 1.6) * minf(1.0, i / 60.0) * vol, i)


func _boom(t: float, vol: float) -> void:
	# Thunder: low rumble of filtered noise with a sub drop.
	var n := int(2.2 * RATE)
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		lp += (randf_range(-1.0, 1.0) - lp) * 0.02
		phase += lerpf(70.0, 30.0, k) / RATE
		var s := lp * 3.0 + sin(phase * TAU) * 0.6
		_add(t, s * pow(1.0 - k, 2.0) * minf(1.0, i / 200.0) * vol, i)


func _riser(t: float, dur: float) -> void:
	var n := int(dur * RATE)
	var phase := 0.0
	var prev := 0.0
	for i in n:
		var k := float(i) / n
		phase += lerpf(200.0, 1600.0, k * k) / RATE
		var noise := randf_range(-1.0, 1.0)
		var s := (noise - prev) * 0.5 + sin(phase * TAU) * 0.2
		prev = noise
		_add(t, s * k * k * 0.5, i)


func _saw(cycles: float) -> float:
	return fmod(cycles, 1.0) * 2.0 - 1.0


func _to_wav() -> AudioStreamWAV:
	var peak := 0.001
	for s in buf:
		peak = maxf(peak, absf(s))
	var gain := 0.9 / peak
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
