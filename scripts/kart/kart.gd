class_name Kart
extends Node3D
## Kart arcade: una esfera RigidBody3D rueda y empuja; el modelo visual la sigue.
## Toda la lógica corre en _physics_process a 60 Hz (con interpolación visual).
## Lee SOLO KartControls (nunca hardware). Efectos temporales: ver KartEffects (fx). Ítems: ItemData.

signal landed(air_time: float)
signal hit_landed(target: Kart)
signal got_hit(attacker: Kart)
signal guard_absorbed
signal hop_started
signal drift_started(direction: int)
signal drift_level_changed(level: int)
signal boost_started(source: StringName, duration: float)
signal item_changed
signal item_used(item: ItemData)
signal teleported

## Resultado de recibir un ataque.
enum HitResult {
	HIT,        ## el efecto se aplicó
	ABSORBED,   ## lo absorbió una guardia (orbitales / trampa llevada atrás)
	REFLECTED,  ## la burbuja reflectante lo devuelve (proyectiles)
	BLOCKED,    ## inmune (escudo, estrella, gigante)
	IGNORED,    ## fantasma o compañero de equipo: no le afecta ni se detiene
}

const SPHERE_RADIUS := 0.5
const DRIFT_LEVEL_TIMES: Array[float] = [0.9, 1.8, 2.8]  ## segundos para nivel 1/2/3
const DRIFT_BOOST_TIMES: Array[float] = [0.6, 1.0, 1.5]
const DRIFT_COLOR_1 := Color(0.2, 0.5, 1.0)   ## azul
const DRIFT_COLOR_2 := Color(1.0, 0.55, 0.1)  ## naranja
const DRIFT_MIN_SPEED := 8.0
const DRIFT_START_WINDOW := 0.25
const HIT_COOLDOWN := 0.6
const HIT_RANGE_X := 3.2    ## alcance lateral del golpe (m)
const HIT_RANGE_Z := 2.2    ## tolerancia delante/detrás (m)
const HIT_IMPULSE := 9.0    ## m/s de empuje lateral a un kart de peso 1
const HOP_SPEED := 3.5      ## m/s hacia arriba al iniciar el derrape
const HOP_DURATION := 0.3   ## s mínimos antes de poder aterrizar y empezar a derrapar
const LANDING_MIN_AIR := 0.3
const LANDING_BOOST_TIME := 0.7
const BOOST_SPEED_MULT := 1.35
const OVERSPEED_DECAY := 10.0
const STEER_SMOOTHING := 9.0
const ROLL_TIME := 1.0      ## s de "ruleta" al recoger un ítem
const TOUCH_HIT_RADIUS := 2.6
const SPIN_SPEED := 12.0    ## rad/s del giro visual

@export var stats: KartStats
@export var character: CharacterData
var controller: KartController

# Estado de conducción
var heading := 0.0
var grounded := false
var air_time := 0.0
var drifting := false
var drift_dir := 0       ## +1 derecha, -1 izquierda
var drift_time := 0.0
var drift_level := 0
var forward_speed := 0.0
var ground_normal := Vector3.UP
var hop_active := false  ## salto previo al derrape en curso

# Efectos, ítems y carrera
var fx := KartEffects.new()
var held_item: ItemData
var held_uses := 0
var race_progress := 0.0  ## lo actualiza la pista/carrera
var race_position := 1
var race_total := 1
var team := -1            ## -1 = sin equipo
var friendly_fire := false
var frozen := false       ## cuenta atrás: no responde a los controles
var is_bot := false
var racer_name := ""

