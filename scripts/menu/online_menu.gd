extends Control
## Multijugador en línea: crear una partida (anfitrión) o unirse a una por IP.
## Escribir la IP requiere teclado; el resto se maneja también con mando.

const MAIN_MENU := "res://scenes/menu/main_menu.tscn"
const LOBBY := "res://scenes/menu/online_lobby.tscn"
const SETTINGS_PATH := "user://settings.cfg"

var _items: Array[String] = ["Crear partida", "Unirse a una partida", "Volver"]
var _sel := 0
var _labels: Array[Label] = []
var _status: Label
var _address: LineEdit
var _input := MenuInput.new()
var _joining := false     ## escribiendo la IP o conectando


func _ready() -> void:
	NetSession.leave()
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(620, 0)
	add_child(box)
	var title := Label.new()
	title.text = "Multijugador en línea"
	title.add_theme_font_size_override("font_size", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var info := Label.new()
	info.text = "1 o 2 jugadores por PC, con una sola vista. Hasta 8 karts (humanos + bots).\nPuerto %d (UDP). Para jugar por Internet el anfitrión debe abrir ese puerto en su router." % NetSession.DEFAULT_PORT
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.modulate = Color(0.75, 0.78, 0.85)
	box.add_child(info)
	for i in _items.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 34)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
		_labels.append(l)
	_address = LineEdit.new()
	_address.placeholder_text = "IP del anfitrión (ej. 192.168.1.20)"
	_address.text = _load_last_address()
	_address.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_address.add_theme_font_size_override("font_size", 28)
	_address.visible = false
	_address.text_submitted.connect(_on_address_submitted)
	box.add_child(_address)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	NetSession.connected_to_host.connect(_on_connected)
	NetSession.connection_failed.connect(_on_failed)
	_refresh()


func _exit_tree() -> void:
	if NetSession.connected_to_host.is_connected(_on_connected):
		NetSession.connected_to_host.disconnect(_on_connected)
	if NetSession.connection_failed.is_connected(_on_failed):
		NetSession.connection_failed.disconnect(_on_failed)


func _process(_delta: float) -> void:
	for e in _input.poll():
		if _joining:
			if e["action"] == "back":
				_cancel_join()
			continue
		match e["action"]:
			"up": _move(-1)
			"down": _move(1)
			"confirm", "start": _activate()
			"back": get_tree().change_scene_to_file(MAIN_MENU)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		if _joining:
			_cancel_join()
		else:
			get_tree().change_scene_to_file(MAIN_MENU)
		return
	if _joining:
		return  # el LineEdit se queda con el teclado
	match event.keycode:
		KEY_UP: _move(-1)
		KEY_DOWN: _move(1)
		KEY_ENTER, KEY_KP_ENTER: _activate()


func _move(d: int) -> void:
	_sel = posmod(_sel + d, _items.size())
	_refresh()


func _activate() -> void:
	match _sel:
		0:
			var err := NetSession.host_game()
			if err == OK:
				get_tree().change_scene_to_file(LOBBY)
			else:
				_status.text = NetSession.last_error
		1:
			_joining = true
			_address.visible = true
			_address.grab_focus()
			_address.caret_column = _address.text.length()
			_status.text = "Escribe la IP del anfitrión y pulsa Enter (Esc: cancelar)"
		2:
			get_tree().change_scene_to_file(MAIN_MENU)


func _on_address_submitted(text: String) -> void:
	var addr := text.strip_edges()
	if addr == "":
		return
	var err := NetSession.join_game(addr)
	if err != OK:
		_status.text = NetSession.last_error
		return
	_save_last_address(addr)
	_address.editable = false
	_status.text = "Conectando con %s…" % addr


func _on_connected() -> void:
	get_tree().change_scene_to_file(LOBBY)


func _on_failed() -> void:
	_status.text = "No se pudo conectar: revisa la IP, el puerto y que el anfitrión ya haya creado la partida"
	_address.editable = true
	_address.grab_focus()


func _cancel_join() -> void:
	NetSession.leave()
	_joining = false
	_address.visible = false
	_address.editable = true
	_address.release_focus()
	_status.text = ""


func _refresh() -> void:
	for i in _labels.size():
		_labels[i].text = ("▶ " if i == _sel else "   ") + _items[i]
		_labels[i].modulate = Color.WHITE if i == _sel else Color(0.6, 0.6, 0.65)


func _load_last_address() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return str(cfg.get_value("net", "last_address", ""))
	return ""


func _save_last_address(addr: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("net", "last_address", addr)
	cfg.save(SETTINGS_PATH)
