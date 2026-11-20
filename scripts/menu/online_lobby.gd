extends Control
## Sala en línea: cada PC elige su vehículo y personaje(s) (1 jugador, o 2 = conductor + artillero) y se marca
## "listo". El anfitrión ajusta bots/vueltas/fuego amigo y da la salida cuando todos están listos.

const MAIN_MENU := "res://scenes/menu/main_menu.tscn"

var _input := MenuInput.new()
var _roster_label: Label
var _me_label: Label
var _preview: CharacterPreview
var _track_art: TextureRect
var _portrait: TextureRect
var _preview_key := ""
var _help: Label
var _veh_idx := 0
var _driver_idx := 0
var _gunner_idx := 1
var _seats := 1
var _ready_flag := false
var _vehicles: Array[VehicleData]
var _characters: Array[CharacterData]


func _ready() -> void:
	_vehicles = DataCatalog.vehicles()
	_characters = DataCatalog.characters()
	if not NetSession.online:
		get_tree().change_scene_to_file(MAIN_MENU)
		return
	_gunner_idx = 1 % _characters.size()
	var mem: Dictionary = GameSession.memory.get("online", {})   # la elección de la partida anterior
	for i in _characters.size():
		if String(_characters[i].id) == mem.get("driver", ""):
			_driver_idx = i
		if String(_characters[i].id) == mem.get("gunner", ""):
			_gunner_idx = i
	for i in _vehicles.size():
		if String(_vehicles[i].id) == mem.get("vehicle", ""):
			_veh_idx = i
	_seats = clampi(int(mem.get("seats", 1)), 1, 2)
	if _seats == 2 and InputManager.get_devices().size() < 2:
		_seats = 1
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 16
	root.offset_bottom = -90
	root.add_theme_constant_override("separation", 24)
	add_child(root)
	_roster_label = Label.new()
	_roster_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_label.add_theme_font_size_override("font_size", 20)
	root.add_child(_roster_label)
	var me_box := VBoxContainer.new()
	me_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(me_box)
	_track_art = TextureRect.new()
	_track_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_track_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_track_art.custom_minimum_size = Vector2(0, 170)
	me_box.add_child(_track_art)
	var pv_row := HBoxContainer.new()
	me_box.add_child(pv_row)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(150, 0)
	pv_row.add_child(_portrait)
	_preview = CharacterPreview.new()
	_preview.custom_minimum_size = Vector2(0, 200)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv_row.add_child(_preview)
	_me_label = Label.new()
	_me_label.add_theme_font_size_override("font_size", 16)
	_me_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	me_box.add_child(_me_label)
	_help = Label.new()
	_help.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_help.offset_top = -84
	_help.offset_left = 24
	_help.offset_right = -24
	_help.add_theme_font_size_override("font_size", 16)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.modulate = Color(0.78, 0.8, 0.88)
	add_child(_help)
	NetSession.roster_changed.connect(_refresh)
	NetSession.host_lost.connect(_on_host_lost)
	NetSession.finish_race()  # al volver de una carrera deja todo "no listo"; también vale al entrar
	_push_choice()
	_refresh()


func _exit_tree() -> void:
	if NetSession.roster_changed.is_connected(_refresh):
		NetSession.roster_changed.disconnect(_refresh)
	if NetSession.host_lost.is_connected(_on_host_lost):
		NetSession.host_lost.disconnect(_on_host_lost)


func _on_host_lost(_reason: String) -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _process(_delta: float) -> void:
	for e in _input.poll():
		match e["action"]:
			"left": _change_driver(-1)
			"right": _change_driver(1)
			"lb": _change_gunner(-1)
			"rb": _change_gunner(1)
			"up": _change_vehicle(-1)
			"down": _change_vehicle(1)
			"swap": _toggle_seats()
			"confirm": _toggle_ready()
			"back": _set_ready(false)
			"start": _try_start()
			"lt": _host_laps(-1)
			"rt": _host_laps(1)
			"select": _host_ff()
			"track": _host_track()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
			NetSession.leave()
			get_tree().change_scene_to_file(MAIN_MENU)
		KEY_ENTER, KEY_KP_ENTER: _try_start()
		KEY_COMMA: _change_gunner(-1)
		KEY_PERIOD: _change_gunner(1)
		KEY_MINUS, KEY_KP_SUBTRACT: _host_bots(-1)
		KEY_EQUAL, KEY_KP_ADD: _host_bots(1)
		KEY_BRACKETLEFT: _host_laps(-1)
		KEY_BRACKETRIGHT: _host_laps(1)
		KEY_F: _host_ff()
		KEY_T: _host_track()


# --- Elecciones locales --------------------------------------------------------------------

func _locked() -> bool:
	return _ready_flag


func _change_driver(d: int) -> void:
	if not _locked():
		_driver_idx = posmod(_driver_idx + d, _characters.size())
		_push_choice()


func _change_gunner(d: int) -> void:
	if not _locked() and _seats == 2:
		_gunner_idx = posmod(_gunner_idx + d, _characters.size())
		_push_choice()


func _change_vehicle(d: int) -> void:
	if not _locked():
		_veh_idx = posmod(_veh_idx + d, _vehicles.size())
		_push_choice()


func _toggle_seats() -> void:
	if _locked():
		return
	if _seats == 1 and InputManager.get_devices().size() < 2:
		return  # hacen falta dos dispositivos (p. ej. dos mandos, o mando y teclado)
	_seats = 2 if _seats == 1 else 1
	_push_choice()


func _toggle_ready() -> void:
	_set_ready(not _ready_flag)


func _set_ready(v: bool) -> void:
	_ready_flag = v
	_push_choice()


