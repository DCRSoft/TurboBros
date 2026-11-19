extends Node
## Datos que el lobby entrega a la carrera.
## setups: un elemento por kart humano -> {"slot": int (0-3, define el color), "seats": Array[Seat]}
## Vacío = modo depuración de la pista (F1-F4).

var setups: Array[Dictionary] = []
