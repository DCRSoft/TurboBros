class_name ArtLibrary
extends RefCounted
## Arte 2D opcional: si el archivo existe se usa en las pantallas de selección; si no, se muestra el modelo 3D.
##   assets/art/characters/<id>.png   retrato del personaje
##   assets/art/vehicles/<id>.png     el vehículo
##   assets/art/tracks/<id>.png       mapa/tarjeta de la pista (recortada de la imagen de pistas)
## La lista de lo que hay que dibujar está en docs/ART_PROMPTS.md.

static var _cache := {}


static func character(id: StringName) -> Texture2D:
	return _load("res://assets/art/characters/%s.png" % id)


static func vehicle(id: StringName) -> Texture2D:
	return _load("res://assets/art/vehicles/%s.png" % id)


static func track(id: StringName) -> Texture2D:
	return _load("res://assets/art/tracks/%s.png" % id)


static func _load(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache[path]