func _push_choice() -> void:
	GameSession.memory["online"] = {"driver": String(_characters[_driver_idx].id), "gunner": String(_characters[_gunner_idx].id),
			"vehicle": String(_vehicles[_veh_idx].id), "seats": _seats}
	NetSession.set_choice({"seats": _seats, "vehicle": String(_vehicles[_veh_idx].id),
			"driver": String(_characters[_driver_idx].id), "gunner": String(_characters[_gunner_idx].id),
			"ready": _ready_flag})
	_refresh()


# --- Opciones del anfitrión ------------------------------------------------------------------

func _host_bots(d: int) -> void:
	if NetSession.is_host():
		NetSession.set_host_config(NetSession.roster["laps"], int(NetSession.roster["bots"]) + d, NetSession.roster["friendly_fire"])


func _host_laps(d: int) -> void:
	if NetSession.is_host():
		NetSession.set_host_config(int(NetSession.roster["laps"]) + d, NetSession.roster["bots"], NetSession.roster["friendly_fire"])


func _host_track() -> void:
	if NetSession.is_host():
		var all := DataCatalog.tracks()
		var cur := 0
		for i in all.size():
			if String(all[i].id) == String(NetSession.roster.get("track", "")):
				cur = i
		NetSession.set_host_track(String(all[(cur + 1) % all.size()].id))


func _host_ff() -> void:
	if NetSession.is_host():
		NetSession.set_host_config(NetSession.roster["laps"], NetSession.roster["bots"], not NetSession.roster["friendly_fire"])


func _try_start() -> void:
	if NetSession.is_host() and NetSession.can_start():
		NetSession.start_race()


# --- Pantalla ----------------------------------------------------------------------------------

func _refresh() -> void:
	if _roster_label == null:
		return
	var L := PackedStringArray()
	L.append("SALA EN LÍNEA")
	if NetSession.is_host():
		L.append("Eres el anfitrión · tu IP: %s · puerto %d" % [_local_ips(), NetSession.DEFAULT_PORT])
	else:
		L.append("Conectado al anfitrión")
	L.append("")
	var ids: Array = NetSession.roster["peers"].keys()
	ids.sort()
	var me := NetSession.my_id()
	for id in ids:
		var p: Dictionary = NetSession.roster["peers"][id]
		var who := "%s%s" % [p.get("name", "?"), " (tú)" if id == me else ""]
		var drv := DataCatalog.character(StringName(p.get("driver", ""))).display_name
		var veh := DataCatalog.vehicle(StringName(p.get("vehicle", ""))).display_name
		var line := "%s — %s en %s" % [who, drv, veh]
		if int(p.get("seats", 1)) == 2:
			line += "  +  artillero %s" % DataCatalog.character(StringName(p.get("gunner", ""))).display_name
		line += "   [%s]" % ("✔ LISTO" if p.get("ready", false) else "eligiendo…")
		L.append(line)
	L.append("")
	L.append("Pista: %s · Bots: %d · Vueltas: %d · Fuego amigo: %s" % [DataCatalog.track(StringName(NetSession.roster.get("track", ""))).display_name, NetSession.roster["bots"], NetSession.roster["laps"],
			"sí" if NetSession.roster["friendly_fire"] else "no"])
	_roster_label.text = "\n".join(L)
	_track_art.texture = ArtLibrary.track(DataCatalog.track(StringName(NetSession.roster.get("track", ""))).id)
	_portrait.texture = ArtLibrary.character(_characters[_driver_idx].id)

	var pv_gunner: CharacterData = _characters[_gunner_idx] if _seats == 2 else null
	var key := "%s:%s:%s" % [_vehicles[_veh_idx].id, _characters[_driver_idx].id, pv_gunner.id if pv_gunner else ""]
	if key != _preview_key:
		_preview_key = key
		_preview.show_kart(_vehicles[_veh_idx], _characters[_driver_idx], pv_gunner, _vehicles[_veh_idx].body_color)
	var M := PackedStringArray()
	M.append("TU KART")
	M.append("Vehículo: ◀▲ %s ▼" % _vehicles[_veh_idx].display_name)
	M.append(_vehicles[_veh_idx].description)
	M.append("")
	M.append("Personaje: ◀ %s ▶" % _characters[_driver_idx].display_name)
	M.append(_characters[_driver_idx].description)
	if _seats == 2:
		M.append("")
		M.append("Artillero (2.º jugador): LB / RB  ó  , . → %s" % _characters[_gunner_idx].display_name)
	M.append("")
	var d := KartBuild.combine(_vehicles[_veh_idx], _characters[_driver_idx],
			_characters[_gunner_idx] if _seats == 2 else null)
	for i in StatDelta.KEYS.size():
		var v: float = d.get(StatDelta.KEYS[i])
		M.append("%-17s %+.0f%%" % [StatDelta.LABELS[i], v])
	M.append("")
	M.append("Jugadores en esta PC: %d %s" % [_seats, "(Y / E / ; para cambiar)"])
	_me_label.text = "\n".join(M)

	var can := NetSession.is_host() and NetSession.can_start()
	_help.text = "Izq/Der: personaje · Arriba/Abajo: vehículo · Y/E/;: 1 ↔ 2 jugadores en esta PC · A: listo · B: quitar listo · Esc: salir\n" \
		+ ("ANFITRIÓN: -/+ bots · [ ] vueltas · F fuego amigo · T pista · Start/Enter: dar la salida %s" % ("(¡todos listos!)" if can else "(faltan listos o jugadores)")
			if NetSession.is_host() else "Esperando a que el anfitrión dé la salida…")


func _local_ips() -> String:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return ", ".join(out) if not out.is_empty() else "?"
