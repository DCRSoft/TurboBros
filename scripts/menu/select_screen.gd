extends Control
## Selección de personaje (cada jugador) y vehículo (jugador solo / conductor). Muestra las estadísticas
## finales del kart en vivo. Cuando todos están listos arranca la carrera.

const RACE := "res://scenes/race/race.tscn"
const LOBBY := "res://scenes/menu/lobby.tscn"
const AUTO_START_DELAY := 0.8

var model: SelectModel
var _input := MenuInput.new()
var _cards: Array[Label] = []
var _bars: Array[ColorRect] = []
var _previews: Array[CharacterPreview] = []
var _prev_keys: Array[String] = []
var _info: Label
var _ready_timer := 0.0


func _ready() -> void:
	if GameSession.setups.is_empty():
		get_tree().change_scene_to_file(LOBBY)
		return
	model = SelectModel.new(GameSession.setups)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 16
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var title := Label.new()
	title.text = "Elige personaje y vehículo"
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	root.add_child(grid)
	for e in model.entries:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		panel.add_child(box)
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(0, 8)
		box.add_child(bar)
		_bars.append(bar)
		var preview := CharacterPreview.new()
		preview.custom_minimum_size = Vector2(0, 150 if model.entries.size() <= 4 else 105)
		box.add_child(preview)
		_previews.append(preview)
		_prev_keys.append("")
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 15 if model.entries.size() <= 4 else 13)
		box.add_child(lbl)
		_cards.append(lbl)
		grid.add_child(panel)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 16)
	root.add_child(_info)


func _process(delta: float) -> void:
	if model == null:
		return
	for ev in _input.poll():
		var e := model.find_entry(ev["kind"], ev["id"])
		if e == null:
			continue
		match ev["action"]:
			"left": model.cycle_character(e, -1)
			"right": model.cycle_character(e, 1)
			"up": model.cycle_vehicle(e, -1)
			"down": model.cycle_vehicle(e, 1)
			"confirm": model.toggle_ready(e)
			"back": model.unready(e)
			"start": _try_start()
	if model.all_ready():
		_ready_timer += delta
		if _ready_timer >= AUTO_START_DELAY:
			_start()
	else:
		_ready_timer = 0.0
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER: _try_start()
		KEY_ESCAPE: get_tree().change_scene_to_file(LOBBY)


func _try_start() -> void:
	if model != null and model.all_ready():
		_start()


func _start() -> void:
	set_process(false)
	model.apply()
	get_tree().change_scene_to_file(RACE)


func _bar(v: float) -> String:
	var n := clampi(roundi(absf(v) / 3.0), 0, 5)
	var neg := n if v < 0.0 else 0
	var pos := n if v > 0.0 else 0
	return "-".repeat(neg).lpad(5, ".") + "|" + "+".repeat(pos).rpad(5, ".")


func _device_name(seat: Seat) -> String:
	return InputManager.describe_seat(seat).get_slice(" (", 0)


func _refresh() -> void:
	for idx in model.entries.size():
		var e := model.entries[idx]
		var ch := model.characters[e.char_idx]
		var v := model.vehicle_of(e.kart_index)
		var team: int = model.setups[e.kart_index].get("team", -1)
		_bars[idx].color = GameSession.TEAM_COLORS[team] if team >= 0 else ch.color
		var drv := model.driver_character(e.kart_index)
		var gun := model.gunner_character(e.kart_index)
		var key := "%s:%s:%s" % [v.id, drv.id if drv else "", gun.id if gun else ""]
		if key != _prev_keys[idx]:   # el modelo solo se reconstruye cuando cambia la elección
			_prev_keys[idx] = key
			_previews[idx].show_kart(v, drv, gun, GameSession.TEAM_COLORS[team] if team >= 0 else v.body_color)
		var role := ""
		match e.seat.role:
			Seat.Role.DRIVER: role = " · Conductor"
			Seat.Role.GUNNER: role = " · Artillero"
		var L := PackedStringArray()
		L.append("Kart %d%s    %s" % [e.kart_index + 1, role, "✔ LISTO" if e.ready else ""])
		L.append(_device_name(e.seat))
		L.append("◀ %s ▶" % ch.display_name)
		L.append("")
		if e.seat.role == Seat.Role.GUNNER:
			L.append("Vehículo: %s (lo elige el conductor)" % v.display_name)
		else:
			L.append("▲ Vehículo: %s ▼" % v.display_name)
		L.append("")
		var d := model.kart_delta(e.kart_index)
		for i in StatDelta.KEYS.size():
			L.append("%-17s %s %+.0f%%" % [StatDelta.LABELS[i], _bar(d.get(StatDelta.KEYS[i])), d.get(StatDelta.KEYS[i])])
		var syn := model.synergy_text(e.kart_index)
		if syn != "":
			L.append("")
			L.append(syn)
		_cards[idx].text = "\n".join(L)
		_cards[idx].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_cards[idx].custom_minimum_size = Vector2(280, 0)
	var ready_n := 0
	for e in model.entries:
		if e.ready:
			ready_n += 1
	_info.text = "Izq/Der: personaje · Arriba/Abajo: vehículo (solo/conductor) · A / confirmar: listo · B: quitar listo · Esc: lobby   —   Listos: %d/%d" % [
			ready_n, model.entries.size()]
