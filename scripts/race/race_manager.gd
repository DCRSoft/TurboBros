class_name RaceManager
extends Node
## Gestor de carrera: cuenta atrás, progreso/vueltas por kart, clasificación en vivo, llegadas y resultados.
## El progreso se mide proyectando cada kart sobre la curva del circuito (ver Circuit); la búsqueda de la
## muestra más cercana es local, así que no se puede "saltar" tramos para ahorrar vueltas.

signal race_started
signal countdown_beep(number: int)
signal kart_finished(kart: Kart, place: int)
signal race_finished(results: Array)

enum State { WAITING, COUNTDOWN, RACING, FINISHED }

const COUNTDOWN_TIME := 3.0
## Arranque: acelerar con MÁS de LAUNCH_WINDOW s por delante ahoga el motor (STALL_TIME s sin poder avanzar); con
## exactamente LAUNCH_WINDOW s da el turbo máximo, que baja de forma proporcional hasta 0 en el momento de la salida.
const LAUNCH_WINDOW := 2.0
const STALL_TIME := 2.0
const LAUNCH_BOOST_MIN := 0.35   ## segundos y velocidad mínimos del turbo (se escalan con el factor)
const LAUNCH_BOOST_MAX := 1.2
const HUMAN_GRACE := 25.0      ## s que se espera a los humanos tras llegar el primero
const BOT_WAIT := 15.0         ## s que se espera a los bots tras llegar el último humano
const MAX_RACE_TIME := 600.0   ## tope de seguridad
const POINTS: Array[int] = [15, 12, 10, 8, 6, 4, 3, 2]

class Racer:
	var kart: Kart
	var is_human := false
	var idx := 0
	var s_prev := 0.0
	var progress := 0.0
	var initialized := false
	var needs_resync := false
	var finished := false
	var finish_time := -1.0
	var place := 0
	var wrong_t := 0.0
	var wrong_way := false
	var respawns := 0
	var launch_pending := true      ## aún no ha acelerado en la cuenta atrás
	var launch_armed := false       ## ya soltó el acelerador desde que empezó la cuenta (A también confirma en los menús)
	var launch_factor := 0.0        ## -1 = motor ahogado; 0..1 = fuerza del turbo de salida

var circuit: Circuit
var laps := 3
var racers: Array[Racer] = []
var state: State = State.WAITING
var race_time := 0.0
var results: Array[Dictionary] = []

var net_client := false    ## en línea y NO anfitrión: las llegadas y los resultados los decide el anfitrión
var _countdown_left := 0.0
var _last_beep := -1
var _finished_count := 0
var _last_human_finish := -1.0
var _first_human_finish := -1.0
var _by_kart := {}


func setup(c: Circuit, karts: Array[Kart], total_laps: int) -> void:
	circuit = c
	laps = total_laps
	net_client = NetSession.online and not NetSession.is_host()
	racers.clear()
	_by_kart.clear()
	for k in karts:
		var r := Racer.new()
		r.kart = k
		r.is_human = not k.is_bot
		racers.append(r)
		_by_kart[k] = r
		k.teleported.connect(func() -> void: r.needs_resync = true)
		k.frozen = true
	for r in racers:
		_update_progress(r, 0.0)
	_rank()


func start() -> void:
	state = State.COUNTDOWN
	_countdown_left = COUNTDOWN_TIME
	race_time = 0.0
	for r in racers:
		r.kart.frozen = true
		r.launch_pending = true
		r.launch_armed = false
		r.launch_factor = 0.0


## Resultado de acelerar cuando faltan "remaining" s para la salida: -1 = motor ahogado, 0..1 = fuerza del turbo.
static func launch_factor_for(remaining: float) -> float:
	if remaining > LAUNCH_WINDOW:
		return -1.0
	return clampf(remaining / LAUNCH_WINDOW, 0.0, 1.0)


## Solo cuentan los karts con un jugador humano local (no la IA ni las marionetas en línea).
func _reads_launch_input(r: Racer) -> bool:
	var k := r.kart
	return r.is_human and not k.net_remote and k.controller != null and not (k.controller is BotController)


func _check_launch_input() -> void:
	for r in racers:
		if not (r.launch_pending and _reads_launch_input(r)):
			continue
		var pressed: bool = r.kart.controller.get_controls().throttle > 0.5
		if not r.launch_armed:
			# Si llega con el acelerador pulsado (el mismo botón que confirmó el menú) no cuenta hasta que lo suelte
			r.launch_armed = not pressed
		elif pressed:
			r.launch_pending = false
			r.launch_factor = launch_factor_for(_countdown_left)


