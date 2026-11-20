extends Node
## Genera hojas de imágenes del arte (personajes, vehículos y parejas de la portada) en docs/art/*.png.
## Necesita render (no headless):  Godot_console.exe --path . res://scenes/debug/art_sheet.tscn
## Argumentos opcionales tras "--":  --only=characters|vehicles|pairs


func _ready() -> void:
	_run.call_deferred()


func _make_viewport(size: Vector2i, cam_pos: Vector3, look_at: Vector3, fov := 35.0) -> SubViewport:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.18, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.7)
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = fov
	cam.position = cam_pos
	vp.add_child(cam)
	cam.look_at(look_at, Vector3.UP)
	return vp


func _label(vp: SubViewport, text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.pixel_size = 0.0075
	l.font_size = 40
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.outline_size = 8
	vp.add_child(l)


func _save(vp: SubViewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/art"))
	img.save_png(ProjectSettings.globalize_path(path))
	print("Guardado: ", path, " ", img.get_size())


func _run() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.get_slice("=", 1)
	var chars := DataCatalog.characters()
	var vehs := DataCatalog.vehicles()

	if only == "" or only == "characters":
		var cols := 4
		var rows := ceili(chars.size() / float(cols))
		var vp := _make_viewport(Vector2i(1800, 360 * rows), Vector3(2.0, 11.0, -21.0), Vector3(0, 0.6, 0.0), 33.0)
		var azul := DataCatalog.vehicle(&"azulon")
		for i in chars.size():
			var x := ((cols - 1) * 0.5 - i % cols) * 3.9
			var z := (floorf(i / float(cols)) - (rows - 1) * 0.5) * 3.8
			var kv := KartVisual.build(azul, chars[i], null, azul.body_color)
			kv.position = Vector3(x, 0, z)
			kv.rotation_degrees.y = 25
			vp.add_child(kv)
			_label(vp, chars[i].display_name, Vector3(x, 2.1, z))
		await _save(vp, "res://docs/art/personajes.png")
		vp.queue_free()

	if only == "" or only == "vehicles":
		var vp2 := _make_viewport(Vector2i(1800, 720), Vector3(2.0, 7.0, -13.0), Vector3(0, 0.6, 0), 36.0)
		var ref := DataCatalog.character(&"drancr")
		for i in vehs.size():
			var x := (1 - i % 3) * 4.4
			var z := (floorf(i / 3.0) - 0.5) * 4.2
			var kv := KartVisual.build(vehs[i], ref, null, vehs[i].body_color)
			kv.position = Vector3(x, 0, z)
			kv.rotation_degrees.y = 25
			vp2.add_child(kv)
			_label(vp2, vehs[i].display_name, Vector3(x, 2.2, z))
		await _save(vp2, "res://docs/art/vehiculos.png")
		vp2.queue_free()

	if only == "" or only == "pairs":
		var vp3 := _make_viewport(Vector2i(1800, 560), Vector3(0.0, 4.6, -9.5), Vector3(0, 0.9, 0), 36.0)
		var pairs := [["chatarrero", "drancr", "clarstar"], ["relampago", "ferchaos", "end"], ["azulon", "agnelopolus", "polewar"]]
		for i in pairs.size():
			var v := DataCatalog.vehicle(StringName(pairs[i][0]))
			var kv := KartVisual.build(v, DataCatalog.character(StringName(pairs[i][1])),
					DataCatalog.character(StringName(pairs[i][2])), v.body_color)
			kv.position = Vector3((1 - i) * 4.6, 0, 0)
			kv.rotation_degrees.y = 25
			vp3.add_child(kv)
			_label(vp3, "%s + %s" % [pairs[i][1], pairs[i][2]], Vector3((1 - i) * 4.6, 2.7, 0))
		await _save(vp3, "res://docs/art/parejas.png")
		vp3.queue_free()
	get_tree().quit()
