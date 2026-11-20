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

## Trazados dibujados a mano (metros, x/z; sentido horario visto desde arriba; el primer punto es la meta), inspirados en
## el cartel de pistas del proyecto. La altura es una ondulación suave (amplitud, armónico, fase). Largo ~1,7 km.
const LAYOUT_COSTA := [[-34.1, 229.4], [120.9, 241.8], [232.5, 179.8], [269.7, 43.4], [244.9, -93.0], [170.5, -204.6], [46.5, -266.6], [-89.9, -254.2], [-189.1, -179.8], [-139.5, -93.0], [-189.1, -18.6], [-127.1, 55.8], [-176.7, 142.6], [-139.5, 217.0]]
const LAYOUT_NEON := [[-140.4, 179.2], [-203.0, 97.7], [-218.7, -19.1], [-177.8, -133.6], [-81.7, -208.6], [43.6, -227.2], [153.8, -184.3], [210.5, -90.4], [205.2, 15.0], [157.8, 69.9], [108.7, 38.0], [69.7, -36.4], [8.2, -74.5], [-43.6, -35.1], [-38.8, 53.5], [-1.6, 142.7], [4.8, 200.5], [-56.5, 212.8]]
const LAYOUT_BOSQUE := [[-223.0, 170.0], [-240.6, 67.3], [-196.9, -20.6], [-212.8, -109.7], [-147.0, -193.7], [-32.4, -230.5], [69.7, -206.1], [152.6, -227.1], [218.4, -171.0], [208.7, -74.5], [152.0, -13.8], [184.9, 62.2], [209.9, 147.9], [128.2, 202.4], [24.9, 167.2], [-42.0, 103.6], [-103.3, 133.7], [-151.0, 192.7]]
const LAYOUT_CIRCUITO := [[-177.2, 153.7], [-201.8, 22.2], [-185.4, -101.0], [-119.6, -175.0], [-4.6, -191.4], [118.7, -175.0], [163.9, -109.2], [151.5, -27.1], [61.2, -10.6], [-21.0, -35.3], [-78.6, -2.4], [-70.3, 55.1], [3.6, 79.8], [102.2, 71.5], [151.5, 112.6], [126.9, 161.9], [-21.0, 170.2]]
const LAYOUT_VOLCAN := [[-249.6, 76.5], [-257.7, -56.2], [-201.1, -186.3], [-86.2, -266.9], [47.5, -281.7], [157.7, -225.6], [197.5, -130.2], [157.7, -64.3], [88.8, -40.9], [53.1, 1.0], [86.8, 62.7], [156.7, 117.9], [175.6, 169.4], [101.0, 195.9], [-1.0, 177.6], [-78.1, 147.5], [-143.4, 153.1], [-205.2, 150.5]]
const LAYOUT_DESIERTO := [[-254.0, 144.0], [-264.3, 40.7], [-181.7, -31.6], [-88.7, -93.6], [4.3, -165.9], [97.2, -238.2], [190.2, -248.5], [200.5, -165.9], [128.2, -103.9], [45.6, -41.9], [97.2, 20.1], [179.9, 71.7], [169.5, 154.3], [66.2, 185.3], [-47.4, 123.4], [-140.4, 164.7], [-202.3, 185.3]]
const LAYOUT_INDUSTRIAL := [[-227.9, 177.2], [-244.4, 54.5], [-205.3, -49.2], [-213.6, -150.5], [-136.6, -221.1], [-32.3, -202.7], [32.9, -139.8], [120.6, -167.7], [206.6, -198.5], [235.0, -112.0], [199.4, -23.7], [224.9, 62.8], [191.1, 158.9], [90.4, 203.8], [2.1, 165.3], [-80.8, 208.0], [-162.1, 234.7]]
const LAYOUT_NIEVE := [[-239.7, 124.5], [-250.3, -14.2], [-165.0, -120.9], [-47.6, -152.9], [-15.6, -238.2], [101.7, -248.9], [197.7, -184.9], [208.4, -67.6], [123.0, -14.2], [59.0, 71.1], [144.4, 135.1], [123.0, 209.8], [-5.0, 199.1], [-79.7, 124.5], [-154.3, 177.8]]
const LAYOUT_EXTREMO := [[-167.1, 129.7], [-182.2, -13.9], [-159.6, -127.3], [-76.4, -172.7], [44.6, -180.2], [135.3, -150.0], [158.0, -66.8], [120.2, -6.4], [44.6, -13.9], [-8.4, -66.8], [-76.4, -59.3], [-99.1, 8.8], [-53.7, 61.7], [29.4, 69.2], [89.9, 46.6], [142.8, 84.4], [127.7, 144.8], [21.9, 160.0], [-91.5, 152.4]]
const LAYOUT_FANTASIA := [[-256.4, 105.9], [-273.8, -29.5], [-220.4, -171.0], [-103.9, -272.6], [41.7, -304.0], [165.7, -261.5], [220.3, -171.5], [192.2, -73.6], [124.7, 12.6], [86.9, 91.7], [100.3, 164.7], [109.8, 219.9], [53.4, 247.2], [-61.4, 242.8], [-178.9, 199.0]]


