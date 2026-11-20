extends Node
## Captura de pantalla de una carrera real (cámara de persecución) a docs/art/carrera.png. Necesita render.
##   Godot_console.exe --path . res://scenes/debug/race_shot.tscn
## Argumentos tras "--":  --duo   (el kart del jugador lleva conductor + artillero)

const SECONDS := 7.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameSession.reset()
	var duo := OS.get_cmdline_user_args().has("--duo")
	var seats: Array[Seat] = []
	var s1 := Seat.new()
	s1.role = Seat.Role.DRIVER if duo else Seat.Role.SOLO
	s1.character_id = &"drancr"
	seats.append(s1)
	if duo:
		var s2 := Seat.new()
		s2.role = Seat.Role.GUNNER
		s2.character_id = &"clarstar"
		seats.append(s2)
	GameSession.setups = [{"slot": 0, "seats": seats, "team": -1, "vehicle": &"chatarrero"}]
	GameSession.bot_teams = [-1, -1, -1]
	GameSession.laps = 1
	var race: Node3D = load("res://scenes/race/race.tscn").instantiate()
	race.autopilot_humans = true
	add_child(race)
	await get_tree().create_timer(SECONDS).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/art"))
	var path := "res://docs/art/carrera%s.png" % ("_duo" if duo else "")
	img.save_png(ProjectSettings.globalize_path(path))
	print("Guardado: ", path, " ", img.get_size())
	get_tree().quit()
