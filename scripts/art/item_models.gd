class_name ItemModels
extends RefCounted
## Modelos 3D low poly de las cajas de ítems, proyectiles y trampas (una malla cada uno, en caché).
## Convención: -Z = hacia delante (los proyectiles giran para mirar hacia donde van).

static var _cache := {}


static func _cached(key: String, builder: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]


## Caja de ítems (fake = caja falsa: casi igual, pero naranja y con "!").
static func box_mesh(fake := false) -> ArrayMesh:
	return _cached("box:%s" % fake, func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var frame := Color(0.85, 0.62, 0.15) if fake else Color(1.0, 0.85, 0.2)
		var glass := Color(1.0, 0.4, 0.15) if fake else Color(0.3, 0.7, 1.0)
		var h := 0.55
		b.box(Vector3.ZERO, Vector3.ONE * 1.0, glass)
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				b.box(Vector3(0, sy * h, sz * h), Vector3(1.2, 0.12, 0.12), frame)   # aristas en X
				b.box(Vector3(sy * h, 0, sz * h), Vector3(0.12, 1.2, 0.12), frame)   # aristas en Y
				b.box(Vector3(sy * h, sz * h, 0), Vector3(0.12, 0.12, 1.2), frame)   # aristas en Z
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					b.sphere(Vector3(sx, sy, sz) * h, 0.11, frame.lightened(0.2), 5, 3)
		return b.build())


static func projectile_mesh(kind: ItemProjectile.Kind, color: Color) -> ArrayMesh:
	return _cached("proj:%d:%s" % [kind, color.to_html()], func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var dark := Color(0.12, 0.12, 0.15)
		var fire := Color(1.0, 0.6, 0.1)
		match kind:
			ItemProjectile.Kind.BOUNCER:
				b.sphere(Vector3.ZERO, 0.38, color, 8, 5)
				for dir in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
					var rot := Basis(Quaternion(Vector3.UP, dir))
					b.push(Transform3D(rot, dir * 0.42))
					b.cone(Vector3.ZERO, 0.1, 0.24, dark, 5)
					b.pop()
				b.sphere(Vector3(0.12, 0.16, -0.28), 0.09, color.lightened(0.5), 5, 3)
			ItemProjectile.Kind.BOMB:
				b.sphere(Vector3.ZERO, 0.55, dark, 9, 6)
				b.sphere(Vector3(-0.18, 0.2, -0.38), 0.12, Color(0.45, 0.47, 0.55), 5, 3)
				b.cylinder(Vector3(0, 0.56, 0), 0.14, 0.17, 0.14, Color(0.4, 0.4, 0.45), 6)
				b.push(Transform3D(Basis(Vector3.BACK, deg_to_rad(-30.0)), Vector3(0.1, 0.78, 0)))
				b.cylinder(Vector3.ZERO, 0.03, 0.03, 0.3, Color(0.7, 0.55, 0.3), 5)
				b.pop()
				b.sphere(Vector3(0.24, 0.94, 0), 0.1, fire, 5, 3)
				b.sphere(Vector3(0.24, 0.94, 0), 0.06, Color(1.0, 0.95, 0.5), 4, 3)
			_:  # misil recto y teledirigido: cuerpo a lo largo de Z, morro hacia -Z
				var body := color if kind == ItemProjectile.Kind.STRAIGHT else color
				b.push(MeshBuilder.rot_x(90.0))
				b.cylinder(Vector3.ZERO, 0.17, 0.17, 0.95, Color(0.92, 0.93, 0.98), 8)
				b.pop()
				b.push(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90.0)), Vector3(0, 0, -0.72)))
				b.cone(Vector3.ZERO, 0.17, 0.4, body, 8)
				b.pop()
				b.push(MeshBuilder.rot_x(90.0))
				b.cylinder(Vector3(0, -0.2, 0), 0.175, 0.175, 0.12, body, 8)   # banda de color
				b.pop()
				for i in 3:
					b.push(Transform3D(Basis(Vector3.BACK, deg_to_rad(120.0 * i)), Vector3(0, 0, 0.42)))
					b.box(Vector3(0, 0.2, 0), Vector3(0.05, 0.3, 0.3), body)
					b.pop()
				b.push(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0, 0, 0.62)))
				b.cone(Vector3.ZERO, 0.14, 0.34, fire, 6)                           # llama
				b.pop()
				if kind == ItemProjectile.Kind.HOMING:
					b.box(Vector3(0, 0.22, -0.2), Vector3(0.05, 0.12, 0.05), dark)     # antena de guiado
					b.sphere(Vector3(0, 0.3, -0.2), 0.07, Color(1.0, 0.3, 0.9), 5, 3)
		return b.build())


