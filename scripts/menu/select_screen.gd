extends Control
## Selección de personaje (cada jugador) y vehículo (jugador solo / conductor). Muestra las estadísticas
## finales del kart en vivo. Cuando todos están listos arranca la carrera.

const RACE := "res://scenes/race/race.tscn"
const LOBBY := "res://scenes/menu/lobby.tscn"
const TRACK_SELECT := "res://scenes/menu/track_select.tscn"
const AUTO_START_DELAY := 0.8

var model: SelectModel
var _input := MenuInput.new()
var _cards: Array[SelectCard] = []
var _info: Label
var _ready_timer := 0.0


func _ready() -> void:
	if GameSession.setups.is_empty():
		get_tree().change_scene_to_file(LOBBY)
		return
	model = SelectModel.new(GameSession.setups)
	model.restore_choices()
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
	var mode := 0 if model.entries.size() <= 2 else (1 if model.entries.size() <= 4 else 2)
	var grid := GridContainer.new()
	grid.columns = mini(model.entries.size(), 4)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	root.add_child(grid)
	for _e in model.entries:
		var card := SelectCard.new()
		card.build(mode, model.characters, model.vehicles)
		grid.add_child(card)
		_cards.append(card)
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
	get_tree().change_scene_to_file(TRACK_SELECT)


func _device_name(seat: Seat) -> String:
	return InputManager.describe_seat(seat).get_slice(" (", 0)


func _refresh() -> void:
	for idx in model.entries.size():
		var e := model.entries[idx]
		var ch := model.characters[e.char_idx]
		var v := model.vehicle_of(e.kart_index)
		var team: int = model.setups[e.kart_index].get("team", -1)
		var drv := model.driver_character(e.kart_index)
		var gun := model.gunner_character(e.kart_index)
		var body: Color = GameSession.TEAM_COLORS[team] if team >= 0 else v.body_color
		var role := ""
		match e.seat.role:
			Seat.Role.DRIVER: role = " · Conductor"
			Seat.Role.GUNNER: role = " · Artillero"
		_cards[idx].show_state({
			"character": ch, "vehicle": v, "driver": drv, "gunner": gun, "body_color": body,
			"bar_color": GameSession.TEAM_COLORS[team] if team >= 0 else ch.color,
			"header": "Kart %d%s — %s" % [e.kart_index + 1, role, _device_name(e.seat)],
			"ready": e.ready, "char_idx": e.char_idx, "veh_idx": model.kart_vehicle[e.kart_index],
			"veh_locked": e.seat.role == Seat.Role.GUNNER, "delta": model.kart_delta(e.kart_index),
			"synergy": model.synergy_text(e.kart_index),
			"preview_key": "%s:%s:%s:%s" % [v.id, drv.id if drv else "", gun.id if gun else "", body.to_html()],
		})
	var ready_n := 0
	for e in model.entries:
		if e.ready:
			ready_n += 1
	_info.text = "◀ ▶ personaje  ·  ▲ ▼ vehículo (jugador solo / conductor)  ·  A: listo  ·  B: quitar listo  ·  Esc: lobby   —   Listos: %d/%d" % [
			ready_n, model.entries.size()]
