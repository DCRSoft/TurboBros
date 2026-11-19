class_name EffectLibrary
extends RefCounted
## Acceso por id a los efectos de data/effects/<id>.tres (con caché).

static var _cache := {}


static func get_effect(id: StringName) -> KartEffect:
	if not _cache.has(id):
		var path := "res://data/effects/%s.tres" % id
		_cache[id] = load(path) as KartEffect if ResourceLoader.exists(path) else null
		if _cache[id] == null:
			push_error("Efecto no encontrado: " + path)
	return _cache[id]
