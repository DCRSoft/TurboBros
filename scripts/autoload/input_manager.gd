extends Node
## Lectura de dispositivos (mandos USB/Bluetooth y teclado) -> KartControls según el rol del asiento.
## Hito 2: asignación provisional por orden (mandos, luego teclado). Hito 3: lobby.

const DEADZONE := 0.18

## Esquemas de teclado (teclas físicas). El teclado como control "oficial" llega en el hito 8.
const KEY_SCHEMES: Array[Dictionary] = [
	{"left": KEY_A, "right": KEY_D, "throttle": KEY_W, "brake": KEY_S,
		"drift": KEY_SHIFT, "item": KEY_SPACE, "hit_l": KEY_Q, "hit_r": KEY_E},
	{"left": KEY_LEFT, "right": KEY_RIGHT, "throttle": KEY_UP, "brake": KEY_DOWN,
		"drift": KEY_L, "item": KEY_K, "hit_l": KEY_J, "hit_r": KEY_SEMICOLON},
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
	var lx := _dz(Input.get_joy_axis(id, JOY_AXIS_LEFT_X))
	var ly := _dz(Input.get_joy_axis(id, JOY_AXIS_LEFT_Y))
	var rt := Input.get_joy_axis(id, JOY_AXIS_TRIGGER_RIGHT)
	var lt := Input.get_joy_axis(id, JOY_AXIS_TRIGGER_LEFT)
	var lb := _btn(id, JOY_BUTTON_LEFT_SHOULDER)
	var rb := _btn(id, JOY_BUTTON_RIGHT_SHOULDER)
	if seat.drives():
		var dpad := int(_btn(id, JOY_BUTTON_DPAD_RIGHT)) - int(_btn(id, JOY_BUTTON_DPAD_LEFT))
		out.steer = clampf(lx + dpad, -1.0, 1.0)
		out.throttle = maxf(rt, 1.0 if _btn(id, JOY_BUTTON_A) else 0.0)
		out.brake = maxf(lt, 1.0 if _btn(id, JOY_BUTTON_B) else 0.0)
		if seat.role == Seat.Role.SOLO:
			out.drift = lb or rb
		else:
			out.drift = rb or lb
	if seat.uses_items():
		out.item = _btn(id, JOY_BUTTON_X) or _btn(id, JOY_BUTTON_Y)
		out.item_back = ly > 0.5
		if seat.role == Seat.Role.GUNNER:
			out.hit_left = lb or lt > 0.5
			out.hit_right = rb or rt > 0.5


func _read_keyboard(seat: Seat, out: KartControls) -> void:
	var k: Dictionary = KEY_SCHEMES[clampi(seat.device_id, 0, KEY_SCHEMES.size() - 1)]
	var down := func(name: String) -> bool: return Input.is_physical_key_pressed(k[name])
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
