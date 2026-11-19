extends Node
## Diagnóstico: conduce un kart (IA) por el circuito y mide rebotes (tiempo en el aire, velocidad vertical).
##   Godot_console.exe --headless --path . res://scenes/debug/stability_probe.tscn

var _y_samples := 0
var _air_ticks := 0
var _air_episodes := 0
var _was_air := false
var _max_vy := 0.0
var _min_vy := 0.0
var _hist := {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("Motor de física 3D: ", ProjectSettings.get_setting("physics/3d/physics_engine", "DEFAULT"))
	GameSession.reset()
	GameSession.laps = 1
	var seats: Array[Seat] = [Seat.new()]
	GameSession.setups = [{"slot": 0, "seats": seats, "team": -1}]
	var race: Node3D = load("res://scenes/race/race.tscn").instantiate()
	race.autopilot_humans = true
	add_child(race)
	await get_tree().physics_frame
	var k: Kart = race.karts[0]
	for i in 60 * 40:
		await get_tree().physics_frame
		if race.manager.state != RaceManager.State.RACING:
			continue
		_y_samples += 1
		var vy := k.sphere.linear_velocity.y
		_max_vy = maxf(_max_vy, vy)
		_min_vy = minf(_min_vy, vy)
		var air := not k.grounded
		if air:
			_air_ticks += 1
			if not _was_air:
				_air_episodes += 1
		_was_air = air
		var b := snappedf(vy, 0.5)
		_hist[b] = _hist.get(b, 0) + 1
	print("Muestras en carrera: %d" % _y_samples)
	print("Tiempo en el aire: %.1f %%  episodios=%d" % [100.0 * _air_ticks / maxi(_y_samples, 1), _air_episodes])
	print("vy máx=%.2f  mín=%.2f" % [_max_vy, _min_vy])
	var keys := _hist.keys()
	keys.sort()
	var line := PackedStringArray()
	for key in keys:
		line.append("%s:%d" % [key, _hist[key]])
	print("Histograma vy (m/s : ticks): ", ", ".join(line))
	var air_pct := 100.0 * _air_ticks / maxi(_y_samples, 1)
	var ok := air_pct < 2.0 and _max_vy < 3.5 and _min_vy > -3.5
	print("%s  estabilidad: aire %.1f %% (<2), vy en [%.1f, %.1f] (±3.5)" % ["PASS" if ok else "FAIL", air_pct, _min_vy, _max_vy])
	get_tree().quit(0 if ok else 1)
