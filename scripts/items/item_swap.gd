class_name ItemSwap
extends ItemData
## Intercambia la posición con el kart inmediatamente por delante (si vas 1.º, no hace nada).


func use(kart: Kart, _backwards: bool) -> void:
	var ahead: Kart = null
	for rival in kart.get_rivals():
		if rival.race_position == kart.race_position - 1:
			ahead = rival
	if ahead == null:
		return
	if ahead.take_hit(kart, null) != Kart.HitResult.HIT:
		return  # protegido
	var p1 := kart.sphere.global_position
	var v1 := kart.sphere.linear_velocity
	var h1 := kart.heading
	kart.set_motion_state(ahead.sphere.global_position, ahead.sphere.linear_velocity, ahead.heading)
	ahead.set_motion_state(p1, v1, h1)
	var pr := kart.race_progress
	kart.race_progress = ahead.race_progress
	ahead.race_progress = pr
