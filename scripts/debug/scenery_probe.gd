extends Node
## Diagnóstico por pista: construye el paisaje (tiempos, trozos, triángulos, decorado) y corre 1 vuelta con 4 karts de
## IA para comprobar que se puede completar sin atascos (reapariciones).
##   Godot_console.exe --headless --path . res://scenes/debug/scenery_probe.tscn

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.time_scale = 4.0
	var failures := 0
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	for tr in DataCatalog.tracks():
		if only != "" and String(tr.id) != only:
			continue
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
		var taken := 0
		for r in m.racers:
			var bc := r.kart.get_node_or_null("Bot") as BotController
			if bc != null:
				taken += bc.shortcuts_taken
		var slowest := INF   # los karts lentos (tanque + personaje pesado) pueden quedarse fuera del plazo de gracia: basta con que avancen
		for r in m.racers:
			slowest = minf(slowest, r.progress / m.circuit.length)
		var ok := m.state == RaceManager.State.FINISHED and fin >= 1 and slowest > 0.85 and resp <= 2
		failures += 0 if ok else 1
		print("%s %s: %.0f m, paisaje %d ms, trozos=%d tris=%d props=%d | 1 vuelta: ganador %.1f s, llegaron %d/4, reapariciones %d, atajos tomados %d" % [
				"OK  " if ok else "FALLO", tr.id, race.circuit.length, s.build_ms, s.terrain_chunks, s.terrain_triangles,
				s.prop_instances, m.results[0]["time"] if not m.results.is_empty() else -1.0, fin, resp, taken])
		if only != "":
			for r in m.racers:
				print("      %s: llegó=%s tiempo=%.1f progreso=%.0f/%.0f reapariciones=%d" % [r.kart.racer_name, r.finished,
						r.finish_time, r.progress, m.circuit.length, r.respawns])
		race.queue_free()
		await get_tree().process_frame
	Engine.time_scale = 1.0
	print("RESULTADO: %s" % ("TODO OK" if failures == 0 else "%d FALLOS" % failures))
	get_tree().quit(failures)