static func trap_mesh(kind: ItemTrap.Kind, color: Color, radius: float) -> ArrayMesh:
	return _cached("trap:%d:%s:%.1f" % [kind, color.to_html(), radius], func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var dark := Color(0.1, 0.1, 0.13)
		match kind:
			ItemTrap.Kind.OIL:
				b.ellipsoid(Vector3(0, 0.05, 0), Vector3(radius * 0.9, 0.06, radius * 0.75), dark, 10, 3)
				b.ellipsoid(Vector3(radius * 0.45, 0.04, radius * 0.25), Vector3(radius * 0.45, 0.06, radius * 0.4), dark, 8, 3)
				b.ellipsoid(Vector3(-radius * 0.5, 0.04, -radius * 0.2), Vector3(radius * 0.4, 0.06, radius * 0.35), dark, 8, 3)
				b.ellipsoid(Vector3(-radius * 0.2, 0.1, -radius * 0.15), Vector3(radius * 0.3, 0.03, radius * 0.15), Color(0.35, 0.4, 0.65), 6, 3)
			ItemTrap.Kind.NAILS:
				b.box(Vector3(0, 0.05, 0), Vector3(radius * 1.5, 0.1, 0.7), Color(0.3, 0.31, 0.36))
				for i in 6:
					var x := -radius * 0.65 + i * radius * 0.26
					b.cone(Vector3(x, 0.28, (i % 2) * 0.12 - 0.06), 0.09, 0.42, Color(0.85, 0.87, 0.93), 5)
			ItemTrap.Kind.FAKE_BOX:
				return box_mesh(true)
			ItemTrap.Kind.BARRIER:
				for sx in [-1.0, 1.0]:
					b.box(Vector3(sx * 1.25, 0.6, 0), Vector3(0.14, 1.2, 0.5), Color(0.5, 0.52, 0.58))
				for i in 3:
					b.box(Vector3(0, 0.25 + i * 0.35, 0), Vector3(2.7, 0.28, 0.2), Color(1.0, 0.5, 0.1) if i % 2 == 0 else Color(0.96, 0.96, 0.98))
				b.sphere(Vector3(0, 1.28, 0), 0.1, Color(1.0, 0.2, 0.15), 5, 3)
			ItemTrap.Kind.MINE:
				b.sphere(Vector3(0, 0.34, 0), 0.42, Color(0.22, 0.2, 0.24), 8, 5)
				for i in 8:
					var a := TAU * i / 8.0
					b.push(Transform3D(Basis(Vector3.UP, PI - a) * Basis(Vector3.BACK, PI / 2.0), Vector3(cos(a) * 0.45, 0.34, sin(a) * 0.45)))
					b.cone(Vector3.ZERO, 0.07, 0.2, Color(0.6, 0.6, 0.66), 5)
					b.pop()
				b.cylinder(Vector3(0, 0.78, 0), 0.08, 0.12, 0.12, Color(0.4, 0.4, 0.45), 6)
				b.sphere(Vector3(0, 0.88, 0), 0.1, Color(1.0, 0.15, 0.1), 5, 3)
		return b.build())


## Versión pequeña de una trampa para llevarla detrás del kart como escudo.
static func carry_mesh(item: ItemData) -> ArrayMesh:
	if item is ItemTrap:
		var t := item as ItemTrap
		return trap_mesh(t.kind, t.color, minf(t.trigger_radius, 1.4))
	return box_mesh(false)
