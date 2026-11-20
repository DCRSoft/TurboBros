extends SceneTree
## Genera los .tres de pistas (data/tracks) y temas (data/themes).
##   Godot_console.exe --headless --path . --script tools/generate_tracks.gd
## Cada pista es una curva cerrada "estrellada" r(θ) (nunca se cruza a sí misma) con relieve; los puntos de control
## quedan guardados como datos y se pueden editar o sustituir por otros trazados. El índice 0 es la meta.

const TRACK_DIR := "res://data/tracks/"
const THEME_DIR := "res://data/themes/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TRACK_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(THEME_DIR))
	_themes()
	_tracks()
	print("Pistas y temas generados.")
	quit()


# --- Pistas ---------------------------------------------------------------------------------

## rx = ax + sum(bx_k sin(k θ + p)),  rz = az + ...,  y = sum(ey_k sin(m θ + q))
func _points(n: int, ax: float, xh: Array, az: float, zh: Array, yh: Array) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in n:
		var th := i * TAU / n
		var rx := ax
		for h in xh:
			rx += h[0] * sin(h[1] * th + h[2])
		var rz := az
		for h in zh:
			rz += h[0] * sin(h[1] * th + h[2])
		var y := 0.0
		for h in yh:
			y += h[0] * sin(h[1] * th + h[2])
		pts.append(Vector3(rx * cos(th), y, rz * sin(th)))
	return pts


func _track(id: String, name: String, desc: String, theme: String, pts: PackedVector3Array, half_width: float, laps := 3) -> void:
	var t := TrackData.new()
	t.id = StringName(id)
	t.display_name = name
	t.description = desc
	t.theme = StringName(theme)
	t.control_points = pts
	t.road_half_width = half_width
	t.default_laps = laps
	var err := ResourceSaver.save(t, TRACK_DIR + id + ".tres")
	if err != OK:
		push_error("No se pudo guardar la pista %s (%d)" % [id, err])


func _tracks() -> void:
	_track("01_bosque", "Bosque Esmeralda", "Un circuito clásico entre pinos, con curvas amplias y una suave subida.", "bosque",
			_points(16, 170.0, [[35.0, 3.0, 0.0]], 110.0, [[25.0, 2.0, 1.0]], [[3.0, 2.0, 0.0]]), 8.0)
	_track("02_dunas", "Dunas del Escorpión", "Rectas largas y anchas sobre dunas ondulantes; el calor no perdona.", "desierto",
			_points(18, 210.0, [[30.0, 2.0, 0.5]], 130.0, [[20.0, 3.0, 0.0]], [[5.0, 1.0, 0.0], [2.0, 3.0, 1.0]]), 9.0)
	_track("03_cumbre", "Cumbre Helada", "Curvas cerradas de montaña con fuertes desniveles entre la nieve.", "nieve",
			_points(20, 150.0, [[22.0, 3.0, 0.3]], 105.0, [[16.0, 2.0, 2.0]], [[9.0, 2.0, 0.0], [3.0, 5.0, 0.0]]), 8.0)
	_track("04_volcan", "Volcán Brasa", "Un trazado retorcido sobre roca negra, con lava a ambos lados.", "volcan",
			_points(20, 175.0, [[32.0, 3.0, 0.5]], 115.0, [[20.0, 2.0, 1.5]], [[6.0, 3.0, 0.0]]), 8.0)
	_track("05_alien", "Planeta Zorp", "Cristales, hongos gigantes y una chicane que no esperabas.", "alien",
			_points(20, 185.0, [[25.0, 2.0, 0.0], [12.0, 5.0, 1.0]], 120.0, [[26.0, 3.0, 0.7]], [[4.0, 4.0, 1.0]]), 8.5)


# --- Temas ----------------------------------------------------------------------------------

func _theme(id: String, name: String, props: Dictionary) -> void:
	var t := ThemeData.new()
	t.id = StringName(id)
	t.display_name = name
	for k in props:
		if k == "props":
			t.props.assign(props[k])   # Array[Dictionary] tipado: no se puede asignar con set()
		else:
			t.set(k, props[k])
	var err := ResourceSaver.save(t, THEME_DIR + id + ".tres")
	if err != OK:
		push_error("No se pudo guardar el tema %s (%d)" % [id, err])


