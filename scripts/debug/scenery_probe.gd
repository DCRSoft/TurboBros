extends Node
## Diagnóstico por pista: construye el paisaje (tiempos, trozos, triángulos, decorado) y corre 1 vuelta con 4 karts de
## IA para comprobar que se puede completar sin atascos (reapariciones).
##   Godot_console.exe --headless --path . res://scenes/debug/scenery_probe.tscn

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.time_scale = 4.0
	var failures := 0
	for tr in DataCatalog.tracks():
		GameSession.reset()
		GameSession.laps = 1
		var seats: Array[Seat] = [Seat.new()]
		GameSession.setups = [{"slot": 0, "seats": seats, "team": -1}]
		GameSession.bot_teams = [-1, -1, -1]
		var race: Node3D = load("res://scenes/race/race.tscn").instantiate()
		race.track_override = tr.id
		race.autopilot_humans = true
		add_child(race)
		await get_tree().physics_frame
		var s: Scenery = race.scenery
		var m: RaceManager = race.manager
		var ticks := 0
		while m.state != RaceManager.State.FINISHED and ticks < 60 * 300:
			await get_tree().physics_frame
			ticks += 1
		var fin := 0
		var resp := 0
		for r in m.racers:
			fin += 1 if r.finished else 0
			resp += r.respawns
		var ok := m.state == RaceManager.State.FINISHED and fin >= 2 and resp <= 2
		failures += 0 if ok else 1
		print("%s %s: %.0f m, paisaje %d ms, trozos=%d tris=%d props=%d | 1 vuelta: ganador %.1f s, llegaron %d/4, reapariciones %d" % [
				"OK  " if ok else "FALLO", tr.id, race.circuit.length, s.build_ms, s.terrain_chunks, s.terrain_triangles,
				s.prop_instances, m.results[0]["time"] if not m.results.is_empty() else -1.0, fin, resp])
		race.queue_free()
		await get_tree().process_frame
	Engine.time_scale = 1.0
	print("RESULTADO: %s" % ("TODO OK" if failures == 0 else "%d FALLOS" % failures))
	get_tree().quit(failures)
