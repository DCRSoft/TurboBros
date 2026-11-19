extends Node3D
## Pista de prueba del hito 1: terreno plano, rampas y pilares de referencia.

@export var attach_player_input := true

@onready var kart: Kart = $Kart
@onready var cam: ChaseCamera = $ChaseCamera
@onready var hud: DebugHud = $Hud

var _spawn: Transform3D


func _ready() -> void:
	_spawn = kart.global_transform
	_spawn_markers()
	if attach_player_input and kart.controller == null:
		var sc := SeatController.new()
		sc.name = "PlayerController"
		sc.seats.append(InputManager.primary_seat)
		kart.add_child(sc)
		kart.controller = sc
	cam.target = kart
	cam.snap()
	hud.kart = kart


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		kart.respawn(_spawn)


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
