class_name SpiritSummon
extends CharacterBody3D
## Espíritu ancestral invocado por el Cetro. Persigue enemigos cercanos,
## golpea con daño mágico heredado de la INT del gladiador y se disipa al
## agotar su duración. Sin navegación: la arena es abierta y el espíritu flota.

const RUTA_MODELO := "res://assets/kaykit/skeletons/Skeleton_Mage.glb"
const VELOCIDAD := 4.2
const ALCANCE := 2.6
const DETECCION := 15.0
const INTERVALO_ATAQUE := 1.1

var _dueno: GladiatorController
var _dano := 10.0
var _vida := 18.0
var _objetivo: Node3D
var _temporizador := 0.0
var _visual: CharacterVisual


static func crear() -> SpiritSummon:
	var espiritu := SpiritSummon.new()
	espiritu.name = "EspirituAncestral"
	espiritu.add_to_group("aliados")
	espiritu.collision_layer = 0
	espiritu.collision_mask = 1

	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.42
	capsula.height = 1.8
	forma.shape = capsula
	forma.position.y = 0.9
	espiritu.add_child(forma)

	var visual := CharacterVisual.new()
	visual.name = "Visual"
	espiritu.add_child(visual)
	visual.configurar(RUTA_MODELO, Color(0.55, 1.0, 0.78), "mago")
	visual.scale = Vector3.ONE * 0.95
	espiritu._visual = visual
	return espiritu


func configurar(dueno: GladiatorController, dano: float, duracion: float) -> void:
	_dueno = dueno
	_dano = maxf(1.0, dano)
	_vida = maxf(2.0, duracion)


func _physics_process(delta: float) -> void:
	_vida -= delta
	if _vida <= 0.0:
		queue_free()
		return

	if not _objetivo_valido():
		_objetivo = _buscar_enemigo()

	var destino := Vector3.ZERO
	if _objetivo != null:
		destino = _objetivo.global_position
		var distancia := global_position.distance_to(destino)
		if distancia > ALCANCE:
			_avanzar_hacia(destino, delta)
		else:
			velocity = Vector3.ZERO
			_atacar(delta)
	else:
		# Sin enemigos: escolta al dueño a media distancia.
		if _dueno != null and is_instance_valid(_dueno):
			destino = _dueno.global_position + Vector3(1.2, 0, 1.2)
			if global_position.distance_to(destino) > 2.2:
				_avanzar_hacia(destino, delta)
			else:
				velocity = Vector3.ZERO
		else:
			velocity = Vector3.ZERO

	move_and_slide()
	if _visual != null:
		_visual.mover(velocity.length())


func _avanzar_hacia(destino: Vector3, delta: float) -> void:
	var direccion := destino - global_position
	direccion.y = 0.0
	if direccion.length_squared() < 0.001:
		velocity = Vector3.ZERO
		return
	velocity = direccion.normalized() * VELOCIDAD
	var giro := atan2(-direccion.x, -direccion.z)
	rotation.y = lerp_angle(rotation.y, giro, minf(1.0, delta * 10.0))


func _atacar(delta: float) -> void:
	_temporizador = maxf(0.0, _temporizador - delta)
	if _temporizador > 0.0 or _objetivo == null:
		return
	_temporizador = INTERVALO_ATAQUE
	if _visual != null:
		_visual.atacar()
	if _objetivo.has_method("recibir_dano"):
		_objetivo.recibir_dano(_dano, GladiatorStats.TIPO_MAGICO, _dueno)


func _buscar_enemigo() -> Node3D:
	var mejor: Node3D = null
	var mejor_distancia := DETECCION * DETECCION
	for nodo in get_tree().get_nodes_in_group("enemigos"):
		var enemigo := nodo as Node3D
		if enemigo == null or enemigo.get("esta_muerto") == true:
			continue
		var distancia := global_position.distance_squared_to(enemigo.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = enemigo
	return mejor


func _objetivo_valido() -> bool:
	if _objetivo == null or not is_instance_valid(_objetivo):
		return false
	return _objetivo.get("esta_muerto") != true and _objetivo.global_position.distance_to(global_position) <= DETECCION
