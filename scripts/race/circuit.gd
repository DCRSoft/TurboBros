class_name Circuit
extends Node3D
## Circuito cerrado generado por código desde una curva (Catmull-Rom). La MISMA curva sirve para
## dibujar la carretera, medir el progreso/vueltas y guiar a los bots.
## Muestras a intervalos regulares (step); índice 0 = línea de meta; la carrera avanza hacia índices crecientes.

## Pista (TrackData) y tema (ThemeData); asignar ANTES de añadir el nodo al árbol. Sin asignar: primera pista.
var track: TrackData
var theme: ThemeData

var road_half_width := 8.0
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
var pads: Array[Dictionary] = []      ## zonas de turbo: {"pos": Vector3, "radius": float, "i": int}
var ramps: Array[Dictionary] = []     ## rampas: {"i": int, "len": float, "lat": float}
var bridges: Array[Dictionary] = []   ## puentes: {"i0": int, "i1": int, "hazard": String}
var tunnels: Array[Dictionary] = []   ## túneles: {"i0": int, "i1": int}

## Atajo (ruta alterna): sale de la carretera principal en la muestra ia y vuelve a ella en ib.
class Alt:
	var ia := 0
	var ib := 0
	var side := 1.0                       ## lado de la carretera por el que sale (+1 derecha, -1 izquierda)
	var points := PackedVector3Array()
	var tangents := PackedVector3Array()
	var rights := PackedVector3Array()
	var turn := PackedFloat32Array()
	var s_map := PackedFloat32Array()     ## s de la carretera principal que equivale a cada muestra (el progreso cuenta igual)
	var count := 0
	var length := 0.0
	var s_scale := 1.0                    ## metros de carretera principal por metro de atajo


var alts: Array[Alt] = []

var _road_colors: Array[Color] = []
var _curb_colors: Array[Color] = []
var _wall_color := Color.WHITE


func _ready() -> void:
	if track == null:
		track = DataCatalog.track(&"")
	if theme == null:
		theme = DataCatalog.theme(track.theme)
	road_half_width = track.road_half_width
	_road_colors = [theme.road_a, theme.road_b]
	_curb_colors = [theme.curb_a, theme.curb_b]
	_wall_color = theme.wall
	_generate_path()
	_generate_alts()
	CircuitFeatures.collect(self)
	_build_geometry()
	CircuitFeatures.build(self)


# --- API -------------------------------------------------------------------

## Peligro bajo el puente en la muestra i ("water", "lava", "void") o "" si la carretera no está en un puente.
func bridge_hazard_at(i: int) -> String:
	for b in bridges:
		if i >= int(b["i0"]) and i <= int(b["i1"]):
			return String(b["hazard"])
	return ""


## Progreso de un kart: {"idx": muestra principal equivalente, "s": distancia a lo largo de la carretera principal,
## "tangent": sentido de la marcha en ese punto}. Si el kart va por un atajo, su progreso se mide en el atajo y se traduce a
## la carretera principal (sale en ia y vuelve en ib), así que cuenta igual que ir por la carretera.
func progress_at(pos: Vector3, hint: int, global_search := false, back := 6, fwd := 24) -> Dictionary:
	var idx := nearest_global(pos) if global_search else nearest_index(pos, hint, back, fwd)
	var best_d := _flat_dist2(pos, points[idx])
	var res := {"idx": idx, "s": raw_s(pos, idx), "tangent": tangents[idx]}
	for a in alts:
		var bk := -1
		var bd := best_d - 0.01   # a igualdad (zona de unión) se queda la carretera principal
		for k in a.count:
			var d := _flat_dist2(pos, a.points[k])
			if d < bd:
				bd = d
				bk = k
		if bk >= 0:
			best_d = bd
			var t := a.tangents[bk]
			var flat := Vector2(t.x, t.z)
			var proj := ((pos.x - a.points[bk].x) * t.x + (pos.z - a.points[bk].z) * t.z) / maxf(flat.length(), 0.001)
			var s_alt := clampf(a.s_map[bk] + proj * a.s_scale, a.ia * step, a.ib * step)
			res = {"idx": posmod(int(s_alt / step), count), "s": s_alt, "tangent": t}
	return res


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
	return track.control_points


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


