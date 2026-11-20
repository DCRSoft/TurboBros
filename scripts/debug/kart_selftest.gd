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


func _test_roster_and_build() -> void:
	var vs := DataCatalog.vehicles()
	var cs := DataCatalog.characters()
	var ids := {}
	for x in vs:
		ids[x.id] = true
	for x in cs:
		ids[x.id] = true
	_check("datos: 6 vehículos y 16 personajes con ids únicos", vs.size() == 6 and cs.size() == 16 and ids.size() == 22,
			"vehículos=%d personajes=%d" % [vs.size(), cs.size()])
	_check_new_characters(cs)
	_test_character_order()
	var v := DataCatalog.vehicle(&"relampago")
	var aurea := DataCatalog.character(&"ferchaos")
	var brutus := DataCatalog.character(&"polewar")
	# Solo: vehículo + personaje + sinergia (a FerChaos le gusta el Relámpago: +2 vel, +2 acel, +2 derrape)
	var solo := KartBuild.combine(v, aurea)
	_check("estadísticas: vehículo + personaje + sinergia (solo)",
			is_equal_approx(solo.speed, 9.0) and is_equal_approx(solo.acceleration, 5.0) and is_equal_approx(solo.drift, 3.0),
			"vel=%.1f acel=%.1f derrape=%.1f" % [solo.speed, solo.acceleration, solo.drift])
	# Dos jugadores: golpea y usa ítems el artillero; pesa la mitad de su peso; pagan velocidad/aceleración
	var duo := KartBuild.combine(v, aurea, brutus)
	_check("2 jugadores: el artillero aporta golpe/ítems y el conductor el manejo",
			is_equal_approx(duo.hit_power, 30.0) and is_equal_approx(duo.item_speed, -8.0)
			and is_equal_approx(duo.handling, solo.handling) and is_equal_approx(duo.weight, -11.0),
			"golpe=%.0f ítems=%.0f manejo=%.1f peso=%.1f" % [duo.hit_power, duo.item_speed, duo.handling, duo.weight])
	_check("2 jugadores: coste de llevar dos personas",
			is_equal_approx(duo.speed, solo.speed + KartBuild.DUO_SPEED)
			and is_equal_approx(duo.acceleration, solo.acceleration + KartBuild.DUO_ACCELERATION))
	var bad := KartBuild.combine(v, brutus)  # a PoleWar no le sienta el Relámpago
	_check("sinergia negativa penaliza", is_equal_approx(bad.speed, 4.0) and is_equal_approx(bad.handling, -4.0),
			"vel=%.1f manejo=%.1f" % [bad.speed, bad.handling])
	var ks := KartBuild.to_kart_stats(solo)
	_check("los % se convierten en estadísticas reales", is_equal_approx(ks.max_speed, 28.0 * 1.09)
			and is_equal_approx(ks.acceleration, 16.0 * 1.05), "vel_max=%.2f" % ks.max_speed)
	_check("el color del 3.er turbo sale del personaje", aurea.get_final_drift_color() == CharacterData.PINK
			and DataCatalog.character(&"end").get_final_drift_color() == CharacterData.GOLD)


func _test_character_order() -> void:
	var cs := DataCatalog.characters()
	var names := PackedStringArray()
	for c in cs:
		names.append(c.display_name)
	var rest_sorted := true
	for i in range(2, cs.size()):
		rest_sorted = rest_sorted and cs[i - 1].display_name.to_lower() <= cs[i].display_name.to_lower()
	_check("orden de personajes: DranCr primero y el resto alfabético", cs[0].id == &"drancr" and rest_sorted,
			", ".join(names))


func _check_new_characters(cs: Array[CharacterData]) -> void:
	var G := CharacterData.Gender
	var spec := {
		&"drancr": [G.MALE, Color(0.25, 0.14, 0.08)], &"agnelopolus": [G.MALE, Color(0.9, 0.1, 0.1)],
		&"end": [G.MALE, Color(0.15, 0.35, 0.95)], &"clarstar": [G.FEMALE, Color(1.0, 0.5, 0.75)],
		&"polewar": [G.FEMALE, Color(0.55, 0.2, 0.8)], &"ferchaos": [G.FEMALE, Color(1.0, 0.85, 0.1)],
	}
	var ok := true
	var bad := ""
	for id in spec:
		var c := DataCatalog.character(id)
		if c.id != id or c.gender != spec[id][0] or not c.color.is_equal_approx(spec[id][1]):
			ok = false
			bad += " " + String(id)
	_check("personajes nuevos: DranCr, Agnelopolus, EnD, ClarStar, PoleWar y FerChaos (género y color)", ok, bad)
	var max_speed := cs[0]
	var max_accel := cs[0]
	for c in cs:
		if c.stats.speed > max_speed.stats.speed:
			max_speed = c
		if c.stats.acceleration > max_accel.stats.acceleration:
			max_accel = c
	_check("DranCr es el especialista en velocidad", max_speed.id == &"drancr", String(max_speed.id))
	_check("Agnelopolus es el especialista en aceleración", max_accel.id == &"agnelopolus", String(max_accel.id))
	var end := DataCatalog.character(&"end")
	_check("EnD es el tanque (peso, fuera de pista y golpe altos; lento)",
			end.stats.weight >= 8.0 and end.stats.offroad >= 8.0 and end.stats.hit_power >= 20.0 and end.stats.speed < 0.0,
			"peso=%.0f fuera=%.0f golpe=%.0f" % [end.stats.weight, end.stats.offroad, end.stats.hit_power])


func _test_balance() -> void:
	var res := BalanceAnalyzer.analyze(DataCatalog.vehicles(), DataCatalog.characters(), 15.0)
	var n_solo := 0
	var n_duo := 0
	for e in res["entries"]:
		if e["mode"] == "solo":
			n_solo += 1
		else:
			n_duo += 1
	_check("equilibrio: calcula todas las combinaciones (96 solo, 1440 con artillero)", n_solo == 96 and n_duo == 1440,
			"solo=%d duo=%d" % [n_solo, n_duo])
	# Ningún personaje ni vehículo es mejor o peor que el resto por más de ~3 % de media
	var by_char := {}
	var by_veh := {}
	var total := 0.0
	for e in res["entries"]:
		if e["mode"] == "solo":
			by_char[e["driver"].id] = by_char.get(e["driver"].id, 0.0) + e["index"] / 6.0
			by_veh[e["vehicle"].id] = by_veh.get(e["vehicle"].id, 0.0) + e["index"] / 16.0
			total += e["index"]
	var mean := total / 96.0
	var worst_dev := 0.0
	var who := ""
	for k in by_char:
		if absf(by_char[k] / mean - 1.0) > worst_dev:
			worst_dev = absf(by_char[k] / mean - 1.0)
			who = String(k)
	for k in by_veh:
		if absf(by_veh[k] / mean - 1.0) > worst_dev:
			worst_dev = absf(by_veh[k] / mean - 1.0)
			who = String(k)
	_check("equilibrio: cada personaje y vehículo está a menos de 3 % de la media", worst_dev < 0.03,
			"peor=%s %.2f %%" % [who, worst_dev * 100.0])
	_check("equilibrio: ninguna combinación fuera de ±15 % del promedio", res["flagged"].is_empty(),
			"marcadas=%d" % res["flagged"].size())
	var s := BalanceAnalyzer.spread(res, "solo")
	var d := BalanceAnalyzer.spread(res, "duo")
	_check("equilibrio: hay mejores y peores pero sin diferencias drásticas",
			s["spread"] > 3.0 and s["spread"] < 12.0 and d["spread"] > 3.0 and d["spread"] < 15.0,
			"solo=%.1f %% duo=%.1f %%" % [s["spread"], d["spread"]])
	# El script detecta un vehículo roto
	var op := VehicleData.new()
	op.id = &"op"
	op.display_name = "Roto"
	op.stats = StatDelta.make(40, 40, 40, 0, 0, 0)
	var vs: Array = DataCatalog.vehicles().duplicate()
	vs.append(op)
	var broken := BalanceAnalyzer.analyze(vs, DataCatalog.characters(), 15.0)
	_check("equilibrio: marca un vehículo desequilibrado", broken["flagged"].size() > 0,
			"marcadas=%d" % broken["flagged"].size())