var _steer := 0.0
var _smooth_up := Vector3.UP
var _drift_prev := false
var _drift_press_window := 0.0
var _landing_window := 0.0
var _visual_drift := 0.0
var _hit_cd := 0.0
var _swing_t := 0.0
var _swing: MeshInstance3D
var _hit_prev_l := false
var _hit_prev_r := false
var _hop_t := 0.0
var _hop_dir := 0
var _item_prev := false
var _roll_t := 0.0
var _roll_item: ItemData
var _spin_angle := 0.0
var _scale := 1.0
var _touch_cd := {}
var _fx_time := 0.0
var _bubble: MeshInstance3D
var _bubble_mat: StandardMaterial3D
var _orbs: Array[MeshInstance3D] = []
var _carry: MeshInstance3D
var _carry_mat: StandardMaterial3D
var _idle_controls := KartControls.new()
var _spark_mat: StandardMaterial3D

@onready var sphere: RigidBody3D = $Sphere
@onready var ground_ray: RayCast3D = $Sphere/GroundRay
@onready var model: Node3D = $Model
@onready var body: Node3D = $Model/Body
@onready var chassis: MeshInstance3D = $Model/Body/Chassis
@onready var sparks: Array[MeshInstance3D] = [$Model/Body/SparkL, $Model/Body/SparkR]


func _ready() -> void:
	if stats == null:
		stats = KartStats.new()
	if character == null:
		character = CharacterData.new()
	add_to_group("karts")
	_build_visual_extras()
	sphere.top_level = true
	sphere.global_position = global_position
	sphere.mass = stats.weight
	var f := -global_basis.z
	heading = atan2(-f.x, -f.z)
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for s in sparks:
		s.material_override = _spark_mat
		s.visible = false
	if controller == null:
		for c in get_children():
			if c is KartController:
				controller = c


func _build_visual_extras() -> void:
	_swing = MeshInstance3D.new()
	var swing_mesh := BoxMesh.new()
	swing_mesh.size = Vector3(1.2, 0.2, 0.3)
	_swing.mesh = swing_mesh
	_swing.visible = false
	body.add_child(_swing)

	_bubble = MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 1.6
	bm.height = 3.2
	bm.radial_segments = 12
	bm.rings = 6
	_bubble.mesh = bm
	_bubble_mat = StandardMaterial3D.new()
	_bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubble_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bubble.material_override = _bubble_mat
	_bubble.position.y = 0.6
	_bubble.visible = false
	body.add_child(_bubble)

	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.25
	orb_mesh.height = 0.5
	orb_mesh.radial_segments = 6
	orb_mesh.rings = 3
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color(0.4, 0.9, 1.0)
	orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 3:
		var o := MeshInstance3D.new()
		o.mesh = orb_mesh
		o.material_override = orb_mat
		o.visible = false
		body.add_child(o)
		_orbs.append(o)

	_carry = MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.6, 0.6, 0.6)
	_carry.mesh = cm
	_carry_mat = StandardMaterial3D.new()
	_carry_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_carry.material_override = _carry_mat
	_carry.position = Vector3(0, 0.6, 1.5)
	_carry.visible = false
	body.add_child(_carry)


func _physics_process(delta: float) -> void:
	fx.tick(delta)
	var c: KartControls = controller.get_controls() if controller else _idle_controls
	if fx.mods.lock_control or frozen:
		c = _idle_controls
		hop_active = false
		_end_drift(false)
	_apply_modifiers_to_body()
	_update_ground(delta)
	var fwd := get_forward()
	forward_speed = sphere.linear_velocity.dot(fwd)
	_update_timers(delta)
	_update_drift(c, delta)
	_update_steering(c, delta)
	_apply_drive(c, delta)
	_update_items(c, delta)
	_update_hit(c)
	_update_touch_hits(delta)
	_update_model(delta)
	_update_effect_visuals(delta)
	global_position = sphere.global_position


# --- API pública -----------------------------------------------------------

func get_forward() -> Vector3:
	return (-model.global_basis.z).normalized()


## Posición/dirección ya interpoladas (para cámaras y HUD, que corren en _process).
func get_visual_position() -> Vector3:
	return get_global_transform_interpolated().origin


func get_visual_forward() -> Vector3:
	return -model.get_global_transform_interpolated().basis.z


func get_speed_kmh() -> float:
	return sphere.linear_velocity.length() * 3.6


