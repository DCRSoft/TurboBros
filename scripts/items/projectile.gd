class_name Projectile
extends Node3D
## Proyectil en vuelo (recto, rebotador, teledirigido, bomba) u ola de choque instantánea.
## Movimiento propio (sin RigidBody): 1-2 raycasts por tick y comprobación de distancia a los karts,
## barato para el i3 de 2 núcleos.

const ARM_TIME := 0.3       ## s antes de poder golpear al dueño
const HIT_RADIUS := 1.5
const FLY_HEIGHT := 0.6
const BOMB_GRAVITY := 26.0
const RING_TIME := 0.4

var data: ItemProjectile
var owner_kart: Kart
var velocity := Vector3.ZERO
var _age := 0.0
var _bounces_left := 0
var _target: Kart
var _spent := false      ## ya explotó / ya terminó; solo queda el anillo visual
var _ring_t := 0.0
var _mesh: MeshInstance3D
var _backwards := false


func setup(d: ItemProjectile, k: Kart, backwards: bool) -> void:
	data = d
	owner_kart = k
	_backwards = backwards
	_bounces_left = d.bounces
	var fwd := k.get_forward()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var dir := -fwd if backwards else fwd
	position = k.sphere.global_position + dir * 2.2 + Vector3.UP * 0.1
	var spd := d.speed * (0.7 if backwards else 1.0)
	velocity = dir * spd
	if d.kind == ItemProjectile.Kind.BOMB:
		velocity = dir * spd * 0.5 + Vector3.UP * 9.0
	if d.kind == ItemProjectile.Kind.SHOCKWAVE:
		position = k.sphere.global_position


func launch() -> void:
	_build_mesh()
	if data.kind == ItemProjectile.Kind.SHOCKWAVE:
		_blast(owner_kart.sphere.global_position, data.blast_radius, true)
		_start_ring(data.blast_radius)
		return
	if data.kind == ItemProjectile.Kind.HOMING:
		_target = _pick_target()


func _build_mesh() -> void:
	_mesh = MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.45 if data.kind != ItemProjectile.Kind.BOMB else 0.6
	m.height = m.radius * 2.0
	m.radial_segments = 8
	m.rings = 4
	_mesh.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data.color
	mat.emission_enabled = true
	mat.emission = data.color
	_mesh.material_override = mat
	add_child(_mesh)
	_mesh.visible = data.kind != ItemProjectile.Kind.SHOCKWAVE


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_age += delta
	if _age >= data.lifetime:
		if data.kind == ItemProjectile.Kind.BOMB:
			_explode()
		else:
			queue_free()
		return

	if data.kind == ItemProjectile.Kind.HOMING:
		_steer_homing(delta)
	if data.kind == ItemProjectile.Kind.BOMB:
		velocity.y -= BOMB_GRAVITY * delta

	var from := global_position
	var to := from + velocity * delta
	var space := get_world_3d().direct_space_state

	# Pared (solo normales casi horizontales; las rampas no cuentan)
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(from.x, maxf(from.y, 0.4), from.z), Vector3(to.x, maxf(from.y, 0.4), to.z), 1))
	if wall and wall.normal.y < 0.5:
		if data.kind == ItemProjectile.Kind.BOUNCER and _bounces_left > 0:
			_bounces_left -= 1
			velocity = velocity.bounce(wall.normal)
			velocity.y = 0.0
			to = from + velocity * delta
		elif data.kind == ItemProjectile.Kind.BOMB:
			velocity = velocity.bounce(wall.normal) * 0.4
			to = from
		else:
			queue_free()
			return

	global_position = to

	# Suelo
	var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 2.0, global_position + Vector3.DOWN * 6.0, 1))
	if data.kind == ItemProjectile.Kind.BOMB:
		if velocity.y < 0.0 and ground and global_position.y <= ground.position.y + 0.4:
			_explode()
			return
	elif ground:
		global_position.y = lerpf(global_position.y, ground.position.y + FLY_HEIGHT, 0.5)

	_check_karts()


func _check_karts() -> void:
	for node in get_tree().get_nodes_in_group("karts"):
		var k := node as Kart
		if k == null or _spent:
			continue
		if k == owner_kart and _age < ARM_TIME:
			continue
		var d := k.sphere.global_position - global_position
		var dy := absf(d.y)
		d.y = 0.0
		if d.length() < HIT_RADIUS * k.fx.mods.scale_mult and dy < 1.8:
			_on_contact(k)


func _on_contact(k: Kart) -> void:
	if data.kind == ItemProjectile.Kind.BOMB:
		_explode()
		return
	var res := k.take_hit(owner_kart, data.hit_effect)
	match res:
		Kart.HitResult.REFLECTED:
			owner_kart = k
			velocity = -velocity
			_age = 0.0
			_target = null
		Kart.HitResult.IGNORED:
			pass  # fantasma o compañero: lo atraviesa
		_:
			queue_free()


func _explode() -> void:
	if _spent:
		return
	_blast(global_position, data.blast_radius, false)
	_start_ring(data.blast_radius)


## Golpea a todos los karts dentro del radio. include_owner=false para la ola de choque (no se golpea a sí mismo).
func _blast(center: Vector3, radius: float, is_shockwave: bool) -> void:
	for node in get_tree().get_nodes_in_group("karts"):
		var k := node as Kart
		if k == null:
			continue
		if is_shockwave and k == owner_kart:
			continue
		var d := k.sphere.global_position - center
		if d.length() > radius:
			continue
		if is_shockwave and not k.grounded:
			continue  # un kart en el aire se libra de la ola
		k.take_hit(owner_kart, data.hit_effect)


func _start_ring(radius: float) -> void:
	_spent = true
	_ring_t = RING_TIME
	_mesh.visible = true
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 12
	m.rings = 6
	_mesh.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(data.color, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	set_meta("ring_radius", radius)


func _process(delta: float) -> void:
	if not _spent:
		return
	_ring_t -= delta
	var radius: float = get_meta("ring_radius", 5.0)
	var t := 1.0 - clampf(_ring_t / RING_TIME, 0.0, 1.0)
	_mesh.scale = Vector3.ONE * maxf(radius * t, 0.1)
	if _ring_t <= 0.0:
		queue_free()


func _pick_target() -> Kart:
	var best: Kart = null
	var best_d := 80.0
	for node in get_tree().get_nodes_in_group("karts"):
		var k := node as Kart
		if k == null or k == owner_kart:
			continue
		if k.race_position == owner_kart.race_position - 1:
			return k  # el kart justo por delante en la clasificación
		var d := k.sphere.global_position.distance_to(global_position)
		var ahead := velocity.normalized().dot((k.sphere.global_position - global_position).normalized()) > 0.3
		if ahead and d < best_d:
			best_d = d
			best = k
	return best


func _steer_homing(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var want := _target.sphere.global_position - global_position
	want.y = 0.0
	if want.length() < 0.1:
		return
	want = want.normalized()
	var cur := velocity
	cur.y = 0.0
	var spd := cur.length()
	if spd < 0.1:
		return
	cur = cur / spd
	var ang := cur.angle_to(want)
	if ang > 0.001:
		var step := minf(ang, data.turn_rate * delta)
		var axis := cur.cross(want)
		if axis.length() < 0.0001:
			axis = Vector3.UP
		cur = cur.rotated(axis.normalized(), step)
	velocity = cur * spd
