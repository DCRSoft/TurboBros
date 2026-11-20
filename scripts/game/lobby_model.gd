class_name LobbyModel
extends RefCounted
## Lógica pura del lobby: reparte jugadores (hasta 8) en karts humanos (hasta 4) con 1 o 2 asientos,
## y guarda las opciones de la carrera (equipos, bots, vueltas, fuego amigo).
## Reparto automático: karts = N si N <= 4, si no ceil(N/2); primero los karts de 1 jugador y luego los de 2
## (1=1, 2=1+1, 3=1+1+1, 5=1+2+2, 6=2+2+2, 7=1+2+2+2, 8=2+2+2+2).
## Cada jugador puede cambiar de kart a mano ("cualquier combinación", máx. 2 por kart).

const MAX_KARTS := 4
const MAX_PLAYERS := 8
const MAX_LAPS := 9

class Player:
	var kind: Seat.DeviceKind
	var device_id: int
	var kart_slot := 0

var players: Array[Player] = []
var swapped := [false, false, false, false]  ## por kart: intercambia conductor/artillero
var teams := [-1, -1, -1, -1]                ## equipo de cada kart humano (-1 = sin equipo)
var bots := 0
var bots_auto := true   ## por defecto SIEMPRE el máximo de bots; deja de ser automático cuando se cambia a mano
var laps := 3
var friendly_fire := false
var track_id: StringName = &""   ## vacío = la primera pista


static func default_kart_count(n: int) -> int:
	return n if n <= MAX_KARTS else ceili(n / 2.0)


func find(kind: Seat.DeviceKind, device_id: int) -> Player:
	for p in players:
		if p.kind == kind and p.device_id == device_id:
			return p
	return null


func add(kind: Seat.DeviceKind, device_id: int) -> Player:
	if players.size() >= MAX_PLAYERS or find(kind, device_id) != null:
		return null
	var p := Player.new()
	p.kind = kind
	p.device_id = device_id
	players.append(p)
	auto_layout()
	return p


func remove(p: Player) -> void:
	players.erase(p)
	auto_layout()


func auto_layout() -> void:
	swapped = [false, false, false, false]
	var n := players.size()
	if n > 0:
		var k := default_kart_count(n)
		var solos := k - (n - k)
		var idx := 0
		for slot in k:
			for i in (1 if slot < solos else 2):
				players[idx].kart_slot = slot
				idx += 1
	_clamp_bots()


func members(slot: int) -> Array[Player]:
	var out: Array[Player] = []
	for p in players:
		if p.kart_slot == slot:
			out.append(p)
	return out


func kart_count() -> int:
	var n := 0
	for slot in MAX_KARTS:
		if not members(slot).is_empty():
			n += 1
	return n


## Mueve al jugador al kart contiguo (dir = -1/+1) si tiene sitio.
func move(p: Player, dir: int) -> bool:
	var target := clampi(p.kart_slot + dir, 0, MAX_KARTS - 1)
	if target == p.kart_slot or members(target).size() >= 2:
		return false
	p.kart_slot = target
	swapped[target] = false
	_clamp_bots()
	return true


func swap_roles(slot: int) -> void:
	if members(slot).size() == 2:
		swapped[slot] = not swapped[slot]


func role_of(p: Player) -> Seat.Role:
	var m := members(p.kart_slot)
	if m.size() < 2:
		return Seat.Role.SOLO
	var first := m[0] == p
	if swapped[p.kart_slot]:
		first = not first
	return Seat.Role.DRIVER if first else Seat.Role.GUNNER


func is_valid() -> bool:
	return players.size() >= 1


# --- Opciones de carrera --------------------------------------------------------

func max_bots() -> int:
	return maxi(0, GameSession.MAX_KARTS - kart_count())


func _init() -> void:
	_clamp_bots()


func set_bots(n: int) -> void:
	bots_auto = false
	bots = clampi(n, 0, max_bots())


func _clamp_bots() -> void:
	bots = max_bots() if bots_auto else clampi(bots, 0, max_bots())


func set_laps(n: int) -> void:
	laps = clampi(n, 1, MAX_LAPS)


## Siguiente/anterior pista del catálogo (las vueltas pasan a las de la pista).
func cycle_track(dir: int) -> void:
	var all := DataCatalog.tracks()
	if all.is_empty():
		return
	var cur := 0
	for i in all.size():
		if all[i].id == track_id:
			cur = i
	var t := all[posmod(cur + dir, all.size())]
	track_id = t.id
	laps = clampi(t.default_laps, 1, MAX_LAPS)


func current_track() -> TrackData:
	return DataCatalog.track(track_id)


func toggle_friendly_fire() -> void:
	friendly_fire = not friendly_fire


## Cambia el equipo del kart del jugador: sin equipo -> 0..3 -> sin equipo (máx. 4 karts por equipo).
func cycle_team(slot: int, dir: int) -> void:
	if members(slot).is_empty():
		return
	var t: int = teams[slot]
	for _i in 6:
		t += dir
		if t > 3:
			t = -1
		elif t < -1:
			t = 3
		if t == -1 or _team_size(t, slot) < GameSession.MAX_TEAM_SIZE:
			teams[slot] = t
			return


func _team_size(team: int, except_slot: int) -> int:
	var n := 0
	for slot in MAX_KARTS:
		if slot != except_slot and teams[slot] == team and not members(slot).is_empty():
			n += 1
	return n


## Equipo de cada bot. Sin equipos entre los humanos -> todos -1. Con equipos, los bots equilibran los equipos
## (si solo hay un equipo humano se crea un rival); máx. 4 karts por equipo.
func bot_teams() -> Array[int]:
	var out: Array[int] = []
	var counts := {}
	for slot in MAX_KARTS:
		if not members(slot).is_empty() and teams[slot] >= 0:
			counts[teams[slot]] = counts.get(teams[slot], 0) + 1
	if counts.is_empty():
		for _b in bots:
			out.append(-1)
		return out
	if counts.size() == 1:
		for id in 4:
			if not counts.has(id):
				counts[id] = 0
				break
	for _b in bots:
		var best := -1
		for id in counts:
			if counts[id] < GameSession.MAX_TEAM_SIZE and (best == -1 or counts[id] < counts[best]
					or (counts[id] == counts[best] and id < best)):
				best = id
		if best >= 0:
			counts[best] += 1
		out.append(best)
	return out


## Un elemento por kart no vacío (en orden de slot), listo para GameSession.setups.
func build_setups() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in MAX_KARTS:
		var m := members(slot)
		if m.is_empty():
			continue
		var seats: Array[Seat] = []
		for p in m:
			var s := Seat.new()
			s.role = role_of(p)
			s.kind = p.kind
			s.device_id = p.device_id
			seats.append(s)
		out.append({"slot": slot, "seats": seats, "team": teams[slot]})
	return out


## Vuelca todo en GameSession para la carrera.
func apply_to_session() -> void:
	GameSession.setups = build_setups()
	GameSession.bot_teams = bot_teams()
	GameSession.laps = laps
	GameSession.friendly_fire = friendly_fire
	GameSession.track_id = current_track().id
