class_name HitboxGolpe3D
extends RefCounted
## Consulta de golpe contra hurtboxes (ReceptorGolpes3D) usando capas separadas.
##
## Se usa en el ataque básico en vez de llamar directamente a `recibir_dano`:
## una SphereShape3D sobre la capa HURTBOX devuelve las zonas solapadas y se
## aplica el daño al dueño más cercano. Así el alcance real lo decide la física
## y el knockback viaja por el mismo hurtbox.

const MAX_RESULTADOS := 8


## Devuelve cuántos objetivos recibieron daño (0 si no había nadie en rango).
static func golpear(
	mundo: World3D,
	centro: Vector3,
	radio: float,
	dano: float,
	tipo: StringName,
	critico: bool,
	fuente: Node3D
) -> int:
	if mundo == null or fuente == null or dano <= 0.0:
		return 0
	var forma := SphereShape3D.new()
	forma.radius = maxf(0.1, radio)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis(), centro)
	consulta.collision_mask = ReceptorGolpes3D.CAPA_HURTBOX
	consulta.collide_with_areas = true
	consulta.collide_with_bodies = false

	var resultados: Array[Dictionary] = mundo.direct_space_state.intersect_shape(consulta, MAX_RESULTADOS)
	var mejor: Node = null
	var mejor_distancia := INF
	for resultado: Dictionary in resultados:
		var area := resultado.get("collider") as Area3D
		if area == null or not area is ReceptorGolpes3D:
			continue
		var dueno := area.get_parent()
		if dueno == null or dueno == fuente:
			continue
		if dueno is Node3D and (dueno as Node3D).global_position.distance_squared_to(centro) < mejor_distancia:
			mejor_distancia = (dueno as Node3D).global_position.distance_squared_to(centro)
			mejor = dueno
	if mejor == null:
		return 0
	if mejor.has_method("recibir_dano"):
		mejor.call("recibir_dano", dano, tipo, fuente, critico)
		return 1
	return 0
