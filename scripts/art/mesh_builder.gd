class_name MeshBuilder
extends RefCounted
## Constructor de mallas low poly con sombreado plano y color por vértice. Une muchas formas en UNA sola malla
## (un solo draw call por figura/vehículo: pensado para el i3 de 2 núcleos). Orientación: -Z = adelante, +Y = arriba.

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _xf := Transform3D.IDENTITY
var _stack: Array[Transform3D] = []

static var _material: StandardMaterial3D


## Material compartido para todas las mallas con color por vértice.
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.85
		_material.cull_mode = BaseMaterial3D.CULL_BACK
	return _material


func triangle_count() -> int:
	return _v.size() / 3


# --- Transformaciones ---------------------------------------------------------

func push(t: Transform3D) -> MeshBuilder:
	_stack.append(_xf)
	_xf = _xf * t
	return self


func pop() -> MeshBuilder:
	_xf = _stack.pop_back()
	return self


static func rot_x(deg: float) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, deg_to_rad(deg)), Vector3.ZERO)


static func rot_y(deg: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(deg)), Vector3.ZERO)


static func rot_z(deg: float) -> Transform3D:
	return Transform3D(Basis(Vector3.BACK, deg_to_rad(deg)), Vector3.ZERO)


static func move(p: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, p)


# --- Primitivas ----------------------------------------------------------------

func _tri(a: Vector3, b: Vector3, c: Vector3, center: Vector3, col: Color) -> void:
	a = _xf * a
	b = _xf * b
	c = _xf * c
	var out := (a + b + c) / 3.0 - _xf * center
	var cr := (b - a).cross(c - a)
	if cr.dot(out) > 0.0:  # Godot: cara frontal = sentido horario
		var t := b
		b = c
		c = t
		cr = -cr
	var n := (-cr).normalized()
	_v.append_array([a, b, c])
	_n.append_array([n, n, n])
	_c.append_array([col, col, col])


func box(center: Vector3, size: Vector3, col: Color) -> MeshBuilder:
	var h := size * 0.5
	var p: Array[Vector3] = []
	for i in 8:
		p.append(center + Vector3(h.x if (i & 1) else -h.x, h.y if (i & 2) else -h.y, h.z if (i & 4) else -h.z))
	for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 2, 6, 4], [1, 5, 7, 3], [0, 4, 5, 1], [2, 3, 7, 6]]:
		_tri(p[f[0]], p[f[1]], p[f[2]], center, col)
		_tri(p[f[0]], p[f[2]], p[f[3]], center, col)
	return self


## Elipsoide (esfera achatada/alargada) con pocos segmentos: aspecto low poly.
func ellipsoid(center: Vector3, radii: Vector3, col: Color, segs := 8, rings := 5) -> MeshBuilder:
	var grid: Array = []
	for r in rings + 1:
		var phi := PI * r / rings
		var row: Array[Vector3] = []
		for s in segs:
			var th := TAU * s / segs
			row.append(center + Vector3(radii.x * sin(phi) * cos(th), radii.y * cos(phi), radii.z * sin(phi) * sin(th)))
		grid.append(row)
	for r in rings:
		for s in segs:
			var s2 := (s + 1) % segs
			var a: Vector3 = grid[r][s]
			var b: Vector3 = grid[r][s2]
			var c: Vector3 = grid[r + 1][s2]
			var d: Vector3 = grid[r + 1][s]
			if r > 0:
				_tri(a, b, c, center, col)
			if r < rings - 1:
				_tri(a, c, d, center, col)
	return self


func sphere(center: Vector3, radius: float, col: Color, segs := 8, rings := 5) -> MeshBuilder:
	return ellipsoid(center, Vector3.ONE * radius, col, segs, rings)


## Cilindro/cono con el eje en Y (radio superior 0 = cono). Para otros ejes usa push(rot_*).
func cylinder(center: Vector3, r_top: float, r_bottom: float, height: float, col: Color, segs := 8) -> MeshBuilder:
	var top := center + Vector3(0, height * 0.5, 0)
	var bot := center - Vector3(0, height * 0.5, 0)
	for s in segs:
		var a0 := TAU * s / segs
		var a1 := TAU * (s + 1) / segs
		var t0 := top + Vector3(cos(a0), 0, sin(a0)) * r_top
		var t1 := top + Vector3(cos(a1), 0, sin(a1)) * r_top
		var b0 := bot + Vector3(cos(a0), 0, sin(a0)) * r_bottom
		var b1 := bot + Vector3(cos(a1), 0, sin(a1)) * r_bottom
		if r_top > 0.0001:
			_tri(t0, t1, b1, center, col)
		_tri(t0, b1, b0, center, col)
		if r_top > 0.0001:
			_tri(top, t1, t0, center, col)
		if r_bottom > 0.0001:
			_tri(bot, b0, b1, center, col)
	return self


func cone(center: Vector3, radius: float, height: float, col: Color, segs := 8) -> MeshBuilder:
	return cylinder(center, 0.0, radius, height, col, segs)


# --- Resultado --------------------------------------------------------------------

func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _v.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	return mesh


func build_instance() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = build()
	return mi
