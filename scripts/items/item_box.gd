class_name ItemBox
extends Node3D
## Caja de ítems. Al tocarla un kart sin ítem, éste sortea uno según su posición. Reaparece tras unos segundos.

@export var respawn_time := 5.0
@export var radius := 1.8

var _t := 0.0
var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 1.2
	_mesh.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.1)
	_mesh.material_override = mat
	_mesh.position.y = 1.0
	add_child(_mesh)


func _process(delta: float) -> void:
	_mesh.rotate_y(delta * 1.5)


func _physics_process(delta: float) -> void:
	if _t > 0.0:
		_t -= delta
		_mesh.visible = _t <= 0.0
		return
	for node in get_tree().get_nodes_in_group("karts"):
		var k := node as Kart
		if k == null or not k.can_pickup():
			continue
		var d := k.sphere.global_position - global_position
		var dy := absf(d.y - 1.0)
		d.y = 0.0
		if d.length() < radius and dy < 2.0:
			k.pickup_item()
			_t = respawn_time
			_mesh.visible = false
			return