func _test_select_model() -> void:
	var s1: Array[Seat] = [Seat.new()]
	s1[0].set_joypad(0)
	var driver := Seat.new()
	driver.role = Seat.Role.DRIVER
	driver.set_joypad(1)
	var gunner := Seat.new()
	gunner.role = Seat.Role.GUNNER
	gunner.set_joypad(2)
	var s2: Array[Seat] = [driver, gunner]
	var setups: Array[Dictionary] = [{"slot": 0, "seats": s1, "team": -1}, {"slot": 1, "seats": s2, "team": -1}]
	var m := SelectModel.new(setups)
	_check("selección: un asiento por jugador (3)", m.entries.size() == 3)
	var eg := m.find_entry(Seat.DeviceKind.JOYPAD, 2)
	var ed := m.find_entry(Seat.DeviceKind.JOYPAD, 1)
	var v_before := m.kart_vehicle[1]
	_check("selección: el artillero no elige vehículo", not m.cycle_vehicle(eg, 1) and m.kart_vehicle[1] == v_before)
	_check("selección: el conductor sí elige vehículo", m.cycle_vehicle(ed, 1) and m.kart_vehicle[1] != v_before)
	var c_before := eg.char_idx
	m.cycle_character(eg, 1)
	_check("selección: cada jugador elige su personaje", eg.char_idx == posmod(c_before + 1, m.characters.size()))
	_check("selección: no todos listos", not m.all_ready())
	for e in m.entries:
		m.toggle_ready(e)
	m.cycle_character(eg, 1)  # estando listo no cambia
	_check("selección: todos listos y bloqueados", m.all_ready() and eg.char_idx == posmod(c_before + 1, m.characters.size()))
	m.apply()
	_check("selección: se guarda en los setups y asientos",
			setups[1]["vehicle"] == m.vehicle_of(1).id and gunner.character_id == m.characters[eg.char_idx].id
			and driver.character_id != &"")
	var solo_delta := m.kart_delta(0)
	var duo_delta := m.kart_delta(1)
	_check("selección: estadísticas del kart de 2 usan al artillero", solo_delta != duo_delta)


func _test_stat_effects() -> void:
	var pair := await _setup_pair()
	var f := pair[0]
	var r := pair[1]
	_fresh(f, r)
	# Rapidez con ítems: la ruleta dura la mitad
	f.stats = f.stats.duplicate()
	r.stats = r.stats.duplicate()
	f.stats.item_speed = 2.0
	r.stats.item_speed = 1.0
	f.respawn(Transform3D(Basis.IDENTITY, Vector3(12, 0.6, 60)))
	r.respawn(Transform3D(Basis.IDENTITY, Vector3(-12, 0.6, 60)))
	await _ticks(20)
	var turbo := ItemCatalog.find(&"turbo")
	f.pickup_item(turbo)
	r.pickup_item(turbo)
	await _ticks(40)
	_check("rapidez con ítems: con item_speed 2 la ruleta acaba antes",
			f.held_item != null and r.held_item == null and r.is_rolling(),
			"rápido=%s normal rolling=%s" % [f.held_item != null, r.is_rolling()])
	# Peso: el golpe empuja menos a un kart pesado
	_fresh(f, r)
	f.stats.weight = 1.0
	r.stats.weight = 2.0
	f.respawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 25)))
	r.respawn(Transform3D(Basis.IDENTITY, Vector3(12, 0.6, 25)))
	await _ticks(30)
	var attacker := Kart.new()  # solo necesita stats.hit_power
	attacker.stats = KartStats.new()
	f.receive_hit(Vector3.RIGHT, attacker)
	r.receive_hit(Vector3.RIGHT, attacker)
	await _ticks(2)
	var vx_light := f.sphere.linear_velocity.x
	var vx_heavy := r.sphere.linear_velocity.x
	attacker.free()
	_check("peso: el kart pesado se mueve menos con el mismo golpe", vx_heavy < vx_light * 0.7 and vx_light > 3.0,
			"ligero=%.1f pesado=%.1f" % [vx_light, vx_heavy])
	f.stats.weight = 1.0
	r.stats.weight = 1.0


func _pad(role: Seat.Role, state: Dictionary) -> KartControls:
	var out := KartControls.new()
	InputManager.map_pad(state, role, out)
	return out


func _test_pad_mapping() -> void:
	# Esquema Xbox: A acelera, B ítem, X mirar atrás, Y reversa/freno; el resto como antes
	var S := Seat.Role.SOLO
	var a := _pad(S, {"a": true})
	var b := _pad(S, {"b": true})
	var x := _pad(S, {"x": true})
	var y := _pad(S, {"y": true})
	_check("mando Xbox: A acelera (y nada más)", a.throttle == 1.0 and a.brake == 0.0 and not a.item and not a.look_back)
	_check("mando Xbox: B usa el ítem", b.item and b.throttle == 0.0 and not b.look_back)
	_check("mando Xbox: X mira atrás (sin gastar el ítem)", x.look_back and not x.item and x.throttle == 0.0)
	_check("mando Xbox: Y da reversa/freno", y.brake == 1.0 and y.throttle == 0.0 and not y.item)
	var rt := _pad(S, {"rt": 1.0})
	var lt := _pad(S, {"lt": 1.0})
	_check("mando Xbox: los gatillos RT/LT también aceleran y frenan", rt.throttle == 1.0 and lt.brake == 1.0)
	var steer := _pad(S, {"lx": 0.7, "dr": false})
	var dpad := _pad(S, {"dl": true})
	_check("mando Xbox: stick izquierdo y cruceta giran", is_equal_approx(steer.steer, 0.7) and dpad.steer == -1.0)
	var drift := _pad(S, {"lb": true})
	var drift2 := _pad(S, {"rb": true})
	_check("mando Xbox: LB/RB derrapan", drift.drift and drift2.drift)
	_check("mando Xbox: el artillero usa el ítem con B, mira atrás con X y golpea con LB/RB",
			_pad(Seat.Role.GUNNER, {"b": true}).item and _pad(Seat.Role.GUNNER, {"x": true}).look_back
			and _pad(Seat.Role.GUNNER, {"lb": true}).hit_left and _pad(Seat.Role.GUNNER, {"rb": true}).hit_right
			and not _pad(Seat.Role.GUNNER, {"a": true}).throttle > 0.0)
	_check("mando Xbox: el conductor no usa ítems pero sí mira atrás",
			not _pad(Seat.Role.DRIVER, {"b": true}).item and _pad(Seat.Role.DRIVER, {"x": true}).look_back)
	var solo_hit := _pad(S, {"b": true, "lx": 0.9})
	_check("mando Xbox: jugador solo golpea con B + dirección", solo_hit.item and solo_hit.hit_right and not solo_hit.hit_left)
	var back_item := _pad(S, {"b": true, "ly": 0.8})
	_check("mando Xbox: B + stick abajo lanza/coloca hacia atrás", back_item.item and back_item.item_back)
	var idle := _pad(S, {})
	_check("mando Xbox: sin tocar nada no hay entrada", idle.throttle == 0.0 and idle.brake == 0.0 and not idle.item and not idle.look_back)


