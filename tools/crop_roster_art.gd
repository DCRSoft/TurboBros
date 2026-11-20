extends SceneTree
## Recorta las tarjetas de personajes y vehículos de assets/art/roster_source.png a assets/art/characters|vehicles/<id>.png.
##   Godot_console.exe --headless --path . --script tools/crop_roster_art.gd
## Imagen © DCRSoft (derechos reservados, ver LICENSE-ASSETS.md).

const CARDS := {
	"characters/drancr": Rect2i(10, 118, 252, 218), "characters/clarstar": Rect2i(258, 118, 258, 218),
	"characters/ferchaos": Rect2i(524, 118, 240, 218), "characters/end": Rect2i(768, 118, 244, 218),
	"characters/agnelopolus": Rect2i(1014, 118, 250, 218), "characters/polewar": Rect2i(1264, 118, 260, 218),
	"characters/brasa": Rect2i(8, 342, 260, 214), "characters/fungo": Rect2i(256, 342, 262, 214),
	"characters/gloop": Rect2i(524, 342, 234, 214), "characters/grunk": Rect2i(762, 342, 262, 214),
	"characters/huesos": Rect2i(1028, 342, 254, 214), "characters/kraki": Rect2i(1284, 342, 246, 214),
	"characters/ojon": Rect2i(46, 560, 346, 202), "characters/tornillo": Rect2i(408, 560, 346, 202),
	"characters/xyla": Rect2i(756, 560, 350, 202), "characters/zorp": Rect2i(1108, 560, 384, 202),
	"vehicles/azulon": Rect2i(10, 792, 250, 222), "vehicles/chatarrero": Rect2i(262, 792, 258, 222),
	"vehicles/cohete": Rect2i(524, 792, 236, 222), "vehicles/escorpion": Rect2i(762, 792, 250, 222),
	"vehicles/relampago": Rect2i(1014, 792, 250, 222), "vehicles/tanque": Rect2i(1264, 792, 260, 222),
}


func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/roster_source.png"))
	if img == null:
		push_error("No se pudo abrir roster_source.png")
		quit(1)
		return
	print("Imagen: ", img.get_size())
	for k in CARDS:
		var c := img.get_region(CARDS[k])
		c.save_png(ProjectSettings.globalize_path("res://assets/art/%s.png" % k))
	print("Recortes: ", CARDS.size())
	quit()
