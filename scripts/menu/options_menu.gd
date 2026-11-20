extends Control
## Opciones gráficas: calidad (Alta/Media/Baja), escala máxima de render, auto-ajuste, FPS y pantalla completa.

const MAIN_MENU := "res://scenes/menu/main_menu.tscn"

var _sel := 0
var _rows: Array[Label] = []
var _info: Label
var _input := MenuInput.new()
const ITEMS: Array[String] = ["Calidad", "Escala máxima de render", "Auto-ajuste de escala (si bajan de 60 FPS)",
		"FPS desbloqueados", "Pantalla completa", "Volumen de efectos", "Volumen del motor", "Volver"]


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 80
	box.offset_right = -80
	box.offset_top = 40
	box.offset_bottom = -40
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var title := Label.new()
	title.text = "Opciones gráficas"
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)
	for i in ITEMS.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 26)
		box.add_child(l)
		_rows.append(l)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 18)
	_info.modulate = Color(0.75, 0.78, 0.85)
	box.add_child(_info)
	_refresh()


func _process(_delta: float) -> void:
	for e in _input.poll():
		match e["action"]:
			"up": _move(-1)
			"down": _move(1)
			"left": _change(-1)
			"right": _change(1)
			"confirm": _change(1) if _sel < ITEMS.size() - 1 else _back()
			"back": _back()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: _back()
			KEY_ENTER, KEY_KP_ENTER:
				if _sel == ITEMS.size() - 1:
					_back()
				else:
					_change(1)


func _back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _move(d: int) -> void:
	_sel = posmod(_sel + d, ITEMS.size())
	_refresh()


func _change(d: int) -> void:
	var g := GraphicsSettings
	match _sel:
		0: g.set_quality(posmod(int(g.quality) + d, 3) as GraphicsSettings.Quality)
		1: g.set_user_scale(g.user_scale + d * 0.05)
		2: g.set_auto_scale(not g.auto_scale)
		3: g.set_unlock_fps(not g.unlock_fps)
		4: g.set_fullscreen(not g.fullscreen)
		5:
			AudioManager.set_sfx_volume(AudioManager.sfx_volume + d * 0.1)
			AudioManager.play(&"pickup", 0.6)
		6: AudioManager.set_engine_volume(AudioManager.engine_volume + d * 0.1)
	_refresh()


func _refresh() -> void:
	var g := GraphicsSettings
	var vals: Array[String] = [
		"◀ %s ▶" % g.quality_name(),
		"◀ %d %% ▶" % roundi(g.user_scale * 100.0),
		"Sí" if g.auto_scale else "No",
		"Sí" if g.unlock_fps else "No (60)",
		"Sí" if g.fullscreen else "No",
		"◀ %d %% ▶" % roundi(AudioManager.sfx_volume * 100.0),
		"◀ %d %% ▶" % roundi(AudioManager.engine_volume * 100.0),
		"",
	]
	for i in ITEMS.size():
		_rows[i].text = ("▶ " if i == _sel else "   ") + ITEMS[i] + ("   " + vals[i] if vals[i] != "" else "")
		_rows[i].modulate = Color.WHITE if i == _sel else Color(0.6, 0.6, 0.65)
	var p := g.preset()
	_info.text = "GPU: %s\nCalidad %s: sombras %s · antialiasing %s · post-procesado %s · distancia de dibujado %d m · presupuesto %s\nArriba/Abajo: elegir · Izq/Der o A: cambiar · B / Esc: volver" % [
			RenderingServer.get_video_adapter_name(), g.quality_name(),
			("reales hasta %d m" % int(p["shadow_distance"])) if p["shadows"] else "tipo blob (sin sombras reales)",
			("MSAA 2x + FXAA" if int(p["msaa"]) >= 2 else "FXAA") if p["fxaa"] else "ninguno",
			"brillo + tono" if p["glow"] else ("tono" if p["tonemap"] else "ninguno"),
			int(p["far"]),
			("≈ %.1f M píxeles internos" % (float(p["pixel_budget"]) / 1000000.0)) if int(p["pixel_budget"]) > 0 else "sin límite"]
