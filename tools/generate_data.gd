extends SceneTree
## Genera los .tres de efectos (data/effects) e ítems (data/items) con valores iniciales.
## Ejecutar desde la raíz del proyecto:
##   Godot_console.exe --headless --path . --script tools/generate_data.gd
## Los .tres generados se pueden editar a mano o en el editor; volver a ejecutar SOBRESCRIBE lo que
## coincida por nombre (para añadir ítems nuevos basta crear otro .tres, no hace falta tocar esto).

const FX_DIR := "res://data/effects/"
const ITEM_DIR := "res://data/items/"

var _fx := {}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FX_DIR))
	for sub in ["speed", "defense", "attack", "trap", "invincibility", "chaos"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ITEM_DIR + sub))
	_effects()
	_items()
	_roster()
	print("Datos generados.")
	quit()


func _e(id: String, name: String, duration: float, props := {}) -> KartEffect:
	var e := KartEffect.new()
	e.id = StringName(id)
	e.display_name = name
	e.duration = duration
	for k in props:
		e.set(k, props[k])
	_fx[id] = e
	var err := ResourceSaver.save(e, FX_DIR + id + ".tres")
	if err != OK:
		push_error("No se pudo guardar el efecto %s (%d)" % [id, err])
	return e


func _effects() -> void:
	_e("boost", "Turbo", 0.6, {"speed_mult": 1.35, "accel_mult": 3.0, "force_throttle": true})
	_e("turbo", "Turbo corto", 1.2, {"speed_mult": 1.45, "accel_mult": 3.0, "force_throttle": true})
	_e("rocket", "Cohete", 2.8, {"speed_mult": 1.9, "accel_mult": 5.0, "force_throttle": true, "steer_mult": 0.6})
	_e("shield", "Escudo", 5.0, {"immune": true, "bubble_color": Color(0.3, 0.6, 1.0, 0.3)})
	_e("guard", "Orbitales", 20.0, {"guard_charges": 3})
	_e("reflect", "Burbuja reflectante", 5.0, {"reflect": true, "bubble_color": Color(0.6, 1.0, 1.0, 0.3)})
	_e("star", "Estrella", 7.0, {"speed_mult": 1.25, "accel_mult": 2.0, "immune": true, "touch_hit": true,
			"bubble_color": Color(1.0, 0.85, 0.2, 0.3)})
	_e("ghost", "Fantasma", 6.0, {"ghost": true, "bubble_color": Color(1.0, 1.0, 1.0, 0.15)})
	_e("giant", "Gigante", 7.0, {"scale_mult": 1.8, "mass_mult": 3.0, "speed_mult": 1.1, "immune": true,
			"touch_hit": true})
	_e("ink", "Tinta", 5.0, {"ink": true})
	_e("invert", "Controles invertidos", 6.0, {"steer_mult": -1.0})
	_e("slow", "Ralentizado", 4.0, {"speed_mult": 0.6, "accel_mult": 0.6})
	_e("spin", "Giro", 1.2, {"lock_control": true, "spin": true, "speed_mult": 0.4, "grip_mult": 0.3})
	_e("stumble", "Tropiezo", 0.5, {"speed_mult": 0.6})
	_e("oil_slip", "Resbalón", 2.0, {"grip_mult": 0.15, "steer_mult": 0.6})
	_e("flat_tire", "Rueda pinchada", 3.0, {"speed_mult": 0.55, "accel_mult": 0.5})
	_e("explode", "Explosión", 1.6, {"lock_control": true, "spin": true, "speed_mult": 0.2, "grip_mult": 0.3})


const CHARACTER_COLORS := {
	"brutus": Color(0.45, 0.28, 0.18), "crimson": Color(0.65, 0.12, 0.12), "azur": Color(0.2, 0.3, 0.6),
	"titan": Color(0.5, 0.5, 0.55), "sakura": Color(1.0, 0.55, 0.75), "aurea": Color(0.95, 0.78, 0.2),
	"violeta": Color(0.6, 0.35, 0.85), "chispa": Color(0.95, 0.5, 0.15),
	"drancr": Color(0.25, 0.14, 0.08),      # café oscuro
	"agnelopolus": Color(0.9, 0.1, 0.1),    # rojo
	"end": Color(0.15, 0.35, 0.95),         # azul
	"clarstar": Color(1.0, 0.5, 0.75),      # rosa
	"polewar": Color(0.55, 0.2, 0.8),       # morado
	"ferchaos": Color(1.0, 0.85, 0.1),      # amarillo
}
const VEHICLE_DIR := "res://data/vehicles/"
const CHARACTER_DIR := "res://data/characters/"


