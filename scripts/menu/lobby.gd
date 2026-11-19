extends Control
## Lobby: cada jugador se une pulsando su botón (A en mando, Espacio = teclado J1, K = teclado J2).
## Reparte automáticamente en karts (ver LobbyModel) y permite cambiar de kart, rol, equipo, bots, vueltas y
## fuego amigo.

const RACE := "res://scenes/race/race.tscn"
const MAIN_MENU := "res://scenes/menu/main_menu.tscn"
const KART_COLORS: Array[Color] = [
	Color(0.85, 0.15, 0.15), Color(0.2, 0.4, 0.9), Color(0.2, 0.75, 0.3), Color(0.95, 0.8, 0.15),
]

var model := LobbyModel.new()
var _input := MenuInput.new()
var _cols: Array[Label] = []
var _bars: Array[ColorRect] = []
var _options: Label
var _help: Label


func _ready() -> void:
	GameSession.reset()
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
	root.add_theme_constant_override("separation", 14)
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
		bar.custom_minimum_size = Vector2(0, 10)
		box.add_child(bar)
		_bars.append(bar)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 22)
		box.add_child(lbl)
		_cols.append(lbl)
		row.add_child(panel)

	_options = Label.new()
	_options.add_theme_font_size_override("font_size", 24)
	root.add_child(_options)
	_help = Label.new()
	_help.add_theme_font_size_override("font_size", 18)
	root.add_child(_help)


func _process(_delta: float) -> void:
	for e in _input.poll():
		_handle(e["kind"], e["id"], e["action"])
	_refresh()


func _handle(kind: Seat.DeviceKind, id: int, action: String) -> void:
	var p := model.find(kind, id)
	if p == null:
		if action == "confirm":
			model.add(kind, id)
		elif action == "back" and model.players.is_empty():
			get_tree().change_scene_to_file(MAIN_MENU)
		return
	match action:
		"back": model.remove(p)
		"left": model.move(p, -1)
		"right": model.move(p, 1)
		"up": model.cycle_team(p.kart_slot, -1)
		"down": model.cycle_team(p.kart_slot, 1)
		"swap": model.swap_roles(p.kart_slot)
		"lb": model.set_bots(model.bots - 1)
		"rb": model.set_bots(model.bots + 1)
		"lt": model.set_laps(model.laps - 1)
		"rt": model.set_laps(model.laps + 1)
		"select": model.toggle_friendly_fire()
		"start": start_race()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER: start_race()
		KEY_MINUS, KEY_KP_SUBTRACT: model.set_bots(model.bots - 1)
		KEY_EQUAL, KEY_KP_ADD: model.set_bots(model.bots + 1)
		KEY_BRACKETLEFT: model.set_laps(model.laps - 1)
		KEY_BRACKETRIGHT: model.set_laps(model.laps + 1)
		KEY_F: model.toggle_friendly_fire()
		KEY_ESCAPE: get_tree().change_scene_to_file(MAIN_MENU)


func start_race() -> void:
	if not model.is_valid():
		return
	model.apply_to_session()
	get_tree().change_scene_to_file(RACE)


func _device_name(p: LobbyModel.Player) -> String:
	if p.kind == Seat.DeviceKind.JOYPAD:
		return "Mando %d" % p.device_id
	return "Teclado J%d" % (p.device_id + 1)


func _refresh() -> void:
	for slot in LobbyModel.MAX_KARTS:
		var m := model.members(slot)
		var team: int = model.teams[slot]
		var lines := PackedStringArray(["Kart %d" % (slot + 1)])
		if team >= 0 and not m.is_empty():
			lines.append("Equipo %s" % GameSession.TEAM_NAMES[team])
			_bars[slot].color = GameSession.TEAM_COLORS[team]
		else:
			lines.append("")
			_bars[slot].color = KART_COLORS[slot]
		lines.append("")
		if m.is_empty():
			lines.append("(vacío)")
		for p in m:
			var role := ""
			match model.role_of(p):
				Seat.Role.DRIVER: role = "  [Conductor]"
				Seat.Role.GUNNER: role = "  [Artillero]"
			lines.append(_device_name(p) + role)
		_cols[slot].text = "\n".join(lines)
	_options.text = "Bots: %d (máx. %d)    Vueltas: %d    Fuego amigo: %s    Jugadores: %d" % [
			model.bots, model.max_bots(), model.laps, "sí" if model.friendly_fire else "no", model.players.size()]
	_help.text = "Unirse: A (mando) / Espacio (J1) / K (J2)   ·   Izq/Der: kart   ·   Arriba/Abajo: equipo   ·   Y / E / ; : conductor↔artillero   ·   B / Q / J: salir\n" \
		+ "LB/RB o -/+ : bots   ·   LT/RT o [ ] : vueltas   ·   Select o F: fuego amigo   ·   Start o Enter: iniciar   ·   Esc: menú"
