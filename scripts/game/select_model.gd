class_name SelectModel
extends RefCounted
## Lógica pura de la pantalla de selección: cada jugador (asiento) elige personaje; el vehículo lo elige el
## jugador solo o el conductor de cada kart. Calcula las estadísticas finales de cada kart al momento.

class Entry:
	var kart_index := 0
	var seat: Seat
	var char_idx := 0
	var ready := false

var entries: Array[Entry] = []
var kart_vehicle: Array[int] = []   ## índice de vehículo de cada kart
var vehicles: Array[VehicleData] = []
var characters: Array[CharacterData] = []
var setups: Array[Dictionary] = []


func _init(p_setups: Array[Dictionary], p_vehicles: Array[VehicleData] = [], p_characters: Array[CharacterData] = []) -> void:
	setups = p_setups
	vehicles = p_vehicles if not p_vehicles.is_empty() else DataCatalog.vehicles()
	characters = p_characters if not p_characters.is_empty() else DataCatalog.characters()
	for i in setups.size():
		kart_vehicle.append(i % vehicles.size())
		for seat in setups[i]["seats"]:
			var e := Entry.new()
			e.kart_index = i
			e.seat = seat
			e.char_idx = entries.size() % characters.size()
			entries.append(e)


func find_entry(kind: Seat.DeviceKind, device_id: int) -> Entry:
	for e in entries:
		if e.seat.kind == kind and e.seat.device_id == device_id:
			return e
	return null


func cycle_character(e: Entry, dir: int) -> void:
	if e.ready:
		return
	e.char_idx = posmod(e.char_idx + dir, characters.size())


## Solo el jugador solo o el conductor eligen vehículo. Devuelve true si cambió.
func cycle_vehicle(e: Entry, dir: int) -> bool:
	if e.ready or e.seat.role == Seat.Role.GUNNER:
		return false
	kart_vehicle[e.kart_index] = posmod(kart_vehicle[e.kart_index] + dir, vehicles.size())
	return true


func toggle_ready(e: Entry) -> void:
	e.ready = not e.ready


func unready(e: Entry) -> void:
	e.ready = false


func all_ready() -> bool:
	for e in entries:
		if not e.ready:
			return false
	return not entries.is_empty()


func vehicle_of(kart_index: int) -> VehicleData:
	return vehicles[kart_vehicle[kart_index]]


func _seat_entry(kart_index: int, gunner: bool) -> Entry:
	for e in entries:
		if e.kart_index == kart_index and (e.seat.role == Seat.Role.GUNNER) == gunner:
			return e
	return null


## Conductor (o jugador solo) y artillero de un kart.
func driver_character(kart_index: int) -> CharacterData:
	var e := _seat_entry(kart_index, false)
	return characters[e.char_idx] if e else null


func gunner_character(kart_index: int) -> CharacterData:
	var e := _seat_entry(kart_index, true)
	return characters[e.char_idx] if e else null


func kart_delta(kart_index: int) -> StatDelta:
	return KartBuild.combine(vehicle_of(kart_index), driver_character(kart_index), gunner_character(kart_index))


## Texto de sinergia para el conductor/solo del kart ("" si no hay).
func synergy_text(kart_index: int) -> String:
	var v := vehicle_of(kart_index)
	var c := driver_character(kart_index)
	if c == null:
		return ""
	if c.likes.has(v.id):
		return "★ %s se siente a gusto en este vehículo" % c.display_name
	if c.dislikes.has(v.id):
		return "✗ %s no se lleva bien con este vehículo" % c.display_name
	return ""


## Guarda las elecciones en los setups (vehículo por kart) y en los asientos (personaje).
func apply() -> void:
	for e in entries:
		e.seat.character_id = characters[e.char_idx].id
	for i in setups.size():
		setups[i]["vehicle"] = vehicles[kart_vehicle[i]].id
