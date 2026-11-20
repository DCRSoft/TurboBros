extends Node
## Versión del juego. Única fuente de verdad: el archivo VERSION en la raíz.
## (Debe incluirse en la exportación: include_filter="VERSION".)

var current: String = "0.0.0"


func _ready() -> void:
	var f := FileAccess.open("res://VERSION", FileAccess.READ)
	if f:
		current = f.get_as_text().strip_edges()
	# Verificación del build exportado:  TurboBros.exe --headless -- --version-info
	if OS.get_cmdline_user_args().has("--version-info"):
		print("TurboBros ", current)
		get_tree().quit()


## Devuelve >0 si a > b, <0 si a < b, 0 si iguales. Acepta "v1.2.0" o "1.2.0".
static func compare(a: String, b: String) -> int:
	var pa := a.trim_prefix("v").split(".")
	var pb := b.trim_prefix("v").split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0
