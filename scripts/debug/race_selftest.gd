extends Node
## Autotest de carrera sin interfaz: circuito, cuenta atrás, bots, vueltas, llegadas y resultados.
##   Godot_console.exe --headless --path . res://scenes/debug/race_selftest.tscn
## Sale con código 0 si todo pasa.

const LAPS := 2
var _max_lap_seen := 1
var failures := 0
var verbose := true


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + name + "  " + detail)
	if not ok:
		failures += 1


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Engine.time_scale = 4.0
	GameSession.reset()
	GameSession.laps = LAPS
	var seats: Array[Seat] = [Seat.new()]
	seats[0].character_id = &"aurea"
	GameSession.setups = [{"slot": 0, "seats": seats, "team": -1, "vehicle": &"relampago"}]
	GameSession.bot_teams = [-1, -1, -1]
	var race: Node3D = load("res://scenes/race/race.tscn").instantiate()
	race.autopilot_humans = true
	add_child(race)
	await _ticks(2)
	var circuit: Circuit = race.circuit
	var manager: RaceManager = race.manager

	# --- Circuito ---
	_check("circuito: curva cerrada con muestras regulares",
			circuit.count > 200 and absf(circuit.points[0].distance_to(circuit.points[circuit.count - 1]) - circuit.step) < 1.0,
			"muestras=%d largo=%.0f m paso=%.2f" % [circuit.count, circuit.length, circuit.step])
	var near := circuit.nearest_global(circuit.points[40] + Vector3(1, 0, 1))
	_check("circuito: búsqueda de la muestra más cercana", near == 40, "idx=%d" % near)
	var g := circuit.grid_transform(0)
	var fwd := -g.basis.z
	_check("circuito: parrilla mira en el sentido de la carrera", fwd.dot(circuit.tangents[0]) > 0.95,
			"dot=%.3f" % fwd.dot(circuit.tangents[0]))
	_check("carrera: 1 humano + 3 bots", race.karts.size() == 4 and race.human_karts.size() == 1 and race.bot_karts.size() == 3)
	var hk: Kart = race.human_karts[0]
	var expected := KartBuild.to_kart_stats(KartBuild.combine(DataCatalog.vehicle(&"relampago"), DataCatalog.character(&"aurea")))
	_check("carrera: el kart usa las estadísticas del vehículo y personaje elegidos",
			is_equal_approx(hk.stats.max_speed, expected.max_speed) and hk.character.id == &"aurea"
			and hk.get_drift_color(3) == CharacterData.PINK,
			"vel_max=%.2f (esperada %.2f)" % [hk.stats.max_speed, expected.max_speed])
	var distinct := {}
	for b in race.bot_karts:
		distinct[b.stats.max_speed] = true
	_check("carrera: los bots también tienen vehículo y personaje", race.bot_karts[0].character != null and distinct.size() >= 1)

	# --- Cuenta atrás: karts congelados (Engine.time_scale = 4 -> cada fotograma son ~4 ticks físicos) ---
	_check("parrilla: progreso inicial negativo (detrás de la meta)", manager.racers[0].progress < 0.0,
			"progreso=%.1f" % manager.racers[0].progress)
	var start_positions: Array[Vector3] = []
	for k in race.karts:
		start_positions.append(k.sphere.global_position)
	await _ticks(12)
	var moved := 0.0
	for i in race.karts.size():
		moved = maxf(moved, race.karts[i].sphere.global_position.distance_to(start_positions[i]))
	_check("cuenta atrás: nadie se mueve antes de la salida", manager.state == RaceManager.State.COUNTDOWN and moved < 0.6,
			"estado=%d movido=%.2f" % [manager.state, moved])

	# --- Carrera completa ---
	var ticks := 0
	var max_ticks := 60 * 200
	var mid_checked := false
	var kart_finishes: Array[int] = []
	manager.kart_finished.connect(func(_k: Kart, place: int) -> void: kart_finishes.append(place))
	while manager.state != RaceManager.State.FINISHED and ticks < max_ticks:
		await get_tree().physics_frame
		ticks += 1
		if verbose and ticks % 600 == 0:
			var line := PackedStringArray()
			for r in manager.racers:
				line.append("%s p=%.0f v=%.0f" % [r.kart.racer_name, r.progress, r.kart.sphere.linear_velocity.length()])
			print("      t=%.0fs  %s" % [manager.race_time, " | ".join(line)])
		for r in manager.racers:
			_max_lap_seen = maxi(_max_lap_seen, manager.lap_of(r))
		if not mid_checked and manager.race_time > 12.0:
			mid_checked = true
			var sorted := manager.racers.duplicate()
			sorted.sort_custom(func(a: RaceManager.Racer, b: RaceManager.Racer) -> bool: return a.progress > b.progress)
			var ok := true
			for i in sorted.size():
				ok = ok and sorted[i].kart.race_position == i + 1
			_check("clasificación en vivo coincide con el progreso", ok)
	_check("la carrera termina", manager.state == RaceManager.State.FINISHED,
			"t=%.1fs fotogramas=%d" % [manager.race_time, ticks])
	for r in manager.racers:
		print("      %s: puesto %d, tiempo %.1f s, reapariciones %d" % [r.kart.racer_name, r.place, r.finish_time, r.respawns])
	var finished := 0
	var places := {}
	var respawns := 0
	for r in manager.racers:
		if r.finished:
			finished += 1
		places[r.place] = true
		respawns += r.respawns
	_check("el contador pasa a la vuelta 2", _max_lap_seen == 2, "vuelta máx. vista=%d" % _max_lap_seen)
	# Los ítems son aleatorios: un bot muy retrasado puede quedar sin llegar al acabar el plazo de gracia.
	_check("al menos 3 de 4 cruzan la meta (los demás puntúan por progreso)", finished >= 3, "llegaron=%d" % finished)
	_check("puestos 1..4 únicos", places.size() == 4 and places.has(1) and places.has(4))
	_check("resultados con 4 filas y puntos", manager.results.size() == 4 and manager.results[0]["points"] == 15,
			str(manager.results.size()))
	var t1: float = manager.results[0]["time"]
	_check("tiempo del ganador razonable (2 vueltas)", t1 > 30.0 and t1 < 150.0, "%.1f s" % t1)
	_check("bots sin atascos graves", respawns <= 2, "reapariciones=%d" % respawns)
	_check("el humano pasó a piloto automático al terminar", manager.racers[0].kart.controller is BotController)

	Engine.time_scale = 1.0
	print("RESULTADO: %s" % ("TODO OK" if failures == 0 else "%d FALLOS" % failures))
	get_tree().quit(failures)