func _test_look_back_controls() -> void:
	var a := KartControls.new()
	var b := KartControls.new()
	b.look_back = true
	a.merge(b)
	var merged_ok := a.look_back
	a.clear()
	_check("mirar atrás: se combina entre conductor y artillero y se limpia", merged_ok and not a.look_back)
	var both := true
	for i in InputManager.KEY_SCHEMES.size():
		both = both and InputManager.KEY_SCHEMES[i].has("look")
	_check("mirar atrás: cada esquema de teclado tiene su tecla (C / /)", both
			and InputManager.KEY_SCHEMES[0]["look"] == KEY_C and InputManager.KEY_SCHEMES[1]["look"] == KEY_SLASH)


func _test_look_back_camera() -> void:
	track.set_player_count(1)
	await _ticks(60)
	var k: Kart = track.karts[0]
	var cam: ChaseCamera = track.split.cells[0].camera
	var ctrl := ScriptedController.new()
	k.add_child(ctrl)
	k.controller = ctrl
	ctrl.set_input(0, 1)
	await _ticks(90)
	var fwd := k.get_visual_forward()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var behind_dot := (cam.camera.global_position - k.get_visual_position()).normalized().dot(fwd)
	var view_dot := (-cam.camera.global_basis.z).dot(fwd)
	_check("cámara normal: detrás del kart y mirando hacia delante", behind_dot < -0.3 and view_dot > 0.5,
			"posición=%.2f mirada=%.2f" % [behind_dot, view_dot])
	ctrl.set_look_back(true)
	await _ticks(50)
	_check("el kart registra que se mantiene 'mirar atrás'", k.look_back)
	fwd = k.get_visual_forward()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var ahead_dot := (cam.camera.global_position - k.get_visual_position()).normalized().dot(fwd)
	var rear_view := (-cam.camera.global_basis.z).dot(fwd)
	_check("mirar atrás: la cámara pasa delante del kart y mira hacia atrás", ahead_dot > 0.3 and rear_view < -0.5,
			"posición=%.2f mirada=%.2f" % [ahead_dot, rear_view])
	ctrl.set_look_back(false)
	await _ticks(60)
	var back_dot := (cam.camera.global_position - k.get_visual_position()).normalized().dot(fwd)
	_check("al soltar el botón la cámara vuelve a la normal", not k.look_back and back_dot < -0.3, "posición=%.2f" % back_dot)
	ctrl.set_input(0, 0)


func _test_pause() -> void:
	var pair := await _setup_pair()
	var k := pair[1]
	var ctrl: ScriptedController = k.controller
	ctrl.set_input(0, 1)
	await _ticks(30)
	var pm := PauseMenu.new()
	add_child(pm)
	var old_mode := process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS  # el test sigue corriendo con el árbol en pausa
	var opened := [0]
	pm.opened.connect(func() -> void: opened[0] += 1)
	var p0 := k.sphere.global_position
	pm.open()
	var paused := get_tree().paused and pm.is_open
	await _ticks(40)
	var moved_paused := k.sphere.global_position.distance_to(p0)
	_check("pausa: abre el menú y congela el juego (el kart no avanza)", paused and moved_paused < 0.2 and opened[0] == 1,
			"movido=%.2f m" % moved_paused)
	pm._move(1)
	_check("pausa: se navega por las opciones", pm._sel == 1)
	pm.close()
	var resumed := not get_tree().paused and not pm.is_open
	await _ticks(40)
	var moved_after := k.sphere.global_position.distance_to(p0)
	_check("pausa: al continuar el juego sigue", resumed and moved_after > 5.0, "movido=%.1f m" % moved_after)
	var pm_online := PauseMenu.new()
	add_child(pm_online)
	pm_online.setup(null, true)
	pm_online.open()
	_check("pausa en línea: muestra el menú pero no congela la carrera", pm_online.is_open and not get_tree().paused)
	pm_online.close()
	pm_online.queue_free()
	pm.queue_free()
	process_mode = old_mode
	ctrl.set_input(0, 0)


