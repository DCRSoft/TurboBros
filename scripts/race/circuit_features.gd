class_name CircuitFeatures
extends RefCounted
## Elementos del trazado (TrackData.features) sobre la carretera: zonas de turbo (decal), rampas (colisión), túneles
## (techo y portales, solo visual) y puentes (tablero, pilares y suelo de color propio). Todo se genera por código.

const TUNNEL_H := 7.0
const RAMP_H := 1.15
const PAD_RADIUS := 4.2


static func deck_color(hazard: String, i: int) -> Color:
	var a := i % 2 == 0
	match hazard:
		"lava": return Color(0.26, 0.22, 0.22) if a else Color(0.32, 0.27, 0.27)
		"void": return Color(0.3, 0.62, 0.82) if a else Color(0.26, 0.55, 0.76)
		_: return Color(0.5, 0.35, 0.2) if a else Color(0.43, 0.29, 0.17)


## Rellena en el circuito las listas de elementos (pads, ramps, bridges, tunnels) a partir de los datos de la pista.
static func collect(c: Circuit) -> void:
	c.pads.clear()
	c.ramps.clear()
	c.bridges.clear()
	c.tunnels.clear()
	for f in c.track.features:
		var i0 := clampi(int(float(f["f"]) * c.count), 0, c.count - 1)
		var span := int(float(f.get("len", 0.0)) / c.step)
		match String(f["type"]):
			"turbo":
				var off: float = float(f.get("lat", 0.0)) * c.road_half_width * 0.5
				c.pads.append({"pos": c.points[i0] + c.rights[i0] * off, "radius": PAD_RADIUS, "i": i0})
			"ramp":
				c.ramps.append({"i": i0, "len": float(f.get("len", 9.0)), "lat": float(f.get("lat", 0.0))})
			"bridge":
				c.bridges.append({"i0": i0, "i1": mini(i0 + span, c.count - 1), "hazard": String(f.get("hazard", ""))})
			"tunnel":
				c.tunnels.append({"i0": i0, "i1": mini(i0 + span, c.count - 1)})


static func build(c: Circuit) -> void:
	_build_pads(c)
	_build_ramps(c)
	_build_tunnels(c)
	_build_bridges(c)


# --- Zonas de turbo ---------------------------------------------------------------------------------

static func _mesh_node(name: String, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray,
		unshaded := false) -> MeshInstance3D:
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
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _build_pads(c: Circuit) -> void:
	if c.pads.is_empty():
		return
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var up := Vector3.UP
	var hot := Color(1.0, 0.75, 0.1)
	var cool := Color(0.25, 0.9, 1.0)
	for p in c.pads:
		var i: int = p["i"]
		var t: Vector3 = Vector3(c.tangents[i].x, 0.0, c.tangents[i].z).normalized()
		var r: Vector3 = c.rights[i]
		var base: Vector3 = p["pos"] + up * 0.08
		# Tres flechas ">" seguidas y una placa base oscura
		_tri_up(c, verts, norms, cols, base - t * 5.0 - r * 3.4, base - t * 5.0 + r * 3.4, base + t * 5.0 + r * 3.4, base + t * 5.0 - r * 3.4, Color(0.05, 0.06, 0.1))
		for k in 3:
			var o := base + t * (k * 3.2 - 3.2) + up * 0.03
			var col := cool if k % 2 == 0 else hot
			c._tri(verts, norms, cols, o + t * 1.9, o - t * 1.3 - r * 2.7, o - t * 1.3 + r * 2.7, up, col)
			c._tri(verts, norms, cols, o + t * 0.5 + up * 0.01, o - t * 1.31 - r * 1.5, o - t * 1.31 + r * 1.5, up, Color(0.05, 0.06, 0.1))
	c.add_child(_mesh_node("TurboPads", verts, norms, cols, true))


## Cuadrilátero horizontal (cara hacia arriba) sin colisión.
static func _tri_up(c: Circuit, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray,
		a: Vector3, b: Vector3, d: Vector3, e: Vector3, col: Color) -> void:
	c._quad(verts, norms, cols, a, b, d, e, Vector3.UP, col)


# --- Rampas -----------------------------------------------------------------------------------------

static func _build_ramps(c: Circuit) -> void:
	if c.ramps.is_empty():
		return
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var faces := PackedVector3Array()
	var up := Vector3.UP
	var yellow := Color(0.95, 0.78, 0.1)
	var black := Color(0.14, 0.14, 0.16)
	for rp in c.ramps:
		var s0: float = int(rp["i"]) * c.step
		var len: float = rp["len"]
		var centre: float = float(rp["lat"]) * c.road_half_width * 0.5
		var w := c.road_half_width * 0.45
		var bands := 4
		for k in bands:
			var sa := s0 + len * k / bands
			var sb := s0 + len * (k + 1) / bands
			var ha := RAMP_H * k / bands
			var hb := RAMP_H * (k + 1) / bands
			var la := c.point_at(sa) + c.right_at(sa) * (centre - w) + up * (ha + 0.04)
			var ra := c.point_at(sa) + c.right_at(sa) * (centre + w) + up * (ha + 0.04)
			var lb := c.point_at(sb) + c.right_at(sb) * (centre - w) + up * (hb + 0.04)
			var rb := c.point_at(sb) + c.right_at(sb) * (centre + w) + up * (hb + 0.04)
			c._quad(verts, norms, cols, la, ra, rb, lb, up, yellow if k % 2 == 0 else black, faces, true)
		# Caras laterales y trasera (para que no se cuele por los lados)
		var sl := s0 + len
		for side in [-1.0, 1.0]:
			var o: float = centre + side * w
			var b0: Vector3 = c.point_at(s0) + c.right_at(s0) * o + up * 0.04
			var b1: Vector3 = c.point_at(sl) + c.right_at(sl) * o + up * 0.04
			var t1: Vector3 = b1 + up * RAMP_H
			c._tri(verts, norms, cols, b0, b1, t1, c.right_at(s0) * side, Color(0.3, 0.3, 0.34), faces, true)
		var e0: Vector3 = c.point_at(sl) + c.right_at(sl) * (centre - w) + up * 0.04
		var e1: Vector3 = c.point_at(sl) + c.right_at(sl) * (centre + w) + up * 0.04
		c._quad(verts, norms, cols, e0, e1, e1 + up * RAMP_H, e0 + up * RAMP_H, c.tangent_at(sl), Color(0.3, 0.3, 0.34), faces, true)
	c.add_child(_mesh_node("Ramps", verts, norms, cols))
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	var body := StaticBody3D.new()
	body.name = "RampBody"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_child(cs)
	c.add_child(body)


