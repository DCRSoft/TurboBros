class_name ItemBox
extends Node3D
## Caja de ítems. Al tocarla un kart sin ítem, éste sortea uno según su posición. Reaparece tras unos segundos.

@export var respawn_time := 5.0
@export var radius := 1.8

var _t := 0.0
var _mesh: MeshInstance3D
var _mark: Label3D
var _clock := 0.0


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = ItemModels.box_mesh(false)   # cubo de cristal azul con marco dorado
	_mesh.position.y = 1.0
	_mesh.scale = Vector3.ONE * 1.1
	add_child(_mesh)
	_mark = Label3D.new()                      # el "?" flota siempre de cara a cada cámara
	_mark.text = "?"
	_mark.font_size = 96
	_mark.pixel_size = 0.012
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.outline_size = 14
	_mark.modulate = Color(1, 1, 1)
	_mark.position.y = 1.0
	add_child(_mark)


func _process(delta: float) -> void:
	_clock += delta
	_mesh.rotate_y(delta * 1.5)
	_mesh.position.y = 1.0 + sin(_clock * 2.2) * 0.12   # sube y baja suavemente
	_mark.position.y = _mesh.position.y

func _physics_process(delta: float) -> void:
	if _t > 0.0:
		_t -= delta
		_mesh.visible = _t <= 0.0
		_mark.visible = _mesh.visible
		return
	for node in get_tree().get_nodes_in_group("karts"):
		var k := node as Kart
		if k == null or k.net_remote or not k.can_pickup():
			continue
		var d := k.sphere.global_position - global_position
		var dy := absf(d.y - 1.0)
		d.y = 0.0
		if d.length() < radius and dy < 2.0:
			k.pickup_item()
			_t = respawn_time
			_mesh.visible = false
			_mark.visible = false
			return
