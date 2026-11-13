class_name SpiritSummon
extends CharacterBody3D
## Espíritu Ancestral del Cetro. Es un aliado autónomo, no un enemigo:
##   * solo ataca nodos del grupo "enemigos";
##   * nunca entra en "enemigos" ni cuenta para las oleadas;
##   * los enemigos no lo eligen como objetivo (es espectral);
##   * recibe buffs de los gladiadores, pero no daño directo.
## Usa NavigationAgent3D para rodear los obstáculos de la arena y un pool de
## proyectiles para mantener el rendimiento web.

signal disipado

enum Estado { ESCOLTAR, PERSEGUIR, ATACAR, LANZAR, DISIPAR }

const RUTA_MODELO := "res://assets/kaykit/skeletons/Skeleton_Mage.glb"
const VELOCIDAD := 4.4
const ALCANCE := 6.5
const DISTANCIA_COMBATE := 4.6
const DETECCION := 16.0
const INTERVALO_ATAQUE := 1.2
const INTERVALO_DESCARGA := 7.0
const INTERVALO_VINCULO := 12.0
const ACELERACION := 18.0
const GRUPO_ALIADOS := &"aliados"
const GRUPO_ENEMIGOS := &"enemigos"

var _dueno: GladiatorController
var _dano := 10.0
var _tiempo_restante := 18.0
var _duracion_total := 18.0
var _objetivo: Node3D
var _temporizador_ataque := 0.0
var _temporizador_descarga := 4.0
var _temporizador_vinculo := 8.0
var _visual: CharacterVisual
var _agente: NavigationAgent3D
var _estado: Estado = Estado.ESCOLTAR
var _es_menor := false
var _disipando := false
var _bob := 0.0
var _atasco := 0.0
var _ultima_posicion := Vector3.ZERO
var _buff_ataque := 0.0
var _buff_robo := 0.0
var _tiempo_buff := 0.0
var _anillo: MeshInstance3D
var _aura: OmniLight3D


static func crear() -> SpiritSummon:
	var espiritu := SpiritSummon.new()
	espiritu.name = "EspirituAncestral"
	espiritu.add_to_group(GRUPO_ALIADOS)
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
	visual.configurar(RUTA_MODELO, Color(0.55, 1.0, 0.78), "mago", true)
	visual.scale = Vector3.ONE * 0.95
	espiritu._visual = visual

	var agente := NavigationAgent3D.new()
	agente.name = "NavigationAgent3D"
	agente.path_desired_distance = 0.8
	agente.target_desired_distance = 1.0
	agente.radius = 0.45
	agente.neighbor_distance = 4.0
	agente.max_neighbors = 6
	espiritu.add_child(agente)
	espiritu._agente = agente

	var anillo := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.86
	toro.outer_radius = 1.0
	toro.rings = 24
	toro.ring_segments = 6
	anillo.mesh = toro
	anillo.rotation_degrees.x = 90.0
	anillo.position.y = 0.06
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 1.0, 0.78, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.25, 1.0, 0.78)
	mat.emission_energy_multiplier = 1.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	anillo.material_override = mat
	espiritu.add_child(anillo)
	espiritu._anillo = anillo

	var aura := OmniLight3D.new()
	aura.light_color = Color(0.3, 1.0, 0.75)
	aura.light_energy = 0.7
	aura.omni_range = 4.0
	aura.shadow_enabled = false
	aura.position.y = 1.1
	espiritu.add_child(aura)
	espiritu._aura = aura
	return espiritu


func configurar(
	dueno: GladiatorController,
	dano: float,
	duracion: float,
	menor: bool = false
) -> void:
	_dueno = dueno
	_dano = maxf(1.0, dano)
	_duracion_total = maxf(2.0, duracion)
	_tiempo_restante = _duracion_total
	_es_menor = menor
	if menor:
		scale = Vector3.ONE * 0.78
		_dano *= 0.8


func _ready() -> void:
	_ultima_posicion = global_position
	if _agente != null:
		_agente.target_position = global_position
	_animar_aparicion()


func _animar_aparicion() -> void:
	var escala_final := scale
	scale = escala_final * 0.2
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", escala_final, 0.35)


func _physics_process(delta: float) -> void:
	if _disipando:
		return
	_tiempo_restante -= delta
	if _tiempo_restante <= 0.0 or not _dueno_valido():
		_disipar()
		return

	_actualizar_temporizadores(delta)
	_actualizar_objetivo()

	if _objetivo != null and _objetivo_valido():
		_combatir(delta)
	else:
		_escoltar(delta)

	move_and_slide()
	_actualizar_animacion(delta)
	_comprobar_atasco(delta)


