class_name Scenery
extends Node3D
## Paisaje de una pista, todo generado por código y solo visual (no colisiona; la carretera tiene sus muros):
##  - terreno: malla de baja resolución en trozos (chunks) con colores por altura/pendiente, bajo la carretera cerca
##    de ella y con colinas (ruido) al alejarse;
##  - montañas lejanas en anillo (sin niebla, con calima);
##  - decorado en MultiMesh por trozo y tipo, con distancia de dibujado y densidad según la calidad gráfica;
##  - elementos a pie de pista y arco de meta;
##  - cielo, niebla y luz del tema.

const CHUNK_CELLS := 16
const HASH := 32.0          ## celda del índice espacial de la carretera
const REGION_RINGS := 6     ## el decorado llega hasta REGION_RINGS * HASH metros de la carretera
const ROAD_DROP := 1.2      ## el terreno queda por debajo de la carretera
const TRACKSIDE_STEP := 36.0
const CANYON_DEPTH := 10.0  ## profundidad del cañón bajo los puentes

var circuit: Circuit
var theme: ThemeData
var preset: Dictionary = {}

# Estadísticas (pruebas y documentación)
var build_ms := 0
var terrain_chunks := 0
var terrain_triangles := 0
var prop_instances := 0
var prop_counts := {}        ## tipo -> instancias
var mean_y := 0.0

var _cell := 7.0
var _x0 := 0.0
var _z0 := 0.0
var _nx := 0
var _nz := 0
var _heights := PackedFloat32Array()
var _dist := PackedFloat32Array()
var _noise: FastNoiseLite
var _hash := {}              ## Vector2i -> PackedInt32Array (índices de muestras)
var _region := {}            ## Vector2i -> anillo (0 = junto a la carretera)
var _rng := RandomNumberGenerator.new()
var _min := Vector2.ZERO
var _max := Vector2.ZERO


func build(c: Circuit, t: ThemeData) -> void:
	var t0 := Time.get_ticks_msec()
	circuit = c
	theme = t
	preset = GraphicsSettings.preset()
	_rng.seed = hash(String(t.id))
	_noise = FastNoiseLite.new()
	_noise.seed = int(hash(String(t.id)) & 0x7fffffff)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0 / maxf(theme.feature_size, 10.0)
	_noise.fractal_octaves = 3
	for i in circuit.count:
		mean_y += circuit.points[i].y
	mean_y /= maxf(circuit.count, 1)
	_index_road()
	_build_terrain()
	_build_hazards()
	_build_mountains()
	_build_props()
	_build_trackside()
	_build_arch()
	build_ms = Time.get_ticks_msec() - t0


## Cielo, niebla y sol del tema (la niebla se ajusta a la distancia de dibujado de la calidad).
func apply_theme(world_env: WorldEnvironment, sun: DirectionalLight3D) -> void:
	var env := world_env.environment
	if env != null:
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = theme.sky_top
		sky_mat.sky_horizon_color = theme.sky_horizon
		sky_mat.ground_horizon_color = theme.fog_color
		sky_mat.ground_bottom_color = theme.fog_color
		sky_mat.sun_angle_max = 25.0
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = theme.ambient
		env.ambient_light_energy = 0.55
		env.fog_enabled = true
		env.fog_light_color = theme.fog_color
		env.fog_density = fog_density_for(theme, GraphicsSettings.preset())
		env.fog_sky_affect = 0.4
	if sun != null:
		sun.rotation_degrees = theme.sun_rotation
		sun.light_color = theme.sun_color
		sun.light_energy = theme.sun_energy


static func fog_density_for(t: ThemeData, p: Dictionary) -> float:
	var view := float(p.get("terrain_distance", 480.0))
	return maxf(t.fog_density, 2.3 / (0.85 * view))


