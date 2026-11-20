class_name PauseMenu
extends CanvasLayer
## Menú de pausa de la carrera. Se abre con Start (mando), P o Esc. En local congela el juego entero
## (física, bots, cuenta atrás y tiempo); EN LÍNEA no puede congelar a los demás, así que solo muestra el menú
## y la carrera sigue.

signal opened
signal closed

const LOBBY := "res://scenes/menu/lobby.tscn"
const MAIN_MENU := "res://scenes/menu/main_menu.tscn"

var manager: RaceManager
var online := false
var is_open := false

var _ids: Array[StringName] = []
var _labels: Array[Label] = []
var _box: VBoxContainer
var _note: Label
var _sel := 0
var _input := MenuInput.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # sigue funcionando con el árbol en pausa
	layer = 30
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_box.add_theme_constant_override("separation", 16)
	_box.custom_minimum_size = Vector2(520, 0)
	add_child(_box)
	var title := Label.new()
	title.text = "PAUSA"
	title.add_theme_font_size_override("font_size", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.modulate = Color(0.8, 0.85, 0.95)
	_box.add_child(_note)
	_rebuild()


func setup(p_manager: RaceManager, is_online: bool) -> void:
	manager = p_manager
	online = is_online
	_rebuild()


func _rebuild() -> void:
	if _box == null:
		return
	for l in _labels:
		l.queue_free()
	_labels.clear()
	_ids.clear()
	if online:
		_ids.append_array([&"resume", &"leave"])
	else:
		_ids.append_array([&"resume", &"restart", &"lobby", &"main"])
	for id in _ids:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 36)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(l)
		_labels.append(l)
	_note.text = "La carrera sigue en línea mientras tanto" if online else ""
	_sel = clampi(_sel, 0, _ids.size() - 1)
	_refresh()


func _text(id: StringName) -> String:
	match id:
		&"resume": return "Continuar"
		&"restart": return "Reiniciar carrera"
		&"lobby": return "Volver al lobby"
		&"main": return "Menú principal"
		&"leave": return "Salir de la partida"
	return str(id)


func _refresh() -> void:
	for i in _labels.size():
		_labels[i].text = ("▶ " if i == _sel else "   ") + _text(_ids[i])
		_labels[i].modulate = Color.WHITE if i == _sel else Color(0.62, 0.64, 0.7)


func open() -> void:
	if is_open or (manager != null and manager.state == RaceManager.State.FINISHED):
		return
	is_open = true
	visible = true
	_sel = 0
	_refresh()
	_input = MenuInput.new()   # ignora lo que ya estuviera pulsado al abrir
	get_tree().paused = not online
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	closed.emit()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func _process(_delta: float) -> void:
	for e in _input.poll():
		if not is_open:
			if e["action"] == "start":
				open()
			continue
		match e["action"]:
			"up": _move(-1)
			"down": _move(1)
			"confirm": _activate()
			"start", "back": close()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
		toggle()
		return
	if not is_open:
		return
	match event.keycode:
		KEY_UP: _move(-1)
		KEY_DOWN: _move(1)
		KEY_ENTER, KEY_KP_ENTER: _activate()


func _move(d: int) -> void:
	_sel = posmod(_sel + d, _ids.size())
	_refresh()


func _activate() -> void:
	match _ids[_sel]:
		&"resume":
			close()
		&"restart":
			close()
			AudioManager.stop_engines()
			get_tree().reload_current_scene()
		&"lobby":
			close()
			AudioManager.stop_engines()
			get_tree().change_scene_to_file(LOBBY)
		&"main":
			close()
			AudioManager.stop_engines()
			get_tree().change_scene_to_file(MAIN_MENU)
		&"leave":
			close()
			AudioManager.stop_engines()
			NetSession.leave()
			get_tree().change_scene_to_file(MAIN_MENU)
