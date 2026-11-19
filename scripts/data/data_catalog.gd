class_name DataCatalog
extends RefCounted
## Catálogo de vehículos (data/vehicles) y personajes (data/characters). Añadir un .tres = opción nueva.

const VEHICLES_DIR := "res://data/vehicles"
const CHARACTERS_DIR := "res://data/characters"

static var _vehicles: Array[VehicleData] = []
static var _characters: Array[CharacterData] = []
static var _loaded := false


static func vehicles() -> Array[VehicleData]:
	_ensure()
	return _vehicles


static func characters() -> Array[CharacterData]:
	_ensure()
	return _characters


static func vehicle(id: StringName) -> VehicleData:
	for v in vehicles():
		if v.id == id:
			return v
	return vehicles()[0] if not vehicles().is_empty() else null


static func character(id: StringName) -> CharacterData:
	for c in characters():
		if c.id == id:
			return c
	return characters()[0] if not characters().is_empty() else null


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	for res in _load_dir(VEHICLES_DIR):
		if res is VehicleData:
			_vehicles.append(res)
	for res in _load_dir(CHARACTERS_DIR):
		if res is CharacterData:
			_characters.append(res)
	_vehicles.sort_custom(func(a: VehicleData, b: VehicleData) -> bool: return String(a.id) < String(b.id))
	_characters.sort_custom(func(a: CharacterData, b: CharacterData) -> bool: return String(a.id) < String(b.id))


static func _load_dir(path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	for f in DirAccess.get_files_at(path):
		var name := f.trim_suffix(".remap")  # builds exportados: .tres.remap
		if name.ends_with(".tres") or name.ends_with(".res"):
			var res := load(path.path_join(name))
			if res != null:
				out.append(res)
	return out