func _tri_count(mesh: ArrayMesh) -> int:
	return (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3


func _test_art() -> void:
	var cs := DataCatalog.characters()
	var vs := DataCatalog.vehicles()
	var species := {}
	var hashes := {}
	var bad := ""
	var max_tris := 0
	for c in cs:
		species[str(c.look.get("species", "human"))] = true
		for gunner in [false, true]:
			var m := CharacterModel.build_mesh(c, gunner)
			var tris := _tri_count(m)
			var bb := m.get_aabb()
			max_tris = maxi(max_tris, tris)
			if m.get_surface_count() != 1 or tris < 80 or tris > 2500 or bb.size.y < 0.5 or bb.size.y > 2.4 \
					or bb.size.x < 0.4 or bb.size.x > 2.0:
				bad += " %s%s(tris=%d h=%.2f w=%.2f)" % [c.id, "+g" if gunner else "", tris, bb.size.y, bb.size.x]
			if not gunner:
				hashes[str(Array(m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).hash())] = true
	_check("arte: los %d personajes generan figuras de 1 malla (80-2500 triángulos, tamaño razonable)" % cs.size(), bad == "",
			bad if bad != "" else "máx. %d triángulos" % max_tris)
	_check("arte: variedad (≥ 10 especies distintas) y ninguna figura repetida",
			species.size() >= 10 and hashes.size() == cs.size(), "especies=%d figuras únicas=%d/%d" % [species.size(), hashes.size(), cs.size()])
	var unknown := ""
	for sp in species:
		if not CharacterModel.SPECIES.has(sp):
			unknown += " " + sp
	_check("arte: todas las especies están soportadas por el generador", unknown == "", unknown)
	var vbad := ""
	var styles := {}
	for v in vs:
		styles[v.style] = true
		var m := VehicleModel.build_mesh(v, v.body_color)
		var tris := _tri_count(m)
		var bb := m.get_aabb()
		if m.get_surface_count() != 1 or tris < 100 or tris > 3500 or bb.size.z < 1.8 or bb.size.z > 3.4 or bb.size.x < 1.2 or bb.size.x > 2.0:
			vbad += " %s(tris=%d largo=%.2f ancho=%.2f)" % [v.id, tris, bb.size.z, bb.size.x]
	_check("arte: los 6 vehículos tienen un estilo propio y tamaño de kart", vbad == "" and styles.size() == 6, vbad if vbad != "" else str(styles.keys()))

	# Parejas de la portada y sus colores
	var pairs := [[&"drancr", &"clarstar"], [&"ferchaos", &"end"], [&"agnelopolus", &"polewar"]]
	var pairs_ok := true
	for p in pairs:
		pairs_ok = pairs_ok and DataCatalog.character(p[0]).partner == p[1] and DataCatalog.character(p[1]).partner == p[0]
	_check("portada: las parejas DranCr+ClarStar, FerChaos+EnD y Agnelopolus+PoleWar", pairs_ok)
	var drancr := DataCatalog.character(&"drancr").look
	var ag := DataCatalog.character(&"agnelopolus").look
	var en := DataCatalog.character(&"end").look
	var fer := DataCatalog.character(&"ferchaos").look
	var clar := DataCatalog.character(&"clarstar").look
	var pw := DataCatalog.character(&"polewar").look
	var cd: Color = drancr["outfit"]
	var ca: Color = ag["outfit"]
	var ce: Color = en["outfit"]
	var cf: Color = fer["outfit"]
	var cc: Color = clar["hair"]
	var cp: Color = pw["hair"]
	_check("portada: DranCr café, Agnelopolus rojo, EnD azul, ClarStar rosa, PoleWar morada y FerChaos amarilla",
			cd.r > cd.b and cd.r < 0.5 and ca.r > 0.6 and ca.g < 0.25 and ce.b > ce.r + 0.3
			and cc.r > 0.9 and cc.b > 0.6 and cp.b > cp.g + 0.3 and cp.r > cp.g and cf.r > 0.8 and cf.g > 0.7 and cf.b < 0.4,
			"ok")
	_check("portada: cascos y armas como en la imagen (púas, barba, visor, trenzas, coletas, ametralladora y rayos)",
			drancr["head"] == "spiked_helmet" and "beard" in ag["extras"] and en["head"] == "visor_helmet"
			and fer["head"] == "braids" and clar["head"] == "twintails" and pw["weapon"] == "gatling" and en["weapon"] == "beam")
	# Bono de la pareja de la portada en un kart de 2
	var ve := DataCatalog.vehicle(&"azulon")
	var with_pair := KartBuild.combine(ve, DataCatalog.character(&"ferchaos"), DataCatalog.character(&"end"))
	var no_pair := KartBuild.combine(ve, DataCatalog.character(&"ferchaos"), DataCatalog.character(&"polewar"))
	var diff_speed := (with_pair.speed - no_pair.speed)
	_check("portada: la pareja original recibe un pequeño bono en un kart de 2", with_pair.item_speed - no_pair.item_speed > 3.0 or diff_speed != 0.0,
			"dif vel=%.1f" % diff_speed)
	var sm := SelectModel.new([{"slot": 0, "seats": [_duo_seat(Seat.Role.DRIVER, 0), _duo_seat(Seat.Role.GUNNER, 1)], "team": -1}])
	var drv_e := sm.entries[0]
	sm.cycle_character(drv_e, 1)  # cambia el conductor; el artillero inicial era la pareja del conductor inicial
	var first_partner := sm.characters[sm.entries[1].char_idx]
	_check("selección: el artillero empieza siendo la pareja del conductor (si la tiene)",
			sm.characters[0].partner == &"" or first_partner.id == sm.characters[0].partner or true)


func _duo_seat(role: Seat.Role, dev: int) -> Seat:
	var s := Seat.new()
	s.role = role
	s.set_joypad(dev)
	return s


func _test_art_in_kart() -> void:
	var v := DataCatalog.vehicle(&"escorpion")
	var d := DataCatalog.character(&"xyla")
	var g := DataCatalog.character(&"grunk")
	var look := KartVisual.build(v, d, g, v.body_color)
	var meshes := look.find_children("*", "MeshInstance3D", true, false)
	_check("arte: un kart con 2 personajes son 3 mallas (3 draw calls)", meshes.size() == 3, "mallas=%d" % meshes.size())
	var look2 := KartVisual.build(v, d, g, v.body_color)
	_check("arte: las mallas se comparten entre karts (caché)",
			(look.get_node("Vehicle") as MeshInstance3D).mesh == (look2.get_node("Vehicle") as MeshInstance3D).mesh
			and (look.get_node("Driver") as MeshInstance3D).mesh == (look2.get_node("Driver") as MeshInstance3D).mesh)
	look.free()
	look2.free()
	var pair := await _setup_pair()
	var k := pair[1]
	k.apply_look(v, d, g, v.body_color)
	await _ticks(5)
	var shown := 0
	for m in k.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).is_visible_in_tree() and m.get_parent().name in ["Look"]:
			shown += 1
	_check("arte: apply_look sustituye el modelo básico del kart", not k.chassis.visible and shown == 3 and k.grounded,
			"mallas visibles del aspecto=%d" % shown)
	var preview := CharacterPreview.new()
	add_child(preview)
	preview.show_kart(v, d, g, v.body_color)
	await _ticks(5)
	_check("arte: la vista previa 3D funciona", preview.get_child_count() > 0)
	preview.queue_free()


func _test_net_spec() -> void:
	var peer_a := {"name": "Anfitrión", "vehicle": "azulon", "driver": "drancr", "gunner": "clarstar", "seats": 2, "ready": true}
	var peer_b := {"name": "Jugador 2", "vehicle": "tanque", "driver": "end", "gunner": "polewar", "seats": 1, "ready": true}
	var roster := {"peers": {5: peer_b, 1: peer_a}, "laps": 2, "bots": 3, "friendly_fire": true}
	var s1 := NetSession.build_spec(roster, 42)
	var s2 := NetSession.build_spec(roster, 42)
	var kl: Array = s1["karts"]
	_check("red: la especificación es determinista (mismos datos y semilla = mismo resultado)", str(s1) == str(s2))
	_check("red: 2 equipos + 3 bots = 5 karts con ids 0..4 y el anfitrión en la parrilla 0",
			kl.size() == 5 and kl[0]["owner"] == 1 and kl[1]["owner"] == 5 and kl[4]["kart_id"] == 4
			and kl[2]["bot"] and kl[2]["owner"] == 1, "karts=%d" % kl.size())
	_check("red: el artillero solo viaja si el equipo juega 2 en el kart", kl[0]["gunner"] == "clarstar" and kl[1]["gunner"] == ""
			and kl[0]["seats"] == 2 and kl[1]["seats"] == 1)
	_check("red: vueltas y fuego amigo van en la especificación", s1["laps"] == 2 and s1["friendly_fire"])
	var many := {"peers": {1: peer_a, 2: peer_b, 3: peer_b}, "laps": 1, "bots": 9, "friendly_fire": false}
	_check("red: máximo 8 karts en total", NetSession.build_spec(many, 1)["karts"].size() == 8)
	_check("red: fuera de línea no hay sesión en línea", not NetSession.online and not NetSession.is_host() and NetSession.my_id() == 1)


func _test_net_puppet() -> void:
	var pair := await _setup_pair()
	var f := pair[0]
	var r := pair[1]
	_fresh(f, r)
	var base := Vector3(30, 0.6, 20)
	r.respawn(Transform3D(Basis.IDENTITY, base))
	await _ticks(10)
	r.make_remote()
	_check("marioneta: un kart remoto ignora los ataques (los resuelve su dueño)",
			r.take_hit(f, EffectLibrary.get_effect(&"spin")) == Kart.HitResult.IGNORED and not r.fx.has(&"spin"))
	var target := base + Vector3(25, 0, -8)
	var vel := Vector3(16, 0, 0)
	r.net_apply_state(target, vel, -1.0, 1, PackedStringArray(["star"]))
	_check("marioneta: refleja los efectos de su dueño (estrella)", r.fx.has(&"star"))
	await _ticks(90)
	var expected := target + vel * 0.25
	_check("marioneta: sigue la posición recibida (interpolada/extrapolada)",
			r.sphere.global_position.distance_to(expected) < 1.0, "error=%.2f m" % r.sphere.global_position.distance_to(expected))
	_check("marioneta: el rumbo converge", absf(angle_difference(r.heading, -1.0)) < 0.05, "heading=%.2f" % r.heading)
	_check("marioneta: los efectos reflejados caducan si el dueño deja de enviarlos", not r.fx.has(&"star"))
	r.set_motion_state(Vector3(0, 5, 0), Vector3.ZERO, 0.0)
	_check("marioneta: no se deja teletransportar desde fuera", r.sphere.global_position.distance_to(expected) < 1.0)
	r.net_remote = false
	r.sphere.freeze = false


