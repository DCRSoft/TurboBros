class_name SelectCard
extends PanelContainer
## Tarjeta de un jugador en la pantalla de selección: retrato (si hay arte), vista 3D del kart con su conductor,
## personaje y vehículo con sus tiras de miniaturas, barras de estadísticas y sinergia.

var _style := StyleBoxFlat.new()
var _bar: ColorRect
var _header: Label
var _ready_tag: Label
var _portrait: TextureRect
var _preview: CharacterPreview
var _char_name: Label
var _char_desc: Label
var _char_strip: ThumbStrip
var _veh_name: Label
var _veh_desc: Label
var _veh_strip: ThumbStrip
var _stats: StatBars
var _syn: Label
var _compact := false
var _tiny := false
var _preview_key := ""


## mode: 0 = completa (1-2 jugadores), 1 = compacta (3-4), 2 = mínima (5-8: sin tiras ni barras).
func build(mode: int, characters: Array[CharacterData], vehicles: Array[VehicleData]) -> void:
	var compact := mode >= 1
	_compact = compact
	_tiny = mode >= 2
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style.bg_color = Color(0.12, 0.13, 0.18)
	_style.set_border_width_all(3)
	_style.border_color = Color(0.25, 0.27, 0.34)
	_style.set_corner_radius_all(6)
	_style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", _style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3 if compact else 5)
	add_child(box)
	_bar = ColorRect.new()
	_bar.custom_minimum_size = Vector2(0, 6)
	box.add_child(_bar)
	var head := HBoxContainer.new()
	box.add_child(head)
	_header = _label(head, 15 if compact else 17, Color(0.9, 0.92, 1.0))
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ready_tag = _label(head, 15 if compact else 17, Color(0.4, 1.0, 0.5))
	var art := HBoxContainer.new()
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(art)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(70 if _tiny else (110 if compact else 150), 0)
	_portrait.visible = false
	art.add_child(_portrait)
	_preview = CharacterPreview.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(110 if _tiny else (140 if compact else 220), 70 if _tiny else (105 if compact else 150))
	art.add_child(_preview)
	_char_name = _label(box, 19 if compact else 24, Color.WHITE)
	_char_desc = _label(box, 12, Color(0.72, 0.75, 0.85))
	_char_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_char_desc.custom_minimum_size = Vector2(200, 0)
	_char_desc.visible = not compact
	_char_strip = ThumbStrip.new()
	var chars: Array[Dictionary] = []
	for c in characters:
		chars.append({"color": c.color, "label": c.display_name.left(1), "tex": ArtLibrary.character(c.id)})
	_char_strip.setup(chars, ceili(characters.size() / 2.0), 22.0 if compact else 28.0)
	_char_strip.visible = not _tiny
	box.add_child(_char_strip)
	_veh_name = _label(box, 17 if compact else 20, Color(1.0, 0.85, 0.4))
	_veh_desc = _label(box, 12, Color(0.72, 0.75, 0.85))
	_veh_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_veh_desc.custom_minimum_size = Vector2(200, 0)
	_veh_desc.visible = not compact
	_veh_strip = ThumbStrip.new()
	var vehs: Array[Dictionary] = []
	for v in vehicles:
		vehs.append({"color": v.body_color, "label": v.display_name.left(1), "tex": ArtLibrary.vehicle(v.id)})
	_veh_strip.setup(vehs, vehicles.size(), 34.0 if compact else 44.0)
	_veh_strip.visible = not _tiny
	box.add_child(_veh_strip)
	_stats = StatBars.new()
	_stats.row = 16.0 if compact else 20.0
	_stats.visible = not _tiny
	box.add_child(_stats)
	_syn = _label(box, 13, Color(1.0, 0.9, 0.5))
	_syn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_syn.custom_minimum_size = Vector2(200, 0)


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


## Una llamada por cambio visible. "veh_locked" = artillero (el vehículo lo elige el conductor).
func show_state(d: Dictionary) -> void:
	var ch: CharacterData = d["character"]
	var v: VehicleData = d["vehicle"]
	_bar.color = d["bar_color"]
	_header.text = d["header"]
	_ready_tag.text = "✔ LISTO" if d["ready"] else ""
	_style.border_color = Color(0.3, 0.9, 0.45) if d["ready"] else Color(0.25, 0.27, 0.34)
	var tex := ArtLibrary.character(ch.id)
	_portrait.texture = tex
	_portrait.visible = tex != null
	var key: String = d["preview_key"]
	if key != _preview_key:   # el modelo 3D solo se reconstruye cuando cambia la elección
		_preview_key = key
		_preview.show_kart(v, d["driver"], d["gunner"], d["body_color"])
	_char_name.text = "◀  %s  ▶" % ch.display_name
	_char_desc.text = ch.description
	_char_strip.set_selected(d["char_idx"])
	if d["veh_locked"]:
		_veh_name.text = "Kart: %s  (lo elige el conductor)" % v.display_name
	else:
		_veh_name.text = "▲  %s  ▼" % v.display_name
	_veh_desc.text = v.description
	_veh_strip.set_selected(d["veh_idx"])
	_stats.set_delta(d["delta"])
	_syn.text = d["synergy"]
	_syn.visible = d["synergy"] != ""
