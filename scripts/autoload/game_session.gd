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
var friendly_fire := false


func reset() -> void:
	setups.clear()
	bot_teams.clear()
	laps = 3
	friendly_fire = false
