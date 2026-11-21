class_name Minimap
extends Control
## Minimapa de la pista (norte arriba): trazado, línea de meta y un punto por kart; el kart de esta vista se destaca.
## Lo dibuja cada vista dentro de su HUD, en la esquina inferior derecha.

var kart: Kart
var manager: RaceManager

var _line := PackedVector2Array()    ## trazado normalizado a 0..1
var _flag := PackedVector2Array()    ## dos puntos de la línea de meta
var _alts: Array[PackedVector2Array] = []   ## atajos normalizados
var _min := Vector2.ZERO
var _scale := 1.0
var _built_for: Circuit


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


## Ajusta la pista (cuadrado de lado 1 con márgenes) desde las muestras del circuito.
func _build(c: Circuit) -> void:
	_built_for = c
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in c.count:
		lo = Vector2(minf(lo.x, c.points[i].x), minf(lo.y, c.points[i].z))
		hi = Vector2(maxf(hi.x, c.points[i].x), maxf(hi.y, c.points[i].z))
	var span := maxf(hi.x - lo.x, hi.y - lo.y)
	_scale = 0.88 / maxf(span, 1.0)
	_min = lo - Vector2(span - (hi.x - lo.x), span - (hi.y - lo.y)) * 0.5 - Vector2(span, span) * 0.06
	_line = PackedVector2Array()
	for i in range(0, c.count, 2):
		_line.append(_norm(Vector3(c.points[i].x, 0.0, c.points[i].z)))
	_line.append(_line[0])
	_alts.clear()
	for a in c.alts:
		var line := PackedVector2Array()
		for k in range(0, a.count, 2):
			line.append(_norm(a.points[k]))
		line.append(_norm(a.points[a.count - 1]))
		_alts.append(line)
	var f := _norm(c.points[0])
	var side := Vector2(c.rights[0].x, c.rights[0].z) * c.road_half_width * _scale * 1.6
	_flag = PackedVector2Array([f - side, f + side])


func _norm(p: Vector3) -> Vector2:
	return (Vector2(p.x, p.z) - _min) * _scale


func _draw() -> void:
	if manager == null or manager.circuit == null:
		return
	if _built_for != manager.circuit:
		_build(manager.circuit)
	var view := get_viewport_rect().size
	var side := clampf(view.y * 0.3, 80.0, 220.0)
	var origin := Vector2(view.x - side - 14.0, view.y - side - 14.0)
	draw_rect(Rect2(origin, Vector2(side, side)), Color(0.05, 0.06, 0.1, 0.55))
	draw_rect(Rect2(origin, Vector2(side, side)), Color(1, 1, 1, 0.35), false, 1.5)
	var pts := PackedVector2Array()
	for p in _line:
		pts.append(origin + p * side)
	draw_polyline(pts, Color(0, 0, 0, 0.9), maxf(side * 0.045, 5.0), true)
	draw_polyline(pts, Color(0.82, 0.84, 0.9), maxf(side * 0.03, 3.0), true)
	for line in _alts:   # atajos: línea azul discontinua
		var pl := PackedVector2Array()
		for q in line:
			pl.append(origin + q * side)
		for k in range(0, pl.size() - 1, 2):
			draw_line(pl[k], pl[k + 1], Color(0.35, 0.8, 1.0), maxf(side * 0.02, 2.0))
	draw_line(origin + _flag[0] * side, origin + _flag[1] * side, Color.WHITE, 3.0)
	# Karts: primero los demás y al final el propio, para que quede encima
	for r in manager.racers:
		if r.kart == kart or r.kart.sphere == null:
			continue
		var pos := origin + _norm(r.kart.sphere.global_position) * side
		var col: Color = GameSession.TEAM_COLORS[r.kart.team] if r.kart.team >= 0 else (Color(0.95, 0.95, 0.95) if r.is_human else Color(0.6, 0.62, 0.7))
		draw_circle(pos, maxf(side * 0.03, 3.0), Color(0, 0, 0, 0.8))
		draw_circle(pos, maxf(side * 0.022, 2.2), col)
	if kart != null and kart.sphere != null:
		var me := origin + _norm(kart.sphere.global_position) * side
		var mine: Color = GameSession.TEAM_COLORS[kart.team] if kart.team >= 0 else Color(1.0, 0.85, 0.2)
		draw_circle(me, maxf(side * 0.05, 5.0), Color(1, 1, 1))
		draw_circle(me, maxf(side * 0.038, 3.8), mine)
