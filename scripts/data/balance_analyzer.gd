class_name BalanceAnalyzer
extends RefCounted
## Equilibrio: calcula el índice de potencia de TODAS las combinaciones (vehículo x personaje en solitario
## y vehículo x conductor x artillero) y marca las que se salen de ±threshold % del promedio de su modo.
## Debe haber mejores y peores combinaciones, pero sin diferencias drásticas.


static func analyze(vehicles: Array, characters: Array, threshold := 15.0) -> Dictionary:
	var entries: Array[Dictionary] = []
	for v in vehicles:
		for c in characters:
			entries.append(_entry("solo", v, c, null))
	for v in vehicles:
		for d in characters:
			for g in characters:
				if g != d:
					entries.append(_entry("duo", v, d, g))
	var means := {}
	for mode in ["solo", "duo"]:
		var sum := 0.0
		var n := 0
		for e in entries:
			if e["mode"] == mode:
				sum += e["index"]
				n += 1
		means[mode] = sum / maxi(n, 1)
	var flagged: Array[Dictionary] = []
	for e in entries:
		e["dev"] = (e["index"] / means[e["mode"]] - 1.0) * 100.0
		e["flagged"] = absf(e["dev"]) > threshold
		if e["flagged"]:
			flagged.append(e)
	return {"entries": entries, "means": means, "flagged": flagged, "threshold": threshold}


static func _entry(mode: String, v: VehicleData, d: CharacterData, g: CharacterData) -> Dictionary:
	var delta := KartBuild.combine(v, d, g)
	return {"mode": mode, "vehicle": v, "driver": d, "gunner": g, "delta": delta,
			"index": KartBuild.power_index(delta), "dev": 0.0, "flagged": false}


static func entry_name(e: Dictionary) -> String:
	var s: String = "%s + %s" % [e["vehicle"].display_name, e["driver"].display_name]
	if e["gunner"] != null:
		s += " (artillero: %s)" % e["gunner"].display_name
	return s


static func _sorted(res: Dictionary, mode: String, descending: bool) -> Array[Dictionary]:
	var arr: Array[Dictionary] = []
	for e in res["entries"]:
		if e["mode"] == mode:
			arr.append(e)
	arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["index"] > b["index"] if descending else a["index"] < b["index"])
	return arr


## Resumen por modo: {min_dev, max_dev, spread} (spread = mejor / peor - 1, en %).
static func spread(res: Dictionary, mode: String) -> Dictionary:
	var best := _sorted(res, mode, true)[0]
	var worst := _sorted(res, mode, false)[0]
	return {"max_dev": best["dev"], "min_dev": worst["dev"], "spread": (best["index"] / worst["index"] - 1.0) * 100.0}


static func format_report(res: Dictionary) -> String:
	var L := PackedStringArray()
	L.append("# Equilibrio de combinaciones")
	L.append("")
	L.append("Generado por `tools/balance.gd`. Índice de potencia: media ponderada de las estadísticas finales (1.00 = kart base).")
	L.append("Se marca toda combinación a más de ±%.0f %% del promedio de su modo." % res["threshold"])
	L.append("")
	for mode in ["solo", "duo"]:
		var sp := spread(res, mode)
		var count := 0
		for e in res["entries"]:
			if e["mode"] == mode:
				count += 1
		L.append("## %s" % ("Kart de 1 jugador" if mode == "solo" else "Kart de 2 jugadores (conductor + artillero)"))
		L.append("")
		L.append("- Combinaciones: %d · índice medio: %.4f" % [count, res["means"][mode]])
		L.append("- Mejor: %+.2f %% · peor: %+.2f %% respecto a la media · diferencia mejor/peor: %.2f %%" % [
				sp["max_dev"], sp["min_dev"], sp["spread"]])
		L.append("")
		L.append("| Mejores | Índice | Desv. |")
		L.append("|---|---|---|")
		var best := _sorted(res, mode, true)
		for i in mini(5, best.size()):
			L.append("| %s | %.4f | %+.2f %% |" % [entry_name(best[i]), best[i]["index"], best[i]["dev"]])
		L.append("")
		L.append("| Peores | Índice | Desv. |")
		L.append("|---|---|---|")
		var worst := _sorted(res, mode, false)
		for i in mini(5, worst.size()):
			L.append("| %s | %.4f | %+.2f %% |" % [entry_name(worst[i]), worst[i]["index"], worst[i]["dev"]])
		L.append("")
	L.append("## Medias por vehículo y personaje (kart de 1 jugador)")
	L.append("")
	var by_v := {}
	var by_c := {}
	for e in res["entries"]:
		if e["mode"] != "solo":
			continue
		by_v[e["vehicle"].display_name] = by_v.get(e["vehicle"].display_name, []) + [e["index"]]
		by_c[e["driver"].display_name] = by_c.get(e["driver"].display_name, []) + [e["index"]]
	L.append("| Vehículo | Índice medio |")
	L.append("|---|---|")
	for k in by_v:
		L.append("| %s | %.4f |" % [k, _avg(by_v[k])])
	L.append("")
	L.append("| Personaje | Índice medio |")
	L.append("|---|---|")
	for k in by_c:
		L.append("| %s | %.4f |" % [k, _avg(by_c[k])])
	L.append("")
	var flagged: Array = res["flagged"]
	L.append("## Fuera de ±%.0f %%: %d combinaciones" % [res["threshold"], flagged.size()])
	L.append("")
	for e in flagged:
		L.append("- %s: %+.2f %%" % [entry_name(e), e["dev"]])
	return "\n".join(L)


static func _avg(a: Array) -> float:
	var s := 0.0
	for x in a:
		s += x
	return s / maxi(a.size(), 1)
