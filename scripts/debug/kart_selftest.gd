extends Node
## Autotest sin interfaz del hito 1. Ejecutar:
##   Godot_console.exe --headless --path . res://scenes/debug/selftest.tscn
## Sale con código 0 si todo pasa.

var track: Node3D
var kart: Kart
var ctrl := ScriptedController.new()
var failures := 0
var _boost_sources: Array[StringName] = []
var _levels: Array[int] = []
var _landings: Array[float] = []


func _ready() -> void:
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(name: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + name + "  " + detail)
	if not ok:
		failures += 1


func _reset() -> void:
	kart.respawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 70)))
	ctrl.set_input(0, 0)
	_boost_sources.clear()
	_levels.clear()
	_landings.clear()


func _test_split_screen() -> void:
	var area := Vector2(1920, 1080)
	for n in [1, 2, 3, 4]:
		var rects := SplitScreen.compute_cells(n, area, 4.0)
		var ok: bool = rects.size() == n
		var inside := true
		var overlap := false
		for i in rects.size():
			inside = inside and Rect2(Vector2.ZERO, area).encloses(rects[i])
			for j in range(i + 1, rects.size()):
				overlap = overlap or rects[i].intersects(rects[j])
		_check("layout %d vista(s)" % n, ok and inside and not overlap,
				"rects=%d dentro=%s solapadas=%s" % [rects.size(), inside, overlap])

	for n in [4, 3, 2, 1]:
		track.set_player_count(n)
		await _ticks(150)
		var split: SplitScreen = track.split
		var all_grounded := true
		var min_dist := INF
		for i in track.karts.size():
			all_grounded = all_grounded and track.karts[i].grounded
			for j in range(i + 1, track.karts.size()):
				min_dist = minf(min_dist, track.karts[i].sphere.global_position.distance_to(
						track.karts[j].sphere.global_position))
		_check("%d karts: viewports y karts creados" % n,
				track.karts.size() == n and split.cells.size() == n and track.seats.size() == n,
				"karts=%d vistas=%d" % [track.karts.size(), split.cells.size()])
		_check("%d karts: todos en el suelo y separados" % n, all_grounded and (n == 1 or min_dist > 2.0),
				"min_dist=%.1f" % (min_dist if n > 1 else 0.0))
		if n == 4:
			print("      píxeles internos totales (4 vistas, ventana %s): %d" % [split.size, split.get_total_pixels()])
	track.set_render_scale(0.5)
	await _ticks(3)
	var px_half: int = track.split.get_total_pixels()
	track.set_render_scale(1.0)
	await _ticks(3)
	var px_full: int = track.split.get_total_pixels()
	_check("la escala de render reduce los píxeles", px_half < px_full, "%d vs %d" % [px_half, px_full])