func _apply_launch(r: Racer) -> void:
	if not _reads_launch_input(r):
		return
	if r.launch_factor < 0.0:
		r.kart.fx.add(EffectLibrary.get_effect(&"stalled"), STALL_TIME)
	elif r.launch_factor > 0.02:
		var f := r.launch_factor
		var eff := EffectLibrary.get_effect(&"launch_boost")
		r.kart.fx.add(eff, lerpf(LAUNCH_BOOST_MIN, LAUNCH_BOOST_MAX, f), lerpf(1.1, eff.speed_mult, f))


func get_racer(kart: Kart) -> Racer:
	return _by_kart.get(kart)


func lap_of(r: Racer) -> int:
	return clampi(floori(r.progress / circuit.length) + 1, 1, laps)


func total_humans() -> int:
	var n := 0
	for r in racers:
		if r.is_human:
			n += 1
	return n


## Texto grande en el centro de la vista de un kart.
func center_text(kart: Kart) -> String:
	var r := get_racer(kart)
	match state:
		State.COUNTDOWN:
			if r and r.launch_factor < 0.0:
				return "%d
¡MOTOR AHOGADO!" % ceili(_countdown_left)
			return str(ceili(_countdown_left))
		State.RACING:
			if r and r.finished:
				return "¡META!  Puesto %d" % r.place
			if r and r.launch_factor < 0.0 and race_time < STALL_TIME:
				return "¡MOTOR AHOGADO!  %.1f" % (STALL_TIME - race_time)
			if race_time < 1.0:
				return "¡ARRANQUE TURBO!" if r and r.launch_factor > 0.5 else "¡YA!"
			if r and r.wrong_way:
				return "¡CONTRAMANO!"
		State.FINISHED:
			if r:
				return "Puesto %d" % r.place
	return ""


func format_time(t: float) -> String:
	var m := int(t) / 60
	return "%d:%05.2f" % [m, t - m * 60.0]


func respawn_kart(kart: Kart) -> void:
	var r := get_racer(kart)
	if r == null:
		return
	r.respawns += 1
	r.needs_resync = true
	kart.respawn(circuit.respawn_transform(r.idx))


func _physics_process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_countdown_left -= delta
			_check_launch_input()
			var n := ceili(_countdown_left)
			if n != _last_beep and n > 0:
				_last_beep = n
				countdown_beep.emit(n)
			if _countdown_left <= 0.0:
				state = State.RACING
				for r in racers:
					r.kart.frozen = false
					_apply_launch(r)
				race_started.emit()
		State.RACING:
			race_time += delta
			_apply_pads()
			for r in racers:
				_update_progress(r, delta)
			_rank()
			_check_end()


## Zonas de turbo: el kart que pasa por encima recibe el turbo (se renueva mientras siga en la zona).
func _apply_pads() -> void:
	if circuit.pads.is_empty():
		return
	var boost := EffectLibrary.get_effect(&"boost")
	for r in racers:
		var k := r.kart
		if k.net_remote or r.finished:
			continue
		var p := k.sphere.global_position
		for pad in circuit.pads:
			var q: Vector3 = pad["pos"]
			var dx := p.x - q.x
			var dz := p.z - q.z
			var rad: float = pad["radius"]
			if dx * dx + dz * dz < rad * rad and absf(p.y - q.y) < 3.0:
				k.fx.add(boost)
				break


func _update_progress(r: Racer, delta: float) -> void:
	var k := r.kart
	var pos := k.sphere.global_position
	if pos.y < circuit.min_y - 25.0 and state == State.RACING:
		if not k.net_remote:
			respawn_kart(k)
		return
	if r.finished:
		return
	var pr := circuit.progress_at(pos, r.idx, not r.initialized or r.needs_resync)
	r.idx = pr["idx"]
	var s_raw: float = pr["s"]
	var half := circuit.length * 0.5
	if not r.initialized:
		r.progress = s_raw if s_raw < half else s_raw - circuit.length
		r.initialized = true
	else:
		r.progress += fposmod(s_raw - r.s_prev + half, circuit.length) - half
	r.s_prev = s_raw
	r.needs_resync = false

	if state != State.RACING:
		return
	# Contramano: velocidad contraria al sentido del circuito
	var t: Vector3 = pr["tangent"]
	var vel := k.sphere.linear_velocity
	if vel.x * t.x + vel.z * t.z < -2.0:
		r.wrong_t += delta
	else:
		r.wrong_t = 0.0
	r.wrong_way = r.wrong_t > 1.0

	if r.progress >= laps * circuit.length and not net_client:
		_finish(r)


