class_name KartEffects
extends RefCounted
## Gestor de efectos de un kart: temporizadores, apilado y modificadores combinados.

signal started(data: KartEffect)
signal ended(data: KartEffect)

class Instance:
	var data: KartEffect
	var time_left := 0.0
	var charges := 0
	var speed_mult := 1.0  ## puede sobrescribir el del recurso (turbos de derrape/aterrizaje)

var instances: Array[Instance] = []
var mods := KartModifiers.new()


## duration / speed_mult < 0 = usar los del recurso.
func add(data: KartEffect, duration := -1.0, speed_mult := -1.0) -> Instance:
	var dur := duration if duration > 0.0 else data.duration
	var spd := speed_mult if speed_mult > 0.0 else data.speed_mult
	if data.stack != KartEffect.Stack.STACK:
		for i in instances:
			if i.data.id == data.id:
				if data.stack == KartEffect.Stack.IGNORE:
					return i
				i.time_left = maxf(i.time_left, dur)
				i.charges = data.guard_charges
				i.speed_mult = maxf(i.speed_mult, spd)
				_recompute()
				return i
	var inst := Instance.new()
	inst.data = data
	inst.time_left = dur
	inst.charges = data.guard_charges
	inst.speed_mult = spd
	instances.append(inst)
	_recompute()
	started.emit(data)
	return inst


func has(id: StringName) -> bool:
	for i in instances:
		if i.data.id == id:
			return true
	return false


func remove(id: StringName) -> void:
	for i in range(instances.size() - 1, -1, -1):
		if instances[i].data.id == id:
			ended.emit(instances[i].data)
			instances.remove_at(i)
	_recompute()


func clear() -> void:
	for i in instances:
		ended.emit(i.data)
	instances.clear()
	_recompute()


func tick(delta: float) -> void:
	var changed := false
	for idx in range(instances.size() - 1, -1, -1):
		var i := instances[idx]
		i.time_left -= delta
		var guard_spent := i.data.guard_charges > 0 and i.charges <= 0
		if i.time_left <= 0.0 or guard_spent:
			ended.emit(i.data)
			instances.remove_at(idx)
			changed = true
	if changed:
		_recompute()


## Consume una carga de guardia (orbitales). true = el ataque fue absorbido.
func consume_guard() -> bool:
	for i in instances:
		if i.data.guard_charges > 0 and i.charges > 0:
			i.charges -= 1
			return true
	return false


func total_guard_charges() -> int:
	var n := 0
	for i in instances:
		if i.data.guard_charges > 0:
			n += i.charges
	return n


func _recompute() -> void:
	mods.reset()
	for i in instances:
		var d := i.data
		mods.speed_mult *= i.speed_mult
		mods.accel_mult *= d.accel_mult
		mods.steer_mult *= d.steer_mult
		mods.grip_mult *= d.grip_mult
		mods.scale_mult = maxf(mods.scale_mult, d.scale_mult)
		mods.mass_mult *= d.mass_mult
		mods.force_throttle = mods.force_throttle or d.force_throttle
		mods.lock_control = mods.lock_control or d.lock_control
		mods.spin = mods.spin or d.spin
		mods.immune = mods.immune or d.immune or d.ghost
		mods.ghost = mods.ghost or d.ghost
		mods.touch_hit = mods.touch_hit or d.touch_hit
		mods.reflect = mods.reflect or d.reflect
		mods.ink = mods.ink or d.ink
