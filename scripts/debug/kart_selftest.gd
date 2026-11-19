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


func _test_lobby_model() -> void:
	var expected := {1: [1], 2: [1, 1], 3: [1, 1, 1], 4: [1, 1, 1, 1], 5: [1, 2, 2],
			6: [2, 2, 2], 7: [1, 2, 2, 2], 8: [2, 2, 2, 2]}
	for n in expected:
		var m := LobbyModel.new()
		for i in n:
			m.add(Seat.DeviceKind.JOYPAD, i)
		var sizes: Array = []
		for s in m.build_setups():
			sizes.append(s["seats"].size())
		_check("lobby: %d jugadores -> %s" % [n, expected[n]], sizes == expected[n], str(sizes))
	var m := LobbyModel.new()
	for i in 4:
		m.add(Seat.DeviceKind.JOYPAD, i)
	var p0 := m.players[0]
	_check("lobby: mover a un kart ocupado con 1 jugador", m.move(p0, 1) and m.members(1).size() == 2)
	_check("lobby: no se puede pasar de 2 por kart", not m.move(m.players[2], -1))
	var duo: Array = m.build_setups()[0]["seats"]
	_check("lobby: kart de 2 = conductor + artillero",
			duo.size() == 2 and duo[0].role == Seat.Role.DRIVER and duo[1].role == Seat.Role.GUNNER)
	m.swap_roles(1)
	var duo2: Array = m.build_setups()[0]["seats"]
	_check("lobby: intercambiar roles", duo2[0].role == Seat.Role.GUNNER and duo2[1].role == Seat.Role.DRIVER)
	m.remove(m.players[3])
	_check("lobby: al salir alguien se reparte de nuevo", m.players.size() == 3 and m.build_setups().size() == 3)

	var drv := KartControls.new()
	drv.steer = 0.7
	drv.throttle = 1.0
	var gun := KartControls.new()
	gun.item = true
	gun.hit_right = true
	var merged := KartControls.new()
	merged.merge(drv)
	merged.merge(gun)
	_check("conductor + artillero se combinan en los controles del kart",
			merged.steer == 0.7 and merged.throttle == 1.0 and merged.item and merged.hit_right)


func _test_hits() -> void:
	track.set_player_count(2)
	await _ticks(60)
	var a: Kart = track.karts[0]
	var b: Kart = track.karts[1]
	a.respawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 70)))
	b.respawn(Transform3D(Basis.IDENTITY, Vector3(2.5, 0.6, 70)))  # a la derecha de A
	var ca := ScriptedController.new()
	a.add_child(ca)
	a.controller = ca
	var landed: Array[bool] = []
	a.hit_landed.connect(func(_t: Kart) -> void: landed.append(true))
	await _ticks(30)
	# golpe a la izquierda: B está a la derecha -> no le afecta
	ca.set_hit(true, false)
	await _ticks(3)
	ca.set_hit(false, false)
	await _ticks(10)
	_check("golpe izquierdo no alcanza a un kart a la derecha", landed.is_empty() and b.sphere.linear_velocity.x < 1.0,
			"vx=%.2f" % b.sphere.linear_velocity.x)
	await _ticks(40)  # enfriamiento
	ca.set_hit(false, true)
	await _ticks(3)
	ca.set_hit(false, false)
	var peak_vx := 0.0
	for i in 20:
		await get_tree().physics_frame
		peak_vx = maxf(peak_vx, b.sphere.linear_velocity.x)
	_check("golpe derecho empuja al kart de la derecha", landed.size() == 1 and peak_vx > 3.0,
			"golpes=%d vx_max=%.2f" % [landed.size(), peak_vx])


