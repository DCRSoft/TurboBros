class_name ItemTrap
extends ItemData
## Trampas colocables: aceite, clavos, caja falsa, barrera, mina. Sin soltar, sirven de escudo trasero
## (carried_guard = true). Hacia adelante se colocan 6 m delante; hacia atrás, 3 m detrás.

enum Kind { OIL, NAILS, FAKE_BOX, BARRIER, MINE }

@export var kind: Kind = Kind.OIL
@export var trigger_radius := 2.0
@export var lifetime := 20.0
@export var arm_time := 1.0       ## s antes de que pueda afectar al dueño
@export var consume_on_trigger := false
@export var blast_radius := 0.0   ## > 0: explota afectando a todos en ese radio (mina)
@export var hit_effect: KartEffect
@export var color := Color(0.1, 0.1, 0.1)


func use(kart: Kart, backwards: bool) -> void:
	var t := Trap.new()
	t.setup(self, kart, backwards)
	kart.get_parent().add_child(t)
