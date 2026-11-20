class_name Trap
extends Node3D
## Trampa colocada en la pista (aceite, clavos, caja falsa, barrera, mina). Parámetros en ItemTrap.

var data: ItemTrap
var owner_kart: Kart
var net_id := -1
var _spin := false
var _visual: MeshInstance3D
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
	mi.mesh = ItemModels.trap_mesh(data.kind, data.color, data.trigger_radius)   # modelo low poly (vertex color)
	match data.kind:
		ItemTrap.Kind.FAKE_BOX:
			mi.position.y = 1.0
			_spin = true
		ItemTrap.Kind.BARRIER:
			var shape := BoxShape3D.new()
			shape.size = Vector3(3.0, 1.2, 0.6)
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position.y = 0.6
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			body.add_child(cs)
			add_child(body)
			if is_instance_valid(owner_kart):
				var fwd := -owner_kart.model.global_basis.z
				rotation.y = atan2(-fwd.x, -fwd.z)
	add_child(mi)
	_visual = mi


func _process(delta: float) -> void:
	if _spin and _visual != null:
		_visual.rotate_y(delta * 1.5)   # la caja falsa gira como una caja de ítems de verdad


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
		if k == null or k == owner_kart or _victim_cd.has(k.get_instance_id()):
			continue   # el dueño nunca activa sus propias trampas (los compañeros, solo con fuego amigo)
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
			if other and other != owner_kart \
					and other.sphere.global_position.distance_to(global_position) <= data.blast_radius:
				other.take_hit(_attacker(), data.hit_effect)
		return true
	var res := k.take_hit(_attacker(), data.hit_effect)
	if res == Kart.HitResult.IGNORED:
		return false  # fantasma/compañero: la atraviesa
	_victim_cd[k.get_instance_id()] = 1.0
	return data.consume_on_trigger


## El dueño puede haber salido de la carrera (p. ej. un jugador en línea que se desconecta): sin él, ataca "nadie".
func _attacker() -> Kart:
	return owner_kart if is_instance_valid(owner_kart) else null
