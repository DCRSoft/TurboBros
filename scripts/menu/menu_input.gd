class_name MenuInput
extends RefCounted
## Navegación de menús con cualquier dispositivo. poll() devuelve los eventos "de borde" de este fotograma:
## [{"kind": Seat.DeviceKind, "id": int, "action": "left"|"right"|"up"|"down"|"confirm"|"back"|"swap"|
##   "start"|"select"|"lb"|"rb"|"lt"|"rt"}]. Ignora lo que ya estaba pulsado al abrir la pantalla.

const BUTTONS: Array[String] = ["confirm", "back", "swap", "start", "select", "lb", "rb", "lt", "rt"]

var _prev := {}
var _warmup := true


func poll() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for dev in InputManager.get_devices():
		var key := "%d:%d" % [dev["kind"], dev["id"]]
		var cur := InputManager.read_menu(dev["kind"], dev["id"])
		var prev: Dictionary = _prev.get(key, {})
		if not _warmup:
			for b in BUTTONS:
				if cur[b] and not prev.get(b, false):
					out.append({"kind": dev["kind"], "id": dev["id"], "action": b})
			_axis(dev, cur, prev, "x", "left", "right", out)
			_axis(dev, cur, prev, "y", "up", "down", out)
		_prev[key] = cur
	_warmup = false
	return out


func _axis(dev: Dictionary, cur: Dictionary, prev: Dictionary, axis: String, neg: String, pos: String,
		out: Array[Dictionary]) -> void:
	var v: float = cur[axis]
	var pv: float = prev.get(axis, 0.0)
	if absf(v) > 0.6 and absf(pv) <= 0.6:
		out.append({"kind": dev["kind"], "id": dev["id"], "action": pos if v > 0.0 else neg})
