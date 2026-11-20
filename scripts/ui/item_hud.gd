class_name ItemHud
extends Control
## Muestra el ítem en mano (icono grande, nombre, usos, ruleta al recogerlo) y los efectos activos con su
## temporizador (verde = a favor, rojo = en contra). Vive dentro del HUD de cada vista.

const PANEL := 108.0
const CHIP_W := 190.0
const CHIP_H := 26.0

var kart: Kart

var _items: Array[ItemData] = []
var _roll_idx := 0
var _roll_t := 0.0
var _clock := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items = ItemCatalog.all()


func _process(delta: float) -> void:
	if kart == null:
		return
	_clock += delta
	if kart.is_rolling() and not _items.is_empty():
		_roll_t += delta
		if _roll_t > 0.07:
			_roll_t = 0.0
			_roll_idx = (_roll_idx + 1 + randi() % 3) % _items.size()
	queue_redraw()


## Los efectos "en contra" se pintan en rojo.
static func is_bad(e: KartEffect) -> bool:
	return e.ink or e.lock_control or e.steer_mult < 0.0 or e.speed_mult < 1.0 or e.grip_mult < 1.0 or e.accel_mult < 1.0


func _text(font: Font, pos: Vector2, text: String, width: float, fsize: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	while fsize > 11 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > width:
		fsize -= 1   # los nombres largos ("Ralentizar a los de delante") encogen para caber
	draw_string_outline(font, pos, text, align, width, fsize, 6, Color(0, 0, 0, 0.9))
	draw_string(font, pos, text, align, width, fsize, col)


func _draw() -> void:
	if kart == null:
		return
	var font := ThemeDB.fallback_font
	var vsize := get_viewport_rect().size
	var pr := Rect2(Vector2(vsize.x * 0.5 - PANEL * 0.5, 12.0), Vector2(PANEL, PANEL))
	var rolling := kart.is_rolling()
	var item: ItemData = kart.held_item
	var shown: ItemData = _items[_roll_idx] if (rolling and not _items.is_empty()) else item
	var accent := Color(0.45, 0.5, 0.65)
	if shown != null:
		accent = shown.icon_color
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.17, 0.25, 0.88)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(5)
	sb.border_color = accent.lightened(0.1) if shown != null else Color(0.35, 0.38, 0.5)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	draw_style_box(sb, pr)

	if shown != null:
		var icon_r := pr.grow(-9.0)
		var pulse := 1.0 + (0.04 * sin(_clock * 8.0) if not rolling else 0.0)
		if pulse != 1.0:
			icon_r = Rect2(icon_r.get_center() - icon_r.size * 0.5 * pulse, icon_r.size * pulse)
		ItemIcons.draw(self, shown.id, icon_r, shown.icon_color)
		if rolling:
			_text(font, pr.position + Vector2(0, PANEL + 22.0), "¡ÍTEM!", PANEL, 20, Color(1.0, 0.95, 0.5))
		else:
			_text(font, pr.position + Vector2(-40.0, PANEL + 22.0), item.display_name, PANEL + 80.0, 20, Color.WHITE)
			if kart.held_uses > 1:
				var badge := Rect2(pr.end - Vector2(34, 34) + Vector2(10, -88), Vector2(40, 28))
				var bsb := StyleBoxFlat.new()
				bsb.bg_color = Color(0.95, 0.35, 0.2)
				bsb.set_corner_radius_all(14)
				draw_style_box(bsb, badge)
				_text(font, badge.position + Vector2(0, 21), "x%d" % kart.held_uses, badge.size.x, 18, Color.WHITE)
			var hint := ""
			if item.carried_guard:
				hint = "Te protege mientras la llevas · ↓ + ítem: soltar atrás"
			elif item is ItemProjectile or item is ItemTrap:
				hint = "↓ + ítem: hacia atrás"
			if hint != "":
				_text(font, pr.position + Vector2(-90.0, PANEL + 42.0), hint, PANEL + 180.0, 14, Color(0.8, 0.85, 1.0))
	else:
		_text(font, pr.position + Vector2(0, PANEL * 0.62), "—", PANEL, 44, Color(0.5, 0.53, 0.65))

	# Efectos activos (a la derecha del panel)
	var y := 14.0
	var x := pr.end.x + 16.0
	for inst in kart.fx.instances:
		if inst.data.id == &"boost":
			continue
		var d: KartEffect = inst.data
		var bad := is_bad(d)
		var base := Color(0.85, 0.25, 0.25) if bad else Color(0.2, 0.7, 0.35)
		var chip := Rect2(Vector2(x, y), Vector2(CHIP_W, CHIP_H))
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.05, 0.06, 0.1, 0.78)
		csb.set_corner_radius_all(9)
		csb.set_border_width_all(2)
		csb.border_color = base
		draw_style_box(csb, chip)
		var frac := clampf(inst.time_left / maxf(d.duration, 0.1), 0.0, 1.0)
		if d.guard_charges > 0:
			frac = float(inst.charges) / float(d.guard_charges)
		draw_rect(Rect2(chip.position + Vector2(3, CHIP_H - 7), Vector2((CHIP_W - 6) * frac, 4)), base)
		var label := d.display_name
		if d.guard_charges > 0:
			label += "  x%d" % inst.charges
		else:
			label += "  %.1fs" % maxf(inst.time_left, 0.0)
		_text(font, chip.position + Vector2(8, 17), label, CHIP_W - 12, 15, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		y += CHIP_H + 6.0
