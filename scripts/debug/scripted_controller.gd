class_name ScriptedController
extends KartController
## Controlador programable para pruebas automáticas.


func set_input(steer: float, throttle: float, brake := 0.0, drift := false) -> void:
	_controls.steer = steer
	_controls.throttle = throttle
	_controls.brake = brake
	_controls.drift = drift
