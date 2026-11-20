extends Node
## Lectura de dispositivos (mandos USB/Bluetooth y teclado) -> KartControls según el rol del asiento.
## Hito 2: asignación provisional por orden (mandos, luego teclado). Hito 3: lobby.

const DEADZONE := 0.18

## Esquemas de teclado (teclas físicas). El teclado como control "oficial" llega en el hito 8.
const KEY_SCHEMES: Array[Dictionary] = [
	{"left": KEY_A, "right": KEY_D, "throttle": KEY_W, "brake": KEY_S,
		"drift": KEY_SHIFT, "item": KEY_SPACE, "hit_l": KEY_Q, "hit_r": KEY_E, "look": KEY_C},
	{"left": KEY_LEFT, "right": KEY_RIGHT, "throttle": KEY_UP, "brake": KEY_DOWN,
		"drift": KEY_L, "item": KEY_K, "hit_l": KEY_J, "hit_r": KEY_SEMICOLON, "look": KEY_SLASH},
]

signal devices_changed

var allow_keyboard := true  ## teclado como respaldo de desarrollo (hito 8: control oficial)


func _ready() -> void:
	Input.joy_connection_changed.connect(func(_id: int, _connected: bool) -> void: devices_changed.emit())


## Mandos conectados (por id) y luego los esquemas de teclado.
func get_devices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pads := Input.get_connected_joypads()
	pads.sort()
	for p in pads:
		out.append({"kind": Seat.DeviceKind.JOYPAD, "id": p})
	if allow_keyboard:
		for s in KEY_SCHEMES.size():
			out.append({"kind": Seat.DeviceKind.KEYBOARD, "id": s})
	return out


## Asignación provisional por orden (el lobby del hito 3 la reemplaza).
## Los asientos sin dispositivo quedan inactivos.
func assign_devices(seats: Array[Seat]) -> void:
	var devs := get_devices()
	for i in seats.size():
		if i < devs.size():
			seats[i].kind = devs[i]["kind"]
			seats[i].device_id = devs[i]["id"]
		else:
			seats[i].clear_device()


func describe_seat(seat: Seat) -> String:
	match seat.kind:
		Seat.DeviceKind.JOYPAD:
			return "Mando %d (%s)" % [seat.device_id, Input.get_joy_name(seat.device_id)]
		Seat.DeviceKind.KEYBOARD:
			return "Teclado (esquema %d)" % seat.device_id
	return "Sin dispositivo (kart inactivo)"


func read_seat(seat: Seat, out: KartControls) -> void:
	match seat.kind:
		Seat.DeviceKind.JOYPAD:
			_read_joypad(seat, out)
		Seat.DeviceKind.KEYBOARD:
			_read_keyboard(seat, out)


func _dz(v: float) -> float:
	var a := absf(v)
	if a < DEADZONE:
		return 0.0
	return signf(v) * (a - DEADZONE) / (1.0 - DEADZONE)


func _btn(id: int, b: JoyButton) -> bool:
	return Input.is_joy_button_pressed(id, b)


func _read_joypad(seat: Seat, out: KartControls) -> void:
	var id := seat.device_id
	var state := {
		"lx": _dz(Input.get_joy_axis(id, JOY_AXIS_LEFT_X)), "ly": _dz(Input.get_joy_axis(id, JOY_AXIS_LEFT_Y)),
		"rt": Input.get_joy_axis(id, JOY_AXIS_TRIGGER_RIGHT), "lt": Input.get_joy_axis(id, JOY_AXIS_TRIGGER_LEFT),
		"a": _btn(id, JOY_BUTTON_A), "b": _btn(id, JOY_BUTTON_B), "x": _btn(id, JOY_BUTTON_X), "y": _btn(id, JOY_BUTTON_Y),
		"lb": _btn(id, JOY_BUTTON_LEFT_SHOULDER), "rb": _btn(id, JOY_BUTTON_RIGHT_SHOULDER),
		"dl": _btn(id, JOY_BUTTON_DPAD_LEFT), "dr": _btn(id, JOY_BUTTON_DPAD_RIGHT),
	}
	map_pad(state, seat.role, out)


