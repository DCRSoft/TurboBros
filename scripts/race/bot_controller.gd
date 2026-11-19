class_name BotController
extends KartController
## Piloto automático: sigue la curva del circuito con un punto de mira, frena en curvas cerradas,
## usa ítems con reglas sencillas y se desatasca solo.
## CPU ligera: "piensa" a 20 Hz (cada 3.er tick) y escalona a los bots entre sí; el resto del tiempo
## devuelve los últimos controles calculados.

const THINK_EVERY := 3
const HELD_MAX := 10.0   ## s máx. que aguanta un ítem antes de usarlo sí o sí

var kart: Kart
var circuit: Circuit
var manager: RaceManager
var skill := 0.95        ## 0.85 .. 1.0: fracción de la velocidad máxima que se atreve a usar
var lane := 0.0          ## desplazamiento lateral deseado (m)

var _idx := 0
var _idx_init := false
var _frame := 0
var _offset := 0
var _item_t := -1.0
var _held_for := 0.0
var _stuck_t := 0.0
var _stuck_count := 0
var _reverse_t := 0.0
var _lane_t := 0.0
var _ok_t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(k: Kart, c: Circuit, m: RaceManager, bot_index: int) -> void:
	kart = k
	circuit = c
	manager = m
	_offset = bot_index % THINK_EVERY
	_rng.seed = 7919 * (bot_index + 1) + 13
	skill = _rng.randf_range(0.88, 1.0)
	lane = _rng.randf_range(-0.4, 0.4) * c.road_half_width


func get_controls() -> KartControls:
	_frame += 1
	if kart != null and circuit != null and (_frame + _offset) % THINK_EVERY == 0:
		_think(THINK_EVERY / 60.0)
	return _controls


func _think(dt: float) -> void:
	var pos := kart.sphere.global_position
	if not _idx_init or Vector2(pos.x - circuit.points[_idx].x, pos.z - circuit.points[_idx].z).length() > 25.0:
		_idx = circuit.nearest_global(pos)
		_idx_init = true
	else:
		_idx = circuit.nearest_index(pos, _idx, 8, 30)
	var vel := kart.sphere.linear_velocity
	var speed := vel.length()
	_controls.item = false

	# Carril: pequeño paseo aleatorio para no ir todos en fila
	_lane_t -= dt
	if _lane_t <= 0.0:
		_lane_t = _rng.randf_range(2.5, 5.0)
		var lim := circuit.road_half_width * 0.45
		lane = clampf(lane + _rng.randf_range(-3.0, 3.0), -lim, lim)

	# Esquivar trampas (barreras sólidas, aceite, clavos, minas) que haya delante
	var dodge := _dodge_lane(pos)
	if not is_nan(dodge):
		lane = lerpf(lane, dodge, 0.8)
		_lane_t = 1.0

	# Dirección hacia el punto de mira
	var look := int(clampf(10.0 + speed * 0.7, 12.0, 34.0) / circuit.step)
	var ti := circuit.wrap_index(_idx + look)
	var target := circuit.points[ti] + circuit.rights[ti] * lane
	var fwd := kart.get_forward()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var to := target - pos
	to.y = 0.0
	var ang := fwd.signed_angle_to(to.normalized(), Vector3.UP)  # + = izquierda
	var steer := clampf(-ang * 2.0, -1.0, 1.0)

	# Velocidad deseada según la curvatura próxima
	var sharp := 0.0
	for j in range(1, 19):
		sharp += absf(circuit.turn[circuit.wrap_index(_idx + j)])
	var v_des := kart.stats.max_speed * skill * lerpf(1.0, 0.7, clampf(sharp / 2.2, 0.0, 1.0))
	if kart.fx.mods.force_throttle:
		v_des = INF
	_controls.drift = false
	_controls.hit_left = false
	_controls.hit_right = false
	_controls.throttle = 0.0
	_controls.brake = 0.0
	if speed > v_des + 3.0:
		_controls.brake = 0.5
	elif speed < v_des:
		_controls.throttle = 1.0

	_unstick(dt, speed, steer)
	if _reverse_t > 0.0:
		_reverse_t -= dt
		_controls.throttle = 0.0
		_controls.brake = 1.0
		steer = -steer
	_controls.steer = steer
	_think_items(dt)


