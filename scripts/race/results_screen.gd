class_name ResultsScreen
extends CanvasLayer
## Pantalla de resultados al terminar la carrera. Enter / Start / A vuelve al lobby.

const LOBBY := "res://scenes/menu/lobby.tscn"

var _label: Label
var _input := MenuInput.new()
var _shown := false


func _ready() -> void:
	layer = 20
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.07, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 80
	_label.offset_top = 50
	_label.add_theme_font_size_override("font_size", 26)
	add_child(_label)


func show_results(manager: RaceManager) -> void:
	var lines := PackedStringArray()
	lines.append("RESULTADOS  —  %d vuelta(s)" % manager.laps)
	lines.append("")
	for r in manager.results:
		var team := ""
		if int(r["team"]) >= 0:
			team = "  [Equipo %s]" % GameSession.TEAM_NAMES[int(r["team"])]
		var t: String = manager.format_time(float(r["time"])) if r["finished"] else "—"
		lines.append("%d.  %s%s   %s   +%d pts" % [r["place"], r["name"], team, t, r["points"]])
	var scores := manager.team_scores()
	if not scores.is_empty():
		lines.append("")
		lines.append("EQUIPOS")
		var ids := scores.keys()
		ids.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])
		for id in ids:
			lines.append("Equipo %s:  %d pts" % [GameSession.TEAM_NAMES[id], scores[id]])
	lines.append("")
	lines.append("Enter / Start / A: volver al lobby")
	_label.text = "\n".join(lines)
	_input = MenuInput.new()
	visible = true
	_shown = true


func _process(_delta: float) -> void:
	if not _shown:
		return
	for e in _input.poll():
		if e["action"] == "confirm" or e["action"] == "start":
			_back()


func _unhandled_key_input(event: InputEvent) -> void:
	if _shown and event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		_back()


func _back() -> void:
	_shown = false
	get_tree().change_scene_to_file(LOBBY)
