class_name StatBars
extends Control
## Barras de estadísticas de un kart como cambio % respecto a la base: verde a la derecha (mejor), rojo a la izquierda
## (peor). Una fila por estadística de StatDelta.

const RANGE := 18.0     ## % que llena media barra
var row := 20.0

var _delta: StatDelta


func set_delta(d: StatDelta) -> void:
	_delta = d
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(200, StatDelta.KEYS.size() * row)


func _draw() -> void:
	if _delta == null:
		return
	var font := ThemeDB.fallback_font
	var label_w := 112.0
	var bar_w := size.x - label_w - 52.0
	for i in StatDelta.KEYS.size():
		var v: float = _delta.get(StatDelta.KEYS[i])
		var y := i * row
		draw_string(font, Vector2(0, y + 14), StatDelta.LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, label_w, 13, Color(0.85, 0.87, 0.92))
		var track := Rect2(label_w, y + 4, bar_w, 10)
		draw_rect(track, Color(0.18, 0.2, 0.26))
		var half := bar_w * 0.5
		var frac := clampf(absf(v) / RANGE, 0.0, 1.0)
		if v >= 0.0:
			draw_rect(Rect2(track.position.x + half, track.position.y, half * frac, track.size.y), Color(0.3, 0.8, 0.4))
		else:
			draw_rect(Rect2(track.position.x + half - half * frac, track.position.y, half * frac, track.size.y), Color(0.9, 0.35, 0.3))
		draw_rect(Rect2(track.position.x + half - 1, track.position.y - 2, 2, track.size.y + 4), Color(0.8, 0.8, 0.85))
		draw_string(font, Vector2(label_w + bar_w + 6, y + 14), "%+.0f%%" % v, HORIZONTAL_ALIGNMENT_LEFT, 46, 13, Color(0.85, 0.87, 0.92))
