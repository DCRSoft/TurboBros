class_name ItemChaos
extends ItemData
## Efectos de caos sobre los rivales: tinta, controles invertidos, ralentización de los de delante...
## Respeta escudos/estrella/guardias de las víctimas.

enum Target { ALL_OTHERS, AHEAD, BEHIND }

@export var target: Target = Target.ALL_OTHERS
@export var effect: KartEffect


func use(kart: Kart, _backwards: bool) -> void:
	for rival in kart.get_rivals():
		var ok := target == Target.ALL_OTHERS \
				or (target == Target.AHEAD and rival.race_position < kart.race_position) \
				or (target == Target.BEHIND and rival.race_position > kart.race_position)
		if ok:
			rival.take_hit(kart, effect)