## Hay un efecto de aceleración automática activo (turbo de derrape/aterrizaje, turbo de ítem, cohete).
func is_boosting() -> bool:
	return fx.mods.force_throttle


func get_rivals() -> Array[Kart]:
	var out: Array[Kart] = []
	for node in get_tree().get_nodes_in_group("karts"):
		var k := node as Kart
		if k != null and k != self:
			out.append(k)
	return out


func get_drift_color(level: int) -> Color:
	match level:
		1: return DRIFT_COLOR_1
		2: return DRIFT_COLOR_2
		3: return character.get_final_drift_color()
	return Color.WHITE


func start_boost(source: StringName, duration: float, mult := BOOST_SPEED_MULT) -> void:
	fx.add(EffectLibrary.get_effect(&"boost"), duration, mult)
	boost_started.emit(source, duration)


func set_body_color(c: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	chassis.material_override = m


## ¿Puede hacer daño a "other"? (equipos: sin fuego amigo por defecto).
func can_hurt(other: Kart) -> bool:
	if other == self:
		return true
	return friendly_fire or team < 0 or other.team != team


## Punto único de entrada de TODOS los ataques (proyectiles, trampas, golpes, caos).
## Orden: compañero/fantasma -> reflejo -> inmunidad -> guardias -> trampa trasera -> efecto.
func take_hit(attacker: Kart, effect: KartEffect) -> HitResult:
	if attacker != null and not attacker.can_hurt(self):
		return HitResult.IGNORED
	if fx.mods.ghost:
		return HitResult.IGNORED
	if fx.mods.reflect:
		return HitResult.REFLECTED
	if fx.mods.immune:
		return HitResult.BLOCKED
	if fx.consume_guard():
		guard_absorbed.emit()
		return HitResult.ABSORBED
	if held_item != null and held_item.carried_guard:
		held_item = null
		held_uses = 0
		item_changed.emit()
		guard_absorbed.emit()
		return HitResult.ABSORBED
	if effect != null:
		fx.add(effect)
	got_hit.emit(attacker)
	return HitResult.HIT


## Golpe cuerpo a cuerpo (artillero / jugador solo): empuja y hace tropezar.
func receive_hit(dir: Vector3, attacker: Kart) -> void:
	var res := take_hit(attacker, EffectLibrary.get_effect(&"stumble"))
	if res == HitResult.HIT:
		sphere.apply_central_impulse(dir * HIT_IMPULSE * attacker.stats.hit_power * sphere.mass)


# --- Ítems -----------------------------------------------------------------

func can_pickup() -> bool:
	return held_item == null and _roll_t <= 0.0


func is_rolling() -> bool:
	return _roll_t > 0.0


## Empieza la ruleta. Sin argumento, el ítem sale según la posición en carrera.
func pickup_item(item: ItemData = null) -> void:
	_roll_item = item if item != null else ItemRoller.roll(race_position, race_total)
	if _roll_item == null:
		return
	_roll_t = ROLL_TIME
	item_changed.emit()


func use_held_item(backwards := false) -> void:
	if held_item == null or is_rolling():
		return
	var it := held_item
	held_uses -= 1
	if held_uses <= 0:
		held_item = null
		held_uses = 0
	it.use(self, backwards)
	item_used.emit(it)
	item_changed.emit()


## Teletransporta la esfera (intercambio de posición) conservando o fijando velocidad y rumbo.
func set_motion_state(pos: Vector3, vel: Vector3, new_heading: float) -> void:
	var rid := sphere.get_rid()
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, pos))
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, vel)
	heading = new_heading
	global_position = pos
	reset_physics_interpolation()
	teleported.emit()