func _test_race_options() -> void:
	var m := LobbyModel.new()
	m.add(Seat.DeviceKind.JOYPAD, 0)
	m.add(Seat.DeviceKind.JOYPAD, 1)
	m.add(Seat.DeviceKind.JOYPAD, 2)
	_check("bots: 3 karts humanos -> máx. 5 bots", m.max_bots() == 5, str(m.max_bots()))
	m.set_bots(9)
	_check("bots: se limita al máximo (8 karts en pantalla)", m.bots == 5, str(m.bots))
	for i in 3:
		m.add(Seat.DeviceKind.KEYBOARD, i)  # 6 jugadores -> 3 karts de 2
	_check("bots: se recortan si se ocupan más karts", m.bots <= m.max_bots())
	m.set_laps(0)
	var low := m.laps
	m.set_laps(99)
	_check("vueltas: entre 1 y 9", low == 1 and m.laps == 9, "%d / %d" % [low, m.laps])

	var t := LobbyModel.new()
	t.add(Seat.DeviceKind.JOYPAD, 0)
	t.set_bots(3)
	_check("equipos: sin equipos los bots van libres", str(t.bot_teams()) == "[-1, -1, -1]", str(t.bot_teams()))
	t.cycle_team(0, 1)
	_check("equipos: el kart pasa al equipo Rojo", t.teams[0] == 0, str(t.teams[0]))
	_check("equipos: los bots equilibran y crean rival", str(t.bot_teams()) == "[1, 0, 1]", str(t.bot_teams()))
	t.cycle_team(0, -1)
	_check("equipos: se puede volver a sin equipo", t.teams[0] == -1)
	t.toggle_friendly_fire()
	t.set_laps(5)
	t.apply_to_session()
	_check("sesión: el lobby entrega vueltas, fuego amigo, karts y bots",
			GameSession.laps == 5 and GameSession.friendly_fire and GameSession.setups.size() == 1
			and GameSession.bot_teams.size() == 3, "vueltas=%d" % GameSession.laps)
	GameSession.reset()
	_check("puntos por puesto", RaceManager.points_for(1) == 15 and RaceManager.points_for(8) == 2
			and RaceManager.points_for(12) == 1)
	var rm := RaceManager.new()
	rm.results = [
		{"team": 0, "points": 15}, {"team": 1, "points": 12}, {"team": 0, "points": 10}, {"team": -1, "points": 8},
	]
	var scores := rm.team_scores()
	_check("equipos: suma de puntos por equipo", scores.get(0) == 25 and scores.get(1) == 12 and not scores.has(-1),
			str(scores))
	rm.free()


func _test_menus_smoke() -> void:
	for path in ["res://scenes/menu/main_menu.tscn", "res://scenes/menu/lobby.tscn"]:
		var scene: Node = load(path).instantiate()
		add_child(scene)
		await _ticks(5)
		scene.queue_free()
		await _ticks(2)
	_check("menús: principal y lobby cargan y corren", true)


func _test_effects_unit() -> void:
	var fx := KartEffects.new()
	fx.add(EffectLibrary.get_effect(&"slow"))
	_check("efecto: aplica modificadores", is_equal_approx(fx.mods.speed_mult, 0.6), str(fx.mods.speed_mult))
	for i in 250:
		fx.tick(1.0 / 60.0)
	_check("efecto: caduca por temporizador", fx.instances.is_empty() and fx.mods.speed_mult == 1.0)
	fx.add(EffectLibrary.get_effect(&"boost"), 0.6, 1.35)
	fx.add(EffectLibrary.get_effect(&"boost"), 1.0, 1.35)
	_check("efecto: renovar no duplica y alarga", fx.instances.size() == 1 and fx.instances[0].time_left >= 0.99)
	fx.clear()
	fx.add(EffectLibrary.get_effect(&"guard"))
	var absorbed := 0
	for i in 4:
		if fx.consume_guard():
			absorbed += 1
	fx.tick(0.01)
	_check("guardia: absorbe 3 ataques y desaparece", absorbed == 3 and fx.instances.is_empty(), "absorbidos=%d" % absorbed)
	fx.add(EffectLibrary.get_effect(&"invert"))
	fx.add(EffectLibrary.get_effect(&"slow"))
	_check("efectos distintos se combinan", fx.mods.steer_mult == -1.0 and fx.mods.speed_mult < 1.0)


func _test_catalog_and_roller() -> void:
	var items := ItemCatalog.all()
	var ids := {}
	var counts := {}
	for it in items:
		ids[it.id] = true
		counts[it.category] = counts.get(it.category, 0) + 1
	var C := ItemData.Category
	_check("catálogo: 23 ítems con ids únicos", items.size() == 23 and ids.size() == 23,
			"items=%d únicos=%d" % [items.size(), ids.size()])
	_check("catálogo: categorías 3/3/5/5/3/4", counts.get(C.SPEED) == 3 and counts.get(C.DEFENSE) == 3
			and counts.get(C.ATTACK) == 5 and counts.get(C.TRAP) == 5 and counts.get(C.INVINCIBILITY) == 3
			and counts.get(C.CHAOS) == 4, str(counts))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var strong := [&"rocket", &"star", &"giant", &"ghost", &"reflect", &"shockwave", &"swap", &"slow_ahead"]
	var first_strong := 0
	var last_strong := 0
	for i in 2000:
		if ItemRoller.roll(1, 8, rng).id in strong:
			first_strong += 1
		if ItemRoller.roll(8, 8, rng).id in strong:
			last_strong += 1
	_check("reparto: en 1.º nunca salen ítems potentes y en último muchos", first_strong == 0 and last_strong > 600,
			"1.º=%d último=%d de 2000" % [first_strong, last_strong])


