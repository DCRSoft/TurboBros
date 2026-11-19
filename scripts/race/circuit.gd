class_name Circuit
extends Node3D
## Circuito cerrado generado por código desde una curva (Catmull-Rom). La MISMA curva sirve para
## dibujar la carretera, medir el progreso/vueltas y guiar a los bots.
## Muestras a intervalos regulares (step); índice 0 = línea de meta; la carrera avanza hacia índices crecientes.

@export var road_half_width := 8.0
@export var wall_height := 2.5
@export var target_spacing := 3.0

var points := PackedVector3Array()
var tangents := PackedVector3Array()
var rights := PackedVector3Array()
var turn := PackedFloat32Array()   ## giro (rad) entre muestras; positivo = izquierda
var count := 0
var step := 3.0
var length := 0.0
var min_y := 0.0

const ROAD_COLORS: Array[Color] = [Color(0.24, 0.24, 0.27), Color(0.29, 0.29, 0.32)]
const CURB_COLORS: Array[Color] = [Color(0.9, 0.15, 0.15), Color(0.95, 0.95, 0.95)]
const WALL_COLOR := Color(0.75, 0.3, 0.25)


func _ready() -> void:
	_generate_path()
	_build_geometry()


# --- API -------------------------------------------------------------------

func wrap_index(i: int) -> int:
	return posmod(i, count)


## Muestra más cercana (distancia horizontal) buscando cerca de "hint" (evita saltos de un tramo a otro).
func nearest_index(pos: Vector3, hint: int, back := 6, fwd := 24) -> int:
	var best := hint
	var best_d := INF
	for o in range(-back, fwd + 1):
		var i := posmod(hint + o, count)
		var d := _flat_dist2(pos, points[i])
		if d < best_d:
			best_d = d
			best = i
	return best


