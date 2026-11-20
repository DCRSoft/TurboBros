extends Node
## Multijugador en línea con el multijugador de alto nivel de Godot (ENet).
## Modelo: el ANFITRIÓN gestiona la sala, la cuenta atrás, las llegadas y los resultados, y simula a los bots.
## Cada equipo simula SUS karts (1 o 2 jugadores por PC, una sola vista) y envía su estado ~20 veces por segundo;
## los karts de los demás son marionetas interpoladas. Los ataques se replican como eventos y cada equipo solo
## modifica sus propios karts (la víctima aplica el efecto en su máquina).
## Las entradas están separadas de la lógica (KartController): en red solo viaja el estado, nunca los mandos.

signal roster_changed
signal connected_to_host
signal connection_failed
signal host_lost(reason: String)
signal race_starting(spec: Dictionary)
signal begin_race
signal peer_dropped(peer_id: int)
signal state_received(sender: int, kart_id: int, data: Array)
signal item_used_received(sender: int, kart_id: int, item_id: String, back: bool, seq: int)
signal melee_received(sender: int, victim_id: int, dir: Vector3, attacker_id: int)
signal finish_received(kart_id: int, place: int, time: float)
signal results_received(results: Array)

const DEFAULT_PORT := 24680
const MAX_KARTS := 8
const RACE_SCENE := "res://scenes/race/race.tscn"

var online := false
var spec := {}                       ## datos de la carrera en curso (vacío = sin carrera en línea)
var roster := {}                     ## {"peers": {id: {...}}, "laps": int, "bots": int, "friendly_fire": bool}
var local_choice := {}               ## {"seats": 1|2, "vehicle": id, "driver": id, "gunner": id, "ready": bool}
var local_seats: Array[Seat] = []
var test_autopilot := false          ## pruebas: el kart local lo conduce la IA
var bind_ip := "*"                   ## interfaz en la que escucha el anfitrión ("127.0.0.1" en las pruebas)
var last_error := ""
var objects := {}                    ## id -> Projectile/Trap activos (para sincronizar su desaparición)

var _loaded := {}


func _ready() -> void:
	_reset_state()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _reset_state() -> void:
	roster = {"peers": {}, "laps": 3, "bots": 0, "friendly_fire": false}
	var vs := DataCatalog.vehicles()
	var cs := DataCatalog.characters()
	local_choice = {"seats": 1, "vehicle": String(vs[0].id) if not vs.is_empty() else "",
			"driver": String(cs[0].id) if not cs.is_empty() else "",
			"gunner": String(cs[1].id) if cs.size() > 1 else "", "ready": false}
	spec = {}
	_loaded.clear()
	objects.clear()


func my_id() -> int:
	return multiplayer.get_unique_id() if online else 1


func is_host() -> bool:
	return online and multiplayer.is_server()


# --- Conexión ----------------------------------------------------------------------

func host_game(port := DEFAULT_PORT) -> int:
	leave()
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip(bind_ip)
	var err := peer.create_server(port, MAX_KARTS - 1)
	if err != OK:
		last_error = "No se pudo crear la partida en el puerto %d (error %d)" % [port, err]
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	roster["peers"][1] = _peer_entry("Anfitrión")
	roster_changed.emit()
	return OK


func join_game(address: String, port := DEFAULT_PORT) -> int:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		last_error = "No se pudo conectar a %s:%d (error %d)" % [address, port, err]
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	return OK


func leave() -> void:
	if online:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	test_autopilot = false
	_reset_state()


func _peer_entry(player_name: String) -> Dictionary:
	var e := local_choice.duplicate()
	e["name"] = player_name
	return e


func _on_connected_to_server() -> void:
	rpc_id(1, "net_hello", local_choice)
	connected_to_host.emit()


func _on_connection_failed() -> void:
	last_error = "No se pudo conectar con el anfitrión"
	leave()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	leave()
	host_lost.emit("El anfitrión se desconectó")


func _on_peer_connected(_id: int) -> void:
	pass  # la sala se actualiza cuando llega su "net_hello"


func _on_peer_disconnected(id: int) -> void:
	_loaded.erase(id)
	if is_host():
		roster["peers"].erase(id)
		_broadcast_roster()
		_check_all_loaded()
	peer_dropped.emit(id)


