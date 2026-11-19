class_name KartModifiers
extends RefCounted
## Resultado de combinar todos los efectos activos de un kart (se recalcula cada tick físico).

var speed_mult := 1.0
var accel_mult := 1.0
var steer_mult := 1.0
var grip_mult := 1.0
var scale_mult := 1.0
var mass_mult := 1.0
var force_throttle := false
var lock_control := false
var spin := false
var immune := false
var ghost := false
var touch_hit := false
var reflect := false
var ink := false


func reset() -> void:
	speed_mult = 1.0
	accel_mult = 1.0
	steer_mult = 1.0
	grip_mult = 1.0
	scale_mult = 1.0
	mass_mult = 1.0
	force_throttle = false
	lock_control = false
	spin = false
	immune = false
	ghost = false
	touch_hit = false
	reflect = false
	ink = false