func _actualizar_temporizadores(delta: float) -> void:
	_temporizador_ataque = maxf(0.0, _temporizador_ataque - delta)
	_temporizador_descarga = maxf(0.0, _temporizador_descarga - delta)
	_temporizador_vinculo = maxf(0.0, _temporizador_vinculo - delta)
	if _tiempo_buff > 0.0:
		_tiempo_buff = maxf(0.0, _tiempo_buff - delta)
		if _tiempo_buff <= 0.0:
			_buff_ataque = 0.0
			_buff_robo = 0.0


func _actualizar_objetivo() -> void:
	if _objetivo_valido():
		return
	_objetivo = _buscar_enemigo()
	if _objetivo == null:
		_estado = Estado.ESCOLTAR


func _combatir(delta: float) -> void:
	if _temporizador_vinculo <= 0.0:
		_temporizador_vinculo = INTERVALO_VINCULO
		if _intentar_vinculo():
			return
	if _temporizador_descarga <= 0.0:
		_temporizador_descarga = INTERVALO_DESCARGA
		if _intentar_descarga():
			return

	var distancia := global_position.distance_to(_objetivo.global_position)
	if distancia > ALCANCE:
		_estado = Estado.PERSEGUIR
		_mover_hacia(_objetivo.global_position, delta, DISTANCIA_COMBATE)
		return
	if distancia > DISTANCIA_COMBATE:
		_estado = Estado.PERSEGUIR
		_mover_hacia(_objetivo.global_position, delta, DISTANCIA_COMBATE)
	else:
		_estado = Estado.ATACAR
		velocity = velocity.move_toward(Vector3.ZERO, ACELERACION * delta)
		_mirar_hacia(_objetivo.global_position, delta)
		_atacar()


func _escoltar(delta: float) -> void:
	_estado = Estado.ESCOLTAR
	if _dueno == null or not is_instance_valid(_dueno):
		velocity = velocity.move_toward(Vector3.ZERO, ACELERACION * delta)
		return
	var destino := _dueno.global_position + Vector3(1.2, 0, 1.2)
	if global_position.distance_to(destino) > 2.6:
		_mover_hacia(destino, delta, 2.2)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, ACELERACION * delta)


func _mover_hacia(destino: Vector3, delta: float, distancia_deseada: float) -> void:
	destino.y = 0.0
	var plano := destino - global_position
	plano.y = 0.0
	if plano.length() <= distancia_deseada:
		velocity = velocity.move_toward(Vector3.ZERO, ACELERACION * delta)
		return

	var siguiente := destino
	if _agente != null:
		_agente.target_position = destino
		var candidato := _agente.get_next_path_position()
		candidato.y = 0.0
		if candidato.distance_to(global_position) > 0.15:
			siguiente = candidato
	var direccion := siguiente - global_position
	direccion.y = 0.0
	if direccion.length_squared() < 0.001:
		velocity = velocity.move_toward(Vector3.ZERO, ACELERACION * delta)
		return
	var deseada := direccion.normalized() * VELOCIDAD
	velocity = velocity.move_toward(deseada, ACELERACION * delta)
	_mirar_hacia(destino, delta)


func _mirar_hacia(destino: Vector3, delta: float) -> void:
	var direccion := destino - global_position
	direccion.y = 0.0
	if direccion.length_squared() < 0.001:
		return
	var giro := atan2(-direccion.x, -direccion.z)
	rotation.y = lerp_angle(rotation.y, giro, minf(1.0, delta * 10.0))


func _atacar() -> void:
	if _temporizador_ataque > 0.0 or _objetivo == null:
		return
	_temporizador_ataque = INTERVALO_ATAQUE / (1.0 + _buff_ataque)
	if _visual != null:
		_visual.atacar()
	var origen := global_position + Vector3(0, 1.25, 0) + (-global_transform.basis.z * 0.45)
	SpiritBolt.disparar(origen, _objetivo, _dano, _dueno)
	Sfx.reproducir("magia", -13.0)
	if _buff_robo > 0.0 and _dueno != null and is_instance_valid(_dueno):
		_dueno.curar(_dano * _buff_robo * 0.5)


func _intentar_descarga() -> bool:
	if _objetivo == null:
		return false
	var enemigos := _enemigos_en_radio(_objetivo.global_position, 4.0)
	if enemigos.size() < 2:
		return false
	_estado = Estado.LANZAR
	velocity = Vector3.ZERO
	if _visual != null:
		_visual.lanzar()
	_crear_onda(_objetivo.global_position, 4.0, Color(0.3, 0.85, 1.0))
	var golpes := 0
	for enemigo in enemigos:
		if golpes >= 4:
			break
		golpes += 1
		if enemigo.has_method("recibir_dano"):
			enemigo.recibir_dano(_dano * 1.15, GladiatorStats.TIPO_MAGICO, _dueno)
			if _dueno != null and is_instance_valid(_dueno):
				_dueno.registrar_dano(_dano * 1.15)
		if enemigo.has_method("aplicar_vulnerabilidad"):
			enemigo.aplicar_vulnerabilidad(2.0)
	Sfx.reproducir("espiritu", -11.0)
	return true


