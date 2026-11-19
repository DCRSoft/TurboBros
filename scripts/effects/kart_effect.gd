class_name KartEffect
extends Resource
## Efecto temporal sobre un kart. UN SOLO tipo basado en datos: turbos, escudos, estrella, tinta, aceite,
## controles invertidos, giro por golpe... son archivos .tres de este recurso (data/effects/).
## Para añadir un efecto nuevo basta crear otro .tres; no hay que tocar el código del kart.

enum Stack {
	REFRESH,  ## si ya está activo, renueva el tiempo (por defecto)
	STACK,    ## instancias independientes
	IGNORE,   ## si ya está activo, no hace nada
}

@export var id: StringName = &""
@export var display_name := ""
@export var duration := 3.0
@export var stack: Stack = Stack.REFRESH

@export_group("Modificadores")
@export var speed_mult := 1.0
@export var accel_mult := 1.0
@export var steer_mult := 1.0     ## -1 = controles invertidos
@export var grip_mult := 1.0
@export var scale_mult := 1.0     ## tamaño visual (gigante)
@export var mass_mult := 1.0

@export_group("Estados")
@export var force_throttle := false  ## acelera solo (turbos, cohete)
@export var lock_control := false    ## ignora la entrada (giro por golpe)
@export var spin := false            ## el kart gira sobre sí mismo (visual)
@export var immune := false          ## inmune a ataques
@export var ghost := false           ## atraviesa karts y es inmune
@export var touch_hit := false       ## golpea a los karts que toca (estrella, gigante)
@export var reflect := false         ## devuelve proyectiles
@export var ink := false             ## tinta en la pantalla de la víctima

@export_group("Defensa")
@export var guard_charges := 0       ## ataques normales que absorbe (orbitales); 0 = no es guardia

@export_group("Visual")
@export var bubble_color := Color(0, 0, 0, 0)  ## burbuja alrededor del kart si alpha > 0
