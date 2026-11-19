class_name DebugHud
extends CanvasLayer
## HUD de depuración: versión, FPS, velocidad, derrape y dispositivo.

var kart: Kart
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
	_label.text = "TurboBros v%s   %d FPS\n%d km/h   %s\n%s\n[Mando] stick: girar | RT/A: acelerar | LT/B: frenar | LB/RB: derrapar\n[Teclado] WASD + Shift (derrape) | R: reiniciar" % [
		GameVersion.current, Engine.get_frames_per_second(), roundi(kart.get_speed_kmh()),
		state, InputManager.describe_seat(InputManager.primary_seat)]
	if _label.text.length() > 0 and kart.character:
		_label.add_theme_color_override("font_color",
				kart.get_drift_color(kart.drift_level) if kart.drifting else Color.WHITE)
