extends Control
## Hoja de arte de los ítems (docs/art/items_*.png): iconos con su marco del HUD, y modelos 3D de cajas,
## proyectiles y trampas. Necesita render:  Godot_console.exe --path . res://scenes/debug/item_sheet.tscn


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var items := ItemCatalog.all()
	# --- Iconos (2D) ---
	var vp2 := SubViewport.new()
	vp2.size = Vector2i(1800, 620)
	vp2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp2)
	var canvas := Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp2.add_child(canvas)
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.15, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	var cols := 8
	for i in items.size():
		var cell := ItemIconCell.new()
		cell.item = items[i]
		cell.position = Vector2(30 + (i % cols) * 220, 30 + (i / cols) * 195)
		cell.size = Vector2(200, 180)
		canvas.add_child(cell)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/art"))
	vp2.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/art/items_iconos.png"))
	print("Guardado: items_iconos.png")
	vp2.queue_free()

	# --- Modelos 3D ---
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(1800, 700)
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
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 38.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 7.5, -11.5), Vector3(0, 0.5, 0), Vector3.UP)
	var entries: Array = []
	for it in items:
		if it is ItemProjectile and it.kind != ItemProjectile.Kind.SHOCKWAVE:
			entries.append([ItemModels.projectile_mesh(it.kind, it.color), it.display_name, 0.6, 1.0])
		elif it is ItemTrap:
			entries.append([ItemModels.trap_mesh(it.kind, it.color, it.trigger_radius), it.display_name, 0.0,
					(0.32 if it.kind == ItemTrap.Kind.OIL else (0.5 if it.kind == ItemTrap.Kind.NAILS else (0.7 if it.kind == ItemTrap.Kind.BARRIER else 1.0)))])
	entries.insert(0, [ItemModels.box_mesh(false), "Caja de ítems", 0.9, 1.0])
	var x := -8.5
	var step := 17.0 / maxf(entries.size() - 1, 1)
	for e in entries:
		var mi := MeshInstance3D.new()
		mi.mesh = e[0]
		mi.position = Vector3(x, e[2], 0)
		mi.rotation_degrees.y = 200
		mi.scale = Vector3.ONE * e[3]
		vp.add_child(mi)
		var l := Label3D.new()
		l.text = e[1]
		l.pixel_size = 0.0075
		l.font_size = 40
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.outline_size = 8
		l.position = Vector3(x, 2.1, 0)
		vp.add_child(l)
		x += step
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/art/items_modelos.png"))
	print("Guardado: items_modelos.png")
	get_tree().quit()


## Celda de la hoja: fondo + icono + nombre (igual que el HUD).
class ItemIconCell extends Control:
	var item: ItemData

	func _draw() -> void:
		var pr := Rect2(Vector2(46, 4), Vector2(108, 108))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.17, 0.25, 0.9)
		sb.set_corner_radius_all(20)
		sb.set_border_width_all(5)
		sb.border_color = item.icon_color.lightened(0.1)
		draw_style_box(sb, pr)
		ItemIcons.draw(self, item.id, pr.grow(-9.0), item.icon_color)
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(0, 142), item.display_name, HORIZONTAL_ALIGNMENT_CENTER, 200, 20, 6, Color.BLACK)
		draw_string(font, Vector2(0, 142), item.display_name, HORIZONTAL_ALIGNMENT_CENTER, 200, 20, Color.WHITE)
		if item.uses > 1:
			draw_string(font, Vector2(0, 166), "x%d usos" % item.uses, HORIZONTAL_ALIGNMENT_CENTER, 200, 16, Color(1.0, 0.6, 0.4))
