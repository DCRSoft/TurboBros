class_name DebugHud
extends CanvasLayer
## HUD de depuración de UN kart (vive dentro de su SubViewport).

var kart: Kart
var seat: Seat
var show_help := false          ## solo la vista 1 muestra versión/FPS/ayuda
var info_provider := Callable() ## devuelve texto extra (p. ej. resolución de la vista)
var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)


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
	lines.append("%d km/h   %s" % [roundi(kart.get_speed_kmh()), state])
	if seat:
		lines.append(InputManager.describe_seat(seat))
	if info_provider.is_valid():
		lines.append(info_provider.call())
	if show_help:
		lines.append("[Mando] stick girar | RT/A acelerar | LT/B frenar | LB/RB derrapar")
		lines.append("[Teclado J1] WASD + Shift | [J2] flechas + L | R reiniciar")
		lines.append("F1-F4: nº de jugadores | [ ]: escala de render")
	_label.text = "\n".join(lines)
	_label.add_theme_color_override("font_color",
			kart.get_drift_color(kart.drift_level) if kart.drifting else Color.WHITE)
