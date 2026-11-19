class_name ItemSelfEffect
extends ItemData
## Aplica uno o más efectos al propio kart: turbos, cohete, escudos, orbitales, burbuja reflectante,
## estrella, fantasma, gigante...

@export var effects: Array[KartEffect] = []


func use(kart: Kart, _backwards: bool) -> void:
	for e in effects:
		kart.fx.add(e)
		if e.force_throttle:
			kart.boost_started.emit(e.id, e.duration)
