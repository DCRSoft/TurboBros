extends SceneTree
## Recorta las 10 tarjetas de pistas de assets/art/tracks_source.webp a assets/art/tracks/<id>.png (título + mapa).
##   Godot_console.exe --headless --path . --script tools/crop_track_art.gd
## Imagen © DCRSoft (derechos reservados, ver LICENSE-ASSETS.md).

const IDS: Array[String] = ["01_costa", "02_neon", "03_bosque", "04_circuito", "05_volcan",
		"06_desierto", "07_industrial", "08_nieve", "09_extremo", "10_fantasia"]
## Rectángulos (x, y, ancho, alto) en la imagen de 1536x1024: solo título y mapa, sin los textos de longitud.
const RECTS: Array[Rect2i] = [
	Rect2i(8, 15, 288, 378), Rect2i(314, 15, 282, 378), Rect2i(607, 15, 290, 378), Rect2i(909, 15, 313, 378), Rect2i(1233, 15, 270, 378),
	Rect2i(8, 488, 302, 326), Rect2i(321, 488, 289, 326), Rect2i(621, 488, 289, 326), Rect2i(922, 488, 298, 326), Rect2i(1230, 488, 300, 326),
]


func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/tracks_source.webp"))
	if img == null:
		push_error("No se pudo abrir tracks_source.webp")
		quit(1)
		return
	print("Imagen: ", img.get_size())
	for i in IDS.size():
		var c := img.get_region(RECTS[i])
		var err := c.save_png(ProjectSettings.globalize_path("res://assets/art/tracks/%s.png" % IDS[i]))
		print(IDS[i], " ", c.get_size(), " ", err)
	quit()
