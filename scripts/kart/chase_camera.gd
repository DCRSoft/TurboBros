class_name ChaseCamera
extends Node3D
## Cámara de persecución. Una por viewport (pantalla dividida en el hito 2).

@export var target: Kart
@export var distance := 5.3   ## más cerca que antes para que se vean bien los personajes
@export var height := 2.5
@export var look_height := 1.1
@export var position_lag := 8.0
@export var heading_lag := 3.5
@export var base_fov := 70.0
@export var max_fov_gain := 14.0

var camera: Camera3D
var _dir := Vector3(0.0, 0.0, -1.0)


func _ready() -> void:
	top_level = true
	camera = Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)
	camera.current = true
	_apply_quality()
	GraphicsSettings.changed.connect(_apply_quality)
	snap()


func _exit_tree() -> void:
	if GraphicsSettings.changed.is_connected(_apply_quality):
		GraphicsSettings.changed.disconnect(_apply_quality)


func _apply_quality() -> void:
	camera.far = float(GraphicsSettings.get_value("far"))  # distancia de dibujado según la calidad


func snap() -> void:
	if target == null or camera == null:
		return
	var f := target.get_visual_forward()
	f.y = 0.0
	_dir = f.normalized() if f.length() > 0.01 else _dir
	camera.global_position = target.get_visual_position() - _dir * distance + Vector3.UP * height


func _process(delta: float) -> void:
	if target == null:
		return
	var f := target.get_visual_forward()
	f.y = 0.0
	if f.length() > 0.01:
		f = f.normalized()
		if _dir.dot(f) < -0.99:
			_dir = f
		else:
			_dir = _dir.lerp(f, clampf(delta * heading_lag, 0.0, 1.0)).normalized()
	var focus := target.get_visual_position()
	var desired := focus - _dir * distance + Vector3.UP * height
	camera.global_position = camera.global_position.lerp(desired, clampf(delta * position_lag, 0.0, 1.0))
	camera.look_at(focus + Vector3.UP * look_height, Vector3.UP)
	var ratio := clampf(target.get_speed_kmh() / (target.stats.max_speed * 3.6), 0.0, 1.5)
	var fov_goal := base_fov + max_fov_gain * ratio
	camera.fov = lerpf(camera.fov, fov_goal, clampf(delta * 4.0, 0.0, 1.0))