# --- Sala --------------------------------------------------------------------------

## El jugador local cambia sus elecciones (vehículo, personajes, 1 o 2 asientos, listo).
func set_choice(changes: Dictionary) -> void:
	for k in changes:
		local_choice[k] = changes[k]
	if not online:
		return
	if is_host():
		_merge_choice(1, local_choice)
		_broadcast_roster()
	else:
		rpc_id(1, "net_choice", local_choice)


func set_host_config(laps: int, bots: int, friendly_fire: bool) -> void:
	if not is_host():
		return
	roster["laps"] = clampi(laps, 1, 9)
	roster["bots"] = clampi(bots, 0, MAX_KARTS - roster["peers"].size())
	roster["friendly_fire"] = friendly_fire
	_broadcast_roster()


func _merge_choice(id: int, c: Dictionary) -> void:
	if not roster["peers"].has(id):
		return
	var e: Dictionary = roster["peers"][id]
	e["seats"] = clampi(int(c.get("seats", 1)), 1, 2)
	e["vehicle"] = str(c.get("vehicle", e.get("vehicle", "")))
	e["driver"] = str(c.get("driver", e.get("driver", "")))
	e["gunner"] = str(c.get("gunner", e.get("gunner", "")))
	e["ready"] = bool(c.get("ready", false))


func _broadcast_roster() -> void:
	roster["bots"] = clampi(int(roster["bots"]), 0, MAX_KARTS - roster["peers"].size())
	roster_changed.emit()
	rpc("net_roster", roster)


func peer_count() -> int:
	return roster["peers"].size()


## Todos listos y al menos 2 karts (humanos + bots).
func can_start() -> bool:
	if not is_host() or roster["peers"].is_empty() or not spec.is_empty():
		return false
	for id in roster["peers"]:
		if not roster["peers"][id].get("ready", false):
			return false
	return roster["peers"].size() + int(roster["bots"]) >= 2


