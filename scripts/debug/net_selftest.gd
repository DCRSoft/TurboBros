extends Node
## Arranque de la prueba de red de DOS procesos (ver tools/net_test.ps1). Esta escena la reemplaza el cambio
## de escena de la partida, así que la lógica vive en un nodo cuelga de la raíz (net_test_runner.gd).
##   Godot_console.exe --headless --path . res://scenes/debug/net_selftest.tscn -- --role=host --port=24690
##   Godot_console.exe --headless --path . res://scenes/debug/net_selftest.tscn -- --role=client --addr=127.0.0.1 --port=24690


func _ready() -> void:
	var runner := Node.new()
	runner.name = "NetTestRunner"
	runner.set_script(load("res://scripts/debug/net_test_runner.gd"))
	get_tree().root.add_child.call_deferred(runner)
