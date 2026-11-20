extends Control
## Menú principal: Jugar / Opciones / Salir (+ actualización si hay una nueva versión en GitHub).
## Se maneja con mando (stick/cruceta + A) o teclado.

const LOBBY := "res://scenes/menu/lobby.tscn"
const OPTIONS := "res://scenes/menu/options.tscn"

var _ids: Array[StringName] = []
var _labels: Array[Label] = []
var _box: VBoxContainer
var _status: Label
var _sel := 0
var _input := MenuInput.new()
var _state := &"checking"   # checking | none | available | downloading | ready | error


func _ready() -> void:
	GameSession.reset()
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Portada a la izquierda (si el archivo existe)
	var cover_path := "res://assets/ui/cover.jpg"
	var has_cover := ResourceLoader.exists(cover_path)
	if has_cover:
		var ratio := AspectRatioContainer.new()
		ratio.ratio = 1296.0 / 1750.0
		ratio.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		ratio.anchor_right = 0.58
		ratio.stretch_mode = AspectRatioContainer.STRETCH_FIT
		ratio.alignment_horizontal = AspectRatioContainer.ALIGNMENT_BEGIN
		add_child(ratio)
		var tex := TextureRect.new()
		tex.texture = load(cover_path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		ratio.add_child(tex)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER_RIGHT if has_cover else Control.PRESET_CENTER)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_box.add_theme_constant_override("separation", 18)
	if has_cover:
		_box.anchor_left = 0.72
		_box.anchor_right = 0.72
		_box.offset_left = -220
		_box.offset_right = 220
	add_child(_box)
	var title := Label.new()
	title.text = "TurboBros"
	title.add_theme_font_size_override("font_size", 56 if has_cover else 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	var ver := Label.new()
	ver.text = "v%s" % GameVersion.current
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(ver)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.modulate = Color(0.75, 0.8, 0.9)
	_box.add_child(_status)

	Updater.check_finished.connect(_on_check)
	Updater.download_progress.connect(_on_progress)
	Updater.download_finished.connect(_on_download)
	if Updater.has_pending():
		_state = &"ready"
	elif Updater.checked and not Updater.latest.is_empty():
		_state = &"available" if Updater.latest.get("available", false) else &"none"
	elif Updater.checked:
		_state = &"none"
	else:
		Updater.check()
	_rebuild()


func _exit_tree() -> void:
	for pair in [[Updater.check_finished, _on_check], [Updater.download_progress, _on_progress],
			[Updater.download_finished, _on_download]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


func _rebuild() -> void:
	for l in _labels:
		l.queue_free()
	_labels.clear()
	_ids.clear()
	if _state == &"available":
		_ids.append(&"update")
	elif _state == &"ready":
		_ids.append(&"install")
	_ids.append_array([&"play", &"options", &"quit"])
	for id in _ids:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 34)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(l)
		_labels.append(l)
	_sel = clampi(_sel, 0, _ids.size() - 1)
	_refresh()


func _text_for(id: StringName) -> String:
	match id:
		&"update": return "⬇ Actualizar a v%s" % Updater.latest.get("version", "?")
		&"install": return "⟳ Instalar y reiniciar"
		&"play": return "Jugar"
		&"options": return "Opciones"
		&"quit": return "Salir"
	return str(id)


func _refresh() -> void:
	for i in _labels.size():
		_labels[i].text = ("▶ " if i == _sel else "   ") + _text_for(_ids[i])
		_labels[i].modulate = Color.WHITE if i == _sel else Color(0.6, 0.6, 0.65)
	match _state:
		&"checking": _status.text = "Buscando actualizaciones…"
		&"none": _status.text = "Estás al día"
		&"available":
			var mb := float(Updater.latest.get("zip_size", 0)) / 1048576.0
			_status.text = "Nueva versión disponible: v%s (%.0f MB)" % [Updater.latest.get("version", "?"), mb]
		&"ready": _status.text = "Actualización descargada y verificada: se instalará al cerrar el juego"


func _on_check(result: Dictionary) -> void:
	match result["status"]:
		"available": _state = &"available"
		"error": _state = &"none"
		_: _state = &"none"
	_rebuild()
	if result["status"] == "error":
		_status.text = "No se pudo buscar actualizaciones (%s)" % result.get("message", "")


func _on_progress(done: int, total: int) -> void:
	if total > 0:
		_status.text = "Descargando actualización… %d %%" % int(100.0 * done / total)


func _on_download(ok: bool, message: String) -> void:
	_state = &"ready" if ok else &"available"
	_rebuild()
	_status.text = message if not ok else "%s: se instalará al cerrar el juego, o elige «Instalar y reiniciar»" % message


func _process(_delta: float) -> void:
	for e in _input.poll():
		match e["action"]:
			"up": _move(-1)
			"down": _move(1)
			"confirm", "start": _activate()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_UP: _move(-1)
		KEY_DOWN: _move(1)
		KEY_ENTER, KEY_KP_ENTER: _activate()
		KEY_ESCAPE: Updater.quit_game()


func _move(d: int) -> void:
	_sel = posmod(_sel + d, _ids.size())
	_refresh()


func _activate() -> void:
	match _ids[_sel]:
		&"play":
			get_tree().change_scene_to_file(LOBBY)
		&"options":
			get_tree().change_scene_to_file(OPTIONS)
		&"quit":
			Updater.quit_game()
		&"update":
			_state = &"downloading"
			_status.text = "Descargando actualización…"
			Updater.download()
		&"install":
			if OS.has_feature("editor"):
				_status.text = "Estás en el editor: la actualización solo se instala en el juego exportado"
			else:
				Updater.quit_game()
