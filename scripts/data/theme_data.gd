class_name ThemeData
extends Resource
## Tema visual de una pista: cielo, niebla, colores del terreno y la carretera, montañas y decorado.
## Los temas son datos (data/themes/*.tres, generados por tools/generate_tracks.gd).

@export var id: StringName = &""
@export var display_name := ""

@export_group("Cielo y luz")
@export var sky_top := Color(0.35, 0.55, 0.9)
@export var sky_horizon := Color(0.75, 0.85, 0.95)
@export var ground_horizon := Color(0.6, 0.7, 0.6)
@export var ambient := Color(0.62, 0.64, 0.7)
@export var fog_color := Color(0.7, 0.8, 0.9)
@export var fog_density := 0.0016
@export var sun_color := Color(1.0, 0.96, 0.88)
@export var sun_energy := 1.0
@export var sun_rotation := Vector3(-50, 35, 0)   ## grados

@export_group("Terreno")
@export var ground_low := Color(0.3, 0.5, 0.25)
@export var ground_high := Color(0.45, 0.55, 0.3)
@export var rock := Color(0.5, 0.48, 0.45)
@export var accent := Color(0.95, 0.96, 1.0)      ## nieve / arena clara en las cimas
@export var amplitude := 22.0                      ## altura de las colinas (m)
@export var feature_size := 120.0                  ## tamaño de las colinas (m)
@export var snow_line := 0.0                       ## 0 = sin nieve; si no, altura relativa desde la que se pinta "accent"

@export_group("Carretera")
@export var road_a := Color(0.24, 0.24, 0.27)
@export var road_b := Color(0.29, 0.29, 0.32)
@export var curb_a := Color(0.9, 0.15, 0.15)
@export var curb_b := Color(0.95, 0.95, 0.95)
@export var wall := Color(0.75, 0.3, 0.25)

@export_group("Montañas lejanas")
@export var mountain := Color(0.4, 0.45, 0.55)
@export var mountain_cap := Color(0.95, 0.96, 1.0)
@export var mountain_count := 22

@export_group("Decorado")
## Cada elemento: {"kind": String, "density": float (por hectárea), "min": float, "max": float, "tint": Color}
@export var props: Array[Dictionary] = []
## Elementos a pie de pista, uno cada ~36 m alternando lados: "banner", "tires", "lamp"
@export var trackside: Array[String] = ["banner", "tires", "lamp"]
@export var banner_color := Color(0.9, 0.2, 0.2)