func respawn(t: Transform3D) -> void:
	var f := -t.basis.z
	set_motion_state(t.origin, Vector3.ZERO, atan2(-f.x, -f.z))
	PhysicsServer3D.body_set_state(sphere.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	drifting = false
	hop_active = false
	_hop_t = 0.0
	drift_level = 0
	drift_time = 0.0
	fx.clear()
	air_time = 0.0
	grounded = false
	_steer = 0.0
	_smooth_up = Vector3.UP
	forward_speed = 0.0
	_spin_angle = 0.0


# --- Internos --------------------------------------------------------------

func _apply_modifiers_to_body() -> void:
	var m := stats.weight * fx.mods.mass_mult
	if not is_equal_approx(sphere.mass, m):
		sphere.mass = m
	var mask := 1 if fx.mods.ghost else 3  # fantasma: atraviesa karts
	if sphere.collision_mask != mask:
		sphere.collision_mask = mask


func _update_ground(delta: float) -> void:
	ground_ray.force_raycast_update()
	var was := grounded
	grounded = ground_ray.is_colliding() and ground_ray.get_collision_normal().y > 0.4
	if grounded:
		ground_normal = ground_ray.get_collision_normal()
		if not was and air_time >= LANDING_MIN_AIR:
			_on_landing(air_time)
		air_time = 0.0
	else:
		air_time += delta
	var target_up := ground_normal if grounded else Vector3.UP
	_smooth_up = _smooth_up.slerp(target_up, clampf(delta * 10.0, 0.0, 1.0)).normalized()


func _on_landing(t: float) -> void:
	landed.emit(t)
	start_boost(&"landing", LANDING_BOOST_TIME)
	_landing_window = DRIFT_START_WINDOW


func _update_timers(delta: float) -> void:
	_drift_press_window = maxf(_drift_press_window - delta, 0.0)
	_landing_window = maxf(_landing_window - delta, 0.0)
	_hop_t = maxf(_hop_t - delta, 0.0)
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	_swing_t = maxf(_swing_t - delta, 0.0)
	_swing.visible = _swing_t > 0.0
	for key in _touch_cd.keys():
		_touch_cd[key] -= delta
		if _touch_cd[key] <= 0.0:
			_touch_cd.erase(key)


func _update_drift(c: KartControls, delta: float) -> void:
	var pressed := c.drift and not _drift_prev
	_drift_prev = c.drift

	# El derrape NO empieza directo: pulsar derrape en el suelo hace un salto (hop) y el derrape
	# arranca al aterrizar si se mantiene el botón y hay dirección (stick o la fijada durante el salto).
	if pressed and not drifting and not hop_active:
		if grounded and forward_speed > DRIFT_MIN_SPEED:
			_start_hop(c)
		else:
			_drift_press_window = DRIFT_START_WINDOW  # en el aire: puede derrapar al aterrizar

	if hop_active:
		if absf(c.steer) > 0.2:
			_hop_dir = 1 if c.steer > 0.0 else -1
		if not c.drift:
			hop_active = false  # soltó el botón: solo fue un saltito
		elif _hop_t <= 0.0 and grounded:
			hop_active = false
			if _hop_dir != 0 and forward_speed > DRIFT_MIN_SPEED * 0.75:
				_begin_drift(_hop_dir)
		return

	if not drifting:
		var can_start := _drift_press_window > 0.0 or _landing_window > 0.0
		if c.drift and can_start and grounded and absf(c.steer) > 0.2 \
				and forward_speed > DRIFT_MIN_SPEED:
			_begin_drift(1 if c.steer > 0.0 else -1)
		return

	if not c.drift:
		_end_drift(true)
	elif sphere.linear_velocity.length() < 4.0:
		_end_drift(false)
	elif grounded:
		var into := (c.steer * drift_dir + 1.0) * 0.5  # 0 en contra .. 1 hacia dentro
		drift_time += delta * lerpf(0.7, 1.3, into) * stats.drift
		var lvl := 0
		for t in DRIFT_LEVEL_TIMES:
			if drift_time >= t:
				lvl += 1
		if lvl != drift_level:
			drift_level = lvl
			drift_level_changed.emit(lvl)


func _start_hop(c: KartControls) -> void:
	hop_active = true
	_hop_t = HOP_DURATION
	_hop_dir = 0
	if absf(c.steer) > 0.2:
		_hop_dir = 1 if c.steer > 0.0 else -1
	sphere.apply_central_impulse(Vector3.UP * HOP_SPEED * sphere.mass)
	hop_started.emit()


func _begin_drift(dir: int) -> void:
	drifting = true
	drift_dir = dir
	drift_time = 0.0
	drift_level = 0
	_drift_press_window = 0.0
	_landing_window = 0.0
	drift_started.emit(dir)


func _end_drift(award: bool) -> void:
	if not drifting:
		return
	if award and drift_level > 0:
		start_boost(&"drift", DRIFT_BOOST_TIMES[drift_level - 1])
	drifting = false
	drift_time = 0.0
	if drift_level != 0:
		drift_level = 0
		drift_level_changed.emit(0)


func _update_steering(c: KartControls, delta: float) -> void:
	_steer = move_toward(_steer, c.steer * fx.mods.steer_mult, STEER_SMOOTHING * delta)
	var speed_factor := clampf(absf(forward_speed) / 6.0, 0.0, 1.0)
	if not grounded:
		speed_factor *= 0.3
	var dir_sign := 1.0 if forward_speed >= 0.0 else -1.0
	var turn: float
	if drifting:
		var into := (_steer * drift_dir + 1.0) * 0.5
		turn = drift_dir * lerpf(0.5, 1.3, into) * stats.handling * 0.6
	else:
		var speed_ratio := clampf(absf(forward_speed) / stats.max_speed, 0.0, 1.0)
		turn = _steer * stats.handling * lerpf(1.0, 0.7, speed_ratio)
	heading -= turn * speed_factor * dir_sign * delta  # +steer = derecha = giro horario


func _apply_drive(c: KartControls, delta: float) -> void:
	if not grounded:
		return
	var m := fx.mods
	var fwd := get_forward()
	var right := model.global_basis.x.normalized()
	var vel := sphere.linear_velocity
	var fspeed := forward_speed
	var max_speed := stats.max_speed * m.speed_mult
	var throttle := 1.0 if m.force_throttle else c.throttle
	var dv := 0.0

	if fspeed > max_speed:
		dv = -minf(OVERSPEED_DECAY * delta, fspeed - max_speed)
	elif throttle > 0.0:
		var accel := stats.acceleration * m.accel_mult \
				* lerpf(1.0, 0.35, clampf(fspeed / max_speed, 0.0, 1.0))
		dv = minf(accel * throttle * delta, max_speed - fspeed)
	elif c.brake > 0.0:
		if fspeed > 0.5:
			dv = -minf(stats.brake_decel * c.brake * delta, fspeed)
		elif fspeed > -stats.reverse_speed:
			dv = -stats.acceleration * 0.6 * c.brake * delta
	else:
		dv = -signf(fspeed) * minf(stats.coast_drag * delta, absf(fspeed))

	var grip := (stats.drift_grip if drifting else stats.grip) * m.grip_mult
	var dside := -vel.dot(right) * clampf(grip * delta, 0.0, 1.0)
	var impulse := (fwd * dv + right * dside) * sphere.mass

	# Sujeción en pendientes cuando está casi parado y sin acelerar.
	if c.throttle == 0.0 and c.brake == 0.0 and absf(fspeed) < 1.0 and not m.force_throttle \
			and not m.lock_control:
		impulse += -vel * sphere.mass * clampf(8.0 * delta, 0.0, 1.0)

	sphere.apply_central_impulse(impulse)


## Ítem: pulsar usa el ítem en mano (con "atrás" lo lanza/coloca detrás).
func _update_items(c: KartControls, delta: float) -> void:
	if _roll_t > 0.0:
		_roll_t -= delta
		if _roll_t <= 0.0:
			_roll_t = 0.0
			held_item = _roll_item
			held_uses = held_item.uses if held_item else 0
			item_changed.emit()
	var pressed := c.item and not _item_prev
	_item_prev = c.item
	if pressed and held_item != null and _roll_t <= 0.0:
		use_held_item(c.item_back)


## Golpe lateral (artillero, o jugador solo). Solo cuando no hay ítem en mano.
func _update_hit(c: KartControls) -> void:
	var left := c.hit_left and not _hit_prev_l
	var right := c.hit_right and not _hit_prev_r
	_hit_prev_l = c.hit_left
	_hit_prev_r = c.hit_right
	if _hit_cd > 0.0 or not (left or right) or held_item != null or is_rolling():
		return
	_do_hit(-1 if left else 1)


func _do_hit(side: int) -> void:
	_hit_cd = HIT_COOLDOWN
	_swing_t = 0.15
	_swing.position = Vector3(side * 1.1, 0.6, 0.0)
	var inv := model.global_transform.affine_inverse()
	var right := model.global_basis.x.normalized()
	for other in get_rivals():
		var local := inv * other.sphere.global_position
		if local.x * side > 0.4 and absf(local.x) < HIT_RANGE_X and absf(local.z) < HIT_RANGE_Z:
			other.receive_hit(right * side, self)
			hit_landed.emit(other)


## Estrella / gigante: golpean a los karts que tocan.
func _update_touch_hits(_delta: float) -> void:
	if not fx.mods.touch_hit:
		return
	for other in get_rivals():
		if _touch_cd.has(other.get_instance_id()):
			continue
		var d := other.sphere.global_position - sphere.global_position
		d.y = 0.0
		if d.length() < TOUCH_HIT_RADIUS * fx.mods.scale_mult:
			_touch_cd[other.get_instance_id()] = 1.0
			var dir := d.normalized() if d.length() > 0.01 else Vector3.RIGHT
			var res := other.take_hit(self, EffectLibrary.get_effect(&"spin"))
			if res == HitResult.HIT:
				other.sphere.apply_central_impulse(dir * HIT_IMPULSE * sphere.mass)
				hit_landed.emit(other)


func _update_model(delta: float) -> void:
	var yaw := Basis(Vector3.UP, heading)
	var up := _smooth_up
	var r := (yaw.x - up * yaw.x.dot(up)).normalized()
	_scale = lerpf(_scale, fx.mods.scale_mult, clampf(delta * 6.0, 0.0, 1.0))
	model.global_basis = Basis(r, up, r.cross(up)).scaled(Vector3.ONE * _scale)
	model.global_position = sphere.global_position - up * SPHERE_RADIUS * _scale

	_visual_drift = lerpf(_visual_drift, (drift_dir * 0.4) if drifting else 0.0,
			clampf(delta * 10.0, 0.0, 1.0))
	if fx.mods.spin:
		_spin_angle += SPIN_SPEED * delta
	else:
		_spin_angle = 0.0
	body.rotation.y = -_visual_drift + _spin_angle

	var show_sparks := drifting and drift_level > 0 and grounded
	if show_sparks:
		_spark_mat.albedo_color = get_drift_color(drift_level)
	for s in sparks:
		s.visible = show_sparks


func _update_effect_visuals(delta: float) -> void:
	_fx_time += delta
	var bubble_on := false
	for i in fx.instances:
		if i.data.bubble_color.a > 0.0:
			_bubble_mat.albedo_color = i.data.bubble_color
			bubble_on = true
			break
	_bubble.visible = bubble_on
	var charges := fx.total_guard_charges()
	for idx in _orbs.size():
		var o := _orbs[idx]
		o.visible = idx < charges
		if o.visible:
			var a := _fx_time * 3.0 + idx * TAU / 3.0
			o.position = Vector3(cos(a) * 1.5, 0.7, sin(a) * 1.5)
	if held_item != null and held_item.carried_guard and not is_rolling():
		_carry.visible = true
		_carry_mat.albedo_color = held_item.icon_color
	else:
		_carry.visible = false
