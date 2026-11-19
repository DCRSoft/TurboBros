class_name KartControls
extends RefCounted
## Estado de entrada de un kart en un instante. La lógica del kart SOLO lee esto
## (nunca el hardware), así sirve igual para mandos, bots y red.

var steer := 0.0       ## -1 izquierda .. +1 derecha
var throttle := 0.0    ## 0..1
var brake := 0.0       ## 0..1
var drift := false
var item := false
var item_back := false ## lanzar hacia atrás
var hit_left := false  ## golpe del artillero
var hit_right := false


func clear() -> void:
	steer = 0.0
	throttle = 0.0
	brake = 0.0
	drift = false
	item = false
	item_back = false
	hit_left = false
	hit_right = false


## Combina otro estado (p. ej. conductor + artillero del mismo kart).
func merge(o: KartControls) -> void:
	if absf(o.steer) > absf(steer):
		steer = o.steer
	throttle = maxf(throttle, o.throttle)
	brake = maxf(brake, o.brake)
	drift = drift or o.drift
	item = item or o.item
	item_back = item_back or o.item_back
	hit_left = hit_left or o.hit_left
	hit_right = hit_right or o.hit_right
