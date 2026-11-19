class_name ItemData
extends Resource
## Base de todos los ítems. Cada ítem es un archivo .tres en data/items/.
## Añadir un ítem nuevo = crear otro .tres (de una subclase existente) en esa carpeta; el catálogo lo detecta solo.

enum Category { SPEED, DEFENSE, ATTACK, TRAP, INVINCIBILITY, CHAOS }

@export var id: StringName = &""
@export var display_name := ""
@export var category: Category = Category.SPEED
@export var icon_color := Color.WHITE
@export_range(1, 9) var uses := 1
@export_group("Probabilidad por posición")
@export var weight_front := 0.0  ## peso relativo yendo en 1.º
@export var weight_mid := 1.0    ## a mitad de la clasificación
@export var weight_back := 1.0   ## yendo último (los últimos reciben opciones más fuertes)
@export_group("Defensa")
@export var carried_guard := false  ## mientras se lleva en la mano, absorbe un ataque (trampas)


## Se llama al usar el ítem. backwards = el jugador mantiene "atrás" (stick abajo).
func use(_kart: Kart, _backwards: bool) -> void:
	pass
