class_name StatDelta
extends Resource
## Bonos/penalizaciones en % sobre las estadísticas base (0 = sin cambio). Los usan vehículos, personajes
## y sinergias; el kart final es la suma de todos ellos (ver KartBuild).

@export var speed := 0.0         ## velocidad máxima
@export var acceleration := 0.0
@export var handling := 0.0      ## manejo (giro)
@export var weight := 0.0        ## peso: más peso = menos empuje de golpes y choques más fuertes
@export var drift := 0.0         ## rapidez de carga del mini turbo
@export var offroad := 0.0       ## control fuera de pista
@export var hit_power := 0.0     ## fuerza de golpe
@export var item_speed := 0.0    ## rapidez con ítems (ruleta y recarga)

const KEYS: Array[String] = ["speed", "acceleration", "handling", "weight", "drift", "offroad",
		"hit_power", "item_speed"]
const LABELS: Array[String] = ["Velocidad", "Aceleración", "Manejo", "Peso", "Derrape", "Fuera de pista",
		"Fuerza de golpe", "Rapidez con ítems"]


static func make(s: float, a: float, h: float, w: float, d: float, o: float, hit := 0.0, item := 0.0) -> StatDelta:
	var r := StatDelta.new()
	r.speed = s
	r.acceleration = a
	r.handling = h
	r.weight = w
	r.drift = d
	r.offroad = o
	r.hit_power = hit
	r.item_speed = item
	return r


func add(o: StatDelta, scale := 1.0) -> void:
	if o == null:
		return
	for k in KEYS:
		set(k, get(k) + o.get(k) * scale)


func copy() -> StatDelta:
	var r := StatDelta.new()
	r.add(self)
	return r
