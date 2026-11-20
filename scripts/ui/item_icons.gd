class_name ItemIcons
extends RefCounted
## Iconos vectoriales (dibujados por código, sin imágenes) de los 23 ítems. Cada icono se dibuja dentro de un
## rectángulo cualquiera con las primitivas de CanvasItem. El HUD pone el fondo; aquí solo va el dibujo.

const ORANGE := Color(1.0, 0.55, 0.1)
const YELLOW := Color(1.0, 0.88, 0.2)
const WHITE := Color(0.96, 0.97, 1.0)
const DARK := Color(0.1, 0.1, 0.14)
const RED := Color(0.95, 0.2, 0.2)
const CYAN := Color(0.4, 0.9, 1.0)
const GREY := Color(0.62, 0.64, 0.7)

const IDS: Array[StringName] = [
	&"turbo", &"triple_turbo", &"rocket", &"shield", &"guard_orbit", &"reflect", &"missile", &"bouncer",
	&"homing", &"bomb", &"shockwave", &"oil", &"nails", &"fake_box", &"barrier", &"mine", &"star", &"ghost",
	&"giant", &"ink", &"invert", &"slow_ahead", &"swap",
]


static func has_icon(id: StringName) -> bool:
	return IDS.has(id)


# --- Utilidades (coordenadas normalizadas 0..1 dentro de "r") -------------------------------

static func _p(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + Vector2(x, y) * r.size


static func _poly(ci: CanvasItem, r: Rect2, pts: Array, col: Color) -> void:
	var v := PackedVector2Array()
	for p in pts:
		v.append(_p(r, p[0], p[1]))
	ci.draw_colored_polygon(v, col)


static func _line(ci: CanvasItem, r: Rect2, a: Array, b: Array, col: Color, w: float) -> void:
	ci.draw_line(_p(r, a[0], a[1]), _p(r, b[0], b[1]), col, w * r.size.x, true)


static func _circle(ci: CanvasItem, r: Rect2, x: float, y: float, rad: float, col: Color) -> void:
	ci.draw_circle(_p(r, x, y), rad * r.size.x, col)


static func _arc(ci: CanvasItem, r: Rect2, x: float, y: float, rad: float, a0: float, a1: float, col: Color, w: float) -> void:
	ci.draw_arc(_p(r, x, y), rad * r.size.x, a0, a1, 24, col, w * r.size.x, true)


static func _star(ci: CanvasItem, r: Rect2, x: float, y: float, rad: float, col: Color, points := 5) -> void:
	var v := PackedVector2Array()
	for i in points * 2:
		var a := -PI / 2.0 + PI * i / points
		var rr := rad if i % 2 == 0 else rad * 0.42
		v.append(_p(r, x + cos(a) * rr, y + sin(a) * rr))
	ci.draw_colored_polygon(v, col)


static func _flame(ci: CanvasItem, r: Rect2, cx: float, cy: float, s: float, outer: Color, inner: Color) -> void:
	_poly(ci, r, [[cx, cy - 0.45 * s], [cx + 0.28 * s, cy - 0.05 * s], [cx + 0.22 * s, cy + 0.3 * s], [cx, cy + 0.45 * s],
			[cx - 0.22 * s, cy + 0.3 * s], [cx - 0.28 * s, cy - 0.05 * s]], outer)
	_poly(ci, r, [[cx, cy - 0.15 * s], [cx + 0.13 * s, cy + 0.08 * s], [cx + 0.09 * s, cy + 0.3 * s], [cx, cy + 0.36 * s],
			[cx - 0.09 * s, cy + 0.3 * s], [cx - 0.13 * s, cy + 0.08 * s]], inner)


## Misil apuntando a la derecha, girado "angle" radianes alrededor del centro del rectángulo.
static func _missile(ci: CanvasItem, r: Rect2, angle: float, body: Color, tip: Color, scale := 1.0) -> void:
	ci.draw_set_transform(_p(r, 0.5, 0.5), angle, Vector2.ONE * scale)
	var s := r.size.x
	ci.draw_rect(Rect2(Vector2(-0.30, -0.09) * s, Vector2(0.46, 0.18) * s), body)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0.16, -0.09) * s, Vector2(0.40, 0) * s, Vector2(0.16, 0.09) * s]), tip)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-0.30, -0.09) * s, Vector2(-0.40, -0.22) * s, Vector2(-0.14, -0.09) * s]), tip)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-0.30, 0.09) * s, Vector2(-0.40, 0.22) * s, Vector2(-0.14, 0.09) * s]), tip)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-0.30, -0.05) * s, Vector2(-0.46, 0) * s, Vector2(-0.30, 0.05) * s]), ORANGE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Iconos ----------------------------------------------------------------------------------