## Especificación de la carrera (igual en todos los equipos). Orden de karts = parrilla.
static func build_spec(r: Dictionary, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ids: Array = r["peers"].keys()
	ids.sort()
	var karts: Array = []
	for id in ids:
		var p: Dictionary = r["peers"][id]
		var two := int(p.get("seats", 1)) == 2
		karts.append({"owner": id, "bot": false, "name": str(p.get("name", "Jugador")), "vehicle": str(p["vehicle"]),
				"driver": str(p["driver"]), "gunner": str(p["gunner"]) if two else "", "seats": 2 if two else 1, "team": -1})
	var vs := DataCatalog.vehicles()
	var cs := DataCatalog.characters()
	var bots := mini(int(r["bots"]), MAX_KARTS - karts.size())
	for b in bots:
		karts.append({"owner": 1, "bot": true, "name": "Bot %d" % (b + 1),
				"vehicle": String(vs[rng.randi() % vs.size()].id), "driver": String(cs[rng.randi() % cs.size()].id),
				"gunner": "", "seats": 1, "team": -1})
	for i in karts.size():
		karts[i]["kart_id"] = i
	return {"karts": karts, "laps": int(r["laps"]), "friendly_fire": bool(r["friendly_fire"]), "seed": seed_value}


func start_race() -> void:
	if not can_start():
		return
	rpc("net_start", build_spec(roster, randi()))


## Asientos del jugador local para esta carrera (1 o 2, con los primeros dispositivos disponibles).
func _build_local_seats() -> void:
	local_seats.clear()
	var devs := InputManager.get_devices()
	var n := int(local_choice.get("seats", 1))
	for i in n:
		var s := Seat.new()
		s.role = Seat.Role.SOLO if n == 1 else (Seat.Role.DRIVER if i == 0 else Seat.Role.GUNNER)
		if i < devs.size():
			s.kind = devs[i]["kind"]
			s.device_id = devs[i]["id"]
		s.character_id = StringName(local_choice["driver"] if i == 0 else local_choice["gunner"])
		local_seats.append(s)


## Fin de la carrera: se vuelve a la sala conservando la conexión.
func finish_race() -> void:
	spec = {}
	_loaded.clear()
	objects.clear()
	if is_host():
		for id in roster["peers"]:
			roster["peers"][id]["ready"] = false
		local_choice["ready"] = false
		_broadcast_roster()
	else:
		local_choice["ready"] = false
		rpc_id(1, "net_choice", local_choice)


# --- Carga y comienzo sincronizados -----------------------------------------------

func report_loaded() -> void:
	if not online:
		return
	if is_host():
		_loaded[1] = true
		_check_all_loaded()
	else:
		rpc_id(1, "net_loaded")


func _check_all_loaded() -> void:
	if not is_host() or spec.is_empty():
		return
	for id in roster["peers"]:
		if not _loaded.has(id):
			return
	_loaded.clear()
	rpc("net_begin")


# --- Eventos de carrera ---------------------------------------------------------------

func send_state(kart: Kart) -> void:
	if online:
		rpc("net_state", kart.net_id, kart.net_collect_state())


func send_item_used(kart_id: int, item_id: String, back: bool, seq: int) -> void:
	if online:
		rpc("net_item_used", kart_id, item_id, back, seq)


func send_melee(victim: Kart, dir: Vector3, attacker: Kart) -> void:
	if online and victim.net_owner != my_id():
		rpc_id(victim.net_owner, "net_melee", victim.net_id, dir, attacker.net_id)


func announce_dead(id: int) -> void:
	if online and id >= 0:
		rpc("net_object_dead", id)


func send_finish(kart_id: int, place: int, time: float) -> void:
	if is_host():
		rpc("net_finish", kart_id, place, time)


func send_results(results: Array) -> void:
	if is_host():
		rpc("net_results", results)


func register_object(id: int, node: Node) -> void:
	objects[id] = node


func unregister_object(id: int, node: Node) -> void:
	if objects.get(id) == node:
		objects.erase(id)


# --- RPC ------------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func net_hello(choice: Dictionary) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if not spec.is_empty() or roster["peers"].size() >= MAX_KARTS:
		multiplayer.multiplayer_peer.disconnect_peer(id)  # carrera en curso o sala llena
		return
	roster["peers"][id] = _peer_entry("Jugador %d" % (roster["peers"].size() + 1))
	_merge_choice(id, choice)
	_broadcast_roster()


@rpc("any_peer", "call_remote", "reliable")
func net_choice(choice: Dictionary) -> void:
	if not is_host() or not spec.is_empty():
		return
	_merge_choice(multiplayer.get_remote_sender_id(), choice)
	_broadcast_roster()


@rpc("authority", "call_remote", "reliable")
func net_roster(r: Dictionary) -> void:
	roster = r
	roster_changed.emit()


@rpc("authority", "call_local", "reliable")
func net_start(s: Dictionary) -> void:
	spec = s
	_loaded.clear()
	objects.clear()
	_build_local_seats()
	race_starting.emit(s)
	get_tree().change_scene_to_file(RACE_SCENE)


@rpc("any_peer", "call_remote", "reliable")
func net_loaded() -> void:
	if is_host():
		_loaded[multiplayer.get_remote_sender_id()] = true
		_check_all_loaded()


@rpc("authority", "call_local", "reliable")
func net_begin() -> void:
	begin_race.emit()


@rpc("any_peer", "call_remote", "unreliable_ordered")
func net_state(kart_id: int, data: Array) -> void:
	if data.size() >= 5:
		state_received.emit(multiplayer.get_remote_sender_id(), kart_id, data)


@rpc("any_peer", "call_remote", "reliable")
func net_item_used(kart_id: int, item_id: String, back: bool, seq: int) -> void:
	item_used_received.emit(multiplayer.get_remote_sender_id(), kart_id, item_id, back, seq)


@rpc("any_peer", "call_remote", "reliable")
func net_melee(victim_id: int, dir: Vector3, attacker_id: int) -> void:
	melee_received.emit(multiplayer.get_remote_sender_id(), victim_id, dir, attacker_id)


@rpc("any_peer", "call_remote", "reliable")
func net_object_dead(id: int) -> void:
	var n: Variant = objects.get(id)
	if n != null and is_instance_valid(n):
		(n as Node).queue_free()
	objects.erase(id)


@rpc("authority", "call_remote", "reliable")
func net_finish(kart_id: int, place: int, time: float) -> void:
	finish_received.emit(kart_id, place, time)


@rpc("authority", "call_remote", "reliable")
func net_results(results: Array) -> void:
	results_received.emit(results)