func _points(layout: Array, amp: float, k: float, phase: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var n := layout.size()
	for i in n:
		var y := amp * sin(TAU * k * i / n + phase)
		pts.append(Vector3(layout[i][0], y, layout[i][1]))
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
	_track("01_costa", "Costa Tropical", "Curvas suaves junto al mar y una chicane entre las palmeras.", "costa", _points(LAYOUT_COSTA, 2.5, 2.0, 0.0), 8.5)
	_track("02_neon", "Ciudad Neón", "De noche entre rascacielos, con una espiral en el centro de la ciudad.", "neon", _points(LAYOUT_NEON, 1.5, 3.0, 1.0), 8.0)
	_track("03_bosque", "Bosque Salvaje", "Una serpiente entre pinos, rocas y cabañas, con subidas y bajadas.", "bosque", _points(LAYOUT_BOSQUE, 6.0, 2.0, 0.0), 8.0)
	_track("04_circuito", "Circuito Internacional", "Trazado profesional: rectas largas, gradas y una horquilla interior.", "circuito", _points(LAYOUT_CIRCUITO, 1.0, 1.0, 0.0), 9.5)
	_track("05_volcan", "Volcán en Erupción", "Roca negra y lava a ambos lados, con una bahía de curvas cerradas.", "volcan", _points(LAYOUT_VOLCAN, 7.0, 2.0, 0.5), 8.0)
	_track("06_desierto", "Autódromo del Desierto", "Rectas largas en diagonal, una chicane y cactus por todas partes.", "desierto", _points(LAYOUT_DESIERTO, 4.0, 1.0, 0.0), 9.0)
	_track("07_industrial", "Ciudad Industrial", "Depósitos y chimeneas, con zigzags entre las fábricas.", "industrial", _points(LAYOUT_INDUSTRIAL, 2.5, 3.0, 0.0), 8.0)
	_track("08_nieve", "Montaña Nevada", "Curvas de montaña entre pinos nevados y cristales de hielo.", "nieve", _points(LAYOUT_NIEVE, 9.0, 2.0, 0.0), 8.0)
	_track("09_extremo", "Autódromo Extremo", "Un gran óvalo con un laberinto interior de curvas técnicas.", "circuito", _points(LAYOUT_EXTREMO, 3.5, 2.0, 1.0), 9.0)
	_track("10_fantasia", "Gran Premio Fantasía", "Cristales y hongos gigantes bajo un cielo violeta.", "alien", _points(LAYOUT_FANTASIA, 6.0, 3.0, 0.0), 8.5)


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
	_theme("alien", "Fantasía", {
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
	_theme("costa", "Costa tropical", {
		"sky_top": Color(0.2, 0.55, 0.95), "sky_horizon": Color(0.7, 0.92, 0.98), "ground_horizon": Color(0.6, 0.85, 0.85),
		"ambient": Color(0.7, 0.74, 0.78), "fog_color": Color(0.7, 0.9, 0.95), "fog_density": 0.0016,
		"sun_color": Color(1.0, 0.95, 0.82), "sun_energy": 0.85, "sun_rotation": Vector3(-55, 25, 0),
		"ground_low": Color(0.76, 0.62, 0.36), "ground_high": Color(0.25, 0.55, 0.24), "rock": Color(0.62, 0.56, 0.48),
		"accent": Color(0.95, 0.95, 0.9), "amplitude": 16.0, "feature_size": 120.0, "snow_line": 0.0,
		"road_a": Color(0.3, 0.3, 0.34), "road_b": Color(0.36, 0.36, 0.4), "curb_a": Color(0.9, 0.15, 0.15), "wall": Color(0.95, 0.93, 0.88),
		"mountain": Color(0.25, 0.6, 0.5), "mountain_cap": Color(0.7, 0.9, 0.6), "mountain_count": 16,
		"props": [_p("palm", 14.0, 0.9, 1.5), _p("bush", 10.0, 0.8, 1.4, Color(0.8, 1.0, 0.7)), _p("rock", 4.0, 0.8, 2.0, Color(1.0, 0.92, 0.8)),
				_p("lighthouse", 0.08, 1.0, 1.2), _p("round_tree", 3.0, 0.9, 1.3)],
		"banner_color": Color(0.1, 0.7, 0.85),
	})
	_theme("neon", "Ciudad neón", {
		"sky_top": Color(0.04, 0.02, 0.2), "sky_horizon": Color(0.6, 0.15, 0.65), "ground_horizon": Color(0.25, 0.1, 0.4),
		"ambient": Color(0.5, 0.42, 0.75), "fog_color": Color(0.28, 0.1, 0.42), "fog_density": 0.0024,
		"sun_color": Color(0.6, 0.65, 1.0), "sun_energy": 0.75, "sun_rotation": Vector3(-35, -40, 0),
		"ground_low": Color(0.11, 0.1, 0.17), "ground_high": Color(0.2, 0.17, 0.3), "rock": Color(0.22, 0.2, 0.3),
		"accent": Color(0.4, 0.9, 1.0), "amplitude": 8.0, "feature_size": 140.0, "snow_line": 0.0,
		"road_a": Color(0.12, 0.12, 0.17), "road_b": Color(0.17, 0.16, 0.23), "curb_a": Color(0.2, 0.95, 1.0), "curb_b": Color(1.0, 0.25, 0.85),
		"wall": Color(0.25, 0.85, 1.0),
		"mountain": Color(0.2, 0.12, 0.34), "mountain_cap": Color(0.95, 0.35, 0.85), "mountain_count": 20,
		"props": [_p("tower", 4.0, 0.9, 1.7), _p("lamp", 5.0, 1.0, 1.2, Color(1.0, 0.6, 0.95)), _p("crystal", 1.0, 0.8, 1.4, Color(1.0, 0.4, 0.9))],
		"banner_color": Color(1.0, 0.25, 0.85),
	})
	_theme("circuito", "Circuito", {
		"sky_top": Color(0.28, 0.55, 0.95), "sky_horizon": Color(0.82, 0.9, 0.97), "ground_horizon": Color(0.55, 0.72, 0.55),
		"ambient": Color(0.68, 0.7, 0.75), "fog_color": Color(0.78, 0.86, 0.94), "fog_density": 0.0014,
		"sun_color": Color(1.0, 0.97, 0.9), "sun_energy": 0.85, "sun_rotation": Vector3(-50, 30, 0),
		"ground_low": Color(0.2, 0.46, 0.18), "ground_high": Color(0.32, 0.55, 0.22), "rock": Color(0.55, 0.55, 0.55),
		"accent": Color(0.9, 0.95, 1.0), "amplitude": 8.0, "feature_size": 150.0, "snow_line": 0.0,
		"road_a": Color(0.26, 0.26, 0.29), "road_b": Color(0.31, 0.31, 0.34), "curb_a": Color(0.9, 0.12, 0.12), "wall": Color(0.92, 0.92, 0.95),
		"mountain": Color(0.4, 0.55, 0.6), "mountain_cap": Color(0.9, 0.95, 1.0), "mountain_count": 18,
		"props": [_p("grandstand", 0.35, 1.0, 1.3), _p("round_tree", 5.0, 0.9, 1.4), _p("bush", 8.0, 0.8, 1.4), _p("pine", 3.0, 0.9, 1.4)],
		"banner_color": Color(0.95, 0.75, 0.1),
	})
	_theme("industrial", "Ciudad industrial", {
		"sky_top": Color(0.45, 0.5, 0.58), "sky_horizon": Color(0.85, 0.7, 0.55), "ground_horizon": Color(0.5, 0.45, 0.4),
		"ambient": Color(0.6, 0.58, 0.58), "fog_color": Color(0.66, 0.58, 0.5), "fog_density": 0.0026,
		"sun_color": Color(1.0, 0.85, 0.7), "sun_energy": 0.95, "sun_rotation": Vector3(-38, 55, 0),
		"ground_low": Color(0.3, 0.28, 0.26), "ground_high": Color(0.42, 0.38, 0.33), "rock": Color(0.4, 0.38, 0.36),
		"accent": Color(0.7, 0.65, 0.55), "amplitude": 10.0, "feature_size": 130.0, "snow_line": 0.0,
		"road_a": Color(0.2, 0.2, 0.22), "road_b": Color(0.25, 0.25, 0.27), "curb_a": Color(0.95, 0.8, 0.1), "curb_b": Color(0.1, 0.1, 0.1),
		"wall": Color(0.9, 0.75, 0.15),
		"mountain": Color(0.4, 0.38, 0.4), "mountain_cap": Color(0.6, 0.55, 0.5), "mountain_count": 18,
		"props": [_p("tank", 1.3, 0.9, 1.5), _p("chimney", 0.9, 0.9, 1.4), _p("rock", 6.0, 0.8, 2.2), _p("dead_tree", 2.0, 0.8, 1.2),
				_p("lamp", 2.0, 1.0, 1.2)],
		"banner_color": Color(0.95, 0.8, 0.1),
	})
