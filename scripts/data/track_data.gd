class_name TrackData
extends Resource
## Una pista: el trazado (puntos de control de una curva cerrada, el índice 0 es la meta, la carrera va hacia
## puntos crecientes), la anchura y el tema visual. Datos puros: crear una pista = crear un .tres.

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var theme: StringName = &"bosque"
@export var control_points := PackedVector3Array()
@export var road_half_width := 8.0
@export var default_laps := 3
## Elementos del trazado: [{"type": "turbo"|"ramp"|"bridge"|"tunnel", "f": 0..1 (posición de inicio como fracción de la
## vuelta), "len": metros (puente/túnel/rampa), "lat": -1..1 (lado, solo turbo/rampa), "hazard": "water"|"lava"|"void" (puente)}]
@export var features: Array[Dictionary] = []

var _length := -1.0
var _dense := PackedVector3Array()
var _cum := PackedFloat32Array()


## Largo aproximado del circuito en metros (suma de la curva Catmull-Rom por los puntos de control).
func length_m() -> float:
	if _length >= 0.0:
		return _length
	var n := control_points.size()
	var total := 0.0
	if n >= 4:
		var prev := control_points[0]
		for i in n:
			var p0 := control_points[(i - 1 + n) % n]
			var p1 := control_points[i]
			var p2 := control_points[(i + 1) % n]
			var p3 := control_points[(i + 2) % n]
			for s in range(1, 21):
				var t := s / 20.0
				var t2 := t * t
				var t3 := t2 * t
				var q := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
						+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
				total += prev.distance_to(q)
				prev = q
	_length = total
	return total


func _build_dense() -> void:
	if not _dense.is_empty():
		return
	var n := control_points.size()
	_dense.append(control_points[0])
	_cum.append(0.0)
	var total := 0.0
	for i in n:
		var p0 := control_points[(i - 1 + n) % n]
		var p1 := control_points[i]
		var p2 := control_points[(i + 1) % n]
		var p3 := control_points[(i + 2) % n]
		for sub in range(1, 21):
			var t := sub / 20.0
			var t2 := t * t
			var t3 := t2 * t
			var q := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			total += _dense[_dense.size() - 1].distance_to(q)
			_dense.append(q)
			_cum.append(total)


## Fracción de la vuelta (0..1) del punto del trazado más cercano a (x, z); sirve para colocar elementos por coordenadas.
func project_f(x: float, z: float) -> float:
	if control_points.size() < 4:
		return 0.0
	_build_dense()
	var best := INF
	var best_s := 0.0
	for i in _dense.size():
		var dx := _dense[i].x - x
		var dz := _dense[i].z - z
		var d := dx * dx + dz * dz
		if d < best:
			best = d
			best_s = _cum[i]
	return best_s / maxf(_cum[_cum.size() - 1], 1.0)