## Altura del terreno en (x, z) (interpolación bilineal de la malla).
func height_at(x: float, z: float) -> float:
	var fx := clampf((x - _x0) / _cell, 0.0, _nx - 1.001)
	var fz := clampf((z - _z0) / _cell, 0.0, _nz - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var h00 := _heights[iz * _nx + ix]
	var h10 := _heights[iz * _nx + ix + 1]
	var h01 := _heights[(iz + 1) * _nx + ix]
	var h11 := _heights[(iz + 1) * _nx + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


## Distancia horizontal a la carretera (eje) hasta ~HASH m; si no hay muestras cerca devuelve 999.
func road_distance(x: float, z: float) -> float:
	var kx := floori(x / HASH)
	var kz := floori(z / HASH)
	var best := INF
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var list: PackedInt32Array = _hash.get(Vector2i(kx + dx, kz + dz), PackedInt32Array())
			for i in list:
				var p := circuit.points[i]
				var ex := p.x - x
				var ez := p.z - z
				var d := ex * ex + ez * ez
				if d < best:
					best = d
	return sqrt(best) if best < INF else 999.0


# --- Índices ---------------------------------------------------------------------------------

func _index_road() -> void:
	_min = Vector2(INF, INF)
	_max = Vector2(-INF, -INF)
	for i in circuit.count:
		var p := circuit.points[i]
		_min = Vector2(minf(_min.x, p.x), minf(_min.y, p.z))
		_max = Vector2(maxf(_max.x, p.x), maxf(_max.y, p.z))
		var k := Vector2i(floori(p.x / HASH), floori(p.z / HASH))
		if not _hash.has(k):
			_hash[k] = PackedInt32Array()
		var arr: PackedInt32Array = _hash[k]
		arr.append(i)
		_hash[k] = arr
	for k in _hash.keys():
		for dx in range(-REGION_RINGS, REGION_RINGS + 1):
			for dz in range(-REGION_RINGS, REGION_RINGS + 1):
				var kk := Vector2i(k.x + dx, k.y + dz)
				var ring := maxi(absi(dx), absi(dz))
				if not _region.has(kk) or _region[kk] > ring:
					_region[kk] = ring


# --- Terreno -----------------------------------------------------------------------------------

func _build_terrain() -> void:
	_cell = float(preset.get("terrain_cell", 7.0))
	var view := float(preset.get("terrain_distance", 480.0))
	var margin := clampf(view * 0.6, 150.0, 260.0)
	_x0 = floorf((_min.x - margin) / _cell) * _cell
	_z0 = floorf((_min.y - margin) / _cell) * _cell
	_nx = int(ceilf((_max.x + margin - _x0) / _cell)) + 1
	_nz = int(ceilf((_max.y + margin - _z0) / _cell)) + 1
	var total := _nx * _nz
	_dist = PackedFloat32Array()
	_dist.resize(total)
	_dist.fill(INF)
	var roady := PackedFloat32Array()
	roady.resize(total)
	var near := PackedInt32Array()
	near.resize(total)
	near.fill(-1)
	var hw := circuit.road_half_width
	var flat := hw + 6.0
	var reach := flat + 55.0
	var r_nodes := int(ceilf(reach / _cell))
	var stride := 2
	for i in range(0, circuit.count, stride):
		var p := circuit.points[i]
		var gx := int(roundf((p.x - _x0) / _cell))
		var gz := int(roundf((p.z - _z0) / _cell))
		for iz in range(maxi(gz - r_nodes, 0), mini(gz + r_nodes + 1, _nz)):
			var nz_pos := _z0 + iz * _cell
			for ix in range(maxi(gx - r_nodes, 0), mini(gx + r_nodes + 1, _nx)):
				var ex := _x0 + ix * _cell - p.x
				var ez := nz_pos - p.z
				var d2 := ex * ex + ez * ez
				if d2 < reach * reach:
					var d := sqrt(d2)
					var idx := iz * _nx + ix
					if d < _dist[idx]:
						_dist[idx] = d
						roady[idx] = p.y
						near[idx] = i
	_heights = PackedFloat32Array()
	_heights.resize(total)
	for iz in _nz:
		for ix in _nx:
			var idx := iz * _nx + ix
			var x := _x0 + ix * _cell
			var z := _z0 + iz * _cell
			var n01 := _noise.get_noise_2d(x, z) * 0.5 + 0.5
			var hill := pow(clampf(n01, 0.0, 1.0), 1.25) * theme.amplitude
			var d := _dist[idx]
			if d == INF:
				_heights[idx] = mean_y + hill
			else:
				var t := smoothstep(flat, reach, d)
				_heights[idx] = lerpf(roady[idx] - ROAD_DROP, mean_y + hill, t)
				var bw := _bridge_weight(near[idx])
				if bw > 0.0:   # cañón bajo el puente: más profundo junto a la carretera
					_heights[idx] -= CANYON_DEPTH * bw * (1.0 - smoothstep(hw + 4.0, hw + 26.0, d))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var cx_n := ceili((_nx - 1.0) / CHUNK_CELLS)
	var cz_n := ceili((_nz - 1.0) / CHUNK_CELLS)
	for cz in cz_n:
		for cx in cx_n:
			_terrain_chunk(cx, cz, mat, view)


## 0..1: cuánto cae el terreno bajo el puente en la muestra i (suave en las bocas del puente).
func _bridge_weight(i: int) -> float:
	var w := 0.0
	for b in circuit.bridges:
		var i0: int = b["i0"]
		var i1: int = b["i1"]
		if i >= i0 - 6 and i <= i1 + 6:
			w = maxf(w, smoothstep(i0 - 6.0, i0 + 3.0, float(i)) * (1.0 - smoothstep(i1 - 3.0, i1 + 6.0, float(i))))
	return w


## Agua / lava / vacío en el fondo de cada cañón de puente (un plano por puente).
func _build_hazards() -> void:
	for b in circuit.bridges:
		var hz: String = b["hazard"]
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		var y := 0.0
		var n := 0
		for i in range(int(b["i0"]), int(b["i1"]) + 1):
			var p := circuit.points[i]
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
			y += p.y
			n += 1
		if n == 0:
			continue
		y = y / n - ROAD_DROP - CANYON_DEPTH + 2.2
		var plane := PlaneMesh.new()
		plane.size = Vector2(hi.x - lo.x + 70.0, hi.y - lo.y + 70.0)
		var mat := StandardMaterial3D.new()
		match hz:
			"lava":
				mat.albedo_color = Color(1.0, 0.38, 0.06)
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			"void":
				mat.albedo_color = Color(0.03, 0.02, 0.12)
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_:
				mat.albedo_color = Color(0.18, 0.5, 0.85, 0.8)
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.roughness = 0.2
		var mi := MeshInstance3D.new()
		mi.name = "Hazard_" + hz
		mi.mesh = plane
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3((lo.x + hi.x) * 0.5, y, (lo.y + hi.y) * 0.5)
		add_child(mi)


func _terrain_chunk(cx: int, cz: int, mat: Material, view: float) -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var i0 := cx * CHUNK_CELLS
	var j0 := cz * CHUNK_CELLS
	var i1 := mini(i0 + CHUNK_CELLS, _nx - 1)
	var j1 := mini(j0 + CHUNK_CELLS, _nz - 1)
	for j in range(j0, j1):
		for i in range(i0, i1):
			var a := _node(i, j)
			var b := _node(i + 1, j)
			var c := _node(i + 1, j + 1)
			var d := _node(i, j + 1)
			# Diagonal alternada para que las colinas no tengan dirección marcada
			if (i + j) % 2 == 0:
				_terrain_tri(verts, norms, cols, a, b, c, i, j)
				_terrain_tri(verts, norms, cols, a, c, d, i, j + 7)
			else:
				_terrain_tri(verts, norms, cols, a, b, d, i, j)
				_terrain_tri(verts, norms, cols, b, c, d, i, j + 7)
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain_%d_%d" % [cx, cz]
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = view + _cell * CHUNK_CELLS * 0.75
	add_child(mi)
	terrain_chunks += 1
	terrain_triangles += verts.size() / 3


func _node(i: int, j: int) -> Vector3:
	return Vector3(_x0 + i * _cell, _heights[j * _nx + i], _z0 + j * _cell)


func _terrain_tri(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray,
		a: Vector3, b: Vector3, c: Vector3, i: int, j: int) -> void:
	var cr := (b - a).cross(c - a)
	if cr.y > 0.0:   # Godot: cara frontal = sentido horario
		var t := b
		b = c
		c = t
		cr = -cr
	var n := (-cr).normalized()
	var avg := (a.y + b.y + c.y) / 3.0
	var rel := avg - mean_y
	var col := theme.ground_low.lerp(theme.ground_high, clampf(rel / maxf(theme.amplitude, 1.0) * 1.5, 0.0, 1.0))
	if n.y < 0.82:
		col = col.lerp(theme.rock, clampf((0.82 - n.y) / 0.22, 0.0, 1.0))
	if theme.snow_line > 0.0 and rel > theme.snow_line:
		col = col.lerp(theme.accent, clampf((rel - theme.snow_line) / 5.0, 0.0, 1.0))
	var jitter := 0.93 + 0.14 * float(((i * 73856093) ^ (j * 19349663)) & 255) / 255.0
	col = Color(col.r * jitter, col.g * jitter, col.b * jitter)
	verts.append_array([a, b, c])
	norms.append_array([n, n, n])
	cols.append_array([col, col, col])


# --- Montañas -----------------------------------------------------------------------------------

func _build_mountains() -> void:
	var view := float(preset.get("terrain_distance", 480.0))
	var margin := clampf(view * 0.6, 150.0, 260.0)
	var center := Vector2((_min.x + _max.x) * 0.5, (_min.y + _max.y) * 0.5)
	var half := Vector2((_max.x - _min.x) * 0.5 + margin, (_max.y - _min.y) * 0.5 + margin)
	var ring := half.length() + 120.0
	var haze := theme.sky_horizon
	var b := MeshBuilder.new()
	var n := maxi(theme.mountain_count, 0)
	var scale_h := clampf(theme.amplitude / 22.0, 0.8, 1.6)
	for i in n:
		var ang := (i + _rng.randf_range(-0.3, 0.3)) * TAU / maxf(n, 1)
		var r := ring + _rng.randf_range(-40.0, 90.0)
		var w := _rng.randf_range(170.0, 330.0)
		var h := _rng.randf_range(80.0, 190.0) * scale_h
		var pos := Vector3(center.x + cos(ang) * r, mean_y - 30.0, center.y + sin(ang) * r)
		var body := theme.mountain.lerp(haze, 0.3)
		var cap := theme.mountain_cap.lerp(haze, 0.15)
		b.push(MeshBuilder.move(pos) * MeshBuilder.rot_y(_rng.randf_range(0.0, 90.0)))
		b.cone(Vector3(0, h * 0.5, 0), w, h, body, 7)
		b.cone(Vector3(0, h * 0.81, 0), w * 0.38 * 1.04, h * 0.38, cap, 7)
		b.pop()
	var mi := MeshInstance3D.new()
	mi.name = "Mountains"
	mi.mesh = b.build()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.disable_fog = true
	mat.roughness = 1.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --- Decorado ---------------------------------------------------------------------------------

func _build_props() -> void:
	var density_k := float(preset.get("prop_density", 1.0))
	var view := float(preset.get("prop_distance", 300.0))
	var chunk_m := _cell * CHUNK_CELLS
	var area_ha := chunk_m * chunk_m / 10000.0
	var hw := circuit.road_half_width
	var cx_n := ceili((_nx - 1.0) / CHUNK_CELLS)
	var cz_n := ceili((_nz - 1.0) / CHUNK_CELLS)
	for cz in cz_n:
		for cx in cx_n:
			var ox := _x0 + cx * chunk_m
			var oz := _z0 + cz * chunk_m
			for entry in theme.props:
				var kind: String = entry["kind"]
				var want := float(entry["density"]) * area_ha * density_k
				var count := int(want) + (1 if _rng.randf() < want - floorf(want) else 0)
				if count <= 0:
					continue
				var tint: Color = entry.get("tint", Color.WHITE)
				var smin := float(entry.get("min", 1.0))
				var smax := float(entry.get("max", 1.0))
				var xfs: Array[Transform3D] = []
				var cls: Array[Color] = []
				for _k in count:
					var x := ox + _rng.randf() * chunk_m
					var z := oz + _rng.randf() * chunk_m
					var key := Vector2i(floori(x / HASH), floori(z / HASH))
					if not _region.has(key):
						continue
					var ring: int = _region[key]
					if _rng.randf() > lerpf(1.0, 0.3, float(ring) / REGION_RINGS):
						continue
					if road_distance(x, z) < hw + 8.0:
						continue
					if x < _x0 or z < _z0 or x > _x0 + (_nx - 1) * _cell or z > _z0 + (_nz - 1) * _cell:
						continue
					var s := _rng.randf_range(smin, smax) * _rng.randf_range(0.85, 1.15)
					var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.9, 1.15), s))
					xfs.append(Transform3D(basis, Vector3(x, height_at(x, z) - 0.15, z)))
					var v := _rng.randf_range(0.88, 1.08)
					cls.append(Color(tint.r * v, tint.g * v, tint.b * v))
				_add_multimesh("Props_%s_%d_%d" % [kind, cx, cz], kind, xfs, cls, view + chunk_m * 0.75)


