extends Node
## Sonido: efectos sintetizados (SfxLibrary) y motor de los karts humanos con tono según la velocidad.
## Los bots no suenan (CPU ligera y menos ruido). Volúmenes en user://settings.cfg, sección [audio].

const POOL_SIZE := 12
const SETTINGS_PATH := "user://settings.cfg"
const MUSIC_DIR := "res://assets/audio/music/"
const MUSIC_GAIN := 0.6          ## la música queda por debajo de los efectos aunque el volumen sea 100 %
const LAST_LAP_PITCH := 1.07     ## en la última vuelta la música sube de tono (y de tempo)

var sfx_volume := 0.5     ## 0..1
var engine_volume := 0.2  ## 0..1 (0 = sin motor)
var music_volume := 0.4   ## 0..1 (0 = sin música)
var music_id: StringName = &""   ## música que suena (o la que sonará)
var music_ducked := false         ## true = bajada (menú de pausa)

var _pool: Array[AudioStreamPlayer] = []
var _engines: Array[Dictionary] = []   ## {"kart": Kart, "player": AudioStreamPlayer}
var _music: AudioStreamPlayer
var _music_tween: Tween
var _race: RaceManager
var _lap_check := 0.0


func _ready() -> void:
	load_settings()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -60.0
	add_child(_music)
	_music.finished.connect(_on_music_finished)


func _process(delta: float) -> void:
	_update_last_lap(delta)
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
	_race = manager
	music_ducked = false
	stop_music(0.5)   # silencio durante la cuenta atrás; la música de la pista entra con la salida
	manager.countdown_beep.connect(func(_n: int) -> void: play(&"beep"))
	manager.race_started.connect(func() -> void:
		play(&"go")
		play_music(StringName(manager.circuit.theme.id)))
	manager.race_finished.connect(func(_r: Array) -> void: play_music(&"resultados", false))
	manager.pad_hit.connect(func(k: Kart) -> void:
		if _is_attached(k):
			play(&"pad", 0.5))
	manager.launch_result.connect(func(k: Kart, factor: float) -> void:
		if factor < 0.0:
			play(&"stall", 0.7)
		elif factor > 0.5 and _is_attached(k):
			play(&"boost", 0.5))


# --- Música ----------------------------------------------------------------------------------

## Volumen lineal que debe tener ahora la música.
func _music_target() -> float:
	return music_volume * MUSIC_GAIN * (0.35 if music_ducked else 1.0)


## Pone la música "id" (assets/audio/music/<id>.wav u .ogg): baja la actual y entra la nueva con fundido.
## loop=false para la fanfarria de resultados (al acabar vuelve a la música de menú).
func play_music(id: StringName, loop := true) -> void:
	if id == music_id and _music.playing:
		return
	music_id = id
	if _music_tween != null:
		_music_tween.kill()
	if music_volume <= 0.0:
		_music.stop()
		return
	_music_tween = create_tween()
	if _music.playing:
		_music_tween.tween_property(_music, "volume_db", -50.0, 0.25)
	_music_tween.tween_callback(_start_music.bind(id, loop))
	_music_tween.tween_property(_music, "volume_db", linear_to_db(maxf(_music_target(), 0.0001)), 0.8)


func _start_music(id: StringName, loop: bool) -> void:
	var stream := _load_music(id, loop)
	if stream == null:
		_music.stop()
		return
	_music.stream = stream
	_music.pitch_scale = 1.0
	_music.volume_db = -50.0
	_music.play()


func _load_music(id: StringName, loop: bool) -> AudioStream:
	for ext in ["wav", "ogg"]:
		var path := "%s%s.%s" % [MUSIC_DIR, id, ext]
		if ResourceLoader.exists(path):
			var s := load(path)
			if s is AudioStreamWAV:
				var w := s as AudioStreamWAV
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
				if loop:
					w.loop_begin = 0
					w.loop_end = int(w.get_length() * w.mix_rate)
			elif s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = loop
			return s
	return null


func stop_music(fade := 0.4) -> void:
	music_id = &""
	if _music_tween != null:
		_music_tween.kill()
	if not _music.playing:
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -50.0, fade)
	_music_tween.tween_callback(_music.stop)


func ensure_menu_music() -> void:
	music_ducked = false
	if music_id != &"menu" and music_id != &"resultados":
		play_music(&"menu")


func is_music_playing() -> bool:
	return _music.playing


func music_pitch() -> float:
	return _music.pitch_scale


## Menú de pausa: la música baja (no se detiene).
func set_music_ducked(v: bool) -> void:
	music_ducked = v
	_apply_music_volume()


func _apply_music_volume() -> void:
	if _music_tween != null and _music_tween.is_running():
		return
	_music.volume_db = linear_to_db(maxf(_music_target(), 0.0001))


func _on_music_finished() -> void:
	if music_id == &"resultados":
		play_music(&"menu")


## Última vuelta de algún jugador humano: música más aguda y rápida.
func _update_last_lap(delta: float) -> void:
	if _race == null or not _music.playing or music_id == &"menu" or music_id == &"resultados":
		return
	_lap_check -= delta
	if _lap_check > 0.0:
		return
	_lap_check = 0.5
	var last := false
	if _race.laps > 1 and _race.state == RaceManager.State.RACING:
		for r in _race.racers:
			if r.is_human and not r.finished and _race.lap_of(r) >= _race.laps:
				last = true
	var target := LAST_LAP_PITCH if last else 1.0
	if target > _music.pitch_scale:
		play(&"lastlap", 0.5)   # aviso al empezar la última vuelta
	_music.pitch_scale = target


## ¿Es un kart humano con sonido (conectado con attach_kart)?
func _is_attached(kart: Kart) -> bool:
	for e in _engines:
		if e["kart"] == kart:
			return true
	return false


func stop_engines() -> void:
	for e in _engines:
		if is_instance_valid(e["player"]):
			(e["player"] as AudioStreamPlayer).queue_free()
	_engines.clear()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(snappedf(v, 0.1), 0.0, 1.0)
	save_settings()


func set_music_volume(v: float) -> void:
	music_volume = clampf(snappedf(v, 0.1), 0.0, 1.0)
	if music_volume <= 0.0:
		var keep := music_id
		stop_music(0.2)
		music_id = keep   # al volver a subir el volumen sigue la misma música
	elif not _music.playing and music_id != &"":
		var id := music_id
		music_id = &""
		play_music(id, id != &"resultados")
	else:
		_apply_music_volume()
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
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", 0.5)), 0.0, 1.0)
	engine_volume = clampf(float(cfg.get_value("audio", "engine_volume", 0.2)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", 0.4)), 0.0, 1.0)