static func draw(ci: CanvasItem, id: StringName, rect: Rect2, color: Color) -> void:
	var r := rect.grow(-rect.size.x * 0.12)   # margen interior
	match id:
		&"turbo":
			_flame(ci, r, 0.5, 0.5, 1.9, ORANGE, YELLOW)
		&"triple_turbo":
			_flame(ci, r, 0.22, 0.55, 1.15, ORANGE, YELLOW)
			_flame(ci, r, 0.5, 0.45, 1.5, ORANGE, YELLOW)
			_flame(ci, r, 0.78, 0.55, 1.15, ORANGE, YELLOW)
		&"rocket":
			_missile(ci, r, -PI / 4.0, WHITE, RED, 1.5)
			_circle(ci, r, 0.5, 0.5, 0.06, CYAN)
		&"shield":
			_poly(ci, r, [[0.5, 0.04], [0.92, 0.18], [0.88, 0.58], [0.5, 0.97], [0.12, 0.58], [0.08, 0.18]], Color(0.25, 0.5, 0.95))
			_poly(ci, r, [[0.5, 0.14], [0.8, 0.25], [0.77, 0.56], [0.5, 0.86], [0.23, 0.56], [0.2, 0.25]], Color(0.55, 0.78, 1.0))
			_line(ci, r, [0.5, 0.2], [0.5, 0.8], Color(0.25, 0.5, 0.95), 0.05)
			_line(ci, r, [0.25, 0.42], [0.75, 0.42], Color(0.25, 0.5, 0.95), 0.05)
		&"guard_orbit":
			_circle(ci, r, 0.5, 0.5, 0.17, CYAN)
			_arc(ci, r, 0.5, 0.5, 0.36, 0.0, TAU, Color(0.4, 0.9, 1.0, 0.55), 0.03)
			for i in 3:
				var a := TAU * i / 3.0 - PI / 2.0
				_circle(ci, r, 0.5 + cos(a) * 0.36, 0.5 + sin(a) * 0.36, 0.09, WHITE)
		&"reflect":
			_circle(ci, r, 0.5, 0.5, 0.42, Color(0.55, 0.95, 1.0, 0.35))
			_arc(ci, r, 0.5, 0.5, 0.42, 0.0, TAU, CYAN, 0.05)
			_arc(ci, r, 0.5, 0.5, 0.3, PI * 1.05, PI * 1.55, WHITE, 0.05)
			_line(ci, r, [0.3, 0.7], [0.7, 0.3], Color(1, 1, 1, 0.8), 0.04)
			_poly(ci, r, [[0.7, 0.3], [0.52, 0.3], [0.7, 0.48]], WHITE)
		&"missile":
			_missile(ci, r, -PI / 6.0, RED, Color(0.35, 0.05, 0.05), 1.6)
		&"bouncer":
			_circle(ci, r, 0.62, 0.3, 0.2, Color(0.25, 0.8, 0.3))
			_circle(ci, r, 0.58, 0.26, 0.07, Color(0.7, 1.0, 0.7))
			ci.draw_polyline(PackedVector2Array([_p(r, 0.05, 0.9), _p(r, 0.25, 0.55), _p(r, 0.4, 0.82), _p(r, 0.52, 0.45)]), WHITE, 0.05 * r.size.x, true)
		&"homing":
			_missile(ci, r, -PI / 5.0, Color(0.85, 0.4, 0.95), Color(0.3, 0.1, 0.4), 1.2)
			_arc(ci, r, 0.5, 0.5, 0.42, 0.0, TAU, Color(1, 1, 1, 0.85), 0.04)
			for pair in [[[0.5, 0.02], [0.5, 0.16]], [[0.5, 0.84], [0.5, 0.98]], [[0.02, 0.5], [0.16, 0.5]], [[0.84, 0.5], [0.98, 0.5]]]:
				_line(ci, r, pair[0], pair[1], Color(1, 1, 1, 0.85), 0.04)
		&"bomb":
			_circle(ci, r, 0.46, 0.58, 0.34, Color(0.22, 0.23, 0.3))
			_arc(ci, r, 0.46, 0.58, 0.34, 0.0, TAU, Color(0.65, 0.68, 0.82), 0.03)
			_circle(ci, r, 0.36, 0.46, 0.08, Color(0.5, 0.52, 0.6))
			_line(ci, r, [0.6, 0.3], [0.74, 0.14], Color(0.6, 0.45, 0.25), 0.05)
			_star(ci, r, 0.78, 0.1, 0.14, YELLOW, 6)
		&"shockwave":
			_circle(ci, r, 0.5, 0.5, 0.1, YELLOW)
			for i in 3:
				_arc(ci, r, 0.5, 0.5, 0.2 + i * 0.12, 0.0, TAU, Color(1.0, 0.85, 0.3, 1.0 - i * 0.28), 0.05)
		&"oil":
			_poly(ci, r, [[0.12, 0.55], [0.22, 0.3], [0.45, 0.22], [0.7, 0.28], [0.9, 0.5], [0.82, 0.74], [0.55, 0.82], [0.3, 0.8]], DARK)
			_outline(ci, r, [[0.12, 0.55], [0.22, 0.3], [0.45, 0.22], [0.7, 0.28], [0.9, 0.5], [0.82, 0.74], [0.55, 0.82], [0.3, 0.8]], Color(0.6, 0.64, 0.85), 0.035)
			_poly(ci, r, [[0.28, 0.4], [0.42, 0.33], [0.5, 0.4], [0.36, 0.5]], Color(0.55, 0.6, 0.85))
			_poly(ci, r, [[0.46, 0.0], [0.58, 0.14], [0.5, 0.22], [0.4, 0.14]], DARK)
		&"nails":
			ci.draw_rect(Rect2(_p(r, 0.08, 0.62), Vector2(0.84, 0.16) * r.size), Color(0.3, 0.31, 0.36))
			for i in 4:
				var x := 0.2 + i * 0.2
				_poly(ci, r, [[x - 0.07, 0.62], [x, 0.16], [x + 0.07, 0.62]], Color(0.82, 0.84, 0.9))
		&"fake_box":
			ci.draw_rect(Rect2(_p(r, 0.12, 0.12), Vector2(0.76, 0.76) * r.size), YELLOW)
			ci.draw_rect(Rect2(_p(r, 0.12, 0.12), Vector2(0.76, 0.76) * r.size), Color(0.7, 0.45, 0.05), false, 0.04 * r.size.x)
			_line(ci, r, [0.5, 0.26], [0.5, 0.56], RED, 0.1)
			_circle(ci, r, 0.5, 0.72, 0.06, RED)
		&"barrier":
			for i in 3:
				var y := 0.2 + i * 0.22
				ci.draw_rect(Rect2(_p(r, 0.04, y), Vector2(0.92, 0.17) * r.size), ORANGE if i % 2 == 0 else WHITE)
			_line(ci, r, [0.16, 0.2], [0.16, 0.95], GREY, 0.06)
			_line(ci, r, [0.84, 0.2], [0.84, 0.95], GREY, 0.06)
		&"mine":
			for i in 8:
				var a := TAU * i / 8.0
				_poly(ci, r, [[0.5 + cos(a - 0.2) * 0.3, 0.5 + sin(a - 0.2) * 0.3], [0.5 + cos(a) * 0.46, 0.5 + sin(a) * 0.46],
						[0.5 + cos(a + 0.2) * 0.3, 0.5 + sin(a + 0.2) * 0.3]], GREY)
			_circle(ci, r, 0.5, 0.5, 0.3, DARK)
			_circle(ci, r, 0.5, 0.5, 0.1, RED)
		&"star":
			_star(ci, r, 0.5, 0.54, 0.5, Color(1.0, 0.8, 0.1))
			_star(ci, r, 0.5, 0.54, 0.3, YELLOW)
		&"ghost":
			_poly(ci, r, [[0.14, 0.9], [0.14, 0.42], [0.2, 0.22], [0.35, 0.1], [0.5, 0.06], [0.65, 0.1], [0.8, 0.22], [0.86, 0.42],
					[0.86, 0.9], [0.75, 0.78], [0.62, 0.9], [0.5, 0.78], [0.38, 0.9], [0.25, 0.78]], Color(0.92, 0.94, 1.0, 0.95))
			_circle(ci, r, 0.38, 0.42, 0.07, DARK)
			_circle(ci, r, 0.62, 0.42, 0.07, DARK)
			_circle(ci, r, 0.5, 0.6, 0.05, DARK)
		&"giant":
			_poly(ci, r, [[0.5, 0.08], [0.72, 0.34], [0.58, 0.34], [0.58, 0.62], [0.42, 0.62], [0.42, 0.34], [0.28, 0.34]], Color(0.95, 0.45, 0.2))
			_circle(ci, r, 0.5, 0.76, 0.12, Color(0.95, 0.75, 0.55))
			_arc(ci, r, 0.5, 0.76, 0.26, PI * 0.1, PI * 0.9, Color(1, 1, 1, 0.7), 0.04)
			for pair in [[0.1, 0.1], [0.9, 0.1], [0.1, 0.9], [0.9, 0.9]]:
				_circle(ci, r, pair[0], pair[1], 0.05, YELLOW)
		&"ink":
			_circle(ci, r, 0.5, 0.5, 0.26, Color(0.4, 0.33, 0.85))
			for i in 7:
				var a := TAU * i / 7.0 + 0.3
				_circle(ci, r, 0.5 + cos(a) * 0.34, 0.5 + sin(a) * 0.34, 0.1 + (i % 3) * 0.015, Color(0.4, 0.33, 0.85))
			_circle(ci, r, 0.42, 0.42, 0.06, Color(0.5, 0.5, 0.8))
		&"invert":
			_poly(ci, r, [[0.08, 0.32], [0.3, 0.12], [0.3, 0.24], [0.9, 0.24], [0.9, 0.4], [0.3, 0.4], [0.3, 0.52]], Color(0.85, 0.35, 0.9))
			_poly(ci, r, [[0.92, 0.68], [0.7, 0.48], [0.7, 0.6], [0.1, 0.6], [0.1, 0.76], [0.7, 0.76], [0.7, 0.88]], Color(0.55, 0.3, 0.95))
		&"slow_ahead":
			_circle(ci, r, 0.5, 0.42, 0.36, Color(0.3, 0.45, 0.95))
			_circle(ci, r, 0.5, 0.42, 0.3, Color(0.75, 0.85, 1.0))
			_line(ci, r, [0.5, 0.42], [0.5, 0.22], DARK, 0.05)
			_line(ci, r, [0.5, 0.42], [0.65, 0.5], DARK, 0.05)
			_poly(ci, r, [[0.34, 0.74], [0.66, 0.74], [0.5, 0.96]], Color(0.3, 0.45, 0.95))
		&"swap":
			_poly(ci, r, [[0.1, 0.28], [0.34, 0.06], [0.34, 0.2], [0.88, 0.2], [0.88, 0.36], [0.34, 0.36], [0.34, 0.5]], Color(0.2, 0.9, 0.9))
			_poly(ci, r, [[0.9, 0.72], [0.66, 0.5], [0.66, 0.64], [0.12, 0.64], [0.12, 0.8], [0.66, 0.8], [0.66, 0.94]], Color(1.0, 0.9, 0.3))
		_:
			_star(ci, r, 0.5, 0.5, 0.4, color)
			_line(ci, r, [0.5, 0.35], [0.5, 0.55], DARK, 0.06)
			_circle(ci, r, 0.5, 0.68, 0.04, DARK)


static func _outline(ci: CanvasItem, r: Rect2, pts: Array, col: Color, w: float) -> void:
	var v := PackedVector2Array()
	for p in pts:
		v.append(_p(r, p[0], p[1]))
	v.append(_p(r, pts[0][0], pts[0][1]))
	ci.draw_polyline(v, col, w * r.size.x, true)
