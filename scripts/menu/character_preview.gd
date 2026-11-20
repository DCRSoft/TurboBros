class_name CharacterPreview
extends SubViewportContainer
## Vista previa 3D giratoria de un kart con su conductor (y artillero). Usa un mundo 3D propio (no se mezcla con
## la escena). Barata: un viewport pequeño con 2-3 mallas.

var _vp: SubViewport
var _pivot: Node3D
var _turn_speed := 0.7


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(200, 140)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.size = Vector2i(400, 280)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.7)
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.1
	_vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 38.0
	_vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.9, 4.6), Vector3(0, 0.75, 0.2), Vector3.UP)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)


func show_kart(vehicle: VehicleData, driver: CharacterData, gunner: CharacterData, body_color: Color) -> void:
	for c in _pivot.get_children():
		c.queue_free()
	_pivot.add_child(KartVisual.build(vehicle, driver, gunner, body_color))
	_pivot.rotation.y = deg_to_rad(-35.0)


func _process(delta: float) -> void:
	if _pivot != null and is_visible_in_tree():
		_pivot.rotate_y(delta * _turn_speed)
