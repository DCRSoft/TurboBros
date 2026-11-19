extends Control
## Menú principal: Jugar / Pantalla completa / Salir. Se maneja con mando (stick/cruceta + A) o teclado.

const LOBBY := "res://scenes/menu/lobby.tscn"

var _items: Array[String] = ["Jugar", "Pantalla completa", "Salir"]
var _sel := 0
var _labels: Array[Label] = []
var _input := MenuInput.new()


func _ready() -> void:
	GameSession.reset()
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	var title := Label.new()
	title.text = "TurboBros"
	title.add_theme_font_size_override("font_size", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var ver := Label.new()
	ver.text = "v%s" % GameVersion.current
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ver)
	for it in _items:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 36)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
		_labels.append(l)
	_refresh()


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
		KEY_ENTER, KEY_KP_ENTER: _activate()
		KEY_ESCAPE: get_tree().quit()


func _move(d: int) -> void:
	_sel = posmod(_sel + d, _items.size())
	_refresh()


func _activate() -> void:
	match _items[_sel]:
		"Jugar":
			get_tree().change_scene_to_file(LOBBY)
		"Pantalla completa":
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full
					else DisplayServer.WINDOW_MODE_FULLSCREEN)
		"Salir":
			get_tree().quit()


func _refresh() -> void:
	for i in _labels.size():
		_labels[i].text = ("▶ " if i == _sel else "   ") + _items[i]
		_labels[i].modulate = Color.WHITE if i == _sel else Color(0.6, 0.6, 0.65)
