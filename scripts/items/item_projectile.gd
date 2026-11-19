class_name ItemProjectile
extends ItemData
## Ataques que se lanzan hacia adelante o atrás: proyectil recto, rebotador, teledirigido,
## bomba de área y ola de choque. Toda la lógica está en Projectile; aquí solo los parámetros.

enum Kind { STRAIGHT, BOUNCER, HOMING, BOMB, SHOCKWAVE }

@export var kind: Kind = Kind.STRAIGHT
@export var speed := 45.0
@export var lifetime := 6.0
@export var bounces := 3          ## rebotes máximos (rebotador)
@export var turn_rate := 2.5      ## rad/s (teledirigido)
@export var blast_radius := 6.0   ## bomba y ola de choque
@export var hit_effect: KartEffect
@export var color := Color(0.9, 0.2, 0.2)


func use(kart: Kart, backwards: bool) -> void:
	var p := Projectile.new()
	p.setup(self, kart, backwards)
	kart.get_parent().add_child(p)
	p.launch()
