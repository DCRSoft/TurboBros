class_name CharacterData
extends Resource
## Personaje seleccionable (data/characters/*.tres). El color del 3.er nivel de mini turbo sale de aquí.

enum Gender { MALE, FEMALE, OTHER }

const PINK := Color(1.0, 0.4, 0.75)
const GOLD := Color(1.0, 0.82, 0.2)

@export var id: StringName = &""
@export var display_name := "Piloto"
@export_multiline var description := ""
@export var gender: Gender = Gender.MALE
@export var use_custom_drift_color := false
@export var custom_drift_color := Color.WHITE
@export_group("Estadísticas")
@export var stats: StatDelta
@export_group("Sinergias con vehículos")
@export var likes: Array[StringName] = []      ## ids de vehículos que le gustan -> like_bonus
@export var like_bonus: StatDelta
@export var dislikes: Array[StringName] = []   ## ids de vehículos que le sientan mal -> dislike_penalty
@export var dislike_penalty: StatDelta


func get_final_drift_color() -> Color:
	if use_custom_drift_color:
		return custom_drift_color
	return PINK if gender == Gender.FEMALE else GOLD
