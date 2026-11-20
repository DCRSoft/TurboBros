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

var _length := -1.0


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
