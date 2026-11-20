extends Node
## Captura de la pantalla de selección (docs/art/seleccion.png). Necesita render.
##   Godot_console.exe --path . res://scenes/debug/select_shot.tscn


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameSession.reset()
	var a: Array[Seat] = [_seat(Seat.Role.SOLO, 0)]
	var b: Array[Seat] = [_seat(Seat.Role.DRIVER, 1), _seat(Seat.Role.GUNNER, 2)]
	var c: Array[Seat] = [_seat(Seat.Role.SOLO, 3)]
	GameSession.setups = [{"slot": 0, "seats": a, "team": -1}, {"slot": 1, "seats": b, "team": 1}, {"slot": 2, "seats": c, "team": -1}]
	var scene: Node = load("res://scenes/menu/select.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/art/seleccion.png"))
	print("Guardado: seleccion.png ", img.get_size())
	get_tree().quit()


func _seat(role: Seat.Role, dev: int) -> Seat:
	var s := Seat.new()
	s.role = role
	s.set_joypad(dev)
	return s
