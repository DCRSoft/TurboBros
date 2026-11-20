extends SceneTree
## Genera los .tres de vehículos (data/vehicles) y personajes (data/characters) con su aspecto 3D.
##   Godot_console.exe --headless --path . --script tools/generate_roster.gd
## Después de cambiar números, comprobar el equilibrio: tools/balance.gd (-- --write).
## Elenco: 6 personajes de la portada (DranCr, ClarStar, FerChaos, EnD, Agnelopolus, PoleWar) + 10 más
## (ogro, gris alienígena, insectoide, cíclope, robot, esqueleto, slime, dragona, hongo y kraken).

const VEHICLE_DIR := "res://data/vehicles/"
const CHARACTER_DIR := "res://data/characters/"

var SD := StatDelta
var G := CharacterData.Gender


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VEHICLE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHARACTER_DIR))
	_vehicles()
	_characters()
	print("Elenco generado.")
	quit()


func _vehicle(id: String, name: String, desc: String, style: String, color: Color, s: StatDelta) -> void:
	var v := VehicleData.new()
	v.id = StringName(id)
	v.display_name = name
	v.description = desc
	v.style = style
	v.body_color = color
	v.stats = s
	var err := ResourceSaver.save(v, VEHICLE_DIR + id + ".tres")
	if err != OK:
		push_error("No se pudo guardar el vehículo %s (%d)" % [id, err])


func _vehicles() -> void:
	# StatDelta.make(velocidad, aceleración, manejo, peso, derrape, fuera de pista, golpe, ítems)
	_vehicle("chatarrero", "Chatarrero", "Pesado y blindado con chatarra, con púas y escapes. Aguanta los choques, le cuesta arrancar y girar.",
			"scrap", Color(0.45, 0.28, 0.18), SD.make(-2, -4, -4, 12, -2, 8))
	_vehicle("azulon", "Azulón", "El equilibrado de la parrilla: sin puntos débiles.",
			"standard", Color(0.2, 0.4, 0.85), SD.make(0, 0, 1, 0, 1, 0))
	_vehicle("relampago", "Relámpago", "Ligero y veloz, con aleta trasera. Se asusta fuera del asfalto y en los choques.",
			"sleek", Color(0.95, 0.78, 0.15), SD.make(6, 2, 0, -10, 1, -8))
	_vehicle("escorpion", "Escorpión", "Con cola y pinzas: hecho para derrapar, carga los mini turbos enseguida.",
			"scorpion", Color(0.55, 0.2, 0.7), SD.make(-2, 1, 3, -4, 8, -4))
	_vehicle("tanque", "Tanque", "Camión todoterreno de ruedas enormes: lento pero se come los baches.",
			"truck", Color(0.3, 0.42, 0.25), SD.make(-4, 0, -2, 10, -3, 12))
	_vehicle("cohete", "Cohete", "Un cohete con ruedas: velocidad punta altísima; acelera y gira con pereza.",
			"rocket", Color(0.85, 0.2, 0.15), SD.make(9, -4, -6, -2, -1, -4))


func _character(id: String, name: String, desc: String, gender: CharacterData.Gender, color: Color, look: Dictionary,
		s: StatDelta, likes: Array[StringName], dislikes: Array[StringName], partner := "") -> void:
	var c := CharacterData.new()
	c.id = StringName(id)
	c.display_name = name
	c.description = desc
	c.gender = gender
	c.color = color
	c.look = look
	c.partner = StringName(partner)
	c.stats = s
	c.likes = likes
	c.like_bonus = SD.make(2, 2, 0, 0, 2, 0)        # se siente a gusto
	c.dislikes = dislikes
	c.dislike_penalty = SD.make(-2, -2, -2, 0, 0, 0)  # le sienta mal
	var err := ResourceSaver.save(c, CHARACTER_DIR + id + ".tres")
	if err != OK:
		push_error("No se pudo guardar el personaje %s (%d)" % [id, err])


