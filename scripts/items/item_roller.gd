class_name ItemRoller
extends RefCounted
## Sorteo de ítems según la posición: weight_front en 1.º, weight_mid a mitad, weight_back en el último.


static func weight_for(item: ItemData, position: int, total: int) -> float:
	var frac := 0.0 if total <= 1 else clampf((position - 1.0) / (total - 1.0), 0.0, 1.0)
	if frac <= 0.5:
		return lerpf(item.weight_front, item.weight_mid, frac * 2.0)
	return lerpf(item.weight_mid, item.weight_back, (frac - 0.5) * 2.0)


static func roll(position: int, total: int, rng: RandomNumberGenerator = null) -> ItemData:
	var items := ItemCatalog.all()
	var sum := 0.0
	for it in items:
		sum += maxf(weight_for(it, position, total), 0.0)
	if sum <= 0.0:
		return null
	var r := (rng.randf() if rng else randf()) * sum
	for it in items:
		r -= maxf(weight_for(it, position, total), 0.0)
		if r <= 0.0:
			return it
	return items[items.size() - 1]