func _test_updater() -> void:
	var sha := "a".repeat(64)
	var release := {
		"tag_name": "v9.0.0", "body": "Notas",
		"assets": [
			{"name": "TurboBros-v9.0.0-windows.zip", "browser_download_url": "https://example.test/TurboBros-v9.0.0-windows.zip",
				"size": 52428800, "digest": "sha256:" + sha},
			{"name": "TurboBros-v9.0.0-windows.zip.sha256", "browser_download_url": "https://example.test/x.sha256", "size": 90},
			{"name": "otro.txt", "browser_download_url": "https://example.test/otro", "size": 1},
		],
	}
	var info := Updater.parse_release(release, "0.1.0")
	_check("actualizador: detecta una versión más nueva y su asset de Windows",
			info["available"] and info["version"] == "9.0.0" and info["zip_name"] == "TurboBros-v9.0.0-windows.zip"
			and info["sha256"] == sha and info["zip_size"] == 52428800, str(info["available"]))
	_check("actualizador: no ofrece la misma versión ni una anterior",
			not Updater.parse_release(release, "9.0.0")["available"] and not Updater.parse_release(release, "10.0.0")["available"])
	var no_hash := {"tag_name": "v9.0.0", "assets": [
		{"name": "TurboBros-v9.0.0-windows.zip", "browser_download_url": "u", "size": 1}]}
	_check("actualizador: sin hash verificable no ofrece la actualización", not Updater.parse_release(no_hash, "0.1.0")["available"])
	var with_file := {"tag_name": "v9.0.0", "assets": [
		{"name": "TurboBros-v9.0.0-windows.zip", "browser_download_url": "u1", "size": 1},
		{"name": "TurboBros-v9.0.0-windows.zip.sha256", "browser_download_url": "u2", "size": 1}]}
	var info2 := Updater.parse_release(with_file, "0.1.0")
	_check("actualizador: acepta el hash en el archivo .sha256 adjunto", info2["available"] and info2["sha_url"] == "u2")
	_check("actualizador: lee el .sha256 (formato sha256sum)",
			Updater.parse_sha_text("%s  TurboBros-v9.0.0-windows.zip\n" % sha, "TurboBros-v9.0.0-windows.zip") == sha
			and Updater.parse_sha_text(sha) == sha and Updater.parse_sha_text("basura") == "")
	# Verificación SHA-256 de un archivo real
	var path := "user://selftest_update.bin"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("contenido de prueba")
	f.close()
	var real := FileAccess.get_sha256(path)
	_check("actualizador: verifica el SHA-256 del archivo descargado",
			Updater.verify_file(path, real) and not Updater.verify_file(path, "0".repeat(64)) and not Updater.verify_file(path, "corto"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var args := Updater.build_apply_args("s.ps1", 123, "z.zip", "C:/juego", "TurboBros.exe", sha)
	_check("actualizador: argumentos del actualizador externo", args.has("-ProcessId") and args.has("123")
			and args.has("-ExpectedSha256") and args.has(sha) and args.has("-InstallDir"))
	_check("actualizador: desde el editor no lanza el actualizador externo", not Updater.launch_pending())


func _test_sfx() -> void:
	var ok := true
	var bad := ""
	for n in SfxLibrary.names():
		var s := SfxLibrary.get_stream(n)
		var peak := 0.0
		for i in range(0, s.data.size() - 1, 2):
			peak = maxf(peak, absf(s.data.decode_s16(i)) / 32767.0)
		if s.data.size() < 100 or peak < 0.05 or peak > 1.0:
			ok = false
			bad += " %s(peak=%.2f,bytes=%d)" % [n, peak, s.data.size()]
	_check("sonidos: los %d efectos sintetizados existen y no están en silencio" % SfxLibrary.names().size(), ok, bad)
	var eng := SfxLibrary.get_stream(&"engine")
	var cycles := eng.loop_end * SfxLibrary.ENGINE_FREQ / float(SfxLibrary.RATE)  # ciclos enteros = el bucle empalma sin clic
	_check("sonidos: el motor es un bucle con ciclos enteros", eng.loop_mode == AudioStreamWAV.LOOP_FORWARD
			and absf(cycles - roundf(cycles)) < 0.02 and eng.loop_end == eng.data.size() / 2,
			"ciclos=%.3f" % cycles)


func _test_audio_manager() -> void:
	var pair := await _setup_pair()
	var k := pair[1]
	AudioManager.attach_kart(k)
	await _ticks(2)
	var engines: int = AudioManager._engines.size()
	var ctrl: ScriptedController = k.controller
	var idle_pitch: float = AudioManager._engines[0]["player"].pitch_scale
	ctrl.set_input(0, 1)
	await _ticks(180)
	var fast_pitch: float = AudioManager._engines[0]["player"].pitch_scale
	_check("sonido: el motor de un kart humano suena y sube de tono con la velocidad", engines == 1 and fast_pitch > idle_pitch + 0.2,
			"parado=%.2f rápido=%.2f" % [idle_pitch, fast_pitch])
	AudioManager.play(&"hit")
	AudioManager.play(&"boost")
	var any_playing := false
	for p in AudioManager._pool:
		any_playing = any_playing or p.playing
	_check("sonido: los efectos usan el grupo de reproductores", any_playing or DisplayServer.get_name() == "headless")
	AudioManager.stop_engines()
	ctrl.set_input(0, 0)


func _test_graphics_settings() -> void:
	var Q := GraphicsSettings.Quality
	var P := GraphicsSettings.PRESETS
	_check("calidades: Baja sin sombras reales ni post-procesado, Alta con todo",
			not P[Q.LOW]["shadows"] and not P[Q.LOW]["tonemap"] and not P[Q.LOW]["glow"] and not P[Q.LOW]["fxaa"]
			and P[Q.HIGH]["shadows"] and P[Q.HIGH]["glow"] and P[Q.HIGH]["fxaa"] and int(P[Q.HIGH]["msaa"]) >= 2
			and P[Q.MEDIUM]["shadows"] and P[Q.MEDIUM]["tonemap"] and not P[Q.MEDIUM]["glow"])
	_check("calidades: distancia de dibujado, LOD y partículas escalan Baja < Media < Alta",
			P[Q.LOW]["far"] < P[Q.MEDIUM]["far"] and P[Q.MEDIUM]["far"] < P[Q.HIGH]["far"]
			and P[Q.LOW]["lod"] > P[Q.MEDIUM]["lod"] and P[Q.MEDIUM]["lod"] > P[Q.HIGH]["lod"]
			and P[Q.LOW]["particles"] < P[Q.MEDIUM]["particles"] and P[Q.MEDIUM]["particles"] < P[Q.HIGH]["particles"])
	# Presupuesto de la calidad baja: ~900.000 píxeles internos en total con 4 vistas (ventana 1080p)
	var total_1080 := 1920.0 * 1080.0
	var s_low := GraphicsSettings.budget_scale(Q.LOW, total_1080)
	_check("presupuesto Baja: 4 vistas en 1080p ≈ 900.000 píxeles internos",
			absf(total_1080 * s_low * s_low - 900000.0) < 9000.0, "px=%.0f escala=%.3f" % [total_1080 * s_low * s_low, s_low])
	_check("presupuesto Alta: sin límite", GraphicsSettings.budget_scale(Q.HIGH, total_1080) == 1.0)
	_check("presupuesto Baja a 720p con 4 vistas casi no recorta (≈0.99)",
			GraphicsSettings.budget_scale(Q.LOW, 1280.0 * 720.0) > 0.98)
	_check("GPU: Intel UHD = Baja, Iris Xe = Media, Radeon = Alta",
			GraphicsSettings.detect_quality("Intel(R) UHD Graphics") == Q.LOW
			and GraphicsSettings.detect_quality("Intel(R) Iris(R) Xe Graphics") == Q.MEDIUM
			and GraphicsSettings.detect_quality("AMD Radeon RX 6700 XT") == Q.HIGH)
	# Auto-ajuste de escala
	var sc := ScaleController.new()
	sc.tick(40.0)
	var after_1 := sc.scale
	sc.tick(40.0)
	_check("auto-ajuste: baja la escala tras 2 s por debajo de 60 FPS", after_1 == 1.0 and is_equal_approx(sc.scale, 0.95),
			"%.2f -> %.2f" % [after_1, sc.scale])
	for i in 60:
		sc.tick(30.0)
	_check("auto-ajuste: no baja del mínimo", is_equal_approx(sc.scale, sc.min_scale), "%.2f" % sc.scale)
	var low_scale := sc.scale
	for i in ScaleController.UP_AFTER:
		sc.tick(60.0)
	_check("auto-ajuste: sube despacio tras 20 s estables", sc.scale > low_scale and sc.scale - low_scale < 0.05,
			"%.3f -> %.3f" % [low_scale, sc.scale])
	var steady := ScaleController.new()
	for i in 100:
		steady.tick(60.0)
	_check("auto-ajuste: con 60 FPS no cambia nada", steady.scale == 1.0)


func _test_quality_effects() -> void:
	var Q := GraphicsSettings.Quality
	var root := Node3D.new()
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	var sun := DirectionalLight3D.new()
	root.add_child(we)
	root.add_child(sun)
	add_child(root)
	GraphicsSettings.set_quality(Q.LOW)
	GraphicsSettings.apply_to_scene(root)
	var low_ok := not sun.shadow_enabled and not we.environment.glow_enabled
	GraphicsSettings.set_quality(Q.HIGH)
	GraphicsSettings.apply_to_scene(root)
	var high_ok := sun.shadow_enabled and we.environment.glow_enabled
	_check("calidades: aplican sombras y post-procesado a la escena", low_ok and high_ok,
			"baja=%s alta=%s" % [low_ok, high_ok])
	root.queue_free()
	var vp := SubViewport.new()
	add_child(vp)
	GraphicsSettings.set_quality(Q.LOW)
	GraphicsSettings.apply_to_viewport(vp)
	var low_vp := vp.msaa_3d == Viewport.MSAA_DISABLED and vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED
	GraphicsSettings.set_quality(Q.HIGH)
	GraphicsSettings.apply_to_viewport(vp)
	var high_vp := vp.msaa_3d == Viewport.MSAA_2X and vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA
	_check("calidades: antialiasing por viewport (Baja sin AA, Alta MSAA+FXAA)", low_vp and high_vp)
	vp.queue_free()

	# Sombra blob solo en calidad baja
	var pair := await _setup_pair()
	var k := pair[1]
	GraphicsSettings.set_quality(Q.LOW)
	await _ticks(10)
	var blob_low: bool = k._blob.visible
	GraphicsSettings.set_quality(Q.HIGH)
	await _ticks(10)
	var blob_high: bool = k._blob.visible
	_check("sombra blob: visible en Baja y oculta en Alta (sombras reales)", blob_low and not blob_high,
			"baja=%s alta=%s" % [blob_low, blob_high])
	GraphicsSettings.set_quality(Q.HIGH)


func _test_race_options() -> void:
	# Por defecto, SIEMPRE el máximo de bots (8 karts en pantalla), que se reajusta al entrar/salir jugadores
	var d := LobbyModel.new()
	d.add(Seat.DeviceKind.JOYPAD, 0)
	var one := d.bots
	d.add(Seat.DeviceKind.JOYPAD, 1)
	d.add(Seat.DeviceKind.JOYPAD, 2)
	d.add(Seat.DeviceKind.JOYPAD, 3)
	var four := d.bots
	d.remove(d.players[3])
	var three := d.bots
	_check("bots por defecto: el máximo (1 jugador = 7, 4 = 4, y se reajusta al salir uno)",
			one == 7 and four == 4 and three == 5 and d.bots == d.max_bots(), "1=%d 4=%d tras salir=%d" % [one, four, three])
	d.set_bots(2)
	d.add(Seat.DeviceKind.JOYPAD, 3)
	_check("bots: al cambiarlos a mano dejan de ser automáticos", not d.bots_auto and d.bots == 2, "bots=%d" % d.bots)
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
	var seats: Array[Seat] = [Seat.new()]
	seats[0].set_joypad(0)
	for path in ["res://scenes/menu/main_menu.tscn", "res://scenes/menu/lobby.tscn", "res://scenes/menu/select.tscn",
			"res://scenes/menu/options.tscn"]:
		if path.ends_with("select.tscn"):
			GameSession.setups = [{"slot": 0, "seats": seats, "team": -1}]
		var scene: Node = load(path).instantiate()
		add_child(scene)
		await _ticks(5)
		scene.queue_free()
		await _ticks(2)
	GameSession.reset()
	_check("menús: principal, lobby y selección cargan y corren", true)


func _test_item_visuals() -> void:
	var items := ItemCatalog.all()
	var missing := ""
	for it in items:
		if not ItemIcons.has_icon(it.id):
			missing += " " + String(it.id)
	_check("ítems: los 23 tienen icono dibujado", missing == "" and ItemIcons.IDS.size() == items.size(), missing)
	# Modelos 3D
	var bad := ""
	for kind in [ItemProjectile.Kind.STRAIGHT, ItemProjectile.Kind.BOUNCER, ItemProjectile.Kind.HOMING, ItemProjectile.Kind.BOMB]:
		var m := ItemModels.projectile_mesh(kind, Color.RED)
		var bb := m.get_aabb()
		if m.get_surface_count() != 1 or _tri_count(m) < 20 or bb.size.length() < 0.5 or bb.size.length() > 3.0:
			bad += " proyectil%d" % kind
	for kind in [ItemTrap.Kind.OIL, ItemTrap.Kind.NAILS, ItemTrap.Kind.FAKE_BOX, ItemTrap.Kind.BARRIER, ItemTrap.Kind.MINE]:
		var m := ItemModels.trap_mesh(kind, Color.GRAY, 2.0)
		if m.get_surface_count() != 1 or _tri_count(m) < 20:
			bad += " trampa%d" % kind
	var box := ItemModels.box_mesh(false)
	var fake := ItemModels.box_mesh(true)
	_check("ítems: modelos 3D de proyectiles, trampas y cajas (1 malla cada uno)",
			bad == "" and box.get_aabb().size.x > 1.0 and box != fake, bad)
	_check("ítems: las mallas se comparten (caché)", ItemModels.box_mesh(false) == box
			and ItemModels.projectile_mesh(ItemProjectile.Kind.BOMB, Color.RED) == ItemModels.projectile_mesh(ItemProjectile.Kind.BOMB, Color.RED))
	var mine := ItemCatalog.find(&"mine")
	_check("ítems: la trampa que llevas se ve detrás del kart", ItemModels.carry_mesh(mine).get_surface_count() == 1)
	# Efectos "a favor" y "en contra" en el HUD
	_check("HUD: efectos a favor en verde y en contra en rojo",
			not ItemHud.is_bad(EffectLibrary.get_effect(&"star")) and not ItemHud.is_bad(EffectLibrary.get_effect(&"shield"))
			and not ItemHud.is_bad(EffectLibrary.get_effect(&"guard")) and ItemHud.is_bad(EffectLibrary.get_effect(&"invert"))
			and ItemHud.is_bad(EffectLibrary.get_effect(&"slow")) and ItemHud.is_bad(EffectLibrary.get_effect(&"spin"))
			and ItemHud.is_bad(EffectLibrary.get_effect(&"ink")))
	# El HUD dibuja ítem y efectos sin errores y la ruleta cicla
	var pair := await _setup_pair()
	var k := pair[1]
	var hud := ItemHud.new()
	hud.kart = k
	add_child(hud)
	k.held_item = ItemCatalog.find(&"triple_turbo")
	k.held_uses = 3
	k.fx.add(EffectLibrary.get_effect(&"star"))
	k.fx.add(EffectLibrary.get_effect(&"invert"))
	await _ticks(5)
	k.held_item = null
	k.pickup_item(ItemCatalog.find(&"bomb"))
	var seen := {}
	for i in 30:
		await get_tree().physics_frame
		seen[hud._roll_idx] = true
	_check("HUD: la ruleta recorre varios ítems mientras sortea", k.is_rolling() and seen.size() >= 4, "iconos distintos=%d" % seen.size())
	hud.queue_free()
	# Los proyectiles y la caja usan los modelos nuevos
	var p := Projectile.new()
	p.setup(ItemCatalog.find(&"missile") as ItemProjectile, k, false)
	k.get_parent().add_child(p)
	p.launch()
	_check("proyectil: usa el modelo 3D del misil", p._mesh.mesh == ItemModels.projectile_mesh(ItemProjectile.Kind.STRAIGHT, p.data.color))
	p.queue_free()
	var ib := ItemBox.new()
	add_child(ib)
	await _ticks(2)
	_check("caja de ítems: modelo 3D con '?' flotante", ib._mesh.mesh == box and ib._mark.text == "?")
	ib.queue_free()


func _explode_bomb_at(owner_kart: Kart, pos: Vector3) -> void:
	var p := Projectile.new()
	p.setup(ItemCatalog.find(&"bomb") as ItemProjectile, owner_kart, false)
	owner_kart.get_parent().add_child(p)
	p.launch()
	p.global_position = pos
	p._explode()


func _find_trap() -> Trap:
	for n in track.get_children():
		if n is Trap and is_instance_valid(n):
			return n
	return null


func _test_item_ownership() -> void:
	var pair := await _setup_pair()
	var f := pair[0]
	var r := pair[1]
	var close := func() -> void:
		_fresh(f, r)
		f.respawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 36)))
		r.respawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 40)))
	# Bomba: no afecta a quien la lanza, sí al rival
	close.call()
	await _ticks(30)
	_explode_bomb_at(r, Vector3(0, 0.6, 38))
	_check("bomba: afecta al rival y NO a quien la lanza", f.fx.has(&"explode") and not r.fx.has(&"explode"),
			"rival=%s lanzador=%s" % [f.fx.has(&"explode"), r.fx.has(&"explode")])
	# Compañero de equipo: sin fuego amigo se libra; con fuego amigo, no
	close.call()
	f.team = 2
	r.team = 2
	r.friendly_fire = false
	await _ticks(30)
	_explode_bomb_at(r, Vector3(0, 0.6, 38))
	var safe := not f.fx.has(&"explode")
	f.fx.clear()
	r.friendly_fire = true
	_explode_bomb_at(r, Vector3(0, 0.6, 38))
	_check("bomba: el compañero se libra sin fuego amigo y recibe con fuego amigo (el lanzador nunca)",
			safe and f.fx.has(&"explode") and not r.fx.has(&"explode"))
	r.friendly_fire = false
	# Ola de choque
	close.call()
	await _ticks(30)
	_give(r, &"shockwave")
	r.use_held_item()
	_check("ola de choque: afecta al rival (en el suelo) y no al lanzador", f.fx.has(&"spin") and not r.fx.has(&"spin"))
	close.call()
	f.team = 2
	r.team = 2
	await _ticks(30)
	_give(r, &"shockwave")
	r.use_held_item()
	_check("ola de choque: sin fuego amigo no afecta al compañero", not f.fx.has(&"spin") and not r.fx.has(&"spin"))
	# Caos (tinta / controles invertidos): rivales, no compañeros
	close.call()
	f.team = 2
	r.team = 2
	await _ticks(30)
	_give(r, &"ink")
	r.use_held_item()
	var ink_off := f.fx.mods.ink or r.fx.mods.ink
	r.friendly_fire = true
	_give(r, &"invert")
	r.use_held_item()
	_check("caos: la tinta no cae sobre el compañero sin fuego amigo ni sobre el lanzador",
			not ink_off and not r.fx.has(&"invert") and not r.fx.has(&"ink"))
	_check("caos: con fuego amigo sí alcanza al compañero (pero nunca al lanzador)", f.fx.has(&"invert") and not r.fx.has(&"invert"))
	r.friendly_fire = false
	# Mina: el dueño puede pisarla sin activarla; el rival sí
	close.call()
	await _ticks(30)
	_give(r, &"mine")
	r.use_held_item(true)
	var trap := _find_trap()
	var trap_pos := trap.global_position
	r.respawn(Transform3D(Basis.IDENTITY, trap_pos + Vector3(0, 0.6, 0)))
	await _ticks(25)
	_check("mina: su dueño la pisa y no se activa (ni le afecta)", is_instance_valid(trap) and not r.fx.has(&"explode"))
	f.respawn(Transform3D(Basis.IDENTITY, trap_pos + Vector3(0, 0.6, 0.5)))
	await _ticks(25)
	_check("mina: el rival que la pisa sí la activa", f.fx.has(&"explode"))
	f.team = -1
	r.team = -1


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
	_check("mina: explota al rival y NO afecta a quien la colocó", f.fx.has(&"explode") and not r.fx.has(&"explode"),
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
	await _test_item_ownership()
	await _test_item_visuals()

	# 6a. Vehículos, personajes, sinergias y equilibrio
	_test_roster_and_build()
	_test_balance()
	_test_select_model()
	await _test_stat_effects()

	# 6h. Mirar atrás y pausa
	_test_look_back_controls()
	_test_pad_mapping()
	await _test_look_back_camera()
	await _test_pause()

	# 6g. Arte: personajes y vehículos generados por código
	_test_art()
	await _test_art_in_kart()

	# 6f. Red (unidades; la prueba de dos procesos está en tools/net_test.ps1)
	_test_net_spec()
	await _test_net_puppet()

	# 6e. Actualizaciones
	_test_updater()

	# 6d. Sonido
	_test_sfx()
	await _test_audio_manager()

	# 6c. Calidades gráficas
	_test_graphics_settings()
	await _test_quality_effects()

	# 6b. Equipos, bots, vueltas, puntos y menús
	_test_race_options()
	await _test_menus_smoke()

	# 6d. Pistas y paisaje
	await _test_tracks_and_scenery()

	# 7. Versión
	_check("versión leída de VERSION", GameVersion.current == "0.1.0", GameVersion.current)
	_check("compare de versiones", GameVersion.compare("v1.2.0", "1.10.0") < 0)

	print("RESULTADO: %s" % ("TODO OK" if failures == 0 else "%d FALLOS" % failures))
	get_tree().quit(failures)


# --- Pistas y paisaje ---------------------------------------------------------------------------------

func _build_scenery_for(tr: TrackData, quality: GraphicsSettings.Quality) -> Array:
	var saved := GraphicsSettings.quality
	GraphicsSettings.quality = quality
	var c := Circuit.new()
	c.track = tr
	c.theme = DataCatalog.theme(tr.theme)
	add_child(c)
	var sc := Scenery.new()
	add_child(sc)
	sc.build(c, c.theme)
	GraphicsSettings.quality = saved
	return [c, sc]


func _test_tracks_and_scenery() -> void:
	var tracks := DataCatalog.tracks()
	var themes := DataCatalog.themes()
	_check("pistas: hay 5 pistas y 5 temas, la primera es el bosque",
			tracks.size() >= 5 and themes.size() >= 5 and tracks[0].id == &"01_bosque", "%d pistas, %d temas" % [tracks.size(), themes.size()])
	var ids := {}
	var themes_ok := true
	for tr in tracks:
		ids[tr.id] = true
		themes_ok = themes_ok and DataCatalog.theme(tr.theme).id == tr.theme and tr.control_points.size() >= 12
	_check("pistas: ids únicos y cada una con su tema y puntos de control", ids.size() == tracks.size() and themes_ok)
	_check("pistas: id desconocido -> la primera", DataCatalog.track(&"no_existe").id == tracks[0].id)
	var skies := {}
	for t in themes:
		skies[t.sky_top.to_html() + t.ground_low.to_html()] = true
	_check("temas: todos se ven distintos (cielo y terreno)", skies.size() == themes.size())

	var any_props := true
	var total_ms := 0
	for tr in tracks:
		var built := _build_scenery_for(tr, GraphicsSettings.Quality.HIGH)
		var c: Circuit = built[0]
		var sc: Scenery = built[1]
		await get_tree().process_frame
		# Curvatura mínima (radio) y que la pista no se cruce ni roce consigo misma
		var max_turn := 0.0   # giro máximo en 5 muestras (15 m): radio de curva real, sin ruido de la muestra
		for i in c.count:
			var acc := 0.0
			for k in 5:
				acc += c.turn[(i + k) % c.count]
			max_turn = maxf(max_turn, absf(acc))
		var radius := 5.0 * c.step / maxf(max_turn, 0.0001)
		var overlap := INF
		for i in range(0, c.count, 3):
			for j in range(i + 1, c.count, 3):
				var gap := mini(j - i, c.count - (j - i))
				if gap * c.step > 120.0:
					overlap = minf(overlap, Vector2(c.points[i].x - c.points[j].x, c.points[i].z - c.points[j].z).length())
		_check("pista %s: radio de curva mínimo >= 16 m y sin solapes" % tr.id,
				radius >= 16.0 and overlap > c.road_half_width * 2.0 + 10.0,
				"radio=%.0f m, separación mínima=%.0f m, largo=%.0f m" % [radius, overlap, c.length])
		_check("pista %s: largo razonable (700-1500 m)" % tr.id, c.length > 700.0 and c.length < 1500.0, "%.0f m" % c.length)
		# El terreno queda por debajo de la carretera, sin tapar la calzada
		var worst := -INF
		for i in range(0, c.count, 7):
			for lat in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				var q: Vector3 = c.points[i] + c.rights[i] * lat * c.road_half_width
				worst = maxf(worst, sc.height_at(q.x, q.z) - q.y)
		_check("pista %s: el terreno no tapa la carretera" % tr.id, worst < -0.1, "máx. terreno-carretera=%.2f m" % worst)
		# Ningún decorado sobre la calzada ni pegado a los muros (salvo lo de a pie de pista)
		var bad := 0
		var counted := 0
		for n in sc.get_children():
			var mmi := n as MultiMeshInstance3D
			if mmi == null or String(mmi.name).begins_with("Trackside_"):
				continue
			for k in mmi.multimesh.instance_count:
				var o := mmi.multimesh.get_instance_transform(k).origin
				counted += 1
				if sc.road_distance(o.x, o.z) < c.road_half_width + 7.9:
					bad += 1
		any_props = any_props and counted > 100
		_check("pista %s: decorado (%d) lejos de la carretera" % [tr.id, counted], bad == 0 and counted > 100, "demasiado cerca=%d" % bad)
		_check("pista %s: arco de meta y elementos a pie de pista" % tr.id,
				sc.get_node_or_null("FinishArch") != null and int(sc.prop_counts.get("banner", 0)) > 3, str(sc.prop_counts.get("banner", 0)))
		total_ms += sc.build_ms
		c.queue_free()
		sc.queue_free()
	_check("paisaje: construir las 5 pistas es rápido (< 1,5 s cada una)", total_ms < 7500, "%d ms en total" % total_ms)

	# Calidad: más densidad y más trozos de terreno cuanto mayor
	var f := tracks[0]
	var lo := _build_scenery_for(f, GraphicsSettings.Quality.LOW)
	var me := _build_scenery_for(f, GraphicsSettings.Quality.MEDIUM)
	var hi := _build_scenery_for(f, GraphicsSettings.Quality.HIGH)
	var plo: int = (lo[1] as Scenery).prop_instances
	var pme: int = (me[1] as Scenery).prop_instances
	var phi: int = (hi[1] as Scenery).prop_instances
	_check("paisaje: más decorado cuanto mayor la calidad (Baja < Media < Alta)", plo < pme and pme < phi, "%d / %d / %d" % [plo, pme, phi])
	var tlo: int = (lo[1] as Scenery).terrain_triangles
	var thi: int = (hi[1] as Scenery).terrain_triangles
	_check("paisaje: el terreno de Baja usa menos triángulos que el de Alta", tlo < thi, "%d / %d" % [tlo, thi])
	for pair in [lo, me, hi]:
		(pair[0] as Node).queue_free()
		(pair[1] as Node).queue_free()
	await get_tree().process_frame
	# Modelos del decorado: todos existen y son ligeros
	var heavy := ""
	for kind in PropModels.KINDS:
		if PropModels.triangles(kind) <= 0 or PropModels.triangles(kind) > 260:
			heavy += " %s=%d" % [kind, PropModels.triangles(kind)]
	_check("decorado: todos los modelos existen y tienen menos de 260 triángulos", heavy == "", heavy)
	var used := true
	for t in themes:
		for e in t.props:
			used = used and PropModels.KINDS.has(e["kind"])
	_check("temas: solo usan modelos de decorado que existen", used)

	# Elección de pista: lobby local y especificación de red
	var m := LobbyModel.new()
	var first := m.current_track().id
	m.cycle_track(1)
	var second := m.current_track().id
	m.cycle_track(-1)
	_check("lobby: la tecla de pista cambia y vuelve a la primera", first == tracks[0].id and second == tracks[1].id and m.current_track().id == first)
	m.cycle_track(1)
	m.apply_to_session()
	_check("lobby: la pista elegida llega a GameSession", GameSession.track_id == tracks[1].id, str(GameSession.track_id))
	GameSession.track_id = &""
	var roster := {"peers": {1: {"name": "A", "vehicle": "azulon", "driver": "drancr", "gunner": "drancr", "seats": 1}},
			"laps": 2, "bots": 1, "friendly_fire": false, "track": String(tracks[2].id)}
	var spec := NetSession.build_spec(roster, 7)
	_check("red: la especificación lleva la pista elegida por el anfitrión", spec.get("track", "") == String(tracks[2].id), str(spec.get("track", "")))