func _characters() -> void:
	# Quita los ficheros de personajes anteriores que ya no existen en el elenco
	var keep := ["drancr", "clarstar", "ferchaos", "end", "agnelopolus", "polewar", "grunk", "zorp", "xyla", "ojon",
			"tornillo", "huesos", "gloop", "brasa", "fungo", "kraki"]
	for f in DirAccess.get_files_at(CHARACTER_DIR):
		if f.ends_with(".tres") and not keep.has(f.get_basename()):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(CHARACTER_DIR + f))

	# StatDelta.make(velocidad, aceleración, manejo, peso, derrape, fuera de pista, golpe, ítems)
	# --- Los de la portada (parejas: DranCr+ClarStar, FerChaos+EnD, Agnelopolus+PoleWar) ---
	_character("drancr", "DranCr", "El marrón de la armadura de púas: especialista en velocidad, nadie le gana en la recta, aunque arranca y gira con pereza.",
			G.MALE, Color(0.25, 0.14, 0.08),
			{"species": "human", "skin": Color(0.85, 0.65, 0.5), "outfit": Color(0.32, 0.2, 0.12), "outfit2": Color(0.55, 0.3, 0.14),
				"hair": Color(0.2, 0.12, 0.08), "eye": Color(0.15, 0.1, 0.05), "head": "spiked_helmet", "extras": ["spikes", "pads"], "weapon": "minigun"},
			SD.make(9, -6, -5, 0, -2, 0, 4, 0), [&"chatarrero"], [&"tanque"], "clarstar")
	_character("clarstar", "ClarStar", "La de las coletas rosas que va con DranCr: reina del derrape, carga los mini turbos al instante.",
			G.FEMALE, Color(1.0, 0.5, 0.75),
			{"species": "human", "skin": Color(0.98, 0.82, 0.76), "outfit": Color(1.0, 0.55, 0.75), "outfit2": Color(1.0, 0.85, 0.92),
				"hair": Color(1.0, 0.6, 0.8), "eye": Color(0.6, 0.2, 0.8), "head": "twintails", "extras": ["flowers"], "weapon": "cannon"},
			SD.make(-3, 0, 3, -3, 10, -2, -5, 5), [&"escorpion"], [&"tanque"], "drancr")
	_character("ferchaos", "FerChaos", "La amarilla de casco dorado y trenzas: caos con ruedas, se maneja bien fuera del asfalto y usa los ítems a la velocidad del rayo.",
			G.FEMALE, Color(1.0, 0.85, 0.1),
			{"species": "human", "skin": Color(0.98, 0.86, 0.72), "outfit": Color(0.95, 0.78, 0.2), "outfit2": Color(0.75, 0.55, 0.1),
				"hair": Color(1.0, 0.9, 0.5), "eye": Color(0.2, 0.5, 0.9), "head": "braids", "extras": ["pads"], "weapon": "blaster"},
			SD.make(1, 1, -4, -3, 0, 8, 0, 18), [&"relampago"], [&"cohete"], "end")
	_character("end", "EnD", "El de la armadura azul y el rifle de rayos, el que va con FerChaos: el tanque del grupo, pesado, resistente y de golpe durísimo.",
			G.MALE, Color(0.15, 0.35, 0.95),
			{"species": "human", "skin": Color(0.8, 0.62, 0.5), "outfit": Color(0.15, 0.3, 0.7), "outfit2": Color(0.1, 0.15, 0.4),
				"hair": Color(0.15, 0.1, 0.1), "eye": Color(0.1, 0.1, 0.15), "head": "visor_helmet", "extras": ["pads"], "weapon": "beam"},
			SD.make(-3, -3, -4, 9, -1, 8, 20, -6), [&"tanque"], [&"cohete"], "ferchaos")
	_character("agnelopolus", "Agnelopolus", "El rojo de casco integral y barba: especialista en aceleración, sale disparado de cada curva.",
			G.MALE, Color(0.9, 0.1, 0.1),
			{"species": "human", "skin": Color(0.85, 0.65, 0.5), "outfit": Color(0.75, 0.12, 0.1), "outfit2": Color(0.4, 0.05, 0.05),
				"hair": Color(0.35, 0.2, 0.1), "eye": Color(0.1, 0.1, 0.1), "head": "full_helmet", "extras": ["beard", "pads"], "weapon": "cannon"},
			SD.make(-3, 9, 1, -2, 0, -2, 0, 0), [&"azulon"], [&"chatarrero"], "polewar")
	_character("polewar", "PoleWar", "La de pelo morado y ametralladora giratoria, la que va con Agnelopolus: su golpe lanza a cualquiera a la cuneta.",
			G.FEMALE, Color(0.55, 0.2, 0.8),
			{"species": "human", "skin": Color(0.95, 0.8, 0.75), "outfit": Color(0.5, 0.25, 0.75), "outfit2": Color(0.3, 0.12, 0.5),
				"hair": Color(0.55, 0.3, 0.85), "eye": Color(0.5, 0.2, 0.7), "head": "ponytail", "extras": [], "weapon": "gatling"},
			SD.make(0, -2, -2, 4, -1, 2, 30, -8), [&"tanque"], [&"relampago"], "agnelopolus")

	# --- Monstruos, alienígenas y compañía ---
	_character("grunk", "Grunk", "Ogro verde de colmillos y garrote. Casi nadie lo mueve y casi nadie lo gira.",
			G.MALE, Color(0.35, 0.65, 0.25),
			{"species": "ogre", "skin": Color(0.4, 0.62, 0.3), "outfit": Color(0.45, 0.3, 0.18), "outfit2": Color(0.3, 0.2, 0.1),
				"eye": Color(0.9, 0.2, 0.1), "extras": ["tusks"], "weapon": "club", "scale": 1.15},
			SD.make(-2, -4, -5, 11, -2, 6, 24, -12), [&"chatarrero"], [&"relampago"])
	_character("zorp", "Zorp", "Alienígena gris de ojos enormes: manos rapidísimas con los ítems, poco peso y poco aguante.",
			G.FEMALE, Color(0.75, 0.8, 0.85),
			{"species": "grey", "skin": Color(0.72, 0.78, 0.8), "outfit": Color(0.5, 0.6, 0.75), "outfit2": Color(0.3, 0.35, 0.5),
				"weapon": "blaster", "scale": 0.9},
			SD.make(-1, 1, 2, -5, 1, 0, -8, 24), [&"cohete"], [&"tanque"])
	_character("xyla", "Xyla", "Insectoide de cuatro ojos y antenas: ágil de reflejos, derrapa como nadie.",
			G.FEMALE, Color(0.1, 0.7, 0.6),
			{"species": "insect", "skin": Color(0.1, 0.6, 0.55), "outfit": Color(0.15, 0.4, 0.45), "outfit2": Color(0.9, 0.8, 0.2),
				"eye": Color(0.1, 0.1, 0.1), "extras": ["antennae", "mandibles", "extra_arms"], "weapon": "blaster"},
			SD.make(-2, 0, 6, -4, 6, -2, 0, 2), [&"escorpion"], [&"tanque"])
	_character("ojon", "Ojón", "Cíclope morado de un solo ojo y un cuerno: tranquilo, pesado y a gusto fuera del asfalto.",
			G.MALE, Color(0.55, 0.3, 0.7),
			{"species": "cyclops", "skin": Color(0.55, 0.35, 0.7), "outfit": Color(0.3, 0.25, 0.45), "outfit2": Color(0.9, 0.85, 0.7),
				"eye": Color(0.9, 0.6, 0.1), "extras": ["single_horn"], "weapon": "cannon", "scale": 1.05},
			SD.make(-1, -2, -2, 6, 0, 10, 12, -6), [&"tanque"], [&"escorpion"])
	_character("tornillo", "Tornillo", "Robot de chatarra con visor verde: fiable y equilibrado, sin sorpresas.",
			G.OTHER, Color(0.85, 0.5, 0.2),
			{"species": "robot", "skin": Color(0.4, 1.0, 0.6), "outfit": Color(0.85, 0.5, 0.2), "outfit2": Color(0.35, 0.36, 0.4),
				"weapon": "minigun"},
			SD.make(3, 3, 0, 2, -2, -2, 0, 0), [&"azulon"], [&"escorpion"])
	_character("huesos", "Huesos", "Esqueleto pirata ligerísimo: corre como el viento aunque cualquier golpe lo desarma.",
			G.MALE, Color(0.92, 0.9, 0.8),
			{"species": "skeleton", "skin": Color(0.93, 0.91, 0.82), "outfit": Color(0.7, 0.1, 0.15), "outfit2": Color(0.5, 0.05, 0.1),
				"head": "pirate", "weapon": "blaster"},
			SD.make(4, 1, 2, -9, 2, -4, -5, 5), [&"relampago"], [&"chatarrero"])
	_character("gloop", "Gloop", "Slime verde y blandengue: se pega a cualquier terreno y rebota con gracia.",
			G.OTHER, Color(0.5, 0.9, 0.3),
			{"species": "slime", "skin": Color(0.55, 0.9, 0.3), "eye": Color(0.05, 0.1, 0.05), "weapon": "blaster"},
			SD.make(-2, 0, 4, -2, 2, 9, -4, 6), [&"azulon"], [&"cohete"])
	_character("brasa", "Brasa", "Dragona de cuernos, cola y alas pequeñas: arranca como una llamarada y pega fuerte.",
			G.FEMALE, Color(0.95, 0.4, 0.15),
			{"species": "dragon", "skin": Color(0.9, 0.35, 0.15), "outfit": Color(0.75, 0.25, 0.1), "outfit2": Color(0.25, 0.12, 0.1),
				"extras": ["horns", "tail", "wings"], "weapon": "claws"},
			SD.make(2, 5, -4, 3, 0, -3, 8, -4), [&"cohete"], [&"azulon"])
	_character("fungo", "Fungo", "Hongo con sombrero de lunares: reparte los ítems con calma y se siente en casa en el barro.",
			G.OTHER, Color(0.8, 0.25, 0.55),
			{"species": "mushroom", "skin": Color(0.95, 0.88, 0.75), "outfit": Color(0.8, 0.2, 0.5), "outfit2": Color(0.6, 0.35, 0.2),
				"eye": Color(0.1, 0.1, 0.1), "weapon": "staff", "scale": 0.95},
			SD.make(-3, -1, 1, 2, 3, 8, -4, 14), [&"tanque"], [&"cohete"])
	_character("kraki", "Kraki", "Kraken azul de tentáculos: se escurre por las curvas y los derrapes largos.",
			G.FEMALE, Color(0.2, 0.45, 0.75),
			{"species": "kraken", "skin": Color(0.25, 0.5, 0.85), "outfit": Color(0.15, 0.3, 0.6), "outfit2": Color(0.9, 0.9, 0.6),
				"eye": Color(0.05, 0.05, 0.1), "extras": ["tentacles"], "weapon": "blaster"},
			SD.make(-3, -1, 6, -1, 7, -1, 0, 8), [&"escorpion"], [&"tanque"])
