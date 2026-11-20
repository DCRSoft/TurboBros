extends Node
## Lógica de la prueba de red. Un proceso hace de anfitrión y otro de cliente, en localhost.
## Escenario: sala -> elecciones -> carrera de 1 vuelta (2 humanos conducidos por la IA + 2 bots) -> resultados.

var role := "host"
var addr := "127.0.0.1"
var port := 24690
var failures := 0
var items_received := 0
var melee_received := 0
var states_received := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.get_slice("=", 1)
		elif a.begins_with("--addr="):
			addr = a.get_slice("=", 1)
		elif a.begins_with("--port="):
			port = int(a.get_slice("=", 1))
	_run.call_deferred()


func _say(msg: String) -> void:
	print("[%s] %s" % [role, msg])


func _check(name: String, ok: bool, detail := "") -> void:
	print("[%s] %s  %s  %s" % [role, "PASS" if ok else "FAIL", name, detail])
	if not ok:
		failures += 1


func _wait(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while not cond.call() and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()


func _race() -> Node:
	var s := get_tree().current_scene
	return s if s != null and s.get("manager") != null else null


func _run() -> void:
	NetSession.bind_ip = "127.0.0.1"
	if role == "host":
		var err := NetSession.host_game(port)
		_check("anfitrión: crea la partida", err == OK, "error=%d" % err)
		NetSession.test_autopilot = true
		var joined := await _wait(func() -> bool: return NetSession.peer_count() >= 2, 40.0)
		_check("anfitrión: el cliente se une a la sala", joined, "equipos=%d" % NetSession.peer_count())
		_check("anfitrión: por defecto el máximo de bots (8 karts - 2 equipos = 6)", int(NetSession.roster["bots"]) == 6,
				"bots=%d" % int(NetSession.roster["bots"]))
		NetSession.set_choice({"vehicle": "relampago", "driver": "drancr", "gunner": "clarstar", "seats": 1, "ready": true})
		NetSession.set_host_config(1, 2, false)
		var ready := await _wait(func() -> bool: return NetSession.can_start(), 40.0)
		_check("anfitrión: todos listos (se puede dar la salida)", ready)
		var peer: Dictionary = NetSession.roster["peers"].get(NetSession.roster["peers"].keys().filter(func(k: int) -> bool: return k != 1)[0], {})
		_check("anfitrión: ve las elecciones del cliente", peer.get("driver") == "end" and peer.get("vehicle") == "tanque",
				"%s / %s" % [peer.get("driver"), peer.get("vehicle")])
		NetSession.start_race()
	else:
		var err := NetSession.join_game(addr, port)
		_check("cliente: inicia la conexión", err == OK, "error=%d" % err)
		NetSession.test_autopilot = true
		var in_room := await _wait(func() -> bool: return NetSession.roster["peers"].size() >= 2, 40.0)
		_check("cliente: recibe la sala", in_room, "equipos=%d" % NetSession.roster["peers"].size())
		NetSession.set_choice({"vehicle": "tanque", "driver": "end", "gunner": "polewar", "seats": 1, "ready": true})

	var started := await _wait(func() -> bool: return not NetSession.spec.is_empty(), 60.0)
	_check("la carrera arranca en ambos equipos", started)
	if not started:
		return _finish()
	_check("especificación: 4 karts (2 equipos + 2 bots), 1 vuelta",
			NetSession.spec["karts"].size() == 4 and NetSession.spec["laps"] == 1, str(NetSession.spec["karts"].size()))
	NetSession.item_used_received.connect(func(_s: int, _k: int, _i: String, _b: bool, _q: int) -> void: items_received += 1)
	NetSession.melee_received.connect(func(_s: int, _v: int, _d: Vector3, _a: int) -> void: melee_received += 1)
	NetSession.state_received.connect(func(_s: int, _k: int, _d: Array) -> void: states_received += 1)

	var in_scene := await _wait(func() -> bool: return _race() != null, 40.0)
	_check("escena de carrera cargada", in_scene)
	if not in_scene:
		return _finish()
	var race := _race()
	var manager: RaceManager = race.manager
	var karts: Array[Kart] = race.karts
	var local_n := 0
	var remote_n := 0
	for k in karts:
		if k.net_remote:
			remote_n += 1
		else:
			local_n += 1
	var my_expected_local := 1 + (2 if role == "host" else 0)  # el anfitrión simula también a los 2 bots
	_check("karts: los propios son locales y los demás marionetas", local_n == my_expected_local and remote_n == 4 - my_expected_local,
			"locales=%d remotos=%d" % [local_n, remote_n])
	_check("una sola vista (1 kart humano local con cámara)", race.split.cells.size() == 1 and race.human_karts.size() == 1)

	var racing := await _wait(func() -> bool: return manager.state == RaceManager.State.RACING, 30.0)
	_check("la cuenta atrás termina y empieza la carrera en ambos", racing)
	# Las marionetas deben moverse (siguen a sus dueños)
	await get_tree().create_timer(12.0).timeout
	var moved_ok := true
	var detail := ""
	for k in karts:
		if k.net_remote:
			var progress := manager.get_racer(k).progress
			if progress < 60.0:
				moved_ok = false
			detail += " k%d=%.0fm" % [k.net_id, progress]
	_check("las marionetas avanzan por el circuito siguiendo a su dueño", moved_ok, detail)
	_check("se reciben instantáneas de estado", states_received > 100, "recibidas=%d" % states_received)

	var finished := await _wait(func() -> bool: return manager.state == RaceManager.State.FINISHED, 150.0)
	_check("la carrera termina y llegan los resultados", finished, "t=%.1fs" % manager.race_time)
	if finished:
		var places := PackedStringArray()
		for r in manager.results:
			places.append("%d:%d" % [int(r["kart"].net_id) if r["kart"] != null else -1, int(r["place"])])
		print("[%s] RESULT %s" % [role, ",".join(places)])
		var unique := {}
		for r in manager.results:
			unique[r["place"]] = true
		_check("resultados: 4 puestos distintos", manager.results.size() == 4 and unique.size() == 4)
		var any_finished := false
		for r in manager.racers:
			any_finished = any_finished or r.finished
		_check("al menos un kart cruzó la meta", any_finished)
	print("[%s] INFO ítems replicados recibidos=%d golpes=%d" % [role, items_received, melee_received])
	_finish()


func _finish() -> void:
	await get_tree().create_timer(4.0).timeout   # deja salir los mensajes fiables antes de cerrar
	print("[%s] %s" % [role, "NETTEST OK" if failures == 0 else "NETTEST FAIL (%d)" % failures])
	get_tree().quit(failures)
