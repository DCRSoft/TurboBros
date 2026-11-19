class_name DebugHud
extends CanvasLayer
## HUD de depuración de UN kart (vive dentro de su SubViewport).

var kart: Kart
var seats: Array[Seat] = []
var show_help := false          ## solo la vista 1 muestra versión/FPS/ayuda
var info_provider := Callable() ## devuelve texto extra (p. ej. resolución de la vista)
var _label: Label
var _ink: Control


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)
	# Manchas de tinta (se muestran cuando el kart tiene un efecto con tinta)
	_ink = Control.new()
	_ink.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.visible = false
	var blobs := [Rect2(0.05, 0.05, 0.35, 0.4), Rect2(0.55, 0.1, 0.4, 0.35), Rect2(0.15, 0.5, 0.45, 0.4),
			Rect2(0.6, 0.55, 0.35, 0.35), Rect2(0.35, 0.3, 0.3, 0.4)]
	for b in blobs:
		var r := ColorRect.new()
		r.color = Color(0.03, 0.02, 0.08, 0.93)
		r.anchor_left = b.position.x
		r.anchor_top = b.position.y
		r.anchor_right = b.position.x + b.size.x
		r.anchor_bottom = b.position.y + b.size.y
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ink.add_child(r)
	add_child(_ink)
	move_child(_label, -1)


func _process(_delta: float) -> void:
	if kart == null:
		return
	var state := "-"
	if kart.drifting:
		state = "DERRAPE nivel %d" % kart.drift_level
	elif kart.is_boosting():
		state = "TURBO"
	elif not kart.grounded:
		state = "EN EL AIRE"
	var lines := PackedStringArray()
	if show_help:
		lines.append("TurboBros v%s   %d FPS" % [GameVersion.current, Engine.get_frames_per_second()])
	lines.append("%d km/h   %s   Pos %d/%d" % [roundi(kart.get_speed_kmh()), state,
			kart.race_position, kart.race_total])
	if kart.is_rolling():
		lines.append("Ítem: ¡sorteando!")
	elif kart.held_item != null:
		var hint := "  (atrás+botón: lanzar/colocar detrás)" if kart.held_item is ItemProjectile \
				or kart.held_item is ItemTrap else ""
		lines.append("Ítem: %s x%d%s" % [kart.held_item.display_name, kart.held_uses, hint])
	else:
		lines.append("Ítem: -")
	var fx_names := PackedStringArray()
	for i in kart.fx.instances:
		if i.data.id != &"boost":
			fx_names.append("%s %.1fs" % [i.data.display_name, i.time_left])
	if not fx_names.is_empty():
		lines.append("Efectos: " + ", ".join(fx_names))
	_ink.visible = kart.fx.mods.ink
	for s in seats:
		var role := ""
		if s.role == Seat.Role.DRIVER:
			role = "Conductor: "
		elif s.role == Seat.Role.GUNNER:
			role = "Artillero: "
		lines.append(role + InputManager.describe_seat(s))
	if info_provider.is_valid():
		lines.append(info_provider.call())
	if show_help:
		lines.append("[Mando] stick girar | RT/A acelerar | LT/B frenar | LB/RB derrapar")
		lines.append("[Teclado J1] WASD + Shift | [J2] flechas + L | R reiniciar")
		lines.append("Artillero: LB/RB golpean izq/der | Esc: volver al lobby")
		lines.append("F1-F4: nº de karts (solo depuración) | [ ]: escala de render")
	_label.text = "\n".join(lines)
	_label.add_theme_color_override("font_color",
			kart.get_drift_color(kart.drift_level) if kart.drifting else Color.WHITE)