func _finish(r: Racer) -> void:
	r.finished = true
	r.finish_time = race_time
	_finished_count += 1
	r.place = _finished_count
	if r.is_human:
		_last_human_finish = race_time
		if _first_human_finish < 0.0:
			_first_human_finish = race_time
		_autopilot(r)
	NetSession.send_finish(r.kart.net_id, r.place, r.finish_time)
	kart_finished.emit(r.kart, r.place)


## Cliente en línea: el anfitrión anuncia que un kart cruzó la meta.
func apply_net_finish(kart: Kart, place: int, time: float) -> void:
	var r := get_racer(kart)
	if r == null or r.finished:
		return
	r.finished = true
	r.place = place
	r.finish_time = time
	_finished_count = maxi(_finished_count, place)
	if r.is_human:
		_autopilot(r)
	kart_finished.emit(kart, place)


## Cliente en línea: resultados finales decididos por el anfitrión (cada entrada trae "kart_id").
func apply_net_results(net_results: Array, karts: Array[Kart]) -> void:
	if state == State.FINISHED:
		return
	state = State.FINISHED
	results.clear()
	for e in net_results:
		var entry: Dictionary = e.duplicate()
		var kid: int = entry.get("kart_id", -1)
		entry["kart"] = karts[kid] if kid >= 0 and kid < karts.size() else null
		results.append(entry)
	for r in racers:
		var match_entry := results.filter(func(en: Dictionary) -> bool: return en["kart"] == r.kart)
		if not match_entry.is_empty():
			r.place = match_entry[0]["place"]
	_rank()
	race_finished.emit(results)


## Un equipo se desconectó: su kart sale de la carrera.
func remove_kart(kart: Kart) -> void:
	var r := get_racer(kart)
	if r != null:
		racers.erase(r)
	_by_kart.erase(kart)
	if is_instance_valid(kart):
		kart.queue_free()
	_rank()


## Al terminar, un kart humano pasa a piloto automático (no se queda parado estorbando).
func _autopilot(r: Racer) -> void:
	if r.kart.net_remote:
		return  # en línea cada equipo conduce el suyo
	var bot := BotController.new()
	bot.setup(r.kart, circuit, self, 0)
	r.kart.add_child(bot)
	r.kart.controller = bot


func _rank() -> void:
	var order := racers.duplicate()
	order.sort_custom(func(a: Racer, b: Racer) -> bool:
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.place < b.place
		return a.progress > b.progress)
	for i in order.size():
		var r: Racer = order[i]
		r.kart.race_position = i + 1
		r.kart.race_total = order.size()
		r.kart.race_progress = r.progress


func _check_end() -> void:
	if net_client:
		return  # el anfitrión decide cuándo acaba
	var all_done := true
	var humans_left := false
	for r in racers:
		if not r.finished:
			all_done = false
			if r.is_human:
				humans_left = true
	var end := all_done or race_time >= MAX_RACE_TIME
	if total_humans() > 0 and not humans_left and race_time - _last_human_finish >= BOT_WAIT:
		end = true
	if _first_human_finish >= 0.0 and race_time - _first_human_finish >= HUMAN_GRACE:
		end = true
	if end:
		_end_race()


func _end_race() -> void:
	state = State.FINISHED
	var rest: Array[Racer] = []
	for r in racers:
		if not r.finished:
			rest.append(r)
	rest.sort_custom(func(a: Racer, b: Racer) -> bool: return a.progress > b.progress)
	for r in rest:
		_finished_count += 1
		r.place = _finished_count
	_rank()
	results.clear()
	var sorted := racers.duplicate()
	sorted.sort_custom(func(a: Racer, b: Racer) -> bool: return a.place < b.place)
	var net_list: Array = []
	for r: Racer in sorted:
		results.append({
			"name": r.kart.racer_name, "kart": r.kart, "team": r.kart.team, "place": r.place,
			"time": r.finish_time, "finished": r.finish_time >= 0.0, "points": points_for(r.place),
			"human": r.is_human,
		})
		net_list.append({
			"name": r.kart.racer_name, "kart_id": r.kart.net_id, "team": r.kart.team, "place": r.place,
			"time": r.finish_time, "finished": r.finish_time >= 0.0, "points": points_for(r.place),
			"human": r.is_human,
		})
	NetSession.send_results(net_list)  # no hace nada fuera de línea
	race_finished.emit(results)


static func points_for(place: int) -> int:
	return POINTS[place - 1] if place >= 1 and place <= POINTS.size() else 1


## Puntos por equipo: {team_id: puntos}. Vacío si nadie tiene equipo.
func team_scores() -> Dictionary:
	var scores := {}
	for res in results:
		var t: int = res["team"]
		if t >= 0:
			scores[t] = scores.get(t, 0) + int(res["points"])
	return scores