## Carril al que desviarse para esquivar la trampa más cercana por delante (NAN = nada que esquivar).
func _dodge_lane(pos: Vector3) -> float:
	var fwd := kart.get_forward()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := circuit.rights[_idx]
	var lat_bot := (pos - circuit.points[_idx]).dot(right)
	var best := NAN
	var best_along := 30.0
	for node in get_tree().get_nodes_in_group("traps"):
		var t := node as Trap
		if t == null:
			continue
		var d := t.global_position - pos
		d.y = 0.0
		var along := d.dot(fwd)
		if along < 2.0 or along > best_along:
			continue
		var lat_trap := lat_bot + d.dot(right)
		var width := maxf(t.data.trigger_radius, 2.0) + 2.5
		if absf(lat_trap - lane) < width:
			best_along = along
			var limit := circuit.road_half_width - 2.0
			var side := lat_trap - width if lat_trap > 0.0 else lat_trap + width
			best = clampf(side, -limit, limit)
	return best


func _unstick(dt: float, speed: float, _steer: float) -> void:
	var racing := manager == null or manager.state == RaceManager.State.RACING
	if racing and speed < 1.5 and _reverse_t <= 0.0 and not kart.fx.mods.lock_control and not kart.frozen:
		_stuck_t += dt
	else:
		_stuck_t = 0.0
	if speed > 8.0:
		_ok_t += dt
		if _ok_t > 3.0:
			_stuck_count = 0
	else:
		_ok_t = 0.0
	if _stuck_t > 1.2:
		_stuck_t = 0.0
		_stuck_count += 1
		if _stuck_count >= 3 and manager != null:
			_stuck_count = 0
			manager.respawn_kart(kart)
		else:
			_reverse_t = 0.9


func _think_items(dt: float) -> void:
	if kart.held_item == null or kart.is_rolling():
		_item_t = -1.0
		return
	if _item_t < 0.0:
		_item_t = _rng.randf_range(0.6, 2.0)
		_held_for = 0.0
	_held_for += dt
	_item_t -= dt
	if _item_t > 0.0:
		return
	var it := kart.held_item
	var use := false
	var back := false
	var forced := _held_for > HELD_MAX
	var ahead := _nearest_rival(true, 55.0)
	var behind := _nearest_rival(false, 30.0)

	if it is ItemSelfEffect:
		use = true
	elif it is ItemChaos:
		var chaos := it as ItemChaos
		use = not kart.get_rivals().is_empty() and (chaos.target != ItemChaos.Target.AHEAD or kart.race_position > 1)
	elif it is ItemSwap:
		use = kart.race_position > 1
	elif it is ItemProjectile:
		var proj := it as ItemProjectile
		match proj.kind:
			ItemProjectile.Kind.SHOCKWAVE:
				use = _any_rival_within(13.0)
			ItemProjectile.Kind.BOMB:
				use = ahead != null and kart.sphere.global_position.distance_to(ahead.sphere.global_position) < 30.0
			_:
				use = ahead != null
		if not use and behind != null and proj.kind != ItemProjectile.Kind.HOMING \
				and proj.kind != ItemProjectile.Kind.SHOCKWAVE:
			use = true
			back = true
		if not use and forced:
			use = true
	elif it is ItemTrap:
		if behind != null:
			use = true
			back = true
		elif forced:
			use = true
			back = true
	else:
		use = true

	if use:
		_controls.item = true
		_controls.item_back = back
		_item_t = -1.0
	else:
		_item_t = 0.5


## Rival más cercano delante (ahead=true) o detrás, alineado con el kart (dentro de ~10 m laterales).
func _nearest_rival(ahead: bool, max_dist: float) -> Kart:
	var fwd := kart.get_forward()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	var best: Kart = null
	var best_d := max_dist
	for rival in kart.get_rivals():
		var d := rival.sphere.global_position - kart.sphere.global_position
		d.y = 0.0
		var along := d.dot(fwd)
		var lat := absf(d.dot(right))
		if (along > 0.0) == ahead and absf(along) < best_d and lat < 10.0:
			best_d = absf(along)
			best = rival
	return best


func _any_rival_within(radius: float) -> bool:
	for rival in kart.get_rivals():
		if rival.sphere.global_position.distance_to(kart.sphere.global_position) < radius:
			return true
	return false