func _vehicle(id: String, name: String, desc: String, color: Color, s: StatDelta) -> void:
	var v := VehicleData.new()
	v.id = StringName(id)
	v.display_name = name
	v.description = desc
	v.body_color = color
	v.stats = s
	var err := ResourceSaver.save(v, VEHICLE_DIR + id + ".tres")
	if err != OK:
		push_error("No se pudo guardar el vehículo %s (%d)" % [id, err])


func _character(id: String, name: String, desc: String, gender: CharacterData.Gender, s: StatDelta,
		likes: Array[StringName], like_bonus: StatDelta, dislikes: Array[StringName], dislike_penalty: StatDelta) -> void:
	var c := CharacterData.new()
	c.id = StringName(id)
	c.display_name = name
	c.description = desc
	c.gender = gender
	c.color = CHARACTER_COLORS.get(id, Color.WHITE)
	c.stats = s
	c.likes = likes
	c.like_bonus = like_bonus
	c.dislikes = dislikes
	c.dislike_penalty = dislike_penalty
	var err := ResourceSaver.save(c, CHARACTER_DIR + id + ".tres")
	if err != OK:
		push_error("No se pudo guardar el personaje %s (%d)" % [id, err])


# StatDelta.make(velocidad, aceleración, manejo, peso, derrape, fuera de pista, fuerza de golpe, rapidez ítems)
func _roster() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VEHICLE_DIR))
	var SD := StatDelta
	_vehicle("chatarrero", "Chatarrero", "Pesado y blindado con chatarra. Aguanta los choques, le cuesta arrancar y girar.",
			Color(0.45, 0.28, 0.18), SD.make(-2, -4, -4, 12, -2, 8))
	_vehicle("azulon", "Azulón", "El equilibrado de la parrilla: sin puntos débiles.",
			Color(0.2, 0.4, 0.85), SD.make(0, 0, 1, 0, 1, 0))
	_vehicle("relampago", "Relámpago", "Ligero y veloz, pero se asusta fuera del asfalto y en los choques.",
			Color(0.95, 0.78, 0.15), SD.make(6, 2, 0, -10, 1, -8))
	_vehicle("escorpion", "Escorpión", "Hecho para derrapar: carga los mini turbos enseguida.",
			Color(0.55, 0.2, 0.7), SD.make(-2, 1, 3, -4, 8, -4))
	_vehicle("tanque", "Tanque", "Camión todoterreno: lento pero se come los baches.",
			Color(0.3, 0.42, 0.25), SD.make(-4, 0, -2, 10, -3, 12))
	_vehicle("cohete", "Cohete", "Velocidad punta altísima; acelera y gira con pereza.",
			Color(0.85, 0.2, 0.15), SD.make(9, -4, -6, -2, -1, -4))

	var like := SD.make(2, 2, 0, 0, 2, 0)      # bono genérico "me siento a gusto"
	var dislike := SD.make(-2, -2, -2, 0, 0, 0)  # penalización genérica
	var G := CharacterData.Gender
	_character("brutus", "Brutus", "Armadura de pinchos y minigun. Pega durísimo y es pesado como un yunque.", G.MALE,
			SD.make(0, -3, -4, 6, -2, 4, 25, -10), [&"chatarrero"], SD.make(0, 3, 3, 0, 2, 0), [&"relampago"], dislike)
	_character("crimson", "Crimson", "Veterano de armadura roja. Equilibrado con buena pegada.", G.MALE,
			SD.make(2, 0, 0, 2, 0, 0, 10, 0), [&"azulon"], like, [&"escorpion"], dislike)
	_character("azur", "Azur", "Soldado de armadura azul con rifle de rayos. Preciso y rápido con los ítems.", G.MALE,
			SD.make(-2, 0, 1, 1, 0, 0, 15, 10), [&"tanque"], like, [&"cohete"], dislike)
	_character("titan", "Titán", "Un gigante. Casi nadie lo mueve y casi nadie lo gira.", G.MALE,
			SD.make(-3, -4, -5, 10, -2, 6, 30, -15), [&"tanque"], SD.make(0, 3, 3, 0, 2, 0), [&"escorpion"], dislike)
	_character("sakura", "Sakura", "Piloto ágil de coletas rosas. Manejo fino y manos rápidas con los ítems.", G.FEMALE,
			SD.make(-2, 3, 5, -4, 3, -2, -10, 20), [&"escorpion"], like, [&"chatarrero"], dislike)
	_character("aurea", "Áurea", "Casco y armadura dorados. Muy buen manejo y arranque.", G.FEMALE,
			SD.make(1, 2, 2, -3, 2, -3, -5, 10), [&"relampago"], like, [&"tanque"], dislike)
	_character("violeta", "Violeta", "Artillera de pelo morado: derrapa mucho y dispara ítems a toda prisa.", G.FEMALE,
			SD.make(-3, 0, 1, -4, 4, 0, 0, 25), [&"escorpion"], like, [&"chatarrero"], dislike)
	# Pilotos de la comunidad (3 masculinos y 3 femeninos)
	_character("drancr", "DranCr", "Especialista en velocidad: nadie le gana en la recta, pero arranca y gira con pereza.",
			G.MALE, SD.make(9, -6, -5, 0, -2, 0, 4, 0), [&"cohete"], like, [&"tanque"], dislike)
	_character("agnelopolus", "Agnelopolus", "Especialista en aceleración: sale disparado de cada curva aunque su punta sea modesta.",
			G.MALE, SD.make(-3, 9, 1, -2, 0, -2, 0, 0), [&"relampago"], like, [&"chatarrero"], dislike)
	_character("end", "EnD", "El tanque del grupo: pesado, resistente y de golpe durísimo; lento de reflejos.",
			G.MALE, SD.make(-3, -3, -4, 9, -1, 8, 20, -6), [&"chatarrero"], SD.make(2, 2, 2, 0, 0, 0), [&"cohete"], dislike)
	_character("clarstar", "ClarStar", "Reina del derrape: carga los mini turbos al instante y se desliza con elegancia.",
			G.FEMALE, SD.make(-3, 0, 3, -3, 10, -2, -5, 5), [&"escorpion"], like, [&"tanque"], dislike)
	_character("polewar", "PoleWar", "Artillera pesada: su golpe lanza a cualquiera a la cuneta; poco amiga de los ítems.",
			G.FEMALE, SD.make(0, -2, -2, 4, -1, 2, 30, -8), [&"tanque"], like, [&"relampago"], dislike)
	_character("ferchaos", "FerChaos", "Caos con ruedas: se maneja bien fuera del asfalto y usa los ítems a la velocidad del rayo.",
			G.FEMALE, SD.make(1, 1, -4, -3, 0, 8, 0, 18), [&"azulon"], like, [&"cohete"], dislike)
	_character("chispa", "Chispa", "Impulsiva y veloz en recta. Poco peso y menos control.", G.FEMALE,
			SD.make(4, -2, -3, -2, 0, -2, 0, 5), [&"cohete"], like, [&"azulon"], dislike)