func _p(kind: String, density: float, smin: float, smax: float, tint := Color.WHITE) -> Dictionary:
	return {"kind": kind, "density": density, "min": smin, "max": smax, "tint": tint}


func _themes() -> void:
	_theme("bosque", "Bosque", {
		"sky_top": Color(0.33, 0.55, 0.92), "sky_horizon": Color(0.78, 0.88, 0.96), "ground_horizon": Color(0.55, 0.7, 0.6),
		"ambient": Color(0.62, 0.66, 0.7), "fog_color": Color(0.72, 0.82, 0.9), "fog_density": 0.0016,
		"sun_color": Color(1.0, 0.96, 0.86), "sun_energy": 1.0, "sun_rotation": Vector3(-48, 35, 0),
		"ground_low": Color(0.28, 0.5, 0.24), "ground_high": Color(0.42, 0.58, 0.3), "rock": Color(0.5, 0.48, 0.45),
		"accent": Color(0.93, 0.95, 0.98), "amplitude": 24.0, "feature_size": 110.0, "snow_line": 0.0,
		"road_a": Color(0.24, 0.24, 0.27), "road_b": Color(0.29, 0.29, 0.32), "wall": Color(0.75, 0.3, 0.25),
		"mountain": Color(0.35, 0.5, 0.45), "mountain_cap": Color(0.96, 0.97, 1.0), "mountain_count": 22,
		"props": [_p("pine", 26.0, 0.9, 1.5, Color(0.9, 1.0, 0.9)), _p("round_tree", 16.0, 0.9, 1.4), _p("bush", 20.0, 0.8, 1.4),
				_p("rock", 5.0, 0.8, 2.2), _p("cabin", 0.18, 1.0, 1.2)],
		"banner_color": Color(0.9, 0.2, 0.2),
	})
	_theme("desierto", "Desierto", {
		"sky_top": Color(0.45, 0.62, 0.85), "sky_horizon": Color(0.98, 0.86, 0.66), "ground_horizon": Color(0.9, 0.75, 0.55),
		"ambient": Color(0.75, 0.68, 0.6), "fog_color": Color(0.95, 0.83, 0.65), "fog_density": 0.0022,
		"sun_color": Color(1.0, 0.88, 0.7), "sun_energy": 1.15, "sun_rotation": Vector3(-42, 50, 0),
		"ground_low": Color(0.86, 0.7, 0.45), "ground_high": Color(0.93, 0.78, 0.52), "rock": Color(0.7, 0.42, 0.28),
		"accent": Color(0.97, 0.9, 0.72), "amplitude": 16.0, "feature_size": 150.0, "snow_line": 0.0,
		"road_a": Color(0.4, 0.34, 0.3), "road_b": Color(0.46, 0.39, 0.34), "curb_a": Color(0.85, 0.35, 0.15), "wall": Color(0.85, 0.5, 0.25),
		"mountain": Color(0.75, 0.45, 0.3), "mountain_cap": Color(0.92, 0.6, 0.4), "mountain_count": 18,
		"props": [_p("cactus", 12.0, 0.8, 1.5), _p("rock", 8.0, 0.8, 2.4, Color(1.0, 0.85, 0.75)), _p("palm", 3.0, 0.9, 1.3),
				_p("dead_tree", 2.5, 0.8, 1.3), _p("ruin_pillar", 0.8, 0.9, 1.4)],
		"banner_color": Color(0.95, 0.55, 0.1),
	})
	_theme("nieve", "Nieve", {
		"sky_top": Color(0.55, 0.68, 0.85), "sky_horizon": Color(0.9, 0.94, 0.98), "ground_horizon": Color(0.85, 0.9, 0.95),
		"ambient": Color(0.72, 0.76, 0.84), "fog_color": Color(0.88, 0.92, 0.97), "fog_density": 0.0026,
		"sun_color": Color(0.95, 0.96, 1.0), "sun_energy": 0.95, "sun_rotation": Vector3(-38, 20, 0),
		"ground_low": Color(0.86, 0.9, 0.96), "ground_high": Color(0.96, 0.97, 1.0), "rock": Color(0.45, 0.47, 0.55),
		"accent": Color(1.0, 1.0, 1.0), "amplitude": 34.0, "feature_size": 100.0, "snow_line": 6.0,
		"road_a": Color(0.3, 0.32, 0.38), "road_b": Color(0.35, 0.37, 0.43), "curb_a": Color(0.2, 0.45, 0.85), "wall": Color(0.55, 0.75, 0.95),
		"mountain": Color(0.55, 0.62, 0.78), "mountain_cap": Color(1.0, 1.0, 1.0), "mountain_count": 26,
		"props": [_p("snow_pine", 28.0, 0.9, 1.6), _p("rock", 7.0, 0.8, 2.2, Color(0.8, 0.85, 0.95)), _p("ice_crystal", 4.0, 0.8, 1.5),
				_p("cabin", 0.22, 1.0, 1.2, Color(0.95, 0.9, 0.85))],
		"banner_color": Color(0.2, 0.5, 0.95),
	})
	_theme("volcan", "Volcán", {
		"sky_top": Color(0.22, 0.12, 0.18), "sky_horizon": Color(0.95, 0.45, 0.2), "ground_horizon": Color(0.5, 0.2, 0.12),
		"ambient": Color(0.5, 0.36, 0.34), "fog_color": Color(0.55, 0.25, 0.15), "fog_density": 0.0028,
		"sun_color": Color(1.0, 0.6, 0.35), "sun_energy": 1.05, "sun_rotation": Vector3(-30, 60, 0),
		"ground_low": Color(0.17, 0.14, 0.14), "ground_high": Color(0.3, 0.2, 0.18), "rock": Color(0.26, 0.23, 0.24),
		"accent": Color(1.0, 0.45, 0.1), "amplitude": 28.0, "feature_size": 95.0, "snow_line": 0.0,
		"road_a": Color(0.2, 0.19, 0.21), "road_b": Color(0.25, 0.23, 0.26), "curb_a": Color(1.0, 0.45, 0.1), "curb_b": Color(0.15, 0.15, 0.17),
		"wall": Color(0.28, 0.24, 0.25),
		"mountain": Color(0.25, 0.2, 0.22), "mountain_cap": Color(1.0, 0.5, 0.15), "mountain_count": 20,
		"props": [_p("lava_spire", 10.0, 0.8, 1.8), _p("rock", 12.0, 0.8, 2.4, Color(0.55, 0.45, 0.45)), _p("dead_tree", 4.0, 0.8, 1.2, Color(0.4, 0.3, 0.3)),
				_p("crystal", 2.0, 0.8, 1.4, Color(1.0, 0.45, 0.35))],
		"banner_color": Color(1.0, 0.4, 0.1),
	})
	_theme("alien", "Planeta alienígena", {
		"sky_top": Color(0.2, 0.12, 0.4), "sky_horizon": Color(0.45, 0.85, 0.85), "ground_horizon": Color(0.4, 0.3, 0.6),
		"ambient": Color(0.55, 0.52, 0.72), "fog_color": Color(0.5, 0.4, 0.75), "fog_density": 0.002,
		"sun_color": Color(0.85, 1.0, 0.95), "sun_energy": 1.0, "sun_rotation": Vector3(-55, -30, 0),
		"ground_low": Color(0.25, 0.16, 0.42), "ground_high": Color(0.36, 0.3, 0.58), "rock": Color(0.2, 0.36, 0.42),
		"accent": Color(0.55, 1.0, 0.9), "amplitude": 26.0, "feature_size": 105.0, "snow_line": 0.0,
		"road_a": Color(0.17, 0.14, 0.26), "road_b": Color(0.22, 0.18, 0.32), "curb_a": Color(0.3, 0.95, 0.9), "curb_b": Color(0.9, 0.3, 0.85),
		"wall": Color(0.3, 0.8, 0.85),
		"mountain": Color(0.4, 0.3, 0.65), "mountain_cap": Color(0.95, 0.5, 0.9), "mountain_count": 22,
		"props": [_p("crystal", 12.0, 0.8, 1.8, Color(0.5, 1.0, 0.95)), _p("mushroom", 14.0, 0.8, 1.8), _p("lava_spire", 3.0, 0.8, 1.4, Color(0.6, 0.4, 0.9)),
				_p("rock", 6.0, 0.8, 2.0, Color(0.7, 0.7, 1.0))],
		"banner_color": Color(0.9, 0.3, 0.85),
	})
