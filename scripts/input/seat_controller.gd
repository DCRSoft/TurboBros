class_name SeatController
extends KartController
## Controlador humano: lee los asientos de su kart a través de InputManager.

var seats: Array[Seat] = []
var _tmp := KartControls.new()


func get_controls() -> KartControls:
	_controls.clear()
	for s in seats:
		_tmp.clear()
		InputManager.read_seat(s, _tmp)
		_controls.merge(_tmp)
	return _controls
