class_name ScaleController
extends RefCounted
## Auto-ajuste de la escala de render: baja si los FPS caen del objetivo y vuelve a subir despacio
## cuando llevan mucho tiempo estables. Se alimenta una vez por segundo con los FPS medidos.

const STEP_DOWN := 0.05
const STEP_UP := 0.025
const DOWN_AFTER := 2     ## s seguidos por debajo del objetivo antes de bajar
const UP_AFTER := 20      ## s seguidos estables antes de intentar subir (tras haber bajado)

var min_scale := 0.4
var max_scale := 1.0
var target_fps := 60.0
var scale := 1.0

var _low_s := 0
var _ok_s := 0


## Llamar una vez por segundo con los FPS actuales. Devuelve la escala nueva.
func tick(fps: float) -> float:
	if fps < target_fps - 2.0:
		_low_s += 1
		_ok_s = 0
		if _low_s >= DOWN_AFTER:
			scale = maxf(scale - STEP_DOWN, min_scale)
			_low_s = 0
	else:
		_low_s = 0
		_ok_s += 1
		if _ok_s >= UP_AFTER and scale < max_scale:
			scale = minf(scale + STEP_UP, max_scale)
			_ok_s = 0
	return scale


func reset(new_scale: float) -> void:
	scale = clampf(new_scale, min_scale, max_scale)
	_low_s = 0
	_ok_s = 0
