class_name Kart
extends Node3D
## Kart arcade: una esfera RigidBody3D rueda y empuja; el modelo visual la sigue.
## Toda la lógica corre en _physics_process a 60 Hz (con interpolación visual).
## Lee SOLO KartControls (nunca hardware).

signal landed(air_time: float)
signal hit_landed(target: Kart)
signal got_hit(attacker: Kart)
signal hop_started
signal drift_started(direction: int)
signal drift_level_changed(level: int)
signal boost_started(source: StringName, duration: float)

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
const HOP_SPEED := 3.5     ## m/s hacia arriba al iniciar el derrape
const HOP_DURATION := 0.3   ## s mínimos antes de poder aterrizar y empezar a derrapar
const LANDING_MIN_AIR := 0.3
const LANDING_BOOST_TIME := 0.7
const BOOST_SPEED_MULT := 1.35
const BOOST_ACCEL_MULT := 3.0
const OVERSPEED_DECAY := 10.0
const STEER_SMOOTHING := 9.0

@export var stats: KartStats
@export var character: CharacterData
var controller: KartController

var heading := 0.0
var grounded := false
var air_time := 0.0
var drifting := false
var drift_dir := 0       ## +1 derecha, -1 izquierda
var drift_time := 0.0
var drift_level := 0
var boost_time := 0.0
var boost_mult := 1.0
var forward_speed := 0.0
var ground_normal := Vector3.UP

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
var hop_active := false  ## salto previo al derrape en curso
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
	_swing = MeshInstance3D.new()
	var swing_mesh := BoxMesh.new()
	swing_mesh.size = Vector3(1.2, 0.2, 0.3)
	_swing.mesh = swing_mesh
	_swing.visible = false
	body.add_child(_swing)
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


func _physics_process(delta: float) -> void:
	var c: KartControls = controller.get_controls() if controller else _idle_controls
	_update_ground(delta)
	var fwd := get_forward()
	forward_speed = sphere.linear_velocity.dot(fwd)
	_update_timers(delta)
	_update_drift(c, delta)
	_update_steering(c, delta)
	_apply_drive(c, delta)
	_update_hit(c)
	_update_model(delta)
	global_position = sphere.global_position


# --- API pública -----------------------------------------------------------

func get_forward() -> Vector3:
	return -model.global_basis.z


## Posición/dirección ya interpoladas (para cámaras y HUD, que corren en _process).
func get_visual_position() -> Vector3:
	return get_global_transform_interpolated().origin


func get_visual_forward() -> Vector3:
	return -model.get_global_transform_interpolated().basis.z


func get_speed_kmh() -> float:
	return sphere.linear_velocity.length() * 3.6


func is_boosting() -> bool:
	return boost_time > 0.0


func get_drift_color(level: int) -> Color:
	match level:
		1: return DRIFT_COLOR_1
		2: return DRIFT_COLOR_2
		3: return character.get_final_drift_color()
	return Color.WHITE


func start_boost(source: StringName, duration: float, mult := BOOST_SPEED_MULT) -> void:
	if boost_time <= 0.0:
		boost_mult = mult
	else:
		boost_mult = maxf(boost_mult, mult)
	boost_time = maxf(boost_time, duration)
	boost_started.emit(source, duration)


func set_body_color(c: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	chassis.material_override = m


func respawn(t: Transform3D) -> void:
	var f := -t.basis.z
	heading = atan2(-f.x, -f.z)
	var st := Transform3D(Basis.IDENTITY, t.origin)
	var rid := sphere.get_rid()
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, st)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	global_position = t.origin
	drifting = false
	hop_active = false
	_hop_t = 0.0
	drift_level = 0
	drift_time = 0.0
	boost_time = 0.0
	boost_mult = 1.0
	air_time = 0.0
	grounded = false
	_steer = 0.0
	_smooth_up = Vector3.UP
	forward_speed = 0.0
	reset_physics_interpolation()


