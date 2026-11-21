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
## el cartel de pistas del proyecto. La altura es una ondulación suave (amplitud, armónico, fase). Largo 1,9-2,3 km (el del cartel).
const LAYOUT_COSTA := [[-125.0, 217.1], [-43.7, 230.7], [47.0, 256.2], [131.4, 271.5], [190.7, 255.5], [219.6, 205.5], [227.7, 128.4], [227.9, 36.7], [225.0, -58.5], [216.7, -148.4], [195.0, -221.7], [150.4, -269.9], [83.7, -292.7], [16.1, -295.4], [-21.8, -278.1], [-14.3, -237.4], [17.1, -183.9], [38.1, -128.4], [28.0, -79.8], [-16.8, -47.1], [-87.0, -31.4], [-164.4, -22.2], [-232.0, -0.3], [-278.3, 42.2], [-297.9, 97.3], [-288.7, 151.4], [-251.1, 191.6], [-193.4, 211.0]]
const LAYOUT_NEON := [[-247.8, 108.3], [-254.7, 181.6], [-238.6, 250.3], [-186.0, 286.9], [-94.3, 300.7], [-2.7, 289.2], [77.4, 273.2], [150.7, 254.9], [214.8, 222.8], [260.6, 174.7], [253.7, 108.3], [203.4, 67.1], [134.7, 39.6], [88.9, -6.2], [59.1, -65.7], [59.1, -116.1], [100.3, -157.3], [157.6, -166.5], [210.2, -189.4], [221.7, -230.6], [196.5, -262.7], [123.2, -269.5], [8.7, -267.2], [-105.8, -265.0], [-169.9, -244.3], [-202.0, -196.3], [-224.9, -139.0], [-261.5, -70.3], [-270.7, 9.8], [-261.5, 78.5]]
const LAYOUT_BOSQUE := [[-187.9, 168.4], [-202.9, 215.5], [-170.7, 258.4], [-95.8, 275.5], [0.6, 275.5], [97.1, 249.8], [150.6, 211.3], [165.6, 157.7], [157.0, 93.4], [150.6, 39.9], [172.0, 1.3], [225.6, -24.4], [272.7, -39.4], [298.4, -78.0], [285.6, -120.8], [242.7, -140.1], [172.0, -135.8], [97.1, -125.1], [32.8, -135.8], [-14.3, -170.1], [-63.6, -217.2], [-106.5, -247.2], [-155.7, -251.5], [-207.2, -227.9], [-230.7, -174.4], [-224.3, -120.8], [-185.7, -78.0], [-142.9, -50.1], [-95.8, -13.7], [-70.0, 39.9], [-74.3, 87.0], [-121.5, 125.6], [-170.7, 151.3]]
const LAYOUT_CIRCUITO := [[-244.2, 61.4], [-246.3, 126.8], [-250.7, 181.3], [-239.8, 224.9], [-196.2, 233.6], [-141.7, 233.6], [-32.6, 233.6], [76.4, 233.6], [163.6, 227.1], [218.1, 198.8], [244.3, 170.4], [229.0, 126.8], [189.8, 98.5], [130.9, 94.1], [65.5, 83.2], [6.6, 50.5], [-26.1, -4.0], [-26.1, -47.6], [0.1, -80.3], [54.6, -102.2], [120.0, -108.7], [189.8, -124.0], [233.4, -156.7], [244.3, -200.3], [218.1, -237.3], [152.7, -235.2], [54.6, -235.2], [-54.4, -235.2], [-163.5, -235.2], [-224.5, -226.4], [-248.5, -189.4], [-250.7, -124.0], [-246.3, -36.7]]
const LAYOUT_VOLCAN := [[-228.0, 110.5], [-228.0, 170.6], [-215.1, 217.9], [-178.6, 245.8], [-103.4, 252.3], [4.1, 252.3], [111.5, 239.4], [193.1, 209.3], [236.1, 166.3], [244.7, 119.1], [214.6, 89.0], [158.7, 84.7], [107.2, 76.1], [77.1, 37.4], [98.6, 7.3], [150.1, -7.7], [214.6, -9.8], [249.0, -44.2], [244.7, -97.9], [214.6, -125.9], [143.7, -134.5], [68.5, -138.7], [25.5, -168.8], [-17.4, -211.8], [-60.4, -237.6], [-114.1, -237.6], [-163.5, -211.8], [-185.0, -173.1], [-157.1, -147.3], [-114.1, -140.9], [-90.5, -108.7], [-99.1, -70.0], [-146.3, -48.5], [-200.0, -35.6], [-228.0, 9.5], [-228.0, 63.2]]
const LAYOUT_DESIERTO := [[-245.1, 42.2], [-214.7, -34.8], [-184.4, -121.2], [-161.0, -198.2], [-121.3, -242.6], [-51.3, -256.6], [42.1, -272.9], [135.5, -291.6], [198.5, -291.6], [228.9, -249.6], [231.2, -191.2], [217.2, -137.5], [170.5, -104.8], [112.1, -90.8], [53.8, -62.8], [35.1, -16.1], [53.8, 25.9], [105.1, 53.9], [170.5, 77.3], [217.2, 112.3], [226.5, 159.0], [198.5, 205.7], [147.2, 226.7], [95.8, 205.7], [72.4, 166.0], [7.1, 161.3], [-86.3, 175.3], [-179.7, 205.7], [-261.4, 233.7], [-315.1, 205.7], [-329.1, 152.0], [-301.1, 95.9], [-268.4, 58.6]]
const LAYOUT_INDUSTRIAL := [[-229.0, 46.5], [-224.3, -4.6], [-219.7, -74.2], [-210.4, -143.9], [-201.1, -195.0], [-173.2, -222.8], [-126.8, -222.8], [-85.0, -202.0], [-43.2, -178.7], [-8.4, -185.7], [12.5, -218.2], [45.0, -248.4], [89.2, -255.4], [124.0, -236.8], [137.9, -178.7], [133.3, -125.3], [165.8, -85.9], [207.6, -51.0], [216.9, -9.2], [193.6, 23.3], [142.6, 34.9], [89.2, 25.6], [49.7, 39.5], [26.5, 72.0], [33.4, 106.9], [63.6, 134.7], [105.4, 153.3], [156.5, 174.2], [189.0, 211.4], [179.7, 253.2], [135.6, 271.7], [77.5, 255.5], [-3.7, 223.0], [-96.6, 206.7], [-177.9, 197.4], [-242.9, 181.2], [-270.8, 139.4], [-261.5, 88.3]]
const LAYOUT_NIEVE := [[-228.9, 66.9], [-259.4, 105.8], [-277.9, 151.1], [-271.4, 194.6], [-232.0, 227.7], [-161.8, 250.9], [-80.5, 273.9], [4.6, 298.9], [93.0, 313.2], [173.0, 304.1], [232.8, 270.8], [262.2, 219.7], [258.0, 162.7], [229.9, 114.7], [197.0, 76.6], [170.4, 41.5], [144.8, 3.9], [124.2, -34.9], [119.3, -67.6], [140.5, -91.4], [183.0, -112.1], [220.0, -146.6], [231.7, -195.5], [212.0, -243.7], [170.1, -273.3], [120.8, -274.9], [71.2, -254.2], [16.9, -230.2], [-46.6, -216.0], [-113.0, -211.9], [-171.3, -205.5], [-214.8, -181.9], [-234.8, -141.2], [-228.2, -99.2], [-200.9, -69.0], [-163.1, -47.6], [-140.9, -23.6], [-156.2, 6.1], [-193.3, 37.4]]
const LAYOUT_EXTREMO := [[-279.8, 26.8], [-254.1, -28.4], [-243.0, -79.9], [-232.0, -138.8], [-217.2, -179.3], [-195.1, -211.0], [-165.7, -221.3], [-117.8, -224.2], [-70.0, -218.3], [-36.8, -206.6], [-7.4, -191.8], [22.1, -186.7], [47.8, -203.6], [81.0, -223.5], [117.8, -238.2], [162.0, -245.6], [206.1, -238.2], [239.3, -216.1], [257.7, -175.6], [256.2, -135.1], [235.6, -105.7], [202.5, -88.8], [162.0, -77.7], [121.5, -63.7], [84.6, -44.6], [62.6, -17.3], [62.6, 12.1], [81.0, 34.2], [117.8, 45.2], [162.0, 54.1], [198.8, 67.3], [231.9, 96.8], [239.3, 129.9], [228.2, 163.1], [195.1, 188.8], [154.6, 225.6], [103.1, 238.2], [44.2, 249.9], [-7.4, 251.4], [-58.9, 251.4], [-110.5, 249.9], [-151.0, 242.6], [-184.1, 218.3], [-197.4, 185.1], [-190.0, 155.7], [-165.7, 137.3], [-125.2, 127.7], [-88.4, 118.9], [-64.8, 100.5], [-67.8, 78.4], [-88.4, 65.9], [-125.2, 63.7], [-169.4, 63.7], [-213.6, 63.7], [-250.4, 54.1]]
const LAYOUT_FANTASIA := [[-166.9, -73.6], [-206.2, -101.6], [-258.6, -71.0], [-302.3, -40.4], [-319.7, 7.6], [-315.4, 55.7], [-289.2, 90.6], [-254.2, 115.1], [-219.3, 134.3], [-175.6, 173.6], [-123.2, 221.6], [-75.2, 260.9], [-49.0, 278.4], [-9.7, 304.6], [51.5, 339.6], [130.1, 357.0], [208.7, 322.1], [269.9, 274.0], [296.1, 221.6], [296.1, 178.0], [269.9, 143.0], [287.3, 55.7], [296.1, -14.2], [287.3, -75.4], [248.0, -119.0], [239.3, -175.8], [200.0, -223.8], [165.0, -258.8], [112.6, -280.6], [51.5, -289.4], [-9.7, -289.4], [-70.8, -280.6], [-110.1, -254.4], [-123.2, -219.5], [-110.1, -184.5], [-75.2, -158.3], [-27.1, -132.1], [7.8, -101.6], [6.1, -71.0], [-35.9, -56.1], [-97.0, -62.3]]


