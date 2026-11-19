class_name RaceManager
extends Node
## Gestor de carrera: cuenta atrás, progreso/vueltas por kart, clasificación en vivo, llegadas y resultados.
## El progreso se mide proyectando cada kart sobre la curva del circuito (ver Circuit); la búsqueda de la
## muestra más cercana es local, así que no se puede "saltar" tramos para ahorrar vueltas.

signal race_started
signal kart_finished(kart: Kart, place: int)
signal race_finished(results: Array)

enum State { WAITING, COUNTDOWN, RACING, FINISHED }

const COUNTDOWN_TIME := 3.0
const HUMAN_GRACE := 25.0      ## s que se espera a los humanos tras llegar el primero
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

var circuit: Circuit
var laps := 3
var racers: Array[Racer] = []
var state: State = State.WAITING
var race_time := 0.0
var results: Array[Dictionary] = []

var _countdown_left := 0.0
var _finished_count := 0
var _last_human_finish := -1.0
var _first_human_finish := -1.0
var _by_kart := {}


func setup(c: Circuit, karts: Array[Kart], total_laps: int) -> void:
	circuit = c
	laps = total_laps
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
			return str(ceili(_countdown_left))
		State.RACING:
			if r and r.finished:
				return "¡META!  Puesto %d" % r.place
			if race_time < 1.0:
				return "¡YA!"
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
			if _countdown_left <= 0.0:
				state = State.RACING
				for r in racers:
					r.kart.frozen = false
				race_started.emit()
		State.RACING:
			race_time += delta
			for r in racers:
				_update_progress(r, delta)
			_rank()
			_check_end()


func _update_progress(r: Racer, delta: float) -> void:
	var k := r.kart
	var pos := k.sphere.global_position
	if pos.y < circuit.min_y - 25.0 and state == State.RACING:
		respawn_kart(k)
		return
	if r.finished:
		return
	if not r.initialized or r.needs_resync:
		r.idx = circuit.nearest_global(pos)
	else:
		r.idx = circuit.nearest_index(pos, r.idx)
	var s_raw := circuit.raw_s(pos, r.idx)
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
	var t := circuit.tangents[r.idx]
	var vel := k.sphere.linear_velocity
	if vel.x * t.x + vel.z * t.z < -2.0:
		r.wrong_t += delta
	else:
		r.wrong_t = 0.0
	r.wrong_way = r.wrong_t > 1.0

	if r.progress >= laps * circuit.length:
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
	kart_finished.emit(r.kart, r.place)


## Al terminar, un kart humano pasa a piloto automático (no se queda parado estorbando).
func _autopilot(r: Racer) -> void:
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
	var all_done := true
	var humans_left := false
	for r in racers:
		if not r.finished:
			all_done = false
			if r.is_human:
				humans_left = true
	var end := all_done or race_time >= MAX_RACE_TIME
	if total_humans() > 0 and not humans_left and race_time - _last_human_finish >= 3.0:
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
	for r: Racer in sorted:
		results.append({
			"name": r.kart.racer_name, "kart": r.kart, "team": r.kart.team, "place": r.place,
			"time": r.finish_time, "finished": r.finish_time >= 0.0, "points": points_for(r.place),
			"human": r.is_human,
		})
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
