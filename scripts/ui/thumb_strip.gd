class_name ThumbStrip
extends Control
## Tira de miniaturas seleccionables (personajes o vehículos): un cuadro por opción con su arte (si existe) o su
## color e inicial, y la opción actual resaltada. Solo dibuja; la lógica de selección es del modelo.

var items: Array[Dictionary] = []   ## [{"color": Color, "label": String, "tex": Texture2D}]
var selected := 0
var per_row := 8
var chip := 28.0
var gap := 4.0


func setup(p_items: Array[Dictionary], p_per_row: int, p_chip := 28.0) -> void:
	items = p_items
	per_row = maxi(p_per_row, 1)
	chip = p_chip
	update_minimum_size()
	queue_redraw()


func set_selected(i: int) -> void:
	if i != selected:
		selected = i
		queue_redraw()


func _get_minimum_size() -> Vector2:
	var rows := ceili(float(items.size()) / per_row)
	var cols := mini(items.size(), per_row)
	return Vector2(cols * (chip + gap), rows * (chip + gap))


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for i in items.size():
		var r := Rect2(Vector2((i % per_row) * (chip + gap), (i / per_row) * (chip + gap)), Vector2(chip, chip))
		var it := items[i]
		var on := i == selected
		draw_rect(r, (it["color"] as Color).darkened(0.35 if not on else 0.0))
		var tex: Texture2D = it.get("tex")
		if tex != null:
			var ts := tex.get_size()   # cuadrado recortado desde arriba (ahí está la cara)
			var side := minf(ts.x, ts.y) * 0.8
			draw_texture_rect_region(tex, r.grow(-1.0), Rect2((ts.x - side) * 0.5, ts.y * 0.04, side, side),
					Color(1, 1, 1, 1.0 if on else 0.6))
		else:
			var lbl: String = it["label"]
			draw_string(font, r.position + Vector2(0, chip * 0.68), lbl, HORIZONTAL_ALIGNMENT_CENTER, chip, int(chip * 0.55),
					Color(1, 1, 1, 1.0 if on else 0.65))
		if on:
			draw_rect(r.grow(2.0), Color(1, 1, 1), false, 3.0)