# --- Internos --------------------------------------------------------------

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
	if boost_time > 0.0:
		boost_time -= delta
		if boost_time <= 0.0:
			boost_time = 0.0
			boost_mult = 1.0


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
	_steer = move_toward(_steer, c.steer, STEER_SMOOTHING * delta)
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
	var fwd := get_forward()
	var right := model.global_basis.x
	var vel := sphere.linear_velocity
	var fspeed := forward_speed
	var boosting := boost_time > 0.0
	var max_speed := stats.max_speed * (boost_mult if boosting else 1.0)
	var throttle := 1.0 if boosting else c.throttle
	var dv := 0.0

	if fspeed > max_speed:
		dv = -minf(OVERSPEED_DECAY * delta, fspeed - max_speed)
	elif throttle > 0.0:
		var accel := stats.acceleration * lerpf(1.0, 0.35, clampf(fspeed / max_speed, 0.0, 1.0))
		if boosting:
			accel *= BOOST_ACCEL_MULT
		dv = minf(accel * throttle * delta, max_speed - fspeed)
	elif c.brake > 0.0:
		if fspeed > 0.5:
			dv = -minf(stats.brake_decel * c.brake * delta, fspeed)
		elif fspeed > -stats.reverse_speed:
			dv = -stats.acceleration * 0.6 * c.brake * delta
	else:
		dv = -signf(fspeed) * minf(stats.coast_drag * delta, absf(fspeed))

	var grip := stats.drift_grip if drifting else stats.grip
	var dside := -vel.dot(right) * clampf(grip * delta, 0.0, 1.0)
	var impulse := (fwd * dv + right * dside) * sphere.mass

	# Sujeción en pendientes cuando está casi parado y sin acelerar.
	if c.throttle == 0.0 and c.brake == 0.0 and absf(fspeed) < 1.0 and not boosting:
		impulse += -vel * sphere.mass * clampf(8.0 * delta, 0.0, 1.0)

	sphere.apply_central_impulse(impulse)


## Golpe lateral (artillero, o jugador solo). Hito 4: solo cuando no hay ítem en mano.
func _update_hit(c: KartControls) -> void:
	var left := c.hit_left and not _hit_prev_l
	var right := c.hit_right and not _hit_prev_r
	_hit_prev_l = c.hit_left
	_hit_prev_r = c.hit_right
	if _hit_cd > 0.0 or not (left or right):
		return
	_do_hit(-1 if left else 1)


func _do_hit(side: int) -> void:
	_hit_cd = HIT_COOLDOWN
	_swing_t = 0.15
	_swing.position = Vector3(side * 1.1, 0.6, 0.0)
	var inv := model.global_transform.affine_inverse()
	for node in get_tree().get_nodes_in_group("karts"):
		var other := node as Kart
		if other == null or other == self:
			continue
		var local := inv * other.sphere.global_position
		if local.x * side > 0.4 and absf(local.x) < HIT_RANGE_X and absf(local.z) < HIT_RANGE_Z:
			other.receive_hit(model.global_basis.x * side, self)
			hit_landed.emit(other)


func receive_hit(dir: Vector3, attacker: Kart) -> void:
	var power := attacker.stats.hit_power
	sphere.apply_central_impulse(dir * HIT_IMPULSE * power * sphere.mass)
	got_hit.emit(attacker)


func _update_model(delta: float) -> void:
	var yaw := Basis(Vector3.UP, heading)
	var up := _smooth_up
	var r := (yaw.x - up * yaw.x.dot(up)).normalized()
	model.global_basis = Basis(r, up, r.cross(up))
	model.global_position = sphere.global_position - up * SPHERE_RADIUS

	_visual_drift = lerpf(_visual_drift, (drift_dir * 0.4) if drifting else 0.0,
			clampf(delta * 10.0, 0.0, 1.0))
	body.rotation.y = -_visual_drift

	var show_sparks := drifting and drift_level > 0 and grounded
	if show_sparks:
		_spark_mat.albedo_color = get_drift_color(drift_level)
	for s in sparks:
		s.visible = show_sparks
