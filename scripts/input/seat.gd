class_name Seat
extends RefCounted
## Un asiento = un jugador humano con un dispositivo y un rol.
## Un kart tiene 1 asiento (SOLO) o 2 (DRIVER + GUNNER).

enum Role { SOLO, DRIVER, GUNNER }
enum DeviceKind { NONE, JOYPAD, KEYBOARD }

var role: Role = Role.SOLO
var kind: DeviceKind = DeviceKind.NONE
var device_id := -1  ## id del mando, o índice del esquema de teclado
var character_id: StringName = &""  ## personaje elegido (pantalla de selección)


func set_joypad(id: int) -> void:
	kind = DeviceKind.JOYPAD
	device_id = id


func set_keyboard(scheme: int) -> void:
	kind = DeviceKind.KEYBOARD
	device_id = scheme


func clear_device() -> void:
	kind = DeviceKind.NONE
	device_id = -1


func drives() -> bool:
	return role == Role.SOLO or role == Role.DRIVER


func uses_items() -> bool:
	return role == Role.SOLO or role == Role.GUNNER