func nearest_global(pos: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in count:
		var d := _flat_dist2(pos, points[i])
		if d < best_d:
			best_d = d
			best = i
	return best


## Distancia a lo largo del circuito (sin vueltas) de la proyección de pos sobre la muestra idx.
func raw_s(pos: Vector3, idx: int) -> float:
	var t := tangents[idx]
	var rel := pos - points[idx]
	var flat_len := Vector2(t.x, t.z).length()
	var proj := (rel.x * t.x + rel.z * t.z) / maxf(flat_len, 0.001)
	return idx * step + proj


func point_at(s: float) -> Vector3:
	var f := fposmod(s, length) / step
	var i := int(floor(f)) % count
	return points[i].lerp(points[(i + 1) % count], f - floor(f))


func tangent_at(s: float) -> Vector3:
	var f := fposmod(s, length) / step
	var i := int(floor(f)) % count
	return tangents[i].lerp(tangents[(i + 1) % count], f - floor(f)).normalized()


func right_at(s: float) -> Vector3:
	var f := fposmod(s, length) / step
	var i := int(floor(f)) % count
	return rights[i].lerp(rights[(i + 1) % count], f - floor(f)).normalized()


## Parrilla de salida: 2 columnas, filas cada 6 m detrás de la meta.
func grid_transform(slot: int) -> Transform3D:
	var row := slot / 2
	var col := slot % 2
	var s := -(5.0 + row * 6.0)
	var pos := point_at(s) + right_at(s) * (-1.0 if col == 0 else 1.0) * road_half_width * 0.35 + Vector3.UP * 0.7
	return Transform3D(_facing(tangent_at(s)), pos)


func respawn_transform(idx: int) -> Transform3D:
	return Transform3D(_facing(tangents[idx]), points[idx] + Vector3.UP * 1.0)


func item_box_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var rows := 6
	for r in rows:
		var s := (r + 0.5) * length / rows + 20.0
		for lat in [-0.45, 0.0, 0.45]:
			out.append(point_at(s) + right_at(s) * lat * road_half_width)
	return out


func _facing(t: Vector3) -> Basis:
	var flat := Vector3(t.x, 0.0, t.z).normalized()
	return Basis.looking_at(flat, Vector3.UP)


func _flat_dist2(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz


# --- Generación de la curva --------------------------------------------------

func _control_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := 16
	for i in n:
		var th := i * TAU / n
		var rx := 170.0 + 35.0 * sin(3.0 * th)
		var rz := 110.0 + 25.0 * sin(2.0 * th + 1.0)
		out.append(Vector3(rx * cos(th), 3.0 * sin(2.0 * th), rz * sin(th)))
	return out


func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _generate_path() -> void:
	var ctrl := _control_points()
	var n := ctrl.size()
	var dense := PackedVector3Array()
	for i in n:
		var p0 := ctrl[(i - 1 + n) % n]
		var p1 := ctrl[i]
		var p2 := ctrl[(i + 1) % n]
		var p3 := ctrl[(i + 2) % n]
		for s in 40:
			dense.append(_catmull(p0, p1, p2, p3, s / 40.0))
	var cum := PackedFloat32Array([0.0])
	var total := 0.0
	for i in dense.size():
		total += dense[i].distance_to(dense[(i + 1) % dense.size()])
		cum.append(total)
	count = roundi(total / target_spacing)
	step = total / count
	length = total
	points.resize(count)
	var seg := 0
	for k in count:
		var target := k * step
		while seg < dense.size() - 1 and cum[seg + 1] < target:
			seg += 1
		var span := cum[seg + 1] - cum[seg]
		var f := (target - cum[seg]) / span if span > 0.0 else 0.0
		points[k] = dense[seg].lerp(dense[(seg + 1) % dense.size()], f)
	tangents.resize(count)
	rights.resize(count)
	turn.resize(count)
	min_y = INF
	for i in count:
		tangents[i] = (points[(i + 1) % count] - points[(i - 1 + count) % count]).normalized()
		var flat := Vector3(tangents[i].x, 0.0, tangents[i].z).normalized()
		rights[i] = flat.cross(Vector3.UP).normalized()
		min_y = minf(min_y, points[i].y)
	for i in count:
		var a := Vector3(tangents[i].x, 0.0, tangents[i].z).normalized()
		var b := Vector3(tangents[(i + 1) % count].x, 0.0, tangents[(i + 1) % count].z).normalized()
		turn[i] = a.signed_angle_to(b, Vector3.UP)


# --- Geometría ---------------------------------------------------------------

func _tri(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray,
		a: Vector3, b: Vector3, c: Vector3, want: Vector3, color: Color,
		faces: PackedVector3Array = PackedVector3Array(), collide := false) -> void:
	# Godot: cara frontal = sentido horario visto desde delante -> la normal geométrica apunta al revés de "want".
	if (b - a).cross(c - a).dot(want) > 0.0:
		var t := b
		b = c
		c = t
	verts.append_array([a, b, c])
	norms.append_array([want, want, want])
	cols.append_array([color, color, color])
	if collide:
		faces.append_array([a, b, c])


func _quad(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray,
		a: Vector3, b: Vector3, c: Vector3, d: Vector3, want: Vector3, color: Color,
		faces: PackedVector3Array = PackedVector3Array(), collide := false) -> void:
	_tri(verts, norms, cols, a, b, c, want, color, faces, collide)
	_tri(verts, norms, cols, a, c, d, want, color, faces, collide)


func _build_geometry() -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var faces := PackedVector3Array()
	var hw := road_half_width
	var up := Vector3.UP
	for i in count:
		var j := (i + 1) % count
		var li := points[i] - rights[i] * hw
		var ri := points[i] + rights[i] * hw
		var lj := points[j] - rights[j] * hw
		var rj := points[j] + rights[j] * hw
		_quad(verts, norms, cols, li, ri, rj, lj, up, ROAD_COLORS[(i / 2) % 2], faces, true)
		# Bordillos (solo visual)
		var cc := CURB_COLORS[i % 2]
		var o := up * 0.03
		_quad(verts, norms, cols, li + o, li + rights[i] + o, lj + rights[j] + o, lj + o, up, cc)
		_quad(verts, norms, cols, ri - rights[i] + o, ri + o, rj + o, rj - rights[j] + o, up, cc)
		# Muros a ambos lados (colisión), con la normal hacia la carretera
		for side in [-1.0, 1.0]:
			var bi: Vector3 = points[i] + rights[i] * side * (hw + 0.3)
			var bj: Vector3 = points[j] + rights[j] * side * (hw + 0.3)
			var inward: Vector3 = -rights[i] * side
			_quad(verts, norms, cols, bi, bi + up * wall_height, bj + up * wall_height, bj, inward,
					WALL_COLOR, faces, true)
	# Línea de meta a cuadros
	var t0 := Vector3(tangents[0].x, 0.0, tangents[0].z).normalized()
	var cells := 10
	var cw := hw * 2.0 / cells
	for cx in cells:
		for row in 2:
			var base := points[0] - rights[0] * hw + rights[0] * cw * cx + t0 * (row - 1.0) + up * 0.05
			var color := Color.WHITE if (cx + row) % 2 == 0 else Color.BLACK
			_quad(verts, norms, cols, base, base + rights[0] * cw, base + rights[0] * cw + t0, base + t0, up, color)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_child(cs)
	add_child(body)

	# Suelo de relleno (solo visual)
	var ground := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(1200, 1, 1200)
	ground.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.32, 0.48, 0.3)
	ground.material_override = gmat
	ground.position = Vector3(0, min_y - 8.5, 0)
	add_child(ground)
