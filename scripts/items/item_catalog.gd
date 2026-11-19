class_name ItemCatalog
extends RefCounted
## Catálogo de ítems: todos los .tres de data/items/ (recursivo). Añadir un archivo = ítem nuevo.

const ITEMS_DIR := "res://data/items"

static var _items: Array[ItemData] = []
static var _loaded := false


static func all() -> Array[ItemData]:
	if not _loaded:
		_items.clear()
		_scan(ITEMS_DIR)
		_loaded = true
	return _items


static func find(id: StringName) -> ItemData:
	for it in all():
		if it.id == id:
			return it
	return null


static func _scan(path: String) -> void:
	for d in DirAccess.get_directories_at(path):
		_scan(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		var name := f.trim_suffix(".remap")  # en builds exportados los .tres aparecen como .tres.remap
		if name.ends_with(".tres") or name.ends_with(".res"):
			var res := load(path.path_join(name))
			if res is ItemData:
				_items.append(res)
