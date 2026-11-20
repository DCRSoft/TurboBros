class_name CharacterModel
extends RefCounted
## Modelos 3D low poly de los personajes, generados por código a partir de CharacterData.look.
## Cada figura es UNA malla (un draw call), sentada en el origen del asiento (-Z = adelante).
## look = {species, skin, outfit, outfit2, hair, eye, head, extras[], eyes, weapon, scale}
## Especies: human, ogre, grey, insect, cyclops, robot, skeleton, slime, dragon, mushroom, kraken.

const FIGURE_SCALE := 1.32   ## tamaño de las figuras respecto al kart (estilo "cabezón" de la portada)
const SPECIES: Array[String] = ["human", "ogre", "grey", "insect", "cyclops", "robot", "skeleton", "slime",
		"dragon", "mushroom", "kraken"]


static func build_mesh(c: CharacterData, gunner := false) -> ArrayMesh:
	var L: Dictionary = c.look
	var sp := str(L.get("species", "human"))
	var b := MeshBuilder.new()
	var s := float(L.get("scale", 1.0)) * FIGURE_SCALE
	b.push(Transform3D(Basis().scaled(Vector3.ONE * s), Vector3.ZERO))
	_body(b, L, sp)
	_head(b, L, sp)
	_extras(b, L, sp)
	_arms(b, L, sp, gunner)
	if gunner:
		_weapon(b, L, sp)
	b.pop()
	return b.build()


