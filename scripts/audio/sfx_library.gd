class_name SfxLibrary
extends RefCounted
## Efectos de sonido sintetizados por código (propios: sin licencias de terceros).
## Cada sonido se genera una vez y se guarda en caché.

const RATE := 22050
static var _cache := {}


static func get_stream(name: StringName) -> AudioStreamWAV:
	if not _cache.has(name):
		_cache[name] = _build(name)
	return _cache[name]


static func names() -> Array[StringName]:
	return [&"beep", &"go", &"boost", &"pickup", &"use_item", &"hit", &"explosion", &"drift_tick",
			&"landing", &"absorb", &"engine"]


static func _build(name: StringName) -> AudioStreamWAV:
	match name:
		&"beep": return _wav(_tone(440.0, 0.18, 0.0, 6.0))
		&"go": return _wav(_tone(880.0, 0.45, 0.0, 3.0))
		&"boost": return _wav(_sweep(180.0, 900.0, 0.55, 0.35, 3.0))
		&"pickup": return _wav(_arpeggio([523.0, 659.0, 784.0, 1047.0], 0.07))
		&"use_item": return _wav(_sweep(700.0, 350.0, 0.18, 0.1, 5.0))
		&"hit": return _wav(_mix(_tone(90.0, 0.25, 0.0, 9.0), _noise(0.25, 10.0), 0.6))
		&"explosion": return _wav(_mix(_sweep(140.0, 40.0, 0.7, 0.2, 4.0), _noise(0.7, 4.0), 0.9))
		&"drift_tick": return _wav(_tone(1200.0, 0.05, 0.0, 12.0))
		&"landing": return _wav(_mix(_tone(70.0, 0.18, 0.0, 12.0), _noise(0.1, 20.0), 0.3))
		&"absorb": return _wav(_arpeggio([880.0, 660.0], 0.06))
		&"engine": return _engine_loop()
	push_error("Sonido desconocido: %s" % name)
	return _wav(PackedFloat32Array([0.0]))


# --- Generadores -----------------------------------------------------------

## Tono (seno con un poco de armónico) con decaimiento exponencial.
static func _tone(freq: float, dur: float, vibrato: float, decay: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (freq + sin(t * 30.0) * vibrato) / RATE
		var env := exp(-decay * t / dur)
		out[i] = (sin(phase) * 0.8 + sin(phase * 2.0) * 0.2) * env * 0.6
	return out


static func _sweep(f0: float, f1: float, dur: float, noise_amt: float, decay: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in n:
		var k := float(i) / n
		phase += TAU * lerpf(f0, f1, k) / RATE
		var env := sin(minf(k * 8.0, 1.0) * PI * 0.5) * exp(-decay * k)
		out[i] = (sin(phase) * (1.0 - noise_amt) + rng.randf_range(-1.0, 1.0) * noise_amt) * env * 0.6
	return out


static func _noise(dur: float, decay: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in n:
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.35)  # ruido filtrado (más grave)
		out[i] = lp * exp(-decay * float(i) / n) * 0.9
	return out


static func _arpeggio(freqs: Array, step_dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f in freqs:
		out.append_array(_tone(f, step_dur, 0.0, 4.0))
	return out


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array, b_gain: float) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = (a[i] if i < a.size() else 0.0) + (b[i] if i < b.size() else 0.0) * b_gain
	return out


## Motor: diente de sierra suave de 110 Hz con ciclos enteros (el bucle no hace "clic").
static func _engine_loop() -> AudioStreamWAV:
	var freq := 110.0
	var cycles := 11
	var n := int(round(RATE * cycles / freq))
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var ph := fmod(float(i) * freq / RATE, 1.0)
		var saw := ph * 2.0 - 1.0
		var tri := absf(ph * 4.0 - 2.0) - 1.0
		out[i] = (saw * 0.45 + tri * 0.35 + sin(ph * TAU * 2.0) * 0.2) * 0.5
	var w := _wav(out)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
