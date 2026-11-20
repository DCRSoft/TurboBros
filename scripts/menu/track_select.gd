extends Control
## Elección de pista tras elegir personajes: cuadrícula con el mapa de cada pista y su ficha (nombre, descripción,
## largo, tema y vueltas). Cualquier jugador mueve la selección; confirmar o Start arranca la carrera.

const RACE := "res://scenes/race/race.tscn"
const SELECT := "res://scenes/menu/select.tscn"
const COLUMNS := 5

var tracks: Array[TrackData] = []
var index := 0
var laps := 3
var _input := MenuInput.new()
var _tiles: Array[PanelContainer] = []
var _styles: Array[StyleBoxFlat] = []
var _big: TextureRect
var _name: Label
var _desc: Label
var _facts: Label
var _help: Label
var _ready_to_go := false


func _ready() -> void:
	tracks = DataCatalog.tracks()
	for i in tracks.size():
		if tracks[i].id == GameSession.track_id:
			index = i
	laps = clampi(GameSession.laps, 1, LobbyModel.MAX_LAPS)
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
	title.text = "Elige la pista"
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	for t in tracks:
		var tile := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.set_border_width_all(4)
		st.set_corner_radius_all(6)
		st.set_content_margin_all(2)
		tile.add_theme_stylebox_override("panel", st)
		var tr := TextureRect.new()
		tr.texture = ArtLibrary.track(t.id)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(150, 170)
		tile.add_child(tr)
		grid.add_child(tile)
		_tiles.append(tile)
		_styles.append(st)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(340, 0)
	side.add_theme_constant_override("separation", 8)
	body.add_child(side)
	_big = TextureRect.new()
	_big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_big.custom_minimum_size = Vector2(340, 340)
	side.add_child(_big)
	_name = _label(side, 26, Color.WHITE)
	_desc = _label(side, 15, Color(0.75, 0.78, 0.88))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_facts = _label(side, 17, Color(1.0, 0.85, 0.4))
	_facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help = _label(root, 17, Color(0.85, 0.87, 0.95))
	_refresh()


func _label(parent: Node, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _process(_delta: float) -> void:
	for ev in _input.poll():
		match ev["action"]:
			"left": move(-1, 0)
			"right": move(1, 0)
			"up": move(0, -1)
			"down": move(0, 1)
			"lb": set_laps(laps - 1)
			"rb": set_laps(laps + 1)
			"confirm", "start": start_race()
			"back": go_back()
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER: start_race()
			KEY_ESCAPE: go_back()
			KEY_MINUS, KEY_BRACKETLEFT: set_laps(laps - 1)
			KEY_EQUAL, KEY_BRACKETRIGHT: set_laps(laps + 1)


## Mueve la selección por la cuadrícula (se envuelve por los bordes).
func move(dx: int, dy: int) -> void:
	var n := tracks.size()
	var rows := ceili(float(n) / COLUMNS)
	var col := posmod(index % COLUMNS + dx, COLUMNS)
	var row := posmod(index / COLUMNS + dy, rows)
	index = clampi(row * COLUMNS + col, 0, n - 1)


func set_laps(n: int) -> void:
	laps = clampi(n, 1, LobbyModel.MAX_LAPS)


func start_race() -> void:
	if _ready_to_go:
		return
	_ready_to_go = true
	set_process(false)
	GameSession.track_id = tracks[index].id
	GameSession.laps = laps
	var lobby: Dictionary = GameSession.memory.get("lobby", {})
	lobby["track"] = String(tracks[index].id)
	lobby["laps"] = laps
	GameSession.memory["lobby"] = lobby
	get_tree().change_scene_to_file(RACE)


func go_back() -> void:
	set_process(false)
	get_tree().change_scene_to_file(SELECT)


func _refresh() -> void:
	for i in tracks.size():
		_styles[i].border_color = Color(1, 1, 1) if i == index else Color(0.2, 0.22, 0.3)
		_styles[i].bg_color = Color(0.2, 0.5, 0.9) if i == index else Color(0.12, 0.13, 0.18)
		_tiles[i].modulate = Color.WHITE if i == index else Color(0.75, 0.75, 0.8)
	var t := tracks[index]
	_big.texture = ArtLibrary.track(t.id)
	_name.text = t.display_name
	_desc.text = t.description
	var theme := DataCatalog.theme(t.theme)
	_facts.text = "Largo: %.1f km  ·  Vueltas: %d  ·  Ambiente: %s" % [t.length_m() / 1000.0, laps, theme.display_name]
	_help.text = "Mover: stick / flechas  ·  LB/RB o - / + : vueltas  ·  A / Enter: ¡a correr!  ·  B / Esc: volver"
