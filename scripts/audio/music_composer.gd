class_name MusicComposer
extends RefCounted
## Compositor procedural: genera por código (sin recursos de terceros) un bucle musical de 12 compases a partir de un
## "estilo" (tempo, escala, progresión, instrumentos, patrones de batería). Es determinista: la misma semilla da la
## misma música. tools/generate_music.gd lo renderiza a assets/audio/music/<tema>.wav (cualquier .wav/.ogg con ese
## nombre lo sustituye, p. ej. música real).

const RATE := 22050
const BARS := 12
const SCALES := {
	"major": [0, 2, 4, 5, 7, 9, 11],
	"minor": [0, 2, 3, 5, 7, 8, 10],
	"phrygian": [0, 1, 4, 5, 7, 8, 10],        ## aire árabe / desierto
	"lydian": [0, 2, 4, 6, 7, 9, 11],          ## fantasía
	"pentatonic": [0, 2, 4, 7, 9, 12, 14],     ## 7 notas "de pentatónica" (cuerdas y campanas)
}

## Estilos por tema (id de ThemeData) + "menu".
const STYLES := {
	&"costa": {"bpm": 104, "root": 48, "scale": "major", "prog": [0, 4, 5, 3], "seed": 11, "bass": "tri", "bass_pat": 2,
			"chords": "stab", "chord_wave": "pluck", "arp": "", "lead": "bell", "lead_density": 0.5, "lead_oct": 1,
			"kick": "x.......x.......", "snare": "....x.......x...", "hat": "..x...x...x...x.", "perc": "soft"},
	&"neon": {"bpm": 118, "root": 45, "scale": "minor", "prog": [0, 5, 2, 6], "seed": 23, "bass": "saw", "bass_pat": 1,
			"chords": "pad", "chord_wave": "pad", "arp": "saw", "lead": "square", "lead_density": 0.45, "lead_oct": 1,
			"kick": "x...x...x...x...", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x.", "perc": "synth"},
	&"bosque": {"bpm": 112, "root": 50, "scale": "pentatonic", "prog": [0, 3, 4, 2], "seed": 37, "bass": "tri", "bass_pat": 3,
			"chords": "stab", "chord_wave": "pluck", "arp": "", "lead": "pluck", "lead_density": 0.55, "lead_oct": 1,
			"kick": "x.....x.x.......", "snare": "....x.......x..x", "hat": "x.x.x.x.x.x.x.x.", "perc": "wood"},
	&"circuito": {"bpm": 140, "root": 52, "scale": "major", "prog": [0, 4, 5, 3], "seed": 41, "bass": "square", "bass_pat": 0,
			"chords": "stab", "chord_wave": "square", "arp": "", "lead": "square", "lead_density": 0.6, "lead_oct": 1,
			"kick": "x...x...x...x.x.", "snare": "....x.......x...", "hat": "xxxxxxxxxxxxxxxx", "perc": "rock"},
	&"volcan": {"bpm": 124, "root": 40, "scale": "minor", "prog": [0, 0, 5, 6], "seed": 53, "bass": "saw", "bass_pat": 0,
			"chords": "pad", "chord_wave": "saw", "arp": "", "lead": "saw", "lead_density": 0.4, "lead_oct": 1,
			"kick": "x..xx..xx..xx.x.", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.xx", "perc": "heavy"},
	&"desierto": {"bpm": 106, "root": 45, "scale": "phrygian", "prog": [0, 1, 0, 6], "seed": 67, "bass": "tri", "bass_pat": 2,
			"chords": "pad", "chord_wave": "pad", "arp": "", "lead": "pluck", "lead_density": 0.55, "lead_oct": 1,
			"kick": "x..x..x.x..x....", "snare": "....x.......x.x.", "hat": "x.xxx.xxx.xxx.xx", "perc": "soft"},
	&"industrial": {"bpm": 126, "root": 43, "scale": "minor", "prog": [0, 6, 5, 6], "seed": 71, "bass": "square", "bass_pat": 1,
			"chords": "stab", "chord_wave": "square", "arp": "square", "lead": "square", "lead_density": 0.35, "lead_oct": 1,
			"kick": "x...x...x..xx...", "snare": "....x.......x..x", "hat": "..x...x...x...x.", "perc": "metal"},
	&"nieve": {"bpm": 96, "root": 53, "scale": "pentatonic", "prog": [0, 5, 3, 4], "seed": 83, "bass": "tri", "bass_pat": 3,
			"chords": "pad", "chord_wave": "pad", "arp": "bell", "lead": "bell", "lead_density": 0.45, "lead_oct": 2,
			"kick": "x.......x.......", "snare": "........x.......", "hat": "..x...x...x...x.", "perc": "soft"},
	&"alien": {"bpm": 132, "root": 50, "scale": "lydian", "prog": [0, 4, 1, 5], "seed": 97, "bass": "saw", "bass_pat": 1,
			"chords": "pad", "chord_wave": "pad", "arp": "bell", "lead": "bell", "lead_density": 0.65, "lead_oct": 2,
			"kick": "x...x...x...x...", "snare": "....x.......x...", "hat": "x.xxx.xxx.xxx.xx", "perc": "synth"},
	&"menu": {"bpm": 110, "root": 48, "scale": "major", "prog": [0, 5, 3, 4], "seed": 5, "bass": "tri", "bass_pat": 2,
			"chords": "stab", "chord_wave": "pluck", "arp": "", "lead": "pluck", "lead_density": 0.5, "lead_oct": 1,
			"kick": "x.......x.......", "snare": "....x.......x...", "hat": "..x...x...x...x.", "perc": "soft"},
}

var _buf := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _sps := 0.0      ## muestras por paso (semicorchea)


static func style_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in STYLES:
		out.append(k)
	return out


## Renderiza el bucle del estilo (mono, RATE Hz, floats -1..1). Las colas de las notas se enrollan al principio del bucle.
func render(style: StringName) -> PackedFloat32Array:
	var st: Dictionary = STYLES[style]
	_rng.seed = int(st["seed"])
	var step_s := 60.0 / float(st["bpm"]) / 4.0
	_sps = RATE * step_s
	var total := int(round(_sps * 16.0 * BARS))
	_buf = PackedFloat32Array()
	_buf.resize(total)
	var scale: Array = SCALES[st["scale"]]
	var prog: Array = st["prog"]
	var root: int = st["root"]
	var motif_a := _motif(st)
	var motif_b := _motif(st)
	for bar in BARS:
		var degree: int = prog[bar % prog.size()]
		var chord_midi := _chord(scale, degree, root)
		var b0 := bar * 16
		_bass(st, b0, scale, degree, root)
		_chords(st, b0, chord_midi)
		if st["arp"] != "":
			_arp(st, b0, chord_midi)
		_lead(st, b0, scale, degree, root, motif_a if bar < 8 else motif_b, bar >= 4 and bar < 8)
		_drums(st, b0, bar == BARS - 1)
	# Mezcla: saturación suave y normalizado
	var peak := 0.001
	for i in total:
		_buf[i] = tanh(_buf[i] * 1.3)
		peak = maxf(peak, absf(_buf[i]))
	var g := 0.82 / peak
	for i in total:
		_buf[i] *= g
	return _buf


## Fanfarria corta (sin bucle) para la pantalla de resultados.
func render_jingle() -> PackedFloat32Array:
	_rng.seed = 99
	_sps = RATE * 60.0 / 132.0 / 4.0
	var total := int(round(_sps * 16.0 * 3.0))
	_buf = PackedFloat32Array()
	_buf.resize(total)
	var notes := [[0, 0, 2], [4, 2, 2], [7, 4, 2], [12, 6, 4], [7, 10, 2], [12, 12, 8], [16, 12, 8], [19, 12, 12]]
	for n in notes:
		_voice("bell", 60.0 + float(n[0]), int(n[1]) * 1, int(n[2]), 0.3)
		_voice("pad", 48.0 + float(n[0]) * 0.0 + (0.0 if int(n[1]) < 12 else 0.0), int(n[1]), int(n[2]), 0.12)
	_kick(0, 0.5)
	_kick(12, 0.5)
	for i in total:
		_buf[i] = tanh(_buf[i] * 1.2)
	return _buf


# --- Teoría ------------------------------------------------------------------------------

func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## Nota (MIDI) del grado de escala "deg" (puede ser negativo o > 6: cambia de octava).
func _note(scale: Array, deg: int, root: int) -> int:
	var oct := floori(float(deg) / 7.0)
	return root + oct * 12 + int(scale[posmod(deg, 7)])


func _chord(scale: Array, degree: int, root: int) -> Array:
	return [_note(scale, degree, root), _note(scale, degree + 2, root), _note(scale, degree + 4, root)]


## Motivo de 16 pasos: [{"step", "move", "len"}], "move" = salto en grados respecto a la nota anterior.
func _motif(st: Dictionary) -> Array:
	var out: Array = []
	var density: float = st["lead_density"]
	var step := 0
	while step < 16:
		var on := step % 4 == 0 or _rng.randf() < density * 0.55
		if on:
			var ln: int = [1, 2, 2, 3, 4][_rng.randi() % 5]
			ln = mini(ln, 16 - step)
			out.append({"step": step, "move": [-2, -1, -1, 0, 1, 1, 2][_rng.randi() % 7], "len": ln})
			step += ln
		else:
			step += 1
	return out


# --- Voces -------------------------------------------------------------------------------

func _bass(st: Dictionary, b0: int, scale: Array, degree: int, root: int) -> void:
	var r := _note(scale, degree, root) - 12
	var fifth := _note(scale, degree + 4, root) - 12
	var wave: String = st["bass"]
	match int(st["bass_pat"]):
		0:   # corcheas de la fundamental
			for s in range(0, 16, 2):
				_voice(wave, r, b0 + s, 2, 0.28)
		1:   # fundamental con octava (síncopa)
			for s in [0, 3, 6, 8, 11, 14]:
				_voice(wave, r + (12 if s in [6, 14] else 0), b0 + s, 2, 0.28)
		2:   # tumbao: fundamental larga y quinta
			_voice(wave, r, b0, 6, 0.3)
			_voice(wave, fifth, b0 + 6, 2, 0.26)
			_voice(wave, r, b0 + 8, 4, 0.3)
			_voice(wave, fifth, b0 + 12, 4, 0.26)
		_:   # caminante: fundamental, tercera, quinta, tercera
			var third := _note(scale, degree + 2, root) - 12
			for k in 4:
				_voice(wave, [r, third, fifth, third][k], b0 + k * 4, 4, 0.27)


func _chords(st: Dictionary, b0: int, chord: Array) -> void:
	var wave: String = st["chord_wave"]
	if st["chords"] == "pad":
		for m in chord:
			_voice(wave, float(m) + 12.0, b0, 16, 0.07)
	else:   # golpes a contratiempo
		for s in [2, 6, 10, 14]:
			for m in chord:
				_voice(wave, float(m) + 12.0, b0 + s, 2, 0.06)


func _arp(st: Dictionary, b0: int, chord: Array) -> void:
	var wave: String = st["arp"]
	for s in 16:
		_voice(wave, float(chord[s % 3]) + 24.0, b0 + s, 1, 0.05)


func _lead(st: Dictionary, b0: int, scale: Array, degree: int, root: int, motif: Array, vary: bool) -> void:
	var wave: String = st["lead"]
	var oct: int = st["lead_oct"]
	var deg := degree + 7 * oct
	for ev in motif:
		var mv: int = ev["move"]
		if vary and _rng.randf() < 0.25:
			mv = -mv   # variación en el segundo bloque
		deg = clampi(deg + mv, degree + 7 * oct - 3, degree + 7 * oct + 5)
		if int(ev["step"]) % 4 == 0 and (deg - degree) % 2 != 0:
			deg += 1   # en los tiempos fuertes tiende a notas del acorde
		_voice(wave, float(_note(scale, deg, root)) + 12.0, b0 + int(ev["step"]), int(ev["len"]), 0.17, 0.004 if wave != "pad" else 0.02)


func _drums(st: Dictionary, b0: int, fill: bool) -> void:
	var kick: String = st["kick"]
	var snare: String = st["snare"]
	var hat: String = st["hat"]
	var perc: String = st["perc"]
	for s in 16:
		if kick[s] == "x":
			_kick(b0 + s, 0.5)
		if snare[s] == "x":
			_snare(b0 + s, 0.3 if perc != "soft" else 0.2, perc)
		if hat[s] == "x":
			_hat(b0 + s, 0.07 if perc != "soft" else 0.05)
	if fill:   # redoble en el último compás
		for s in [12, 13, 14, 15]:
			_snare(b0 + s, 0.22, perc)


# --- Síntesis -----------------------------------------------------------------------------

func _add(i: int, v: float) -> void:
	_buf[posmod(i, _buf.size())] += v


## Oscilador (fase 0..1).
func _osc(wave: String, ph: float) -> float:
	match wave:
		"saw": return 2.0 * ph - 1.0
		"square": return 1.0 if ph < 0.5 else -1.0
		"tri": return 4.0 * absf(ph - 0.5) - 1.0
		_: return sin(ph * TAU)


## Una nota: wave = tri|saw|square|pluck|bell|pad; start/len en pasos; vol 0..1.
func _voice(wave: String, midi: float, start_step: int, len_steps: int, vol: float, attack := 0.004) -> void:
	var f := _hz(midi)
	var i0 := int(start_step * _sps)
	var n := int(len_steps * _sps)
	var rel := int(RATE * 0.12)
	var total := n + rel
	var ph := 0.0
	var ph2 := 0.0
	var dt := f / RATE
	for k in total:
		var t := float(k) / RATE
		var env := 1.0
		if k < n:
			env = minf(t / maxf(attack, 0.001), 1.0)
		else:
			env = (1.0 - float(k - n) / rel) * minf(t / maxf(attack, 0.001), 1.0)
		var s := 0.0
		match wave:
			"pluck":
				env *= exp(-5.0 * t) + 0.05
				s = _osc("saw", ph) * 0.6 + _osc("sin", ph * 2.0) * 0.3
			"bell":
				env *= exp(-3.5 * t)
				s = sin(ph * TAU) * 0.6 + sin(ph * TAU * 2.76) * 0.25 + sin(ph * TAU * 5.4) * 0.1
			"pad":
				s = (_osc("saw", ph) + _osc("saw", ph2)) * 0.3
				env *= minf(t / 0.08, 1.0)
			"tri", "saw", "square":
				s = _osc(wave, ph)
				if wave != "tri":
					s *= 0.7
				env *= 0.4 + 0.6 * exp(-4.0 * t)   # ataque marcado y sostén
			_:
				s = sin(ph * TAU)
		_add(i0 + k, s * env * vol)
		ph = fposmod(ph + dt, 1.0)
		ph2 = fposmod(ph2 + dt * 1.007, 1.0)


func _kick(step: int, vol: float) -> void:
	var i0 := int(step * _sps)
	var n := int(RATE * 0.16)
	var ph := 0.0
	for k in n:
		var t := float(k) / RATE
		ph += TAU * (45.0 + 90.0 * exp(-30.0 * t)) / RATE
		_add(i0 + k, sin(ph) * exp(-18.0 * t) * vol)


func _snare(step: int, vol: float, perc: String) -> void:
	var i0 := int(step * _sps)
	var dur := 0.16 if perc != "metal" else 0.22
	var n := int(RATE * dur)
	var lp := 0.0
	for k in n:
		var t := float(k) / RATE
		lp = lerpf(lp, _rng.randf_range(-1.0, 1.0), 0.6)
		var body := sin(TAU * 190.0 * t) * exp(-30.0 * t) * 0.4
		var tone := 0.0
		if perc == "metal":
			tone = sin(TAU * 420.0 * t) * exp(-14.0 * t) * 0.3 + sin(TAU * 673.0 * t) * exp(-14.0 * t) * 0.2
		_add(i0 + k, (lp * exp(-22.0 * t) * 0.7 + body + tone) * vol)


func _hat(step: int, vol: float) -> void:
	var i0 := int(step * _sps)
	var n := int(RATE * 0.04)
	var prev := 0.0
	for k in n:
		var t := float(k) / RATE
		var x := _rng.randf_range(-1.0, 1.0)
		_add(i0 + k, (x - prev) * exp(-90.0 * t) * vol)   # filtro paso alto simple
		prev = x
