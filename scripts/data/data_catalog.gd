class_name DataCatalog
extends RefCounted
## Catálogo de vehículos (data/vehicles) y personajes (data/characters). Añadir un .tres = opción nueva.

const VEHICLES_DIR := "res://data/vehicles"
const CHARACTERS_DIR := "res://data/characters"
const FIRST_CHARACTER: StringName = &"drancr"   ## el primero de la lista; el resto, alfabético
const TRACKS_DIR := "res://data/tracks"
const THEMES_DIR := "res://data/themes"

static var _vehicles: Array[VehicleData] = []
static var _characters: Array[CharacterData] = []
static var _tracks: Array[TrackData] = []
static var _themes: Array[ThemeData] = []
static var _loaded := false


## Pistas ordenadas por id ("01_...", "02_..."): la primera es la pista por defecto.
static func tracks() -> Array[TrackData]:
	_ensure()
	return _tracks


static func track(id: StringName) -> TrackData:
	for t in tracks():
		if t.id == id:
			return t
	return tracks()[0] if not tracks().is_empty() else null


static func themes() -> Array[ThemeData]:
	_ensure()
	return _themes


static func theme(id: StringName) -> ThemeData:
	for t in themes():
		if t.id == id:
			return t
	return themes()[0] if not themes().is_empty() else null


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
	for res in _load_dir(TRACKS_DIR):
		if res is TrackData:
			_tracks.append(res)
	for res in _load_dir(THEMES_DIR):
		if res is ThemeData:
			_themes.append(res)
	_tracks.sort_custom(func(a: TrackData, b: TrackData) -> bool: return String(a.id) < String(b.id))
	_themes.sort_custom(func(a: ThemeData, b: ThemeData) -> bool: return String(a.id) < String(b.id))
	_vehicles.sort_custom(func(a: VehicleData, b: VehicleData) -> bool: return String(a.id) < String(b.id))
	# Orden de personajes: DranCr primero y después alfabético por nombre
	_characters.sort_custom(func(a: CharacterData, b: CharacterData) -> bool:
		if a.id == FIRST_CHARACTER or b.id == FIRST_CHARACTER:
			return a.id == FIRST_CHARACTER and b.id != FIRST_CHARACTER
		return a.display_name.to_lower() < b.display_name.to_lower())


static func _load_dir(path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	for f in DirAccess.get_files_at(path):
		var name := f.trim_suffix(".remap")  # builds exportados: .tres.remap
		if name.ends_with(".tres") or name.ends_with(".res"):
			var res := load(path.path_join(name))
			if res != null:
				out.append(res)
	return out
