class_name VehicleModel
extends RefCounted
## Modelos 3D low poly de los vehículos (una sola malla por vehículo). Origen = suelo bajo el centro del kart,
## -Z = adelante. Los asientos del conductor y del artillero son comunes a todos los estilos.

const SEAT_DRIVER := Vector3(0, 0.40, 0.18)
const SEAT_GUNNER := Vector3(0, 0.50, 0.88)
const STYLES: Array[String] = ["scrap", "standard", "sleek", "scorpion", "truck", "rocket"]


static func build_mesh(v: VehicleData, body_color: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	var dark := Color(0.09, 0.09, 0.1)
	var metal := Color(0.45, 0.46, 0.5)
	var trim := body_color.lightened(0.35)
	var shade := body_color.darkened(0.3)
	var wheel_r := 0.30
	var wheel_x := 0.70
	var wheel_z := 0.78
	var style := v.style
	match style:
		"scrap":
			wheel_r = 0.32
			b.box(Vector3(0, 0.34, 0.05), Vector3(1.32, 0.34, 2.15), body_color)
			b.box(Vector3(0.0, 0.58, -0.55), Vector3(1.1, 0.26, 0.8), shade)                    # capó remachado
			b.box(Vector3(-0.2, 0.62, 0.3), Vector3(0.5, 0.22, 0.5), Color(0.55, 0.32, 0.18))   # chapa oxidada
			b.box(Vector3(0.38, 0.66, -0.15), Vector3(0.34, 0.12, 0.6), Color(0.35, 0.36, 0.38))
			for sx in [-1.0, 1.0]:
				b.push(MeshBuilder.rot_x(90.0))
				b.cylinder(Vector3(sx * 0.72, 0.0, -0.3), 0.07, 0.07, 1.1, metal, 6)             # tubos de escape laterales
				b.pop()
			for i in 5:
				b.cone(Vector3(-0.5 + i * 0.25, 0.34, -1.22), 0.07, 0.32, metal, 5)              # púas del parachoques
			b.box(Vector3(0, 0.78, 1.18), Vector3(0.3, 0.2, 0.3), dark)                           # soporte de arma
		"standard":
			b.box(Vector3(0, 0.32, 0.05), Vector3(1.22, 0.30, 2.1), body_color)
			b.ellipsoid(Vector3(0, 0.34, -0.75), Vector3(0.58, 0.24, 0.62), body_color, 8, 5)    # morro redondeado
			b.box(Vector3(0, 0.26, 0.05), Vector3(1.28, 0.06, 1.7), trim)                          # franja
			b.box(Vector3(0, 0.70, 1.12), Vector3(1.1, 0.07, 0.34), trim)                          # alerón
			for sx in [-1.0, 1.0]:
				b.box(Vector3(sx * 0.46, 0.55, 1.1), Vector3(0.06, 0.34, 0.12), dark)
		"sleek":
			wheel_r = 0.27
			wheel_z = 0.82
			b.ellipsoid(Vector3(0, 0.30, 0.0), Vector3(0.62, 0.20, 1.22), body_color, 9, 5)     # carrocería alargada
			b.box(Vector3(0, 0.20, 0.05), Vector3(1.0, 0.14, 2.0), shade)
			b.box(Vector3(0, 0.36, -1.18), Vector3(1.3, 0.04, 0.30), trim)                         # alerón delantero
			b.box(Vector3(0, 0.78, 1.15), Vector3(0.06, 0.5, 0.5), trim)                           # aleta trasera
			b.box(Vector3(0, 0.52, 0.95), Vector3(0.9, 0.05, 0.3), trim)
		"scorpion":
			wheel_r = 0.29
			b.box(Vector3(0, 0.28, 0.1), Vector3(1.2, 0.26, 2.0), body_color)
			b.ellipsoid(Vector3(0, 0.36, -0.7), Vector3(0.5, 0.2, 0.55), shade, 8, 5)
			for sx in [-1.0, 1.0]:                                                                 # pinzas delanteras
				b.push(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90.0)) * Basis(Vector3.UP, deg_to_rad(sx * 12.0)),
						Vector3(sx * 0.42, 0.34, -1.25)))
				b.cone(Vector3.ZERO, 0.12, 0.55, trim, 6)
				b.pop()
			for i in 6:                                                                            # cola curva hacia delante
				var t := float(i) / 5.0
				b.sphere(Vector3(0, 0.50 + sin(t * PI * 0.8) * 1.05, 1.05 + t * 0.35 - sin(t * PI) * 0.35), 0.20 - t * 0.05, body_color, 7, 4)
			b.push(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-60.0)), Vector3(0, 1.62, 0.78)))
			b.cone(Vector3.ZERO, 0.09, 0.38, trim, 6)                                              # aguijón
			b.pop()
		"truck":
			wheel_r = 0.42
			wheel_x = 0.76
			b.box(Vector3(0, 0.50, 0.15), Vector3(1.35, 0.5, 2.15), body_color)
			b.box(Vector3(0, 0.95, -0.2), Vector3(1.1, 0.42, 0.9), shade)                          # cabina
			b.box(Vector3(0, 0.95, -0.66), Vector3(0.95, 0.24, 0.04), Color(0.55, 0.8, 0.95))      # parabrisas
			b.box(Vector3(0, 0.82, 0.78), Vector3(1.2, 0.07, 0.6), metal)                          # baca
			for sx in [-1.0, 1.0]:
				b.box(Vector3(sx * 0.5, 0.45, -1.15), Vector3(0.08, 0.5, 0.1), metal)              # defensa
				b.cylinder(Vector3(sx * 0.62, 1.02, 0.42), 0.05, 0.05, 0.6, metal, 6)              # chimeneas
			b.box(Vector3(0, 0.4, -1.18), Vector3(1.1, 0.07, 0.1), metal)
		"rocket":
			wheel_r = 0.28
			b.push(MeshBuilder.rot_x(90.0))
			b.cylinder(Vector3(0, 0.0, -0.4), 0.38, 0.38, 2.0, body_color, 10)                    # fuselaje (eje Z)
			b.pop()
			b.push(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90.0)), Vector3(0, 0.40, -1.35)))
			b.cone(Vector3.ZERO, 0.38, 0.8, trim, 10)                                              # morro (punta hacia delante)
			b.pop()
			b.push(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90.0)), Vector3(0, 0.40, 1.12)))
			b.cone(Vector3.ZERO, 0.22, 0.4, Color(1.0, 0.6, 0.15), 8)                              # tobera
			b.pop()
			for i in 3:                                                                            # aletas
				b.push(Transform3D(Basis(Vector3.BACK, deg_to_rad(120.0 * i)), Vector3(0, 0.40, 0.95)))
				b.box(Vector3(0, 0.46, 0), Vector3(0.05, 0.42, 0.5), trim)
				b.pop()
	# Ruedas comunes
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.push(Transform3D(Basis(Vector3.BACK, deg_to_rad(90.0)), Vector3(sx * wheel_x, wheel_r, sz * wheel_z)))
			b.cylinder(Vector3.ZERO, wheel_r, wheel_r, 0.30, dark, 8)
			b.cylinder(Vector3(0, sx * 0.0, 0), wheel_r * 0.55, wheel_r * 0.55, 0.32, metal, 6)
			b.pop()
	# Asientos (comunes)
	b.box(SEAT_DRIVER + Vector3(0, -0.12, 0.1), Vector3(0.5, 0.12, 0.45), dark)
	b.box(SEAT_GUNNER + Vector3(0, -0.12, 0.1), Vector3(0.44, 0.10, 0.4), dark)
	return b.build()
