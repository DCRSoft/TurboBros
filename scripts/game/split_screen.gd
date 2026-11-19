class_name SplitScreen
extends Control
## Pantalla dividida para 1-4 karts. Cada kart tiene su SubViewport (comparten el mismo World3D)
## con su cámara; el resultado se dibuja en un TextureRect, así la resolución interna es libre:
##   render_scale 1.0 = resolución nativa de la celda, 0.5 = mitad (ahorro de GPU en gráficos integrados).

class Cell:
	var kart: Kart
	var viewport: SubViewport
	var view: TextureRect
	var camera: ChaseCamera
	var hud: DebugHud

@export var gap := 4.0
@export_range(0.25, 1.0, 0.05) var render_scale := 1.0:
	set(v):
		render_scale = clampf(v, 0.25, 1.0)
		_relayout()

var cells: Array[Cell] = []


func _ready() -> void:
	resized.connect(_relayout)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)


## Rectángulos de cada vista. 1 = completa, 2 = arriba/abajo, 3-4 = cuadrícula 2x2.
static func compute_cells(count: int, area: Vector2, gap_px: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	match count:
		1:
			out.append(Rect2(Vector2.ZERO, area))
		2:
			var h := (area.y - gap_px) * 0.5
			out.append(Rect2(0.0, 0.0, area.x, h))
			out.append(Rect2(0.0, h + gap_px, area.x, h))
		_:
			var w := (area.x - gap_px) * 0.5
			var h := (area.y - gap_px) * 0.5
			for i in mini(count, 4):
				out.append(Rect2((i % 2) * (w + gap_px), floorf(i / 2.0) * (h + gap_px), w, h))
	return out


## seat_groups[i] = Array[Seat] del kart i (para mostrar conductor/artillero en el HUD).
func setup(karts: Array[Kart], seat_groups: Array) -> void:
	clear()
	for i in karts.size():
		var c := Cell.new()
		c.kart = karts[i]
		c.viewport = SubViewport.new()
		c.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		c.viewport.size = Vector2i(640, 360)
		add_child(c.viewport)
		c.camera = ChaseCamera.new()
		c.camera.target = karts[i]
		c.viewport.add_child(c.camera)
		c.hud = DebugHud.new()
		c.hud.kart = karts[i]
		if i < seat_groups.size():
			c.hud.seats.assign(seat_groups[i])
		c.hud.show_help = (i == 0)
		c.hud.info_provider = func() -> String:
			return "Vista %d: %dx%d (escala %.2f)" % [
					karts.find(c.kart) + 1, c.viewport.size.x, c.viewport.size.y, render_scale]
		c.viewport.add_child(c.hud)
		c.view = TextureRect.new()
		c.view.texture = c.viewport.get_texture()
		c.view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.view.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(c.view)
		cells.append(c)
	_relayout()


func clear() -> void:
	for c in cells:
		c.viewport.queue_free()
		c.view.queue_free()
	cells.clear()


## Píxeles internos totales que se están renderizando (para el presupuesto de calidad).
func get_total_pixels() -> int:
	var total := 0
	for c in cells:
		total += c.viewport.size.x * c.viewport.size.y
	return total


func _relayout() -> void:
	if cells.is_empty() or size.x < 1.0 or size.y < 1.0:
		return
	var rects := compute_cells(cells.size(), size, gap)
	for i in cells.size():
		var r := rects[i]
		cells[i].view.position = r.position
		cells[i].view.size = r.size
		cells[i].viewport.size = Vector2i(
				maxi(16, roundi(r.size.x * render_scale)), maxi(16, roundi(r.size.y * render_scale)))
	queue_redraw()
