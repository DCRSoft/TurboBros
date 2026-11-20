extends Node
## Datos que el lobby entrega a la carrera.
## setups: un elemento por kart humano -> {"slot": int (0-3), "seats": Array[Seat], "team": int (-1 = sin equipo)}
## Vacío = la carrera arranca en modo demostración (1 kart humano + 3 bots).

const TEAM_NAMES: Array[String] = ["Rojo", "Azul", "Verde", "Amarillo"]
const TEAM_COLORS: Array[Color] = [
	Color(0.9, 0.15, 0.15), Color(0.2, 0.4, 0.95), Color(0.2, 0.75, 0.3), Color(0.95, 0.8, 0.15),
]
const MAX_TEAM_SIZE := 4
const MAX_KARTS := 8

var setups: Array[Dictionary] = []
var bot_teams: Array[int] = []   ## un elemento por bot (-1 = sin equipo)
var laps := 3
var track_id: StringName = &""   ## pista elegida en el lobby (vacío = la primera); no se borra con reset()
var friendly_fire := false
## Memoria de la sesión (no la borra reset()): jugadores activos y sus elecciones, para no empezar de cero en cada carrera.
## {"lobby": {...}, "chars": {"tipo:dispositivo": id_personaje}, "vehicles": {"tipo:dispositivo": id_vehiculo}}
var memory := {}
var benchmark := false   ## prueba de rendimiento: 4 vistas + 4 bots, todos conducidos por la IA


func reset() -> void:
	setups.clear()
	bot_teams.clear()
	laps = 3
	friendly_fire = false
	benchmark = false


## 4 karts "humanos" (con vista, sin dispositivo, pilotados por la IA) + 4 bots, 3 vueltas.
func setup_benchmark() -> void:
	reset()
	benchmark = true
	for i in 4:
		var seats: Array[Seat] = [Seat.new()]
		setups.append({"slot": i, "seats": seats, "team": -1})
	for _b in 4:
		bot_teams.append(-1)
