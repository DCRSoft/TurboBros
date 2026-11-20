class_name NetSync
extends Node
## Sincronización de una carrera en línea: envía el estado de los karts locales (~20 Hz), aplica el de los remotos,
## replica los usos de ítem y los golpes, y reenvía llegadas/resultados al RaceManager.

const SEND_EVERY := 3   ## ticks físicos entre instantáneas (60 Hz / 3 = 20 Hz)

var karts: Array[Kart] = []
var manager: RaceManager
var _tick := 0


func setup(p_karts: Array[Kart], p_manager: RaceManager) -> void:
	karts = p_karts
	manager = p_manager
	for k in karts:
		if not k.net_remote:
			k.item_used.connect(_on_local_item_used.bind(k))
	NetSession.state_received.connect(_on_state)
	NetSession.item_used_received.connect(_on_item)
	NetSession.melee_received.connect(_on_melee)
	NetSession.finish_received.connect(_on_finish)
	NetSession.results_received.connect(_on_results)
	NetSession.peer_dropped.connect(_on_peer_dropped)


func _exit_tree() -> void:
	for pair in [[NetSession.state_received, _on_state], [NetSession.item_used_received, _on_item],
			[NetSession.melee_received, _on_melee], [NetSession.finish_received, _on_finish],
			[NetSession.results_received, _on_results], [NetSession.peer_dropped, _on_peer_dropped]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


func _physics_process(_delta: float) -> void:
	_tick += 1
	if _tick % SEND_EVERY != 0:
		return
	for k in karts:
		if is_instance_valid(k) and not k.net_remote:
			NetSession.send_state(k)


func _kart(id: int) -> Kart:
	return karts[id] if id >= 0 and id < karts.size() and is_instance_valid(karts[id]) else null


func _on_local_item_used(it: ItemData, k: Kart) -> void:
	NetSession.send_item_used(k.net_id, String(it.id), k.last_use_back, k.use_seq)


func _on_state(sender: int, kart_id: int, data: Array) -> void:
	var k := _kart(kart_id)
	if k != null and k.net_remote and k.net_owner == sender:  # solo su dueño puede mover su kart
		k.net_apply_state(data[0], data[1], data[2], data[3], data[4])


func _on_item(sender: int, kart_id: int, item_id: String, back: bool, seq: int) -> void:
	var k := _kart(kart_id)
	var item := ItemCatalog.find(StringName(item_id))
	if k != null and k.net_remote and k.net_owner == sender and item != null:
		k.replay_item(item, back, seq)


func _on_melee(sender: int, victim_id: int, dir: Vector3, attacker_id: int) -> void:
	var victim := _kart(victim_id)
	var attacker := _kart(attacker_id)
	if victim != null and attacker != null and not victim.net_remote and attacker.net_owner == sender:
		victim.receive_hit(dir, attacker)


func _on_finish(kart_id: int, place: int, time: float) -> void:
	var k := _kart(kart_id)
	if k != null:
		manager.apply_net_finish(k, place, time)


func _on_results(results: Array) -> void:
	manager.apply_net_results(results, karts)


func _on_peer_dropped(peer_id: int) -> void:
	for k in karts.duplicate():
		if is_instance_valid(k) and k.net_owner == peer_id and not k.is_bot:
			manager.remove_kart(k)