func _setup_pair() -> Array[Kart]:
	track.set_player_count(2)
	await _ticks(5)
	var out: Array[Kart] = [track.karts[0], track.karts[1]]
	for k in out:
		var c := ScriptedController.new()
		k.add_child(c)
		k.controller = c
	out[0].respawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 25)))
	out[1].respawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 40)))
	await _ticks(30)
	return out


func _give(k: Kart, id: StringName) -> void:
	k.held_item = ItemCatalog.find(id)
	k.held_uses = k.held_item.uses


func _fresh(f: Kart, r: Kart) -> void:
	for k in [f, r]:
		k.fx.clear()
		k.held_item = null
		k.team = -1
	f.respawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 25)))
	r.respawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 40)))


func _test_items() -> void:
	var pair := await _setup_pair()
	var f := pair[0]  # delante (z=25)
	var r := pair[1]  # detrás (z=40)
	_check("clasificación: el de delante va 1.º", f.race_position == 1 and r.race_position == 2,
			"f=%d r=%d" % [f.race_position, r.race_position])

	# Turbo por la entrada del jugador (pulsar ítem)
	f.respawn(Transform3D(Basis.IDENTITY, Vector3(12, 0.6, 60)))
	_give(r, &"turbo")
	var cr: ScriptedController = r.controller
	cr.set_item(true)
	await _ticks(2)
	cr.set_item(false)
	var peak := 0.0
	for i in 60:
		await get_tree().physics_frame
		peak = maxf(peak, r.get_speed_kmh() / 3.6)
	_check("ítem turbo: se usa con el botón y acelera", r.held_item == null and peak > 30.0, "pico=%.1f m/s" % peak)
	_fresh(f, r)
	await _ticks(30)

	# Proyectil recto
	_give(r, &"missile")
	r.use_held_item()
	await _ticks(35)
	_check("proyectil recto golpea al de delante", f.fx.has(&"spin"), "efectos=%d" % f.fx.instances.size())

	# Escudo bloquea
	_fresh(f, r)
	await _ticks(30)
	f.fx.add(EffectLibrary.get_effect(&"shield"))
	_give(r, &"missile")
	r.use_held_item()
	await _ticks(35)
	_check("escudo bloquea el proyectil", not f.fx.has(&"spin"))

	# Burbuja reflectante
	_fresh(f, r)
	await _ticks(30)
	f.fx.add(EffectLibrary.get_effect(&"reflect"))
	_give(r, &"missile")
	r.use_held_item()
	await _ticks(85)
	_check("burbuja reflejo devuelve el proyectil al atacante", r.fx.has(&"spin") and not f.fx.has(&"spin"))

	# Orbitales
	_fresh(f, r)
	await _ticks(30)
	f.fx.add(EffectLibrary.get_effect(&"guard"))
	_give(r, &"missile")
	r.use_held_item()
	await _ticks(35)
	_check("orbitales absorben un ataque", not f.fx.has(&"spin") and f.fx.total_guard_charges() == 2,
			"cargas=%d" % f.fx.total_guard_charges())

	# Trampa llevada atrás como escudo
	_fresh(f, r)
	await _ticks(30)
	_give(f, &"mine")
	_give(r, &"missile")
	r.use_held_item()
	await _ticks(35)
	_check("trampa en mano hace de escudo trasero", f.held_item == null and not f.fx.has(&"spin"))

	# Aceite colocado detrás
	_fresh(f, r)
	await _ticks(30)
	_give(r, &"oil")
	r.use_held_item(true)  # 3 m detrás de r (z=43)
	f.respawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 44.0)))
	await _ticks(20)
	_check("aceite: resbalón al pisarlo", f.fx.has(&"oil_slip"))

	# Barrera: aunque se use hacia adelante, queda detrás (no bloquea al dueño)
	_fresh(f, r)
	f.respawn(Transform3D(Basis.IDENTITY, Vector3(12, 0.6, 60)))
	await _ticks(30)
	_give(r, &"barrier")
	r.use_held_item(false)
	await _ticks(2)
	var barrier: Trap
	for n in track.get_children():
		if n is Trap and n.data.kind == ItemTrap.Kind.BARRIER:
			barrier = n
	_check("barrera: siempre se coloca detrás del dueño", barrier != null and barrier.position.z > r.sphere.global_position.z + 2.0,
			"barrera z=%.1f kart z=%.1f" % [barrier.position.z if barrier else 0.0, r.sphere.global_position.z])
	if barrier:
		barrier.queue_free()

	# Mina: explota al acercarse y afecta al radio
	_fresh(f, r)
	await _ticks(30)
	_give(r, &"mine")
	r.use_held_item(true)
	f.respawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 44.5)))
	await _ticks(20)
	_check("mina: explota y afecta a los cercanos", f.fx.has(&"explode") and r.fx.has(&"explode"),
			"f=%s r=%s" % [f.fx.has(&"explode"), r.fx.has(&"explode")])

	# Caos
	_fresh(f, r)
	await _ticks(30)
	_give(r, &"slow_ahead")
	r.use_held_item()
	_check("caos: ralentiza al de delante", f.fx.has(&"slow") and not r.fx.has(&"slow"))
	_give(r, &"ink")
	r.use_held_item()
	_give(r, &"invert")
	r.use_held_item()
	_check("caos: tinta y controles invertidos", f.fx.mods.ink and f.fx.mods.steer_mult == -1.0)

	# Intercambio de posición
	_fresh(f, r)
	await _ticks(30)
	_give(r, &"swap")
	r.use_held_item()
	await _ticks(10)
	_check("intercambio de posición", r.sphere.global_position.z < 30.0 and f.sphere.global_position.z > 35.0,
			"r.z=%.1f f.z=%.1f" % [r.sphere.global_position.z, f.sphere.global_position.z])

	# Estrella golpea al tocar
	_fresh(f, r)
	f.respawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 38.0)))
	await _ticks(20)
	_give(r, &"star")
	r.use_held_item()
	await _ticks(10)
	_check("estrella: golpea al kart que toca", f.fx.has(&"spin") and r.fx.mods.immune)

	# Fantasma y gigante
	_fresh(f, r)
	await _ticks(30)
	_give(r, &"ghost")
	r.use_held_item()
	await _ticks(3)
	_check("fantasma: sin colisión con karts e ignora ataques",
			r.sphere.collision_mask == 1 and r.take_hit(f, null) == Kart.HitResult.IGNORED)
	_fresh(f, r)
	await _ticks(30)
	_give(r, &"giant")
	r.use_held_item()
	await _ticks(40)
	_check("gigante: crece y pesa más", r.model.global_basis.get_scale().x > 1.5 and r.sphere.mass > 2.5,
			"escala=%.2f masa=%.1f" % [r.model.global_basis.get_scale().x, r.sphere.mass])

	# Equipos y fuego amigo
	_fresh(f, r)
	f.team = 1
	r.team = 1
	var ff_off := f.take_hit(r, null)
	f.friendly_fire = false
	r.friendly_fire = true
	var ff_on := f.take_hit(r, null)
	r.friendly_fire = false
	_check("equipos: sin fuego amigo por defecto, activable",
			ff_off == Kart.HitResult.IGNORED and ff_on == Kart.HitResult.HIT)
	f.team = -1
	r.team = -1

	# Caja de ítems
	_fresh(f, r)
	f.respawn(Transform3D(Basis.IDENTITY, Vector3(12, 0.6, 60)))
	r.respawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 50)))  # sobre una caja
	await _ticks(20)
	var rolling := r.is_rolling()
	await _ticks(80)
	_check("caja de ítems: sortea y entrega un ítem", rolling and r.held_item != null,
			"ítem=%s" % [r.held_item.id if r.held_item else "ninguno"])


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

	# 2a. Contravolante: el derrape se abre (mismo lado = cerrado, lado contrario = abierto)
	var turned := {}
	for counter in [false, true]:
		_reset()
		await _ticks(10)
		ctrl.set_input(0, 1)
		await _ticks(100)
		ctrl.set_input(1, 1, 0, true)
		await _ticks(40)
		var drifting_ok := kart.drifting
		var h0 := kart.heading
		ctrl.set_input(-1 if counter else 1, 1, 0, true)
		await _ticks(60)
		turned[counter] = absf(kart.heading - h0)
		_check("derrape %s: sigue derrapando" % ("con contravolante" if counter else "cerrado"),
				drifting_ok and kart.drifting)
	_check("contravolante abre el derrape (gira < 40 % que el cerrado)",
			turned[true] < turned[false] * 0.4 and turned[false] > 1.0,
			"cerrado=%.2f rad, abierto=%.2f rad" % [turned[false], turned[true]])

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

	# 6. Lobby, asientos y golpes
	_test_lobby_model()
	await _test_hits()
	_test_effects_unit()
	_test_catalog_and_roller()
	await _test_items()

	# 6b. Equipos, bots, vueltas, puntos y menús
	_test_race_options()
	await _test_menus_smoke()

	# 7. Versión
	_check("versión leída de VERSION", GameVersion.current == "0.1.0", GameVersion.current)
	_check("compare de versiones", GameVersion.compare("v1.2.0", "1.10.0") < 0)

	print("RESULTADO: %s" % ("TODO OK" if failures == 0 else "%d FALLOS" % failures))
	get_tree().quit(failures)