## Elementos de cada pista por coordenadas (m); _track() los convierte en fracciones de la vuelta.
const FEATURES := {
	"01_costa": [{"type": "bridge", "a": [226.4, 32.4], "b": [226.4, -88.2], "hazard": "water"}, {"type": "turbo", "a": [-48.5, 220.5], "lat": 0.0}, {"type": "turbo", "a": [226.4, -179.8], "lat": 0.0}, {"type": "turbo", "a": [-169.0, -30.3], "lat": 0.0}, {"type": "turbo", "a": [84.1, -300.4], "lat": 0.0}],
	"02_neon": [{"type": "tunnel", "a": [-82.9, 296.1], "b": [100.3, 266.3], "hazard": ""}, {"type": "tunnel", "a": [100.3, -267.2], "b": [-105.8, -265.0], "hazard": ""}, {"type": "ramp", "a": [-254.7, 181.6], "lat": 0.0, "len": 9}, {"type": "ramp", "a": [134.7, 39.6], "lat": 0.0, "len": 9}, {"type": "turbo", "a": [214.8, 222.8], "lat": 0.0}, {"type": "turbo", "a": [59.1, -93.2], "lat": 0.0}, {"type": "turbo", "a": [-238.6, -70.3], "lat": 0.0}],
	"03_bosque": [{"type": "bridge", "a": [-147.2, -54.4], "b": [-70.0, 31.3], "hazard": "water"}, {"type": "bridge", "a": [159.2, 129.8], "b": [169.9, 9.9], "hazard": "water"}, {"type": "turbo", "a": [0.6, 275.5], "lat": 0.0}, {"type": "turbo", "a": [32.8, -135.8], "lat": 0.0}, {"type": "turbo", "a": [-155.7, -251.5], "lat": 0.0}],
	"04_circuito": [{"type": "turbo", "a": [-54.4, 233.6], "lat": 0.0}, {"type": "turbo", "a": [-54.4, -235.2], "lat": 0.0}, {"type": "turbo", "a": [54.6, -102.2], "lat": 0.0}, {"type": "turbo", "a": [-246.3, -36.7], "lat": 0.0}],
	"05_volcan": [{"type": "bridge", "a": [4.1, -198.9], "b": [-94.8, -237.6], "hazard": "lava"}, {"type": "ramp", "a": [-103.4, 252.3], "lat": 0.0, "len": 9}, {"type": "turbo", "a": [111.5, 239.4], "lat": 0.0}, {"type": "turbo", "a": [175.9, -134.5], "lat": 0.0}, {"type": "turbo", "a": [-228.0, 31.0], "lat": 0.0}],
	"06_desierto": [{"type": "ramp", "a": [42.1, -272.9], "lat": 0.0, "len": 9}, {"type": "turbo", "a": [-184.4, -121.2], "lat": 0.0}, {"type": "turbo", "a": [135.5, -291.6], "lat": 0.0}, {"type": "turbo", "a": [-86.3, 175.3], "lat": 0.0}, {"type": "turbo", "a": [217.2, 112.3], "lat": 0.0}],
	"07_industrial": [{"type": "ramp", "a": [-219.7, -74.2], "lat": 0.0, "len": 9}, {"type": "ramp", "a": [89.2, 25.6], "lat": 0.0, "len": 9}, {"type": "turbo", "a": [-96.6, 206.7], "lat": 0.0}, {"type": "turbo", "a": [-38.6, -178.7], "lat": 0.0}, {"type": "turbo", "a": [207.6, -51.0], "lat": 0.0}],
	"08_nieve": [{"type": "tunnel", "a": [13.6, -221.5], "b": [-116.2, -212.1], "hazard": ""}, {"type": "bridge", "a": [193.0, 75.8], "b": [138.7, 0.3], "hazard": "water"}, {"type": "ramp", "a": [-80.8, 271.7], "lat": 0.0, "len": 9}, {"type": "turbo", "a": [242.5, 276.4], "lat": 0.0}, {"type": "turbo", "a": [228.4, -146.0], "lat": 0.0}, {"type": "turbo", "a": [-243.6, -141.3], "lat": 0.0}],
	"09_extremo": [{"type": "turbo", "a": [50.8, 250.7], "lat": 0.0}, {"type": "turbo", "a": [161.2, -246.3], "lat": 0.0}, {"type": "turbo", "a": [83.9, -45.3], "lat": 0.0}, {"type": "turbo", "a": [-254.1, -109.4], "lat": 0.0}],
	"10_fantasia": [{"type": "bridge", "a": [-140.7, 207.7], "b": [-72.5, 265.3], "hazard": "void"}, {"type": "turbo", "a": [129.2, 357.0], "lat": 0.0}, {"type": "turbo", "a": [50.6, -290.2], "lat": 0.0}, {"type": "turbo", "a": [-245.5, -75.4], "lat": 0.0}, {"type": "turbo", "a": [265.5, 29.5], "lat": 0.0}],
}


