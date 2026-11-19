class_name LobbyModel
extends RefCounted
## Lógica pura del lobby: reparte jugadores (hasta 8) en karts humanos (hasta 4) con 1 o 2 asientos.
## Reparto automático: karts = N si N <= 4, si no ceil(N/2); primero los karts de 1 jugador y luego los de 2
## (1=1, 2=1+1, 3=1+1+1, 5=1+2+2, 6=2+2+2, 7=1+2+2+2, 8=2+2+2+2).
## Cada jugador puede cambiar de kart a mano ("cualquier combinación", máx. 2 por kart).

const MAX_KARTS := 4
const MAX_PLAYERS := 8

class Player:
	var kind: Seat.DeviceKind
	var device_id: int
	var kart_slot := 0

var players: Array[Player] = []
var swapped := [false, false, false, false]  ## por kart: intercambia conductor/artillero


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
	if n == 0:
		return
	var k := default_kart_count(n)
	var solos := k - (n - k)
	var idx := 0
	for slot in k:
		for i in (1 if slot < solos else 2):
			players[idx].kart_slot = slot
			idx += 1


func members(slot: int) -> Array[Player]:
	var out: Array[Player] = []
	for p in players:
		if p.kart_slot == slot:
			out.append(p)
	return out


## Mueve al jugador al kart contiguo (dir = -1/+1) si tiene sitio.
func move(p: Player, dir: int) -> bool:
	var target := clampi(p.kart_slot + dir, 0, MAX_KARTS - 1)
	if target == p.kart_slot or members(target).size() >= 2:
		return false
	p.kart_slot = target
	swapped[target] = false
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
		out.append({"slot": slot, "seats": seats})
	return out
