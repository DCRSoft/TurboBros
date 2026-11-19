extends Node3D
## Pista de prueba: terreno plano, rampas y pilares de referencia. 1-4 karts en pantalla dividida.
## Si GameSession.setups trae datos del lobby se usan; si no, modo depuración (F1-F4, un asiento por kart).

const KART_SCENE: PackedScene = preload("res://scenes/kart/kart.tscn")
const MAX_PLAYERS := 4
const BODY_COLORS: Array[Color] = [
	Color(0.85, 0.15, 0.15), Color(0.2, 0.4, 0.9), Color(0.2, 0.75, 0.3), Color(0.95, 0.8, 0.15),
]

@export var attach_player_input := true
@export_range(1, 4) var player_count := 1
@export_range(0.25, 1.0, 0.05) var render_scale := 1.0

@onready var split: SplitScreen = $UI/SplitScreen

var karts: Array[Kart] = []
var seats: Array[Seat] = []        ## todos los asientos (plano)
var _debug_mode := true
var _spawns: Array[Transform3D] = []


func _ready() -> void:
	_spawn_markers()
	split.render_scale = render_scale
	InputManager.devices_changed.connect(_on_devices_changed)
	if GameSession.setups.is_empty():
		set_player_count(player_count)
	else:
		_debug_mode = false
		build_from_setups(GameSession.setups)


func _on_devices_changed() -> void:
	if _debug_mode:
		InputManager.assign_devices(seats)


## Modo depuración: n karts, cada uno con un asiento SOLO y dispositivos por orden.
func set_player_count(n: int) -> void:
	player_count = clampi(n, 1, MAX_PLAYERS)
	var debug_seats: Array[Seat] = []
	for i in player_count:
		debug_seats.append(Seat.new())
	InputManager.assign_devices(debug_seats)
	var setups: Array[Dictionary] = []
	for i in player_count:
		var group: Array[Seat] = [debug_seats[i]]
		setups.append({"slot": i, "seats": group})
	build_from_setups(setups)
	seats = debug_seats


## setups: [{"slot": int, "seats": Array[Seat]}, ...] (formato de LobbyModel.build_setups).
func build_from_setups(setups: Array[Dictionary]) -> void:
	for k in karts:
		remove_child(k)
		k.queue_free()
	karts.clear()
	seats.clear()
	_spawns.clear()
	var groups: Array = []
	var n := setups.size()
	for i in n:
		var k: Kart = KART_SCENE.instantiate()
		var t := _spawn_transform(i, n)
		k.transform = t
		_spawns.append(t)
		add_child(k)
		k.set_body_color(BODY_COLORS[setups[i]["slot"] % BODY_COLORS.size()])
		var kart_seats: Array[Seat] = []
		kart_seats.assign(setups[i]["seats"])
		if attach_player_input:
			var sc := SeatController.new()
			sc.name = "PlayerController"
			sc.seats.assign(kart_seats)
			k.add_child(sc)
			k.controller = sc
		seats.append_array(kart_seats)
		groups.append(kart_seats)
		karts.append(k)
	split.setup(karts, groups)


func set_render_scale(s: float) -> void:
	render_scale = clampf(s, 0.25, 1.0)
	split.render_scale = render_scale


func respawn_all() -> void:
	for i in karts.size():
		karts[i].respawn(_spawns[i])


func _spawn_transform(i: int, n: int) -> Transform3D:
	var x := 0.0 if n == 1 else (-3.0 if i % 2 == 0 else 3.0)
	var z := 70.0 + floorf(i / 2.0) * 6.0
	return Transform3D(Basis.IDENTITY, Vector3(x, 0.6, z))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_R: respawn_all()
		KEY_ESCAPE:
			GameSession.setups.clear()
			get_tree().change_scene_to_file("res://scenes/menu/lobby.tscn")
		KEY_F1: _debug_players(1)
		KEY_F2: _debug_players(2)
		KEY_F3: _debug_players(3)
		KEY_F4: _debug_players(4)
		KEY_BRACKETLEFT: set_render_scale(render_scale - 0.1)
		KEY_BRACKETRIGHT: set_render_scale(render_scale + 0.1)


func _debug_players(n: int) -> void:
	if _debug_mode:
		set_player_count(n)


func _spawn_markers() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 3, 1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.95)
	mesh.material = mat
	for ix in range(-80, 81, 20):
		for iz in range(-80, 81, 20):
			if absi(ix) < 15 and iz < 0:
				continue  # deja libre el pasillo de la rampa grande
			if absi(ix) == 30 and absi(iz) < 15:
				continue  # rampas laterales
			var m := MeshInstance3D.new()
			m.mesh = mesh
			m.position = Vector3(ix, 1.5, iz)
			add_child(m)
