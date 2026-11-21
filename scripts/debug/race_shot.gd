extends Node
## Captura de pantalla de una carrera real (cámara de persecución) a docs/art/carrera.png. Necesita render.
##   Godot_console.exe --path . res://scenes/debug/race_shot.tscn
## Argumentos tras "--":  --duo   (el kart del jugador lleva conductor + artillero)
##   --track=<id>  pista (p. ej. 03_cumbre)   --aerial  vista aérea de la pista   --far  cámara a 60 m detrás del kart

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
	var args := OS.get_cmdline_user_args()
	var track_name := ""
	for a in args:
		if a.begins_with("--track="):
			track_name = a.substr(8)
			race.track_override = StringName(track_name)
	add_child(race)
	var feature := ""
	for a2 in args:
		if a2.begins_with("--feature="):
			feature = a2.substr(10)
	if feature != "":
		await _show_feature(race, feature)
	else:
		await get_tree().create_timer(SECONDS).timeout
	if args.has("--aerial") or args.has("--far"):
		for cam in race.find_children("*", "ChaseCamera", true, false):
			var cc := cam as ChaseCamera
			cc.set_process(false)
			var c3 := cc.camera
			var k: Kart = cc.target
			if args.has("--aerial"):
				var mid: Vector3 = race.circuit.points[race.circuit.count / 2]
				c3.global_position = Vector3(0, 520, 380)
				c3.look_at(Vector3(0, 0, 0))
				c3.fov = 62.0
			else:
				var back: Vector3 = -k.get_visual_forward().normalized()
				c3.global_position = k.get_visual_position() + back * 45.0 + Vector3.UP * 22.0
				c3.look_at(k.get_visual_position() + k.get_visual_forward() * 60.0)
		await get_tree().create_timer(0.3).timeout
	if args.has("--back"):
		(race.human_karts[0].controller as KartController).get_controls().look_back = true
		await get_tree().create_timer(0.8).timeout
	if args.has("--hud"):
		var hk: Kart = race.human_karts[0]
		hk.held_item = ItemCatalog.find(&"triple_turbo")
		hk.held_uses = 3
		hk.fx.add(EffectLibrary.get_effect(&"star"))
		hk.fx.add(EffectLibrary.get_effect(&"invert"))
		hk.fx.add(EffectLibrary.get_effect(&"guard"))
		await get_tree().create_timer(0.6).timeout
	if args.has("--pause"):
		race.pause_menu.open()
		await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/art"))
	var suffix := ("_" + track_name) if track_name != "" else ""
	suffix += "_aerea" if args.has("--aerial") else ("_lejos" if args.has("--far") else "")
	if suffix == "":
		suffix = "_duo" if duo else ("_atras" if args.has("--back") else ("_pausa" if args.has("--pause") else ("_hud" if args.has("--hud") else "")))
	var path := "res://docs/art/carrera%s.png" % suffix
	img.save_png(ProjectSettings.globalize_path(path))
	print("Guardado: ", path, " ", img.get_size())
	get_tree().quit()


## --feature=bridge|tunnel|ramp|turbo[,n]: coloca el kart unos metros antes del elemento n-ésimo de ese tipo y espera a la cuenta atrás.
func _show_feature(race: Node3D, spec: String) -> void:
	var parts := spec.split(",")
	var kind := parts[0]
	var n := int(parts[1]) if parts.size() > 1 else 0
	await get_tree().create_timer(0.5).timeout
	var c: Circuit = race.circuit
	if kind == "shortcut" and not c.alts.is_empty():
		race.human_karts[0].respawn(c.respawn_transform(c.wrap_index(c.alts[0].ia - 8)))
		await get_tree().create_timer(1.2).timeout
		return
	var list: Array = {"bridge": c.bridges, "tunnel": c.tunnels, "ramp": c.ramps, "turbo": c.pads}.get(kind, [])
	if list.is_empty():
		print("Sin elementos de tipo ", kind)
		return
	var e: Dictionary = list[mini(n, list.size() - 1)]
	var i: int = e["i0"] if e.has("i0") else e["i"]
	var k: Kart = race.human_karts[0]
	k.respawn(c.respawn_transform(c.wrap_index(i - 8)))
	await get_tree().create_timer(1.2).timeout