# --- Túneles ----------------------------------------------------------------------------------------

static func _build_tunnels(c: Circuit) -> void:
	if c.tunnels.is_empty():
		return
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var hw := c.road_half_width
	var up := Vector3.UP
	var wall_col := c.theme.wall.darkened(0.45)
	var roof_col := Color(0.1, 0.1, 0.13)
	var b := MeshBuilder.new()
	for tn in c.tunnels:
		var i0: int = tn["i0"]
		var i1: int = tn["i1"]
		for i in range(i0, i1):
			var j := i + 1
			var li: Vector3 = c.points[i] - c.rights[i] * (hw + 0.3)
			var ri: Vector3 = c.points[i] + c.rights[i] * (hw + 0.3)
			var lj: Vector3 = c.points[j] - c.rights[j] * (hw + 0.3)
			var rj: Vector3 = c.points[j] + c.rights[j] * (hw + 0.3)
			var h := up * TUNNEL_H
			c._quad(verts, norms, cols, li + h, ri + h, rj + h, lj + h, Vector3.DOWN, roof_col)
			c._quad(verts, norms, cols, li + up * c.wall_height, li + h, lj + h, lj + up * c.wall_height, c.rights[i], wall_col)
			c._quad(verts, norms, cols, ri + up * c.wall_height, ri + h, rj + h, rj + up * c.wall_height, -c.rights[i], wall_col)
		# Portales en las dos bocas: dos pilares y un dintel
		for idx in [i0, i1]:
			var t: Vector3 = Vector3(c.tangents[idx].x, 0.0, c.tangents[idx].z).normalized()
			var xf := Transform3D(Basis.looking_at(t, Vector3.UP), c.points[idx])
			b.push(xf)
			b.box(Vector3(-(hw + 1.1), TUNNEL_H * 0.5, 0), Vector3(1.6, TUNNEL_H, 1.4), c.theme.curb_a)
			b.box(Vector3(hw + 1.1, TUNNEL_H * 0.5, 0), Vector3(1.6, TUNNEL_H, 1.4), c.theme.curb_a)
			b.box(Vector3(0, TUNNEL_H + 0.5, 0), Vector3(hw * 2.0 + 4.0, 1.4, 1.4), c.theme.curb_a)
			b.pop()
	c.add_child(_mesh_node("Tunnels", verts, norms, cols))
	var portals := b.build_instance()
	portals.name = "TunnelPortals"
	c.add_child(portals)


# --- Puentes ----------------------------------------------------------------------------------------

static func _build_bridges(c: Circuit) -> void:
	if c.bridges.is_empty():
		return
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var hw := c.road_half_width
	var up := Vector3.UP
	var pier := MeshBuilder.new()
	for br in c.bridges:
		var i0: int = br["i0"]
		var i1: int = br["i1"]
		var hz: String = br["hazard"]
		var steel := Color(0.35, 0.36, 0.4) if hz != "water" else Color(0.38, 0.27, 0.17)
		for i in range(i0, i1):
			var j := i + 1
			var li: Vector3 = c.points[i] - c.rights[i] * (hw + 0.3)
			var ri: Vector3 = c.points[i] + c.rights[i] * (hw + 0.3)
			var lj: Vector3 = c.points[j] - c.rights[j] * (hw + 0.3)
			var rj: Vector3 = c.points[j] + c.rights[j] * (hw + 0.3)
			var d := up * 1.3
			c._quad(verts, norms, cols, li - d, ri - d, rj - d, lj - d, Vector3.DOWN, steel.darkened(0.3))
			c._quad(verts, norms, cols, li - d, li, lj, lj - d, -c.rights[i], steel)
			c._quad(verts, norms, cols, ri - d, ri, rj, rj - d, c.rights[i], steel)
			if (i - i0) % 4 == 0:
				for side in [-1.0, 1.0]:
					var pos: Vector3 = c.points[i] + c.rights[i] * side * hw * 0.62
					pier.box(pos - up * (1.3 + 7.0), Vector3(1.5, 14.0, 1.5), steel.darkened(0.15))
	c.add_child(_mesh_node("BridgeDecks", verts, norms, cols))
	var piers := pier.build_instance()
	piers.name = "BridgePiers"
	c.add_child(piers)
