class_name KartController
extends Node
## Fuente de controles de un kart. Subclases: SeatController (humanos),
## ScriptedController (pruebas), más adelante bots y red.

var _controls := KartControls.new()


func get_controls() -> KartControls:
	return _controls