## Atajos por pista: fracción de salida/entrada y puntos intermedios (x, z en m).
const SHORTCUTS := {
	"01_costa": [{"fa": 0.58594, "fb": 0.74219, "pts": [[-6.0, -218.0], [-10.6, -193.9], [-17.0, -170.7], [-25.1, -148.2], [-34.7, -126.6], [-45.9, -105.7], [-58.6, -85.5], [-72.7, -66.0], [-88.1, -47.2]]}],
	"02_neon": [{"fa": 0.26857, "fb": 0.40286, "pts": [[162.2, 248.4], [173.3, 226.4], [183.4, 203.5], [191.7, 180.0], [197.9, 156.3], [201.2, 132.6], [201.1, 109.2], [197.2, 86.4], [188.7, 64.6]]}],
	"03_bosque": [{"fa": 0.39385, "fb": 0.52462, "pts": [[266.6, -37.9], [268.5, -56.3], [258.9, -71.8], [240.8, -85.1], [216.9, -96.9], [190.4, -107.6], [164.0, -118.1], [140.7, -128.9]]}],
	"04_circuito": [{"fa": 0.26739, "fb": 0.36698, "pts": [[180.7, 219.2], [187.8, 196.7], [189.1, 172.6], [185.1, 148.5], [176.1, 125.7], [162.7, 105.7]]}],
	"05_volcan": [{"fa": 0.81698, "fb": 0.91947, "pts": [[-141.3, -143.4], [-131.9, -128.5], [-136.2, -108.4], [-149.7, -85.8], [-168.1, -63.4], [-187.0, -44.0]]}],
	"06_desierto": [{"fa": 0.53975, "fb": 0.66248, "pts": [[116.5, 60.4], [129.6, 81.7], [143.1, 104.0], [155.8, 126.7], [166.0, 149.6], [172.3, 172.2], [173.3, 194.1], [167.5, 214.9]]}],
	"07_industrial": [{"fa": 0.24138, "fb": 0.35982, "pts": [[5.4, -203.5], [27.1, -210.8], [51.0, -211.1], [75.2, -205.3], [98.0, -194.2], [117.2, -178.7], [131.2, -159.7]]}],
	"08_nieve": [{"fa": 0.54286, "fb": 0.67286, "pts": [[172.5, -108.2], [179.5, -130.7], [181.9, -154.8], [180.1, -179.4], [174.2, -203.6], [164.6, -226.3], [151.4, -246.5], [134.8, -263.3]]}],
	"09_extremo": [{"fa": 0.51200, "fb": 0.62133, "pts": [[129.9, 49.8], [144.6, 69.6], [157.4, 90.2], [168.0, 111.8], [176.3, 134.1], [181.8, 157.3], [184.3, 181.1]]}],
	"10_fantasia": [{"fa": 0.77575, "fb": 0.87875, "pts": [[-37.6, -285.5], [-52.4, -268.0], [-61.5, -246.7], [-65.3, -222.8], [-64.5, -197.9], [-59.3, -173.4], [-50.2, -150.6]]}],
}


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
	var total := t.length_m()
	for f in FEATURES.get(id, []):
		var a: Array = f["a"]
		var f0 := t.project_f(a[0], a[1])
		if f["type"] == "turbo":
			t.features.append({"type": "turbo", "f": f0, "lat": float(f["lat"])})
		elif f["type"] == "ramp":
			t.features.append({"type": "ramp", "f": f0, "lat": float(f["lat"]), "len": float(f["len"])})
		else:
			var bb: Array = f["b"]
			var f1 := t.project_f(bb[0], bb[1])
			if f1 < f0:
				var tmp := f0
				f0 = f1
				f1 = tmp
			var is_bridge: bool = f["type"] == "bridge"   # puentes de unos 45-65 m y túneles de 70-100 m
			var span := clampf((f1 - f0) * total, 45.0 if is_bridge else 70.0, 65.0 if is_bridge else 100.0)
			t.features.append({"type": String(f["type"]), "f": f0, "len": span, "hazard": String(f["hazard"])})
	for sc in SHORTCUTS.get(id, []):
		var mid := PackedVector3Array()
		for q in sc["pts"]:
			mid.append(Vector3(q[0], 0.0, q[1]))
		t.shortcuts.append({"fa": float(sc["fa"]), "fb": float(sc["fb"]), "pts": mid})
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
