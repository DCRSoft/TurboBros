class_name ScriptedController
extends KartController
## Controlador programable para pruebas automáticas.


func set_item(pressed: bool, back := false) -> void:
	_controls.item = pressed
	_controls.item_back = back


func set_hit(left: bool, right: bool) -> void:
	_controls.hit_left = left
	_controls.hit_right = right


func set_input(steer: float, throttle: float, brake := 0.0, drift := false) -> void:
	_controls.steer = steer
	_controls.throttle = throttle
	_controls.brake = brake
	_controls.drift = drift
