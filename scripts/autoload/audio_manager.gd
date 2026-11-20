extends Node
## Sonido: efectos sintetizados (SfxLibrary) y motor de los karts humanos con tono según la velocidad.
## Los bots no suenan (CPU ligera y menos ruido). Volúmenes en user://settings.cfg, sección [audio].

const POOL_SIZE := 12
const SETTINGS_PATH := "user://settings.cfg"

var sfx_volume := 0.5     ## 0..1
var engine_volume := 0.2  ## 0..1 (0 = sin motor)

var _pool: Array[AudioStreamPlayer] = []
var _engines: Array[Dictionary] = []   ## {"kart": Kart, "player": AudioStreamPlayer}


func _ready() -> void:
	load_settings()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func _process(_delta: float) -> void:
	var humans := maxi(_engines.size(), 1)
	for i in range(_engines.size() - 1, -1, -1):
		var e := _engines[i]
		var player: AudioStreamPlayer = e["player"]
		if not is_instance_valid(e["kart"]):  # el kart ya se liberó (se salió de la carrera)
			if is_instance_valid(player):
				player.queue_free()
			_engines.remove_at(i)
			continue
		var kart: Kart = e["kart"]
		var ratio := clampf(kart.get_speed_kmh() / (kart.stats.max_speed * 3.6), 0.0, 1.6)
		player.pitch_scale = 0.8 + ratio * 0.7 + (0.12 if kart.is_boosting() else 0.0)
		var vol := engine_volume * (0.5 + 0.5 * minf(ratio, 1.0)) / sqrt(float(humans))
		player.volume_db = linear_to_db(maxf(vol, 0.0001))


func play(name: StringName, volume := 1.0, pitch := 1.0) -> void:
	if sfx_volume <= 0.0:
		return
	var player: AudioStreamPlayer = null
	for p in _pool:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _pool[0]  # sin huecos: reutiliza el más antiguo
	player.stream = SfxLibrary.get_stream(name)
	player.volume_db = linear_to_db(maxf(sfx_volume * volume, 0.0001))
	player.pitch_scale = pitch
	player.play()


## Conecta los sonidos de un kart humano (y su motor).
func attach_kart(kart: Kart) -> void:
	kart.boost_started.connect(func(source: StringName, _d: float) -> void:
		if source != &"landing" and source != &"drift":
			play(&"boost", 0.4))
	kart.drift_level_changed.connect(func(level: int) -> void:
		if level > 0:
			play(&"drift_tick", 0.3, 0.9 + level * 0.12))
	kart.landed.connect(func(_t: float) -> void: play(&"landing", 0.5))
	kart.got_hit.connect(func(_a: Kart) -> void: play(&"hit", 0.7))
	kart.hit_landed.connect(func(_t: Kart) -> void: play(&"hit", 0.4, 1.2))
	kart.guard_absorbed.connect(func() -> void: play(&"absorb", 0.6))
	kart.item_used.connect(func(_i: ItemData) -> void: play(&"use_item", 0.6))
	kart.item_changed.connect(func() -> void:
		if kart.is_rolling():
			play(&"pickup", 0.6))
	var engine := AudioStreamPlayer.new()
	engine.stream = SfxLibrary.get_stream(&"engine")
	engine.volume_db = linear_to_db(maxf(engine_volume * 0.35, 0.0001))
	add_child(engine)
	engine.play()
	_engines.append({"kart": kart, "player": engine})


## Pitidos de la cuenta atrás y de la salida.
func attach_race(manager: RaceManager) -> void:
	manager.countdown_beep.connect(func(_n: int) -> void: play(&"beep"))
	manager.race_started.connect(func() -> void: play(&"go"))


func stop_engines() -> void:
	for e in _engines:
		if is_instance_valid(e["player"]):
			(e["player"] as AudioStreamPlayer).queue_free()
	_engines.clear()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(snappedf(v, 0.1), 0.0, 1.0)
	save_settings()


func set_engine_volume(v: float) -> void:
	engine_volume = clampf(snappedf(v, 0.1), 0.0, 1.0)
	save_settings()


func save_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # conserva la sección de gráficos
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "engine_volume", engine_volume)
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", 0.5)), 0.0, 1.0)
	engine_volume = clampf(float(cfg.get_value("audio", "engine_volume", 0.2)), 0.0, 1.0)