func _intentar_vinculo() -> bool:
	if _dueno == null or not is_instance_valid(_dueno):
		return false
	if _dueno.salud_actual >= _dueno.estadisticas.salud_maxima * 0.55:
		return false
	_estado = Estado.LANZAR
	velocity = Vector3.ZERO
	if _visual != null:
		_visual.lanzar()
	var cantidad := _dueno.estadisticas.salud_maxima * 0.08
	_dueno.curar(cantidad)
	_crear_onda(_dueno.global_position, 2.2, Color(0.35, 1.0, 0.55))
	Sfx.reproducir("espiritu", -12.0)
	return true


func _enemigos_en_radio(centro: Vector3, radio: float) -> Array[Node3D]:
	var resultado: Array[Node3D] = []
	for nodo in get_tree().get_nodes_in_group(GRUPO_ENEMIGOS):
		var enemigo := nodo as Node3D
		if enemigo == null or not _es_enemigo_valido(enemigo):
			continue
		if enemigo.global_position.distance_to(centro) <= radio:
			resultado.append(enemigo)
	return resultado


func _buscar_enemigo() -> Node3D:
	var mejor: Node3D = null
	var mejor_distancia := DETECCION * DETECCION
	for nodo in get_tree().get_nodes_in_group(GRUPO_ENEMIGOS):
		var enemigo := nodo as Node3D
		if enemigo == null or not _es_enemigo_valido(enemigo):
			continue
		var distancia := global_position.distance_squared_to(enemigo.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = enemigo
	return mejor


func _es_enemigo_valido(enemigo: Node3D) -> bool:
	if enemigo == self or not enemigo.is_in_group(GRUPO_ENEMIGOS):
		return false
	if enemigo.is_in_group(GRUPO_ALIADOS):
		return false
	if enemigo.get("esta_muerto") == true:
		return false
	if enemigo.get("activo") == false:
		return false
	return true


func _objetivo_valido() -> bool:
	if _objetivo == null or not is_instance_valid(_objetivo):
		return false
	if not _es_enemigo_valido(_objetivo):
		return false
	return _objetivo.global_position.distance_to(global_position) <= DETECCION


func _dueno_valido() -> bool:
	return _dueno != null and is_instance_valid(_dueno) and not _dueno.esta_muerto


func _actualizar_animacion(delta: float) -> void:
	_bob += delta * 2.2
	if _visual != null:
		_visual.position.y = sin(_bob) * 0.07
		_visual.mover(velocity.length())
	if _anillo != null:
		_anillo.rotate_y(delta * 0.9)


func _comprobar_atasco(delta: float) -> void:
	if velocity.length() < 0.15:
		_atasco = 0.0
		_ultima_posicion = global_position
		return
	var avance := global_position.distance_to(_ultima_posicion)
	_ultima_posicion = global_position
	if avance < 0.02:
		_atasco += delta
	else:
		_atasco = maxf(0.0, _atasco - delta * 0.5)
	if _atasco > 2.5:
		_atasco = 0.0
		var destino := _objetivo.global_position if _objetivo != null else (_dueno.global_position if _dueno != null else global_position)
		global_position = destino + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
		if _agente != null:
			_agente.target_position = global_position


func _crear_onda(centro: Vector3, radio: float, color: Color) -> void:
	var onda := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = radio * 0.9
	toro.outer_radius = radio
	onda.mesh = toro
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.75)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	onda.material_override = mat
	onda.position = Vector3(centro.x, 0.08, centro.z)
	get_tree().current_scene.add_child(onda)
	var color_final := mat.albedo_color
	color_final.a = 0.0
	var tween := onda.create_tween()
	tween.set_parallel(true)
	tween.tween_property(onda, "scale", Vector3.ONE * 0.4, 0.35)
	tween.tween_property(mat, "albedo_color", color_final, 0.35)
	tween.chain().tween_callback(onda.queue_free)


func aplicar_buff(duracion: float, bonus_ataque: float, robo: float) -> void:
	_buff_ataque = maxf(_buff_ataque, bonus_ataque)
	_buff_robo = maxf(_buff_robo, robo)
	_tiempo_buff = maxf(_tiempo_buff, duracion)


func _disipar() -> void:
	if _disipando:
		return
	_disipando = true
	_estado = Estado.DISIPAR
	velocity = Vector3.ZERO
	set_physics_process(false)
	if _agente != null:
		_agente.set_physics_process(false)
	if _aura != null:
		_aura.light_energy = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", scale * 0.15, 0.35)
	tween.tween_property(self, "rotation:y", rotation.y + 1.8, 0.35)
	var _cb_disipar := Callable(self, "_on_disipado_tween_completo")
	tween.chain().tween_callback(_cb_disipar)

func _on_disipado_tween_completo() -> void:
	disipado.emit()
	queue_free()