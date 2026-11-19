extends Control
## Lobby: cada jugador se une pulsando su botón (A en mando, Espacio = teclado J1, K = teclado J2).
## Reparte automáticamente en karts (ver LobbyModel) y permite cambiar de kart y de rol.

const TRACK := "res://scenes/tracks/test_track.tscn"
const KART_COLORS: Array[Color] = [
	Color(0.85, 0.15, 0.15), Color(0.2, 0.4, 0.9), Color(0.2, 0.75, 0.3), Color(0.95, 0.8, 0.15),
]

var model := LobbyModel.new()
var _prev := {}
var _warmup := true
var _cols: Array[Label] = []
var _help: Label


func _ready() -> void:
	GameSession.setups.clear()
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 32
	root.offset_right = -32
	root.offset_top = 24
	root.offset_bottom = -24
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var title := Label.new()
	title.text = "TurboBros  v%s  —  Lobby" % GameVersion.current
	title.add_theme_font_size_override("font_size", 34)
	root.add_child(title)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	root.add_child(row)
	for i in LobbyModel.MAX_KARTS:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		panel.add_child(box)
		var bar := ColorRect.new()
		bar.color = KART_COLORS[i]
		bar.custom_minimum_size = Vector2(0, 10)
		box.add_child(bar)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 22)
		box.add_child(lbl)
		_cols.append(lbl)
		row.add_child(panel)

	_help = Label.new()
	_help.add_theme_font_size_override("font_size", 20)
	root.add_child(_help)


func _process(_delta: float) -> void:
	for dev in InputManager.get_devices():
		var key := "%d:%d" % [dev["kind"], dev["id"]]
		var cur := InputManager.read_menu(dev["kind"], dev["id"])
		if not _warmup:
			_handle(dev["kind"], dev["id"], cur, _prev.get(key, {}))
		_prev[key] = cur
	_warmup = false
	_refresh()


func _edge(cur: Dictionary, prev: Dictionary, name: String) -> bool:
	return cur[name] and not prev.get(name, false)


func _handle(kind: Seat.DeviceKind, id: int, cur: Dictionary, prev: Dictionary) -> void:
	var p := model.find(kind, id)
	if p == null:
		if _edge(cur, prev, "confirm"):
			model.add(kind, id)
		return
	if _edge(cur, prev, "back"):
		model.remove(p)
		return
	var x: float = cur["x"]
	var px: float = prev.get("x", 0.0)
	if absf(x) > 0.6 and absf(px) <= 0.6:
		model.move(p, 1 if x > 0.0 else -1)
	if _edge(cur, prev, "swap"):
		model.swap_roles(p.kart_slot)
	if _edge(cur, prev, "start"):
		start_race()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		start_race()


func start_race() -> void:
	if not model.is_valid():
		return
	GameSession.setups = model.build_setups()
	get_tree().change_scene_to_file(TRACK)


func _device_name(p: LobbyModel.Player) -> String:
	if p.kind == Seat.DeviceKind.JOYPAD:
		return "Mando %d" % p.device_id
	return "Teclado J%d" % (p.device_id + 1)


func _refresh() -> void:
	for slot in LobbyModel.MAX_KARTS:
		var m := model.members(slot)
		var lines := PackedStringArray(["Kart %d" % (slot + 1), ""])
		if m.is_empty():
			lines.append("(vacío)")
		for p in m:
			var role := ""
			match model.role_of(p):
				Seat.Role.DRIVER: role = "  [Conductor]"
				Seat.Role.GUNNER: role = "  [Artillero]"
			lines.append(_device_name(p) + role)
		_cols[slot].text = "\n".join(lines)
	_help.text = "Unirse: A (mando) / Espacio (teclado J1) / K (teclado J2)\n" \
		+ "Izq/Der: cambiar de kart · Y / E / ; : intercambiar conductor y artillero · B / Q / J : salir\n" \
		+ "Start (mando) o Enter: iniciar   |   %d jugador(es)" % model.players.size()
