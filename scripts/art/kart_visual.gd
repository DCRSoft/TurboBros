class_name KartVisual
extends RefCounted
## Ensambla el aspecto de un kart: vehículo + conductor (+ artillero). Mallas en caché (se comparten entre karts):
## 2-3 draw calls por kart en total.

static var _cache := {}


static func _mesh(key: String, builder: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]


## Nodo "Look" con las mallas; origen = suelo bajo el kart, -Z = adelante.
static func build(vehicle: VehicleData, driver: CharacterData, gunner: CharacterData, body_color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Look"
	var vm := MeshInstance3D.new()
	vm.name = "Vehicle"
	vm.mesh = _mesh("v:%s:%s" % [vehicle.id, body_color.to_html()], func() -> ArrayMesh: return VehicleModel.build_mesh(vehicle, body_color))
	root.add_child(vm)
	if driver != null:
		var d := MeshInstance3D.new()
		d.name = "Driver"
		d.mesh = _mesh("c:%s:0" % driver.id, func() -> ArrayMesh: return CharacterModel.build_mesh(driver, false))
		d.position = VehicleModel.SEAT_DRIVER
		root.add_child(d)
	if gunner != null:
		var g := MeshInstance3D.new()
		g.name = "Gunner"
		g.mesh = _mesh("c:%s:1" % gunner.id, func() -> ArrayMesh: return CharacterModel.build_mesh(gunner, true))
		g.position = VehicleModel.SEAT_GUNNER
		root.add_child(g)
	return root
