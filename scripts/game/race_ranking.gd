class_name RaceRanking
extends RefCounted
## Clasificación provisional por race_progress (hito 5: vueltas y checkpoints).


static func update(karts: Array[Kart]) -> void:
	var sorted := karts.duplicate()
	sorted.sort_custom(func(a: Kart, b: Kart) -> bool: return a.race_progress > b.race_progress)
	for i in sorted.size():
		sorted[i].race_position = i + 1
		sorted[i].race_total = sorted.size()