static func build_instance(c: CharacterData, gunner := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = build_mesh(c, gunner)
	mi.name = "Gunner" if gunner else "Driver"
	return mi


# --- Utilidades ------------------------------------------------------------------

static func _col(L: Dictionary, key: String, fallback: Color) -> Color:
	var v: Variant = L.get(key, fallback)
	return v if v is Color else fallback


static func _has(L: Dictionary, extra: String) -> bool:
	var ex: Variant = L.get("extras", [])
	return ex is Array and (ex as Array).has(extra)


static func _limb(b: MeshBuilder, from: Vector3, to: Vector3, r: float, col: Color) -> void:
	var d := to - from
	var len := d.length()
	if len < 0.001:
		return
	b.push(Transform3D(Basis(Quaternion(Vector3.UP, d / len)), (from + to) * 0.5))
	b.cylinder(Vector3.ZERO, r, r * 0.9, len, col, 6)
	b.pop()


static func _head_center(sp: String) -> Vector3:
	match sp:
		"ogre": return Vector3(0, 0.86, -0.02)
		"grey": return Vector3(0, 0.90, -0.02)
		"insect": return Vector3(0, 0.80, -0.04)
		"cyclops": return Vector3(0, 0.88, -0.02)
		"skeleton": return Vector3(0, 0.82, -0.02)
		"dragon": return Vector3(0, 0.82, -0.04)
		"mushroom": return Vector3(0, 0.74, -0.02)
		"kraken": return Vector3(0, 0.84, -0.02)
		"slime": return Vector3(0, 0.50, -0.10)
	return Vector3(0, 0.84, -0.02)


static func _head_radius(sp: String) -> float:
	match sp:
		"ogre": return 0.29
		"grey": return 0.30
		"insect": return 0.24
		"cyclops": return 0.30
		"skeleton": return 0.25
		"dragon": return 0.26
		"mushroom": return 0.21
		"kraken": return 0.30
		"slime": return 0.28
	return 0.27


# --- Cuerpo ----------------------------------------------------------------------

static func _body(b: MeshBuilder, L: Dictionary, sp: String) -> void:
	var skin := _col(L, "skin", Color(0.9, 0.72, 0.58))
	var outfit := _col(L, "outfit", Color(0.5, 0.5, 0.55))
	var outfit2 := _col(L, "outfit2", Color(0.3, 0.3, 0.33))
	b.box(Vector3(0, 0.04, -0.04), Vector3(0.42, 0.14, 0.32), outfit2)   # cadera
	match sp:
		"human":
			b.box(Vector3(0, 0.30, 0), Vector3(0.46, 0.50, 0.30), outfit)
			b.box(Vector3(0, 0.12, -0.01), Vector3(0.48, 0.07, 0.32), outfit2)  # cinturón
			if _has(L, "pads"):
				for sx in [-1.0, 1.0]:
					b.ellipsoid(Vector3(sx * 0.31, 0.56, 0), Vector3(0.13, 0.09, 0.15), outfit2, 6, 4)
		"ogre":
			b.ellipsoid(Vector3(0, 0.32, 0), Vector3(0.38, 0.30, 0.26), skin, 8, 5)
			b.box(Vector3(0, 0.34, -0.02), Vector3(0.64, 0.26, 0.40), outfit)         # chaleco
			b.ellipsoid(Vector3(0, 0.20, -0.14), Vector3(0.26, 0.20, 0.18), skin, 7, 4)  # barriga
		"grey":
			b.box(Vector3(0, 0.28, 0), Vector3(0.30, 0.46, 0.20), outfit)
			b.cylinder(Vector3(0, 0.58, 0), 0.06, 0.07, 0.14, skin, 6)  # cuello
		"insect":
			b.ellipsoid(Vector3(0, 0.30, 0.02), Vector3(0.26, 0.28, 0.20), outfit, 7, 4)  # tórax
			b.ellipsoid(Vector3(0, 0.10, 0.22), Vector3(0.20, 0.16, 0.26), outfit2, 7, 4)  # abdomen
		"cyclops":
			b.box(Vector3(0, 0.30, 0), Vector3(0.58, 0.50, 0.34), outfit)
			b.ellipsoid(Vector3(0, 0.40, -0.12), Vector3(0.22, 0.2, 0.12), skin, 6, 4)
		"robot":
			b.box(Vector3(0, 0.30, 0), Vector3(0.50, 0.50, 0.34), outfit)
			b.box(Vector3(0, 0.34, -0.18), Vector3(0.30, 0.24, 0.04), outfit2)      # panel
			for i in 3:
				b.box(Vector3(-0.09 + i * 0.09, 0.40, -0.21), Vector3(0.05, 0.05, 0.03), skin)  # luces
		"skeleton":
			b.cylinder(Vector3(0, 0.30, 0.04), 0.05, 0.05, 0.50, skin, 6)  # columna
			for i in 4:
				b.box(Vector3(0, 0.18 + i * 0.1, -0.03), Vector3(0.36 - i * 0.03, 0.04, 0.16), skin)  # costillas
			b.box(Vector3(0, 0.04, -0.02), Vector3(0.30, 0.10, 0.20), skin)
		"slime":
			b.ellipsoid(Vector3(0, 0.28, 0), Vector3(0.42, 0.34, 0.36), skin, 9, 6)
			for i in 3:
				b.sphere(Vector3(-0.2 + i * 0.2, 0.05, -0.2 + (i % 2) * 0.1), 0.09, skin, 6, 4)
		"dragon":
			b.box(Vector3(0, 0.30, 0), Vector3(0.44, 0.48, 0.30), outfit)
			b.box(Vector3(0, 0.26, -0.16), Vector3(0.28, 0.34, 0.04), skin)  # vientre claro
		"mushroom":
			b.cylinder(Vector3(0, 0.30, 0), 0.19, 0.25, 0.56, skin, 8)
			b.cylinder(Vector3(0, 0.12, 0), 0.26, 0.26, 0.05, outfit2, 8)
		"kraken":
			b.ellipsoid(Vector3(0, 0.30, 0), Vector3(0.26, 0.28, 0.20), outfit, 7, 4)
	# faldón / ropa común de cintura hacia abajo no se ve: el kart tapa las piernas


# --- Cabeza ------------------------------------------------------------------------

static func _eye(b: MeshBuilder, pos: Vector3, r: float, white: Color, pupil: Color) -> void:
	b.sphere(pos, r, white, 6, 4)
	b.sphere(pos + Vector3(0, 0, -r * 0.6), r * 0.55, pupil, 5, 3)


static func _head(b: MeshBuilder, L: Dictionary, sp: String) -> void:
	var skin := _col(L, "skin", Color(0.9, 0.72, 0.58))
	var outfit := _col(L, "outfit", Color(0.5, 0.5, 0.55))
	var outfit2 := _col(L, "outfit2", Color(0.3, 0.3, 0.33))
	var hair := _col(L, "hair", Color(0.3, 0.2, 0.1))
	var eye := _col(L, "eye", Color(0.1, 0.1, 0.15))
	var hc := _head_center(sp)
	var hr := _head_radius(sp)
	var style := str(L.get("head", "bare"))
	match sp:
		"grey":
			b.ellipsoid(hc + Vector3(0, 0.04, 0), Vector3(hr * 0.95, hr * 1.25, hr * 0.95), skin, 9, 6)
			for sx in [-1.0, 1.0]:
				b.push(Transform3D(Basis(Vector3.BACK, deg_to_rad(sx * 25.0)), hc + Vector3(sx * hr * 0.42, 0.0, -hr * 0.78)))
				b.ellipsoid(Vector3.ZERO, Vector3(0.10, 0.17, 0.05), Color(0.02, 0.02, 0.05), 6, 4)
				b.pop()
			return
		"robot":
			b.box(hc, Vector3(hr * 2.0, hr * 1.7, hr * 1.8), outfit)
			b.box(hc + Vector3(0, 0.02, -hr * 0.92), Vector3(hr * 1.6, hr * 0.5, 0.04), skin)   # visor luminoso
			b.cylinder(hc + Vector3(0, hr * 1.2, 0), 0.02, 0.02, 0.22, outfit2, 5)
			b.sphere(hc + Vector3(0, hr * 1.35, 0), 0.05, skin, 5, 3)
			for sx in [-1.0, 1.0]:
				b.box(hc + Vector3(sx * hr * 1.05, 0, 0), Vector3(0.06, 0.16, 0.14), outfit2)  # orejeras
			return
		"skeleton":
			b.ellipsoid(hc + Vector3(0, 0.02, 0), Vector3(hr, hr * 1.05, hr * 1.0), skin, 8, 5)
			b.box(hc + Vector3(0, -hr * 0.8, -hr * 0.3), Vector3(hr * 1.0, 0.07, hr * 0.7), skin)  # mandíbula
			for sx in [-1.0, 1.0]:
				b.ellipsoid(hc + Vector3(sx * hr * 0.4, 0.03, -hr * 0.82), Vector3(0.08, 0.1, 0.04), Color(0.02, 0.02, 0.03), 6, 4)
			for i in 4:
				b.box(hc + Vector3(-0.07 + i * 0.047, -hr * 0.7, -hr * 0.62), Vector3(0.03, 0.05, 0.03), Color.WHITE)
			if style == "pirate":
				b.cylinder(hc + Vector3(0, hr * 0.95, 0), hr * 0.95, hr * 1.05, 0.12, outfit, 8)
			return
		"slime":
			for sx in [-1.0, 1.0]:
				_eye(b, hc + Vector3(sx * 0.12, 0.08, -0.22), 0.07, Color.WHITE, eye)
			b.sphere(hc + Vector3(0.0, 0.34, 0.05), 0.07, skin, 5, 3)   # gota
			return
		"mushroom":
			b.ellipsoid(hc, Vector3(hr, hr * 0.9, hr), skin, 8, 5)
			for sx in [-1.0, 1.0]:
				_eye(b, hc + Vector3(sx * 0.09, 0.03, -hr * 0.8), 0.045, Color.WHITE, eye)
			var cap := _col(L, "outfit", Color(0.8, 0.2, 0.3))
			b.ellipsoid(hc + Vector3(0, 0.14, 0), Vector3(0.52, 0.28, 0.52), cap, 10, 5)
			for i in 6:
				var a := TAU * i / 6.0
				b.sphere(hc + Vector3(cos(a) * 0.30, 0.30 - (i % 2) * 0.05, sin(a) * 0.30), 0.065, Color(1, 1, 0.9), 5, 3)
			b.sphere(hc + Vector3(0, 0.40, 0), 0.07, Color(1, 1, 0.9), 5, 3)
			return
		"kraken":
			b.ellipsoid(hc + Vector3(0, 0.08, 0.04), Vector3(hr, hr * 1.15, hr * 1.05), skin, 9, 6)
			for sx in [-1.0, 1.0]:
				_eye(b, hc + Vector3(sx * 0.13, 0.05, -hr * 0.85), 0.07, Color.WHITE, eye)
			for i in 4:  # tentáculos que cuelgan
				var tx := -0.17 + i * 0.113
				_limb(b, hc + Vector3(tx, -0.15, 0.0), hc + Vector3(tx * 1.4, -0.42, -0.06 + (i % 2) * 0.1), 0.045, skin)
			return
		"dragon":
			b.ellipsoid(hc, Vector3(hr * 0.95, hr * 0.9, hr * 1.0), skin, 8, 5)
			b.box(hc + Vector3(0, -0.05, -hr * 0.95), Vector3(0.20, 0.13, 0.22), skin)   # hocico
			for sx in [-1.0, 1.0]:
				_eye(b, hc + Vector3(sx * 0.13, 0.08, -hr * 0.65), 0.05, Color(1, 0.9, 0.2), eye)
				b.sphere(hc + Vector3(sx * 0.05, -0.04, -hr * 1.18), 0.025, Color(0.1, 0.1, 0.1), 4, 3)
			return
		"insect":
			b.ellipsoid(hc, Vector3(hr * 1.05, hr * 0.95, hr * 0.95), skin, 8, 5)
			for sx in [-1.0, 1.0]:
				_eye(b, hc + Vector3(sx * 0.12, 0.07, -hr * 0.8), 0.075, Color(0.9, 0.95, 0.4), eye)
				_eye(b, hc + Vector3(sx * 0.06, -0.03, -hr * 0.9), 0.04, Color(0.9, 0.95, 0.4), eye)
			return
		"cyclops":
			b.ellipsoid(hc, Vector3(hr * 1.05, hr, hr), skin, 8, 5)
			b.sphere(hc + Vector3(0, 0.04, -hr * 0.82), 0.13, Color.WHITE, 7, 5)
			b.sphere(hc + Vector3(0, 0.04, -hr * 0.82 - 0.08), 0.07, eye, 6, 4)
			b.box(hc + Vector3(0, -0.14, -hr * 0.88), Vector3(0.22, 0.05, 0.05), Color(0.15, 0.05, 0.1))  # boca
			for i in 3:
				b.box(hc + Vector3(-0.07 + i * 0.07, -0.11, -hr * 0.9), Vector3(0.035, 0.045, 0.03), Color.WHITE)
			return
		"ogre":
			b.ellipsoid(hc, Vector3(hr * 1.1, hr * 0.95, hr), skin, 8, 5)
			b.box(hc + Vector3(0, 0.08, -hr * 0.8), Vector3(hr * 1.6, 0.07, 0.1), skin.darkened(0.2))  # ceja
			for sx in [-1.0, 1.0]:
				b.sphere(hc + Vector3(sx * 0.1, 0.03, -hr * 0.88), 0.035, eye, 5, 3)
			return

	# Humanos (y base): cabeza + ojos + peinado/casco
	b.sphere(hc, hr, skin, 9, 6)
	for sx in [-1.0, 1.0]:
		_eye(b, hc + Vector3(sx * 0.10, 0.02, -hr * 0.86), 0.045, Color.WHITE, eye)
	match style:
		"twintails":
			b.ellipsoid(hc + Vector3(0, 0.08, 0.03), Vector3(hr * 1.1, hr * 0.9, hr * 1.1), hair, 9, 5)
			b.box(hc + Vector3(0, 0.12, -hr * 0.85), Vector3(hr * 1.4, 0.09, 0.07), hair)   # flequillo
			for sx in [-1.0, 1.0]:
				b.sphere(hc + Vector3(sx * (hr + 0.10), 0.02, 0.06), 0.11, hair, 6, 4)
				b.cone(hc + Vector3(sx * (hr + 0.12), -0.18, 0.08), 0.10, 0.34, hair, 6)
				b.sphere(hc + Vector3(sx * (hr + 0.03), 0.10, 0.04), 0.06, outfit2, 5, 3)  # lazo/flor
		"braids":
			b.ellipsoid(hc + Vector3(0, 0.06, 0.0), Vector3(hr * 1.12, hr * 0.95, hr * 1.12), outfit, 9, 5)  # casco
			b.box(hc + Vector3(0, 0.30, -0.02), Vector3(0.05, 0.12, hr * 1.6), outfit2)                       # cresta
			b.box(hc + Vector3(0, 0.0, -hr * 0.97), Vector3(hr * 1.3, 0.06, 0.03), Color(0.1, 0.1, 0.12))    # visera
			for i in 5:
				b.sphere(hc + Vector3(0.0, -0.10 - i * 0.10, hr * 0.9 + i * 0.03), 0.08 - i * 0.008, hair, 5, 3)  # trenza
		"spiked_helmet":
			b.ellipsoid(hc + Vector3(0, 0.05, 0), Vector3(hr * 1.14, hr * 1.0, hr * 1.14), outfit, 9, 5)
			b.box(hc + Vector3(0, -0.02, -hr * 0.98), Vector3(hr * 1.2, 0.07, 0.03), Color(0.08, 0.05, 0.05))
			for i in 3:
				b.cone(hc + Vector3(0, hr * 1.0, -0.08 + i * 0.08), 0.045, 0.16, outfit2, 5)
			for sx in [-1.0, 1.0]:
				b.push(Transform3D(Basis(Vector3.BACK, deg_to_rad(-sx * 70.0)), hc + Vector3(sx * hr * 1.1, 0.1, 0)))
				b.cone(Vector3.ZERO, 0.06, 0.24, outfit2, 5)
				b.pop()
		"full_helmet":
			b.ellipsoid(hc + Vector3(0, 0.02, 0), Vector3(hr * 1.14, hr * 1.1, hr * 1.14), outfit, 9, 6)
			b.box(hc + Vector3(0, 0.0, -hr * 1.0), Vector3(hr * 1.25, 0.08, 0.03), Color(0.06, 0.06, 0.08))
			b.box(hc + Vector3(0, 0.26, 0.02), Vector3(0.04, 0.10, hr * 1.5), outfit2)
		"visor_helmet":
			b.ellipsoid(hc + Vector3(0, 0.03, 0), Vector3(hr * 1.14, hr * 1.05, hr * 1.14), outfit, 9, 5)
			b.box(hc + Vector3(0, 0.02, -hr * 1.0), Vector3(hr * 1.3, 0.10, 0.03), Color(0.3, 0.95, 1.0))
		"ponytail":
			b.ellipsoid(hc + Vector3(0, 0.07, 0.02), Vector3(hr * 1.1, hr * 0.9, hr * 1.1), hair, 9, 5)
			b.box(hc + Vector3(0, 0.12, -hr * 0.85), Vector3(hr * 1.4, 0.09, 0.07), hair)
			b.box(hc + Vector3(0, 0.12, -0.0), Vector3(hr * 2.15, 0.04, hr * 2.2), outfit2)      # diadema
			for i in 4:
				b.sphere(hc + Vector3(0.0, 0.10 - i * 0.05, hr * 1.0 + i * 0.10), 0.10 - i * 0.012, hair, 6, 4)
	if _has(L, "beard"):
		b.ellipsoid(hc + Vector3(0, -hr * 0.62, -hr * 0.42), Vector3(hr * 0.78, 0.16, 0.14), hair, 7, 4)


# --- Extras -------------------------------------------------------------------------

static func _extras(b: MeshBuilder, L: Dictionary, sp: String) -> void:
	var skin := _col(L, "skin", Color(0.9, 0.72, 0.58))
	var outfit2 := _col(L, "outfit2", Color(0.3, 0.3, 0.33))
	var hair := _col(L, "hair", Color(0.3, 0.2, 0.1))
	var hc := _head_center(sp)
	var hr := _head_radius(sp)
	if _has(L, "horns"):
		for sx in [-1.0, 1.0]:
			b.push(Transform3D(Basis(Vector3.BACK, deg_to_rad(-sx * 28.0)), hc + Vector3(sx * hr * 0.7, hr * 0.85, 0)))
			b.cone(Vector3.ZERO, 0.06, 0.26, outfit2, 5)
			b.pop()
	if _has(L, "single_horn"):
		b.cone(hc + Vector3(0, hr * 1.1, -0.02), 0.06, 0.24, outfit2, 5)
	if _has(L, "tusks"):
		for sx in [-1.0, 1.0]:
			b.cone(hc + Vector3(sx * 0.12, -0.10, -hr * 0.88), 0.035, 0.16, Color(0.95, 0.93, 0.8), 5)
	if _has(L, "antennae"):
		for sx in [-1.0, 1.0]:
			_limb(b, hc + Vector3(sx * 0.08, hr * 0.8, -0.05), hc + Vector3(sx * 0.2, hr * 0.8 + 0.28, -0.12), 0.018, skin)
			b.sphere(hc + Vector3(sx * 0.2, hr * 0.8 + 0.3, -0.12), 0.045, outfit2, 5, 3)
	if _has(L, "mandibles"):
		for sx in [-1.0, 1.0]:
			b.push(Transform3D(Basis(Vector3.BACK, deg_to_rad(sx * 25.0)) * Basis(Vector3.RIGHT, deg_to_rad(-80.0)),
					hc + Vector3(sx * 0.07, -0.13, -hr * 0.95)))
			b.cone(Vector3.ZERO, 0.04, 0.16, outfit2, 5)
			b.pop()
	if _has(L, "ears"):
		for sx in [-1.0, 1.0]:
			b.push(Transform3D(Basis(Vector3.BACK, deg_to_rad(-sx * 80.0)), hc + Vector3(sx * hr * 1.0, 0.04, 0.0)))
			b.cone(Vector3.ZERO, 0.07, 0.2, skin, 5)
			b.pop()
	if _has(L, "spikes"):
		for sx in [-1.0, 1.0]:
			for i in 2:
				b.push(Transform3D(Basis(Vector3.BACK, deg_to_rad(-sx * 55.0)), Vector3(sx * 0.32, 0.62 - i * 0.12, 0.0)))
				b.cone(Vector3.ZERO, 0.055, 0.2, outfit2, 5)
				b.pop()
	if _has(L, "tail"):
		for i in 5:
			b.cone(Vector3(0, 0.08 - i * 0.015, 0.34 + i * 0.14), 0.12 - i * 0.02, 0.2, skin, 6)
	if _has(L, "wings"):
		for sx in [-1.0, 1.0]:
			b.push(Transform3D(Basis(Vector3.UP, deg_to_rad(-sx * 25.0)) * Basis(Vector3.BACK, deg_to_rad(sx * 35.0)),
					Vector3(sx * 0.32, 0.62, 0.20)))
			b.box(Vector3(sx * 0.18, 0.0, 0), Vector3(0.36, 0.03, 0.30), outfit2)
			b.box(Vector3(sx * 0.30, 0.1, 0.05), Vector3(0.14, 0.03, 0.16), outfit2)
			b.pop()
	if _has(L, "cape"):
		b.box(Vector3(0, 0.30, 0.20), Vector3(0.46, 0.55, 0.04), outfit2)
	if _has(L, "extra_arms") and sp == "insect":
		for sx in [-1.0, 1.0]:
			_limb(b, Vector3(sx * 0.22, 0.20, -0.05), Vector3(sx * 0.30, 0.10, -0.30), 0.035, skin)
	if _has(L, "flowers"):
		for sx in [-1.0, 1.0]:
			b.sphere(hc + Vector3(sx * (hr + 0.02), 0.16, 0.02), 0.05, Color(1.0, 0.9, 0.4), 5, 3)
	if _has(L, "mohawk"):
		for i in 4:
			b.cone(hc + Vector3(0, hr * 0.95, -0.12 + i * 0.08), 0.05, 0.16, hair, 5)
	if _has(L, "tentacles") and sp == "kraken":
		for i in 4:
			var tx := -0.16 + i * 0.107
			_limb(b, Vector3(tx, 0.10, 0.12), Vector3(tx * 1.3, 0.02, 0.45 + (i % 2) * 0.1), 0.05, skin)


# --- Brazos y arma -------------------------------------------------------------------

static func _arms(b: MeshBuilder, L: Dictionary, sp: String, gunner: bool) -> void:
	if sp == "slime":
		for sx in [-1.0, 1.0]:
			b.sphere(Vector3(sx * 0.40, 0.26, -0.18), 0.10, _col(L, "skin", Color.WHITE), 6, 4)
		return
	var skin := _col(L, "skin", Color(0.9, 0.72, 0.58))
	var sleeve := _col(L, "outfit", Color(0.5, 0.5, 0.55))
	if sp == "robot" or sp == "skeleton" or sp == "insect" or sp == "dragon":
		sleeve = _col(L, "outfit2", sleeve) if sp == "robot" else skin
	var shoulder_x := 0.30 if sp != "ogre" else 0.40
	var r := 0.06 if sp != "ogre" else 0.09
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		var from := Vector3(sx * shoulder_x, 0.50, 0.0)
		var to: Vector3
		if gunner:
			to = Vector3(0.34, 0.74, -0.40) if i == 1 else Vector3(0.14, 0.66, -0.42)  # manos en el arma
		else:
			to = Vector3(sx * 0.17, 0.40, -0.40)  # manos al volante
		_limb(b, from, to, r, sleeve)
		b.sphere(to, r * 1.25, skin, 6, 4)


static func _weapon(b: MeshBuilder, L: Dictionary, sp: String) -> void:
	var metal := Color(0.25, 0.26, 0.3)
	var dark := Color(0.12, 0.12, 0.14)
	var glow := _col(L, "outfit", Color(0.9, 0.3, 0.2))
	var w := str(L.get("weapon", "blaster"))
	b.push(MeshBuilder.move(Vector3(0.34, 0.74, -0.40)))
	match w:
		"minigun":
			b.box(Vector3(0, 0, 0.05), Vector3(0.14, 0.14, 0.34), metal)
			b.push(MeshBuilder.rot_x(90.0))
			for i in 3:
				var a := TAU * i / 3.0
				b.cylinder(Vector3(cos(a) * 0.04, -0.42, sin(a) * 0.04), 0.022, 0.022, 0.55, dark, 5)
			b.pop()
		"gatling":
			b.cylinder(Vector3(0, 0, 0.0), 0.11, 0.11, 0.30, metal, 8)
			b.push(MeshBuilder.rot_x(90.0))
			for i in 6:
				var a := TAU * i / 6.0
				b.cylinder(Vector3(cos(a) * 0.07, -0.55, sin(a) * 0.07), 0.02, 0.02, 0.6, dark, 5)
			b.pop()
		"beam":
			b.box(Vector3(0, 0, 0.0), Vector3(0.10, 0.12, 0.46), metal)
			b.box(Vector3(0, 0.02, -0.40), Vector3(0.05, 0.05, 0.46), dark)
			b.sphere(Vector3(0, 0.02, -0.66), 0.06, Color(0.4, 0.95, 1.0), 6, 4)
		"cannon":
			b.box(Vector3(0, 0, 0.1), Vector3(0.20, 0.18, 0.30), metal)
			b.push(MeshBuilder.rot_x(90.0))
			b.cylinder(Vector3(0, -0.46, 0), 0.08, 0.10, 0.6, dark, 8)
			b.pop()
		"club":
			b.push(MeshBuilder.rot_x(110.0))
			b.cylinder(Vector3(0, -0.30, 0), 0.10, 0.04, 0.7, Color(0.45, 0.3, 0.18), 7)
			b.pop()
		"claws":
			for i in 3:
				b.push(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90.0)), Vector3(-0.07 + i * 0.07, 0, -0.18)))
				b.cone(Vector3.ZERO, 0.03, 0.28, Color(0.95, 0.93, 0.85), 5)
				b.pop()
		"staff":
			b.push(MeshBuilder.rot_x(100.0))
			b.cylinder(Vector3(0, -0.32, 0), 0.025, 0.03, 0.8, Color(0.5, 0.35, 0.2), 5)
			b.pop()
			b.sphere(Vector3(0, 0.12, -0.62), 0.09, glow.lightened(0.2), 6, 4)
		_:  # blaster
			b.box(Vector3(0, 0, 0.0), Vector3(0.10, 0.14, 0.26), metal)
			b.box(Vector3(0, 0.02, -0.22), Vector3(0.05, 0.05, 0.22), dark)
			b.box(Vector3(0, 0.10, 0.05), Vector3(0.03, 0.08, 0.14), glow)
	b.pop()