func _add_multimesh(node_name: String, kind: String, xfs: Array[Transform3D], cls: Array[Color], range_end: float) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = PropModels.mesh(kind)
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, cls[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	if range_end > 0.0:
		mmi.visibility_range_end = range_end
	add_child(mmi)
	prop_instances += xfs.size()
	prop_counts[kind] = int(prop_counts.get(kind, 0)) + xfs.size()


func _build_trackside() -> void:
	if theme.trackside.is_empty():
		return
	var per_kind := {}
	var hw := circuit.road_half_width
	var k := 0
	var s := 18.0
	while s < circuit.length - 10.0:
		var kind: String = theme.trackside[k % theme.trackside.size()]
		var side := -1.0 if k % 2 == 0 else 1.0
		var t := circuit.tangent_at(s)
		var flat := Vector3(t.x, 0.0, t.z).normalized()
		var pos := circuit.point_at(s) + circuit.right_at(s) * side * (hw + 2.6)
		pos.y = height_at(pos.x, pos.z)
		# El banderín apunta hacia la carretera
		var look := flat if side < 0.0 else -flat
		var xf := Transform3D(Basis.looking_at(look, Vector3.UP), pos)
		if not per_kind.has(kind):
			per_kind[kind] = [[], []]
		per_kind[kind][0].append(xf)
		per_kind[kind][1].append(theme.banner_color if kind == "banner" else Color.WHITE)
		k += 1
		s += TRACKSIDE_STEP
	for kind in per_kind:
		var xfs: Array[Transform3D] = []
		xfs.assign(per_kind[kind][0])
		var cls: Array[Color] = []
		cls.assign(per_kind[kind][1])
		_add_multimesh("Trackside_%s" % kind, kind, xfs, cls, float(preset.get("prop_distance", 300.0)) + 80.0)


func _build_arch() -> void:
	var hw := circuit.road_half_width
	var t := circuit.tangent_at(0.0)
	var flat := Vector3(t.x, 0.0, t.z).normalized()
	var b := MeshBuilder.new()
	var post := Color(0.85, 0.85, 0.9)
	var top := 6.8
	for side in [-1.0, 1.0]:
		var x: float = side * (hw + 1.8)
		b.cylinder(Vector3(x, top * 0.5 - 0.6, 0), 0.4, 0.5, top + 1.2, post, 8)
	b.box(Vector3(0, top + 0.2, 0), Vector3(hw * 2.0 + 4.4, 1.5, 0.7), Color(0.12, 0.12, 0.14))
	var cells := int(ceilf((hw * 2.0 + 4.4) / 1.1))
	var cw := (hw * 2.0 + 4.4) / cells
	for i in cells:
		for row in 2:
			var c := Color.WHITE if (i + row) % 2 == 0 else Color(0.08, 0.08, 0.08)
			var x := -hw - 2.2 + cw * (i + 0.5)
			b.box(Vector3(x, top + 0.2 + (row - 0.5) * 0.6, 0.0), Vector3(cw, 0.6, 0.76), c)
	var mi := b.build_instance()
	mi.name = "FinishArch"
	var ground := circuit.points[0]
	mi.transform = Transform3D(Basis.looking_at(flat, Vector3.UP), Vector3(ground.x, ground.y, ground.z))
	add_child(mi)
	var label := Label3D.new()
	label.text = "META"
	label.font_size = 96
	label.pixel_size = 0.02
	label.outline_size = 16
	label.modulate = Color(1.0, 0.95, 0.3)
	label.double_sided = true
	label.transform = Transform3D(Basis.looking_at(flat, Vector3.UP), ground + Vector3(0, top + 2.3, 0))
	add_child(label)