func _save(item: ItemData, sub: String) -> void:
	var err := ResourceSaver.save(item, ITEM_DIR + sub + "/" + String(item.id) + ".tres")
	if err != OK:
		push_error("No se pudo guardar el ítem %s (%d)" % [item.id, err])


func _base(item: ItemData, id: String, name: String, cat: ItemData.Category, color: Color,
		w: Vector3, uses := 1, guard := false) -> void:
	item.id = StringName(id)
	item.display_name = name
	item.category = cat
	item.icon_color = color
	item.uses = uses
	item.weight_front = w.x
	item.weight_mid = w.y
	item.weight_back = w.z
	item.carried_guard = guard


func _self(id: String, name: String, cat: ItemData.Category, color: Color, w: Vector3, sub: String,
		effects: Array, uses := 1) -> void:
	var it := ItemSelfEffect.new()
	_base(it, id, name, cat, color, w, uses)
	for e in effects:
		it.effects.append(_fx[e])
	_save(it, sub)


func _proj(id: String, name: String, w: Vector3, kind: ItemProjectile.Kind, color: Color, props := {}) -> void:
	var it := ItemProjectile.new()
	_base(it, id, name, ItemData.Category.ATTACK, color, w)
	it.kind = kind
	it.color = color
	it.hit_effect = _fx["spin"]
	for k in props:
		it.set(k, props[k])
	_save(it, "attack")


func _trap(id: String, name: String, w: Vector3, kind: ItemTrap.Kind, color: Color, effect: String, props := {}) -> void:
	var it := ItemTrap.new()
	_base(it, id, name, ItemData.Category.TRAP, color, w, 1, true)
	it.kind = kind
	it.color = color
	it.hit_effect = _fx[effect] if effect != "" else null
	for k in props:
		it.set(k, props[k])
	_save(it, "trap")


func _chaos(id: String, name: String, w: Vector3, target: ItemChaos.Target, color: Color, effect: String) -> void:
	var it := ItemChaos.new()
	_base(it, id, name, ItemData.Category.CHAOS, color, w)
	it.target = target
	it.effect = _fx[effect]
	_save(it, "chaos")


