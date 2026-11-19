extends Node3D
## Pista de prueba: terreno plano, rampas y pilares de referencia. Soporta 1-4 karts en pantalla dividida.

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
var seats: Array[Seat] = []
var _spawns: Array[Transform3D] = []


func _ready() -> void:
	_spawn_markers()
	split.render_scale = render_scale
	InputManager.devices_changed.connect(func() -> void: InputManager.assign_devices(seats))
	set_player_count(player_count)


func set_player_count(n: int) -> void:
	player_count = clampi(n, 1, MAX_PLAYERS)
	for k in karts:
		remove_child(k)
		k.queue_free()
	karts.clear()
	seats.clear()
	_spawns.clear()
	for i in player_count:
		seats.append(Seat.new())
	InputManager.assign_devices(seats)
	for i in player_count:
		var k: Kart = KART_SCENE.instantiate()
		var t := _spawn_transform(i, player_count)
		k.transform = t
		_spawns.append(t)
		add_child(k)
		k.set_body_color(BODY_COLORS[i])
		if attach_player_input:
			var sc := SeatController.new()
			sc.name = "PlayerController"
			sc.seats.append(seats[i])
			k.add_child(sc)
			k.controller = sc
		karts.append(k)
	split.setup(karts, seats)


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
		KEY_F1: set_player_count(1)
		KEY_F2: set_player_count(2)
		KEY_F3: set_player_count(3)
		KEY_F4: set_player_count(4)
		KEY_BRACKETLEFT: set_render_scale(render_scale - 0.1)
		KEY_BRACKETRIGHT: set_render_scale(render_scale + 0.1)


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