func _run() -> void:
	var scene: PackedScene = load("res://scenes/tracks/test_track.tscn")
	track = scene.instantiate()
	track.attach_player_input = false
	add_child(track)
	await _ticks(2)
	kart = track.karts[0]
	kart.add_child(ctrl)
	kart.controller = ctrl
	kart.drift_level_changed.connect(func(l: int) -> void: _levels.append(l))
	kart.boost_started.connect(func(s: StringName, _d: float) -> void: _boost_sources.append(s))
	kart.landed.connect(func(t: float) -> void: _landings.append(t))
	await _ticks(30)

	# 1. Aceleración recta
	_reset()
	await _ticks(10)
	ctrl.set_input(0, 1)
	await _ticks(240)
	var v := kart.sphere.linear_velocity.length()
	_check("acelera hasta ~velocidad máxima", v > kart.stats.max_speed * 0.9 and v < kart.stats.max_speed * 1.05,
			"v=%.1f m/s (max %.1f)" % [v, kart.stats.max_speed])
	_check("se mantiene pegado al suelo", kart.grounded and kart.sphere.global_position.y < 1.0,
			"y=%.2f" % kart.sphere.global_position.y)
	_check("rumbo recto", absf(kart.sphere.global_position.x) < 0.5, "x=%.2f" % kart.sphere.global_position.x)

	# 2. Derrape completo con mini turbo nivel 3
	_reset()
	await _ticks(10)
	ctrl.set_input(0, 1)
	await _ticks(100)
	ctrl.set_input(1, 1, 0, true)
	await _ticks(4)
	_check("el derrape empieza con un salto, no directo", kart.hop_active and not kart.drifting,
			"hop=%s drifting=%s" % [kart.hop_active, kart.drifting])
	var hop_peak := 0.0
	for i in 26:
		await get_tree().physics_frame
		hop_peak = maxf(hop_peak, kart.sphere.global_position.y)
	_check("el salto despega del suelo", hop_peak > 0.62, "y_max=%.2f (suelo 0.49)" % hop_peak)
	_check("inicia derrape al aterrizar", kart.drifting and not kart.hop_active,
			"drifting=%s hop=%s" % [kart.drifting, kart.hop_active])
	await _ticks(200)
	_check("alcanza nivel 3 en ~3 s", kart.drift_level == 3, "nivel=%d niveles=%s" % [kart.drift_level, _levels])
	var heading_before := kart.heading
	var dcolor := kart.get_drift_color(3)
	_check("color nivel 3 masculino = dorado", dcolor == CharacterData.GOLD, str(dcolor))
	ctrl.set_input(0, 1, 0, false)
	await _ticks(5)
	_check("soltar derrape da turbo", _boost_sources.has(&"drift") and kart.is_boosting(), str(_boost_sources))
	await _ticks(30)
	var peak := 0.0
	for i in 90:
		await get_tree().physics_frame
		peak = maxf(peak, kart.get_speed_kmh() / 3.6)
	_check("el turbo lleva la velocidad por encima del máximo", peak > kart.stats.max_speed * 1.1,
			"pico=%.1f m/s" % peak)
	_check("el derrape giró el kart", absf(heading_before) > 0.5, "heading=%.2f" % heading_before)

	# 2b. Derrape sin dirección: solo salta, no derrapa
	_reset()
	await _ticks(10)
	ctrl.set_input(0, 1)
	await _ticks(100)
	ctrl.set_input(0, 1, 0, true)
	await _ticks(60)
	_check("sin dirección solo hay salto (no derrapa)", not kart.drifting and not kart.hop_active,
			"drifting=%s" % kart.drifting)

	# 3. Rampa: aterrizaje con mini turbo
	_reset()
	await _ticks(10)
	ctrl.set_input(0, 1)
	var max_y := 0.0
	for i in 480:
		await get_tree().physics_frame
		max_y = maxf(max_y, kart.sphere.global_position.y)
	print("      rampa: z=%.1f y_max=%.2f" % [kart.sphere.global_position.z, max_y])
	_check("salta y aterriza (mini turbo)", _landings.size() > 0 and _boost_sources.has(&"landing"),
			"aterrizajes=%s" % [_landings])

	# 4. Frenado y marcha atrás
	_reset()
	await _ticks(10)
	ctrl.set_input(0, 1)
	await _ticks(150)
	ctrl.set_input(0, 0, 1)
	await _ticks(120)
	_check("frena hasta parar", kart.sphere.linear_velocity.length() < 1.0 or kart.forward_speed < 0.0,
			"fspeed=%.2f" % kart.forward_speed)
	ctrl.set_input(0, 0, 1)
	await _ticks(60)
	_check("da marcha atrás", kart.forward_speed < -1.0, "fspeed=%.2f" % kart.forward_speed)

	# 5. Pantalla dividida
	await _test_split_screen()

	# 6. Versión
	_check("versión leída de VERSION", GameVersion.current == "0.1.0", GameVersion.current)
	_check("compare de versiones", GameVersion.compare("v1.2.0", "1.10.0") < 0)

	print("RESULTADO: %s" % ("TODO OK" if failures == 0 else "%d FALLOS" % failures))
	get_tree().quit(failures)
