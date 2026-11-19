class_name CharacterData
extends Resource
## Datos de un personaje. El color del 3.er nivel de mini turbo sale de aquí.

enum Gender { MALE, FEMALE, OTHER }

const PINK := Color(1.0, 0.4, 0.75)
const GOLD := Color(1.0, 0.82, 0.2)

@export var display_name := "Piloto"
@export var gender: Gender = Gender.MALE
@export var use_custom_drift_color := false
@export var custom_drift_color := Color.WHITE


func get_final_drift_color() -> Color:
	if use_custom_drift_color:
		return custom_drift_color
	return PINK if gender == Gender.FEMALE else GOLD
