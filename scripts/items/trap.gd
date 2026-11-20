class_name Trap
extends Node3D
## Trampa colocada en la pista (aceite, clavos, caja falsa, barrera, mina). Parámetros en ItemTrap.

var data: ItemTrap
var owner_kart: Kart
var net_id := -1
var _age := 0.0
var _victim_cd := {}   ## instance_id del kart -> s restantes (las persistentes no repiten cada tick)


func setup(d: ItemTrap, k: Kart, backwards: bool) -> void:
	data = d
	owner_kart = k
	net_id = k.net_id * 1000 + k.use_seq if k.net_id >= 0 else -1
	var fwd := k.get_forward()
	fwd.y = 0.0
	fwd = fwd.normalized()
	# La barrera es sólida: siempre se coloca detrás para no bloquear a su dueño.
	var behind := backwards or d.kind == ItemTrap.Kind.BARRIER
	position = k.sphere.global_position + (-fwd * 3.0 if behind else fwd * 6.0)


func _exit_tree() -> void:
	if net_id >= 0:
		NetSession.unregister_object(net_id, self)


func _ready() -> void:
	add_to_group("traps")
	if net_id >= 0:
		NetSession.register_object(net_id, self)
	# Apoya la trampa en el suelo
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
			position + Vector3.UP * 3.0, position + Vector3.DOWN * 8.0, 1))
	if hit:
		position.y = hit.position.y
	_build()


func _build() -> void:
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data.color
	match data.kind:
		ItemTrap.Kind.OIL:
			var m := CylinderMesh.new()
			m.top_radius = data.trigger_radius
			m.bottom_radius = data.trigger_radius
			m.height = 0.05
			m.radial_segments = 12
			mi.mesh = m
			mi.position.y = 0.03
		ItemTrap.Kind.NAILS:
			var m := BoxMesh.new()
			m.size = Vector3(data.trigger_radius * 1.4, 0.15, 0.6)
			mi.mesh = m
			mi.position.y = 0.08
		ItemTrap.Kind.FAKE_BOX:
			var m := BoxMesh.new()
			m.size = Vector3.ONE * 1.2
			mi.mesh = m
			mi.position.y = 1.0
		ItemTrap.Kind.BARRIER:
			var m := BoxMesh.new()
			m.size = Vector3(3.0, 1.2, 0.6)
			mi.mesh = m
			mi.position.y = 0.6
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = m.size
			cs.shape = shape
			cs.position.y = 0.6
			body.add_child(cs)
			add_child(body)
			var fwd := -owner_kart.model.global_basis.z
			rotation.y = atan2(-fwd.x, -fwd.z)
		ItemTrap.Kind.MINE:
			var m := SphereMesh.new()
			m.radius = 0.5
			m.height = 0.7
			m.radial_segments = 8
			m.rings = 4
			mi.mesh = m
			mi.position.y = 0.3
			mat.emission_enabled = true
			mat.emission = Color(0.8, 0.1, 0.1)
	mi.material_override = mat
	add_child(mi)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= data.lifetime:
		queue_free()
		return
	for key in _victim_cd.keys():
		_victim_cd[key] -= delta
		if _victim_cd[key] <= 0.0:
			_victim_cd.erase(key)
	if data.kind == ItemTrap.Kind.BARRIER:
		return  # es un obstáculo sólido; no tiene disparador
	for node in get_tree().get_nodes_in_group("karts"):
		var k := node as Kart
		if k == null or _victim_cd.has(k.get_instance_id()):
			continue
		if k == owner_kart and _age < data.arm_time:
			continue
		var d := k.sphere.global_position - global_position
		var dy := absf(d.y)
		d.y = 0.0
		if d.length() < data.trigger_radius * k.fx.mods.scale_mult and dy < 1.5:
			if _trigger(k):
				NetSession.announce_dead(net_id)
				queue_free()
				return


## true = la trampa se consume.
func _trigger(k: Kart) -> bool:
	if data.blast_radius > 0.0:
		for node in get_tree().get_nodes_in_group("karts"):
			var other := node as Kart
			if other and other.sphere.global_position.distance_to(global_position) <= data.blast_radius:
				other.take_hit(owner_kart, data.hit_effect)
		return true
	var res := k.take_hit(owner_kart, data.hit_effect)
	if res == Kart.HitResult.IGNORED:
		return false  # fantasma/compañero: la atraviesa
	_victim_cd[k.get_instance_id()] = 1.0
	return data.consume_on_trigger