## Mapeo del mando (esquema Xbox), separado del hardware para poder probarlo:
## A (o RT) acelera · Y (o LT) reversa/freno · B ítem · X mirar atrás · LB/RB derrapan (artillero: golpean)
## stick izq./cruceta gira (stick abajo + ítem = lanzar/colocar hacia atrás).
static func map_pad(st: Dictionary, role: Seat.Role, out: KartControls) -> void:
	var drives := role == Seat.Role.SOLO or role == Seat.Role.DRIVER
	var uses_items := role == Seat.Role.SOLO or role == Seat.Role.GUNNER
	var lb: bool = st.get("lb", false)
	var rb: bool = st.get("rb", false)
	var lt: float = st.get("lt", 0.0)
	var rt: float = st.get("rt", 0.0)
	out.look_back = st.get("x", false)
	if drives:
		var dpad := int(st.get("dr", false)) - int(st.get("dl", false))
		out.steer = clampf(float(st.get("lx", 0.0)) + dpad, -1.0, 1.0)
		out.throttle = maxf(rt, 1.0 if st.get("a", false) else 0.0)
		out.brake = maxf(lt, 1.0 if st.get("y", false) else 0.0)
		out.drift = lb or rb
	if uses_items:
		out.item = st.get("b", false)
		out.item_back = float(st.get("ly", 0.0)) > 0.5
		if role == Seat.Role.GUNNER:
			out.hit_left = lb or lt > 0.5
			out.hit_right = rb or rt > 0.5
		else:
			_solo_hit(out)


func _read_keyboard(seat: Seat, out: KartControls) -> void:
	var k: Dictionary = KEY_SCHEMES[clampi(seat.device_id, 0, KEY_SCHEMES.size() - 1)]
	var down := func(name: String) -> bool: return Input.is_physical_key_pressed(k[name])
	out.look_back = down.call("look")
	if seat.drives():
		out.steer = float(int(down.call("right")) - int(down.call("left")))
		out.throttle = 1.0 if down.call("throttle") else 0.0
		out.brake = 1.0 if down.call("brake") else 0.0
		out.drift = down.call("drift")
	if seat.uses_items():
		out.item = down.call("item")
		out.item_back = down.call("brake")
		if seat.role == Seat.Role.GUNNER:
			out.hit_left = down.call("hit_l")
			out.hit_right = down.call("hit_r")
		else:
			_solo_hit(out)


## Jugador SOLO: golpea con el botón de ítem + dirección (hito 4: solo si no tiene ítem).
static func _solo_hit(out: KartControls) -> void:
	if out.item:
		out.hit_left = out.steer < -0.5
		out.hit_right = out.steer > 0.5


## Entrada de menú de un dispositivo: x/y (-1..1; y>0 = abajo), confirm, back, swap, start, select,
## lb, rb, lt, rt, track.
func read_menu(kind: Seat.DeviceKind, id: int) -> Dictionary:
	if kind == Seat.DeviceKind.JOYPAD:
		var dx := int(_btn(id, JOY_BUTTON_DPAD_RIGHT)) - int(_btn(id, JOY_BUTTON_DPAD_LEFT))
		var dy := int(_btn(id, JOY_BUTTON_DPAD_DOWN)) - int(_btn(id, JOY_BUTTON_DPAD_UP))
		return {"x": clampf(_dz(Input.get_joy_axis(id, JOY_AXIS_LEFT_X)) + dx, -1.0, 1.0),
				"y": clampf(_dz(Input.get_joy_axis(id, JOY_AXIS_LEFT_Y)) + dy, -1.0, 1.0),
				"confirm": _btn(id, JOY_BUTTON_A), "back": _btn(id, JOY_BUTTON_B),
				"swap": _btn(id, JOY_BUTTON_Y), "start": _btn(id, JOY_BUTTON_START),
				"select": _btn(id, JOY_BUTTON_BACK), "track": _btn(id, JOY_BUTTON_X),
				"lb": _btn(id, JOY_BUTTON_LEFT_SHOULDER), "rb": _btn(id, JOY_BUTTON_RIGHT_SHOULDER),
				"lt": Input.get_joy_axis(id, JOY_AXIS_TRIGGER_LEFT) > 0.6,
				"rt": Input.get_joy_axis(id, JOY_AXIS_TRIGGER_RIGHT) > 0.6}
	var k: Dictionary = KEY_SCHEMES[clampi(id, 0, KEY_SCHEMES.size() - 1)]
	var key := func(name: String) -> bool: return Input.is_physical_key_pressed(k[name])
	return {"x": float(int(key.call("right")) - int(key.call("left"))),
			"y": float(int(key.call("brake")) - int(key.call("throttle"))),
			"confirm": key.call("item"), "back": key.call("hit_l"),
			"swap": key.call("hit_r"), "start": false, "select": false,
			"lb": false, "rb": false, "lt": false, "rt": false, "track": false}
