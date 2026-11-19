class_name KartStats
extends Resource
## Estadísticas de un vehículo. En el hito 6 el kart final = vehículo + personaje (+ sinergias).

@export_group("Velocidad")
@export var max_speed := 28.0       ## m/s
@export var acceleration := 16.0    ## m/s²
@export var brake_decel := 40.0
@export var reverse_speed := 9.0
@export var coast_drag := 5.0

@export_group("Manejo")
@export var handling := 2.3         ## rad/s de giro a tope
@export var grip := 9.0             ## agarre lateral normal
@export var weight := 1.0

@export_group("Derrape")
@export var drift := 1.0            ## rapidez de carga del mini turbo
@export var drift_grip := 3.0      ## agarre lateral derrapando

@export_group("Golpes")
@export var hit_power := 1.0        ## empuje del golpe (lo aporta el artillero en karts de 2)
@export var item_speed := 1.0       ## rapidez con ítems: acorta la ruleta y la espera entre usos

@export_group("Superficie")
@export var offroad_control := 0.6  ## (se usa cuando existan superficies)