func _items() -> void:
	var C := ItemData.Category
	# Velocidad
	_self("turbo", "Turbo corto", C.SPEED, Color(1.0, 0.6, 0.1), Vector3(2, 2, 1), "speed", ["turbo"])
	_self("triple_turbo", "Triple turbo", C.SPEED, Color(1.0, 0.45, 0.1), Vector3(0.5, 1.5, 2), "speed", ["turbo"], 3)
	_self("rocket", "Cohete", C.SPEED, Color(1.0, 0.2, 0.1), Vector3(0, 0.3, 3), "speed", ["rocket"])
	# Defensa
	_self("shield", "Escudo", C.DEFENSE, Color(0.3, 0.6, 1.0), Vector3(1, 1.5, 1), "defense", ["shield"])
	_self("guard_orbit", "Orbitales", C.DEFENSE, Color(0.4, 0.9, 1.0), Vector3(1, 1.5, 1.5), "defense", ["guard"])
	_self("reflect", "Burbuja reflectante", C.DEFENSE, Color(0.6, 1.0, 1.0), Vector3(0, 1, 2), "defense", ["reflect"])
	# Ataque
	_proj("missile", "Proyectil recto", Vector3(3, 2, 1), ItemProjectile.Kind.STRAIGHT, Color(0.9, 0.2, 0.2),
			{"speed": 50.0})
	_proj("bouncer", "Rebotador", Vector3(2, 2, 1), ItemProjectile.Kind.BOUNCER, Color(0.2, 0.9, 0.3),
			{"speed": 40.0, "bounces": 3, "lifetime": 8.0})
	_proj("homing", "Teledirigido", Vector3(0.5, 2, 3), ItemProjectile.Kind.HOMING, Color(0.9, 0.3, 0.9),
			{"speed": 38.0, "turn_rate": 2.5})
	_proj("bomb", "Bomba de área", Vector3(1, 2, 2), ItemProjectile.Kind.BOMB, Color(0.15, 0.15, 0.15),
			{"speed": 40.0, "blast_radius": 6.0, "lifetime": 5.0, "hit_effect": _fx["explode"]})
	_proj("shockwave", "Ola de choque", Vector3(0, 1, 3), ItemProjectile.Kind.SHOCKWAVE, Color(1.0, 0.9, 0.3),
			{"blast_radius": 12.0})
	# Trampas
	_trap("oil", "Aceite", Vector3(3, 1.5, 0.5), ItemTrap.Kind.OIL, Color(0.05, 0.05, 0.08), "oil_slip",
			{"trigger_radius": 2.5, "lifetime": 20.0})
	_trap("nails", "Clavos", Vector3(2, 1.5, 0.5), ItemTrap.Kind.NAILS, Color(0.6, 0.6, 0.65), "flat_tire",
			{"trigger_radius": 2.0, "lifetime": 20.0})
	_trap("fake_box", "Caja falsa", Vector3(2, 1, 0.5), ItemTrap.Kind.FAKE_BOX, Color(1.0, 0.85, 0.2), "spin",
			{"trigger_radius": 1.6, "lifetime": 25.0, "consume_on_trigger": true})
	_trap("barrier", "Barrera", Vector3(2, 1.5, 0.5), ItemTrap.Kind.BARRIER, Color(1.0, 0.5, 0.1), "",
			{"lifetime": 15.0})
	_trap("mine", "Mina", Vector3(1, 1.5, 1), ItemTrap.Kind.MINE, Color(0.3, 0.1, 0.1), "explode",
			{"trigger_radius": 2.2, "blast_radius": 6.0, "lifetime": 30.0, "consume_on_trigger": true})
	# Invencibilidad
	_self("star", "Estrella", C.INVINCIBILITY, Color(1.0, 0.85, 0.2), Vector3(0, 0.5, 2.5), "invincibility", ["star"])
	_self("ghost", "Fantasma", C.INVINCIBILITY, Color(0.9, 0.9, 1.0), Vector3(0, 0.8, 2), "invincibility", ["ghost"])
	_self("giant", "Gigante", C.INVINCIBILITY, Color(0.9, 0.4, 0.2), Vector3(0, 0.5, 2.5), "invincibility", ["giant"])
	# Caos
	_chaos("ink", "Tinta", Vector3(0.5, 1.5, 1.5), ItemChaos.Target.ALL_OTHERS, Color(0.1, 0.1, 0.2), "ink")
	_chaos("invert", "Controles invertidos", Vector3(0.5, 1.5, 1), ItemChaos.Target.ALL_OTHERS,
			Color(0.8, 0.2, 0.8), "invert")
	_chaos("slow_ahead", "Ralentizar a los de delante", Vector3(0, 1, 2.5), ItemChaos.Target.AHEAD,
			Color(0.3, 0.3, 0.9), "slow")
	var swap := ItemSwap.new()
	_base(swap, "swap", "Intercambio de posición", ItemData.Category.CHAOS, Color(0.2, 0.9, 0.9), Vector3(0, 1, 2))
	_save(swap, "chaos")