func _generate_alts() -> void:
	alts.clear()
	for sc in track.shortcuts:
		var a := Alt.new()
		a.ia = clampi(int(float(sc["fa"]) * count), 0, count - 1)
		a.ib = clampi(int(float(sc["fb"]) * count), a.ia + 5, count - 1)
		var mids: PackedVector3Array = sc["pts"]
		var ctrl := PackedVector3Array()
		ctrl.append(points[a.ia])
		for q in mids:
			ctrl.append(Vector3(q.x, 0.0, q.z))
		ctrl.append(points[a.ib])
		var m := ctrl.size()
		var dense := PackedVector3Array()
		for i in m - 1:
			var p0 := ctrl[i - 1] if i > 0 else ctrl[0] * 2.0 - ctrl[1]
			var p3 := ctrl[i + 2] if i + 2 < m else ctrl[m - 1] * 2.0 - ctrl[m - 2]
			for k in 40:
				dense.append(_catmull(p0, ctrl[i], ctrl[i + 1], p3, k / 40.0))
		dense.append(ctrl[m - 1])
		var cum := PackedFloat32Array([0.0])
		var total := 0.0
		for i in range(1, dense.size()):
			total += dense[i].distance_to(dense[i - 1])
			cum.append(total)
		a.count = maxi(roundi(total / target_spacing), 8) + 1
		var st := total / (a.count - 1)
		a.length = total
		var seg := 0
		for k in a.count:
			var target := k * st
			while seg < dense.size() - 2 and cum[seg + 1] < target:
				seg += 1
			var span := cum[seg + 1] - cum[seg]
			var f := clampf((target - cum[seg]) / span if span > 0.0 else 0.0, 0.0, 1.0)
			var q := dense[seg].lerp(dense[seg + 1], f)
			var u := float(k) / (a.count - 1)
			q.y = lerpf(points[a.ia].y, points[a.ib].y, u) + 0.03
			a.points.append(q)
			a.s_map.append(lerpf(a.ia * step, a.ib * step, u))
		a.points[0] = points[a.ia] + Vector3.UP * 0.03
		a.points[a.count - 1] = points[a.ib] + Vector3.UP * 0.03
		a.s_scale = (a.ib - a.ia) * step / maxf(total, 1.0)
		a.tangents.resize(a.count)
		a.rights.resize(a.count)
		a.turn.resize(a.count)
		for k in a.count:
			var prev := a.points[maxi(k - 1, 0)]
			var nxt := a.points[mini(k + 1, a.count - 1)]
			a.tangents[k] = (nxt - prev).normalized()
			var flat := Vector3(a.tangents[k].x, 0.0, a.tangents[k].z).normalized()
			a.rights[k] = flat.cross(Vector3.UP).normalized()
		for k in a.count - 1:
			var f0 := Vector3(a.tangents[k].x, 0.0, a.tangents[k].z).normalized()
			var f1 := Vector3(a.tangents[k + 1].x, 0.0, a.tangents[k + 1].z).normalized()
			a.turn[k] = f0.signed_angle_to(f1, Vector3.UP)
		a.side = 1.0 if (a.points[mini(5, a.count - 1)] - points[a.ia]).dot(rights[a.ia]) > 0.0 else -1.0
		alts.append(a)


## ¿Hay un hueco de salida/entrada de un atajo en el muro de ese lado en la muestra i?
func _wall_gap(i: int, side: float) -> bool:
	for a in alts:
		if a.side == side and ((i >= a.ia - 3 and i <= a.ia + 14) or (i >= a.ib - 14 and i <= a.ib + 3)):
			return true
	return false


func _build_alt_geometry(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray,
		faces: PackedVector3Array) -> void:
	var hw := road_half_width
	var up := Vector3.UP
	for a in alts:
		for k in a.count - 1:
			var j := k + 1
			var li := a.points[k] - a.rights[k] * hw
			var ri := a.points[k] + a.rights[k] * hw
			var lj := a.points[j] - a.rights[j] * hw
			var rj := a.points[j] + a.rights[j] * hw
			_quad(verts, norms, cols, li, ri, rj, lj, up, _road_colors[(k / 2) % 2], faces, true)
			var cc := _curb_colors[k % 2]
			var o := up * 0.03
			_quad(verts, norms, cols, li + o, li + a.rights[k] + o, lj + a.rights[j] + o, lj + o, up, cc)
			_quad(verts, norms, cols, ri - a.rights[k] + o, ri + o, rj + o, rj - a.rights[j] + o, up, cc)
			if k < 10 or k > a.count - 12:
				continue   # junto a la carretera principal no hay muros
			for side in [-1.0, 1.0]:
				var bi: Vector3 = a.points[k] + a.rights[k] * side * (hw + 0.3)
				var bj: Vector3 = a.points[j] + a.rights[j] * side * (hw + 0.3)
				_quad(verts, norms, cols, bi, bi + up * wall_height, bj + up * wall_height, bj, -a.rights[k] * side,
						_wall_color, faces, true)


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
		var hz := bridge_hazard_at(i)
		var road_col: Color = CircuitFeatures.deck_color(hz, i / 2) if hz != "" else _road_colors[(i / 2) % 2]
		_quad(verts, norms, cols, li, ri, rj, lj, up, road_col, faces, true)
		# Bordillos (solo visual)
		var cc := _curb_colors[i % 2]
		var o := up * 0.03
		_quad(verts, norms, cols, li + o, li + rights[i] + o, lj + rights[j] + o, lj + o, up, cc)
		_quad(verts, norms, cols, ri - rights[i] + o, ri + o, rj + o, rj - rights[j] + o, up, cc)
		# Muros a ambos lados (colisión), con la normal hacia la carretera
		for side in [-1.0, 1.0]:
			if _wall_gap(i, side):
				continue
			var bi: Vector3 = points[i] + rights[i] * side * (hw + 0.3)
			var bj: Vector3 = points[j] + rights[j] * side * (hw + 0.3)
			var inward: Vector3 = -rights[i] * side
			_quad(verts, norms, cols, bi, bi + up * wall_height, bj + up * wall_height, bj, inward,
					_wall_color, faces, true)
	# Línea de meta a cuadros
	var t0 := Vector3(tangents[0].x, 0.0, tangents[0].z).normalized()
	var cells := 10
	var cw := hw * 2.0 / cells
	for cx in cells:
		for row in 2:
			var base := points[0] - rights[0] * hw + rights[0] * cw * cx + t0 * (row - 1.0) + up * 0.05
			var color := Color.WHITE if (cx + row) % 2 == 0 else Color.BLACK
			_quad(verts, norms, cols, base, base + rights[0] * cw, base + rights[0] * cw + t0, base + t0, up, color)

	_build_alt_geometry(verts, norms, cols, faces)
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
