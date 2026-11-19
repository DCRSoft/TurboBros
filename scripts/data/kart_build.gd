class_name KartBuild
extends RefCounted
## Estadísticas finales de un kart = base del vehículo + base del personaje + sinergias.
## Kart de 1 jugador: el personaje aporta todo (conducir, golpear, ítems).
## Kart de 2 jugadores: el conductor aporta manejo y demás estadísticas de conducción; el artillero aporta
## fuerza de golpe, rapidez con ítems y la mitad de su peso. Llevar dos personas cuesta un poco de velocidad
## y aceleración.

const DUO_SPEED := -2.0
const DUO_ACCELERATION := -3.0
const GUNNER_WEIGHT_SHARE := 0.5

## Peso de cada estadística en el índice de potencia (suman 1.0). Lo usa el script de equilibrado.
const INDEX_WEIGHTS := {
	"speed": 0.30, "acceleration": 0.17, "handling": 0.17, "drift": 0.13,
	"weight": 0.05, "offroad": 0.05, "hit_power": 0.07, "item_speed": 0.06,
}


## Sinergia vehículo-personaje: bono si le gusta, penalización si no.
static func synergy(vehicle: VehicleData, character: CharacterData) -> StatDelta:
	var d := StatDelta.new()
	if vehicle == null or character == null:
		return d
	if character.likes.has(vehicle.id):
		d.add(character.like_bonus)
	if character.dislikes.has(vehicle.id):
		d.add(character.dislike_penalty)
	return d


static func combine(vehicle: VehicleData, driver: CharacterData, gunner: CharacterData = null) -> StatDelta:
	var d := StatDelta.new()
	if vehicle != null:
		d.add(vehicle.stats)
	if driver != null:
		d.add(driver.stats)
	d.add(synergy(vehicle, driver))
	if gunner != null:
		if driver != null and driver.stats != null:
			d.hit_power -= driver.stats.hit_power  # en un kart de 2, golpea y usa ítems el artillero
			d.item_speed -= driver.stats.item_speed
		if gunner.stats != null:
			d.hit_power += gunner.stats.hit_power
			d.item_speed += gunner.stats.item_speed
			d.weight += gunner.stats.weight * GUNNER_WEIGHT_SHARE
		d.speed += DUO_SPEED
		d.acceleration += DUO_ACCELERATION
	return d


## Convierte los % en estadísticas reales del kart.
static func to_kart_stats(d: StatDelta, base: KartStats = null) -> KartStats:
	var s: KartStats = base.duplicate() if base != null else KartStats.new()
	s.max_speed *= 1.0 + d.speed / 100.0
	s.acceleration *= 1.0 + d.acceleration / 100.0
	s.handling *= 1.0 + d.handling / 100.0
	s.weight *= 1.0 + d.weight / 100.0
	s.drift *= 1.0 + d.drift / 100.0
	s.offroad_control *= 1.0 + d.offroad / 100.0
	s.hit_power *= 1.0 + d.hit_power / 100.0
	s.item_speed *= 1.0 + d.item_speed / 100.0
	return s


## 1.0 = kart base. Media ponderada de las estadísticas finales.
static func power_index(d: StatDelta) -> float:
	var idx := 0.0
	for k in INDEX_WEIGHTS:
		idx += INDEX_WEIGHTS[k] * (1.0 + d.get(k) / 100.0)
	return idx
