extends SceneTree
## Script de equilibrio: calcula todas las combinaciones y marca las que se salen de ±15 % del promedio.
##   Godot_console.exe --headless --path . --script tools/balance.gd -- [--threshold=15] [--write]
## --write guarda el informe en docs/BALANCE.md. Sale con código 1 si hay combinaciones marcadas.


func _init() -> void:
	var threshold := 15.0
	var write := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--threshold="):
			threshold = float(a.get_slice("=", 1))
		elif a == "--write":
			write = true
	var res := BalanceAnalyzer.analyze(DataCatalog.vehicles(), DataCatalog.characters(), threshold)
	var report := BalanceAnalyzer.format_report(res)
	print(report)
	if write:
		var f := FileAccess.open("res://docs/BALANCE.md", FileAccess.WRITE)
		f.store_string(report + "\n")
		f.close()
		print("Informe guardado en docs/BALANCE.md")
	quit(1 if not res["flagged"].is_empty() else 0)
