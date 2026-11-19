class_name VehicleData
extends Resource
## Vehículo seleccionable (data/vehicles/*.tres).

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var body_color := Color(0.85, 0.15, 0.15)
@export var stats: StatDelta
