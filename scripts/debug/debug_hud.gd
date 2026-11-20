class_name DebugHud
extends CanvasLayer
## HUD de depuración de UN kart (vive dentro de su SubViewport).

var kart: Kart
var seats: Array[Seat] = []
var show_help := false          ## solo la vista 1 muestra versión/FPS/ayuda
var info_provider := Callable() ## devuelve texto extra (p. ej. resolución de la vista)
var race: RaceManager           ## si hay carrera: vueltas, tiempo y mensajes centrales
var _label: Label
var _center: Label
var _warn: Label
var _ink: Control
var _item_hud: ItemHud
var _minimap: Minimap


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
	_center = Label.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center.add_theme_font_size_override("font_size", 72)
	_center.add_theme_color_override("font_outline_color", Color.BLACK)
	_center.add_theme_constant_override("outline_size", 12)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	# Aviso de efectos que alteran el control (controles invertidos, ralentización...)
	_warn = Label.new()
	_warn.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_warn.offset_top = 175
	_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn.add_theme_font_size_override("font_size", 34)
	_warn.add_theme_color_override("font_color", Color(1.0, 0.45, 1.0))
	_warn.add_theme_color_override("font_outline_color", Color.BLACK)
	_warn.add_theme_constant_override("outline_size", 10)
	_warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_warn)
	_item_hud = ItemHud.new()
	add_child(_item_hud)
	_minimap = Minimap.new()
	add_child(_minimap)


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
	if race != null:
		var r := race.get_racer(kart)
		if r != null:
			lines.append("Vuelta %d/%d   Tiempo %s" % [race.lap_of(r), race.laps, race.format_time(race.race_time)])
		_center.text = race.center_text(kart)
	if kart.team >= 0:
		lines.append("Equipo %s" % GameSession.TEAM_NAMES[kart.team])
	_minimap.kart = kart
	_minimap.manager = race
	_item_hud.kart = kart   # el ítem y los efectos se dibujan en ItemHud (iconos), ya no como texto
	_ink.visible = kart.fx.mods.ink
	var warns := PackedStringArray()
	if kart.fx.mods.steer_mult < 0.0:
		warns.append("⇄ ¡CONTROLES INVERTIDOS!")
	if kart.fx.mods.lock_control:
		warns.append("¡SIN CONTROL!")
	if kart.look_back:
		warns.append("↩ MIRANDO ATRÁS")
	_warn.text = "\n".join(warns)
	for s in seats:
		var role := ""
		if s.role == Seat.Role.DRIVER:
			role = "Conductor: "
		elif s.role == Seat.Role.GUNNER:
			role = "Artillero: "
		lines.append(role + InputManager.describe_seat(s))
	if info_provider.is_valid():
		lines.append(info_provider.call())
	# La ayuda de controles se ve en la cuenta atrás y los primeros segundos; luego se oculta para no tapar la vista
	var show_controls_help := race == null or race.state != RaceManager.State.RACING or race.race_time < 14.0
	if show_help and show_controls_help:
		lines.append("[Mando] stick girar | A/RT acelerar | Y/LT reversa | B ítem | X mirar atrás | LB/RB derrapar")
		lines.append("[Teclado J1] WASD + Shift | [J2] flechas + L | R reiniciar")
		lines.append("Pausa: Start / P / Esc | Mirar atrás: X (mando) / C (J1) / / (J2)")
		lines.append("Artillero: LB/RB golpean izq/der · B ítem")
		lines.append("F1-F4: nº de karts (solo depuración) | [ ]: escala de render")
	_label.text = "\n".join(lines)
	_label.add_theme_color_override("font_color",
			kart.get_drift_color(kart.drift_level) if kart.drifting else Color.WHITE)
