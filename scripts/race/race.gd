extends Node3D
## Carrera: monta circuito, karts humanos (con vista) y bots (sin vista) a partir de GameSession (local)
## o de NetSession.spec (en línea: 1 vista, el kart local + marionetas de los demás equipos).
## Sin datos del lobby arranca en modo demostración (1 humano + 3 bots).

const KART_SCENE: PackedScene = preload("res://scenes/kart/kart.tscn")
const LOBBY := "res://scenes/menu/lobby.tscn"
const MAIN_MENU := "res://scenes/menu/main_menu.tscn"
const HUMAN_COLORS: Array[Color] = [
	Color(0.85, 0.15, 0.15), Color(0.2, 0.4, 0.9), Color(0.2, 0.75, 0.3), Color(0.95, 0.8, 0.15),
]
const BOT_COLORS: Array[Color] = [
	Color(0.6, 0.3, 0.85), Color(0.95, 0.5, 0.1), Color(0.2, 0.8, 0.8), Color(0.9, 0.9, 0.9),
	Color(0.9, 0.4, 0.6), Color(0.5, 0.35, 0.2), Color(0.4, 0.4, 0.45), Color(0.7, 0.85, 0.2),
]

@export var attach_player_input := true
@export var autopilot_humans := false  ## pruebas/demo: los karts humanos los conduce la IA
@export var demo_bots := 3
@export_range(0.25, 1.0, 0.05) var render_scale := 1.0

@onready var circuit: Circuit = $Circuit
@onready var manager: RaceManager = $RaceManager
@onready var split: SplitScreen = $UI/SplitScreen
@onready var results: ResultsScreen = $Results

var karts: Array[Kart] = []
var human_karts: Array[Kart] = []   ## karts con vista en ESTE equipo
var bot_karts: Array[Kart] = []
var net_sync: NetSync
var pause_menu: PauseMenu
var _online := false


func _ready() -> void:
	_apply_graphics()
	GraphicsSettings.changed.connect(_apply_graphics)
	split.render_scale = render_scale
	_online = NetSession.online and not NetSession.spec.is_empty()
	var groups: Array = []
	var laps := GameSession.laps
	if _online:
		laps = int(NetSession.spec["laps"])
		groups = _build_online()
	else:
		groups = _build_offline()

	AudioManager.stop_engines()
	for hk in human_karts:
		AudioManager.attach_kart(hk)
	AudioManager.attach_race(manager)
	manager.setup(circuit, karts, laps)
	split.setup(human_karts, groups, manager)
	manager.race_finished.connect(func(_r: Array) -> void: results.show_results(manager))
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.setup(manager, _online)
	for pos in circuit.item_box_positions():
		var box := ItemBox.new()
		box.position = pos
		add_child(box)
	if _online:
		net_sync = NetSync.new()
		net_sync.name = "NetSync"
		add_child(net_sync)
		net_sync.setup(karts, manager)
		NetSession.begin_race.connect(manager.start)
		NetSession.host_lost.connect(_on_host_lost)
		NetSession.report_loaded()  # cuando todos hayan cargado el anfitrión da la salida
	else:
		manager.start()


# --- Local ---------------------------------------------------------------------------------

func _build_offline() -> Array:
	var setups: Array[Dictionary] = GameSession.setups
	var bot_teams: Array[int] = GameSession.bot_teams
	if setups.is_empty():
		var seat := Seat.new()
		var tmp: Array[Seat] = [seat]
		InputManager.assign_devices(tmp)
		setups = [{"slot": 0, "seats": tmp, "team": -1}]
		bot_teams = []
		for _b in demo_bots:
			bot_teams.append(-1)
	if GameSession.benchmark:
		autopilot_humans = true
	var groups: Array = []
	var humans := setups.size()
	var bots := mini(bot_teams.size(), GameSession.MAX_KARTS - humans)
	var grid := 0
	for i in humans:
		var team: int = setups[i]["team"]
		var kart_seats: Array[Seat] = []
		kart_seats.assign(setups[i]["seats"])
		var vehicle := DataCatalog.vehicle(setups[i].get("vehicle", &""))
		var driver: CharacterData = null
		var gunner: CharacterData = null
		for s in kart_seats:
			var ch := DataCatalog.character(s.character_id)
			if s.role == Seat.Role.GUNNER:
				gunner = ch
			else:
				driver = ch
		var k := _spawn(grid, _color(team, vehicle.body_color), vehicle, driver, gunner)
		grid += 1
		k.team = team
		k.racer_name = "Kart %d (%s)" % [int(setups[i]["slot"]) + 1, driver.display_name]
		if autopilot_humans:
			_attach_bot(k, i)
		elif attach_player_input:
			_attach_player(k, kart_seats)
		groups.append(kart_seats)
		human_karts.append(k)
	var pick := RandomNumberGenerator.new()
	pick.randomize()
	var all_v := DataCatalog.vehicles()
	var all_c := DataCatalog.characters()
	for b in bots:
		var team := bot_teams[b]
		var vehicle := all_v[pick.randi() % all_v.size()]
		var driver := all_c[pick.randi() % all_c.size()]
		var k := _spawn(grid, _color(team, vehicle.body_color), vehicle, driver, null)
		grid += 1
		k.team = team
		k.is_bot = true
		k.racer_name = "Bot %d (%s)" % [b + 1, driver.display_name]
		_attach_bot(k, humans + b)
		bot_karts.append(k)
	return groups


