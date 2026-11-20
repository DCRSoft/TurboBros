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