# --- En línea --------------------------------------------------------------------------------

## Un kart por entrada de la especificación (mismo orden en todos los equipos = parrilla). El del equipo local lo
## controla este equipo; los bots los simula el anfitrión; el resto son marionetas.
func _build_online() -> Array:
	var spec: Dictionary = NetSession.spec
	var my := NetSession.my_id()
	var groups: Array = []
	for e in spec["karts"]:
		var vehicle := DataCatalog.vehicle(StringName(e["vehicle"]))
		var driver := DataCatalog.character(StringName(e["driver"]))
		var gunner: CharacterData = DataCatalog.character(StringName(e["gunner"])) if e["gunner"] != "" else null
		var id: int = e["kart_id"]
		var owner_id: int = e["owner"]
		var k := _spawn(id, _color(int(e["team"]), vehicle.body_color), vehicle, driver, gunner)
		k.net_id = id
		k.net_owner = owner_id
		k.is_bot = e["bot"]
		k.friendly_fire = bool(spec["friendly_fire"])
		k.racer_name = "%s (%s)" % [e["name"], driver.display_name]
		var local := owner_id == my
		if local and not e["bot"]:
			if NetSession.test_autopilot:
				_attach_bot(k, id)
			else:
				_attach_player(k, NetSession.local_seats)
			groups.append(NetSession.local_seats.duplicate())
			human_karts.append(k)
		elif local and e["bot"]:
			_attach_bot(k, id)   # bots: solo en el anfitrión
			bot_karts.append(k)
		else:
			k.make_remote()
			if e["bot"]:
				bot_karts.append(k)
	return groups


func _on_host_lost(_reason: String) -> void:
	AudioManager.stop_engines()
	get_tree().change_scene_to_file(MAIN_MENU)


# --- Comunes ------------------------------------------------------------------------------------

func _apply_graphics() -> void:
	GraphicsSettings.apply_to_scene(self)


func _color(team: int, fallback: Color) -> Color:
	return GameSession.TEAM_COLORS[team] if team >= 0 else fallback


func _spawn(grid_slot: int, color: Color, vehicle: VehicleData, driver: CharacterData, gunner: CharacterData) -> Kart:
	var k: Kart = KART_SCENE.instantiate()
	k.transform = circuit.grid_transform(grid_slot)
	k.friendly_fire = GameSession.friendly_fire
	k.stats = KartBuild.to_kart_stats(KartBuild.combine(vehicle, driver, gunner))
	k.character = driver
	add_child(k)
	k.apply_look(vehicle, driver, gunner, color)
	karts.append(k)
	return k


func _attach_player(k: Kart, kart_seats: Array) -> void:
	var sc := SeatController.new()
	sc.name = "PlayerController"
	sc.seats.assign(kart_seats)
	k.add_child(sc)
	k.controller = sc


func _attach_bot(k: Kart, index: int) -> void:
	var bot := BotController.new()
	bot.name = "Bot"
	bot.setup(k, circuit, manager, index)
	k.add_child(bot)
	k.controller = bot


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_R:
			for k in human_karts:
				manager.respawn_kart(k)
		KEY_BRACKETLEFT: split.render_scale -= 0.1
		KEY_BRACKETRIGHT: split.render_scale += 0.1
