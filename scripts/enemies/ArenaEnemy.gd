class_name ArenaEnemy
extends CharacterBody3D
## Enemigo básico de oleada (orco imperial / gladiador rival).
##
## IA deliberadamente simple: sin NavigationAgent. La arena es convexa y sin
## obstáculos, así que la persecución directa es más barata en Web que mantener
## decenas de agentes de navegación. El jugador sí usa NavigationAgent3D.
##
## Prioridad de objetivo:
## 1. Quien lo haya provocado (taunt) mientras dure el efecto.
## 2. El jugador si está a menos de 5,5 m.
## 3. El estandarte central.

signal murio(oro: int)

const GRUPO := &"enemigos"
const RUTA_ESQUELETO := "res://assets/kaykit/skeletons/Skeleton_Warrior.glb"
const RUTA_ESPECTRO := "res://assets/kaykit/skeletons/Skeleton_Rogue.glb"
const RUTA_CABALLERO := "res://assets/kaykit/adventurers/Knight.glb"

var es_elite := false
var es_ligero := false
var activo := false
var salud_maxima := 30.0
var salud_actual := 0.0
var dano := 5.0
var velocidad := 2.5
var rango := 2.2
var cadencia := 1.5
## Arquero: se mantiene a distancia y dispara proyectiles en lugar de cuerpo a cuerpo.
var es_arquero := false
var rango_ataque_distancia := 8.0
var cadencia_disparo := 2.0
var _tiempo_disparo := 0.0

## Hechicero: lanza proyectiles mágicos con daño en área al impactar.
var es_hechicero := false
var rango_ataque_magia := 10.0
var cadencia_magia := 2.5
var _tiempo_magia := 0.0
var dano_magia := 18.0
var radio_magia := 3.5

## Tanque: más vida, escudo que absorbe daño y se recarga, ataque fuerte pero lento.
var es_tanque := false
var escudo_tanque_actual := 0.0
var escudo_tanque_maxima := 0.0
var _tiempo_recarga_escudo := 0.0
var recompensa := 8
var xp_recompensa := 0
var visual: CharacterVisual

var _jugador: GladiatorController
var _bandera: Node3D
var _gestor: Node
var _pool: ObjectPool
var _fuente_provocacion: Node3D
var _provocado := 0.0
var _temporizador := 0.0
var _flash := 0.0
var _tipo_visual := &""
var _tiempo_muerte := 0.0
var _marca_verdugo := 0.0
var _vulnerable_magico := 0.0
var _aturdido := 0.0


static func crear() -> ArenaEnemy:
	var enemigo := ArenaEnemy.new()
	enemigo._construir()
	return enemigo


func _construir() -> void:
	collision_layer = 2
	collision_mask = 0

	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.45
	capsula.height = 1.5
	forma.shape = capsula
	forma.position.y = 0.75
	add_child(forma)


## Construye o reutiliza el modelo animado según el tipo de enemigo.
func _configurar_visual(elite: bool, ligero: bool = false) -> void:
	var tipo := &"caballero" if elite else (&"espectro" if ligero else &"esqueleto")
	var ruta := RUTA_CABALLERO if elite else (RUTA_ESPECTRO if ligero else RUTA_ESQUELETO)
	var tinte := Color(1.0, 0.72, 0.66) if elite else Color(0.82, 0.95, 0.90)
	if ligero:
		tinte = Color(0.74, 0.86, 1.0)

	if visual != null and _tipo_visual == tipo:
		visual.aplicar_skin(tinte)
		return
	if visual != null:
		visual.queue_free()
		visual = null
	visual = CharacterVisual.new()
	visual.name = "Visual"
	add_child(visual)
	visual.configurar(ruta, tinte, "caballero" if elite else "esqueleto")
	_tipo_visual = tipo


func preparar(
	ronda: int,
	elite: bool,
	jugador: GladiatorController,
	bandera: Node3D,
	gestor: Node,
	pool: ObjectPool,
	xp: int = 0
) -> void:
	es_elite = elite
	xp_recompensa = xp
	activo = true
	_jugador = jugador
	_bandera = bandera
	_gestor = gestor
	_pool = pool

	var factor_elite := 2.4 if elite else 1.0
	var ligero := not elite and randf() < 0.35
	es_ligero = ligero
	es_arquero = not elite and not ligero and randf() < 0.18
	es_hechicero = not elite and not ligero and not es_arquero and randf() < 0.12
	es_tanque = not elite and not ligero and not es_arquero and not es_hechicero and randf() < 0.10
	if es_hechicero:
		salud_maxima *= 0.60
		velocidad *= 0.80
	if es_tanque:
		salud_maxima *= 1.8
		velocidad *= 0.65
		dano *= 1.5
		escudo_tanque_maxima = 60.0 + ronda * 5.0
		escudo_tanque_actual = escudo_tanque_maxima
	if es_arquero:
		salud_maxima *= 0.70
		velocidad *= 0.85
	salud_maxima = (50.0 + ronda * 18.0) * factor_elite
	dano = (7.0 + ronda * 2.5) * (1.5 if elite else 1.0)
	velocidad = 2.3 + minf(ronda * 0.04, 0.9)
	if ligero:
		salud_maxima *= 0.85
		velocidad *= 1.12
	salud_actual = salud_maxima
	recompensa = (12 + ronda) * (3 if elite else 1)
	_temporizador = randf_range(0.0, 0.5)
	_provocado = 0.0
	_fuente_provocacion = null
	_flash = 0.0
	_tiempo_muerte = 0.0
	_marca_verdugo = 0.0
	_vulnerable_magico = 0.0
	_aturdido = 0.0
	_configurar_visual(elite, ligero)
	scale = Vector3.ONE * (1.25 if elite else 1.0)
	add_to_group(GRUPO)
	if es_arquero and visual != null:
		visual.aplicar_skin(Color(0.95, 0.45, 0.40))
	if es_hechicero and visual != null:
		visual.aplicar_skin(Color(0.80, 0.40, 1.00))
	if es_tanque and visual != null:
		visual.aplicar_skin(Color(0.70, 0.70, 0.80))
	var tracker = get_tree().get_first_node_in_group("enemy_tracker")
	if tracker != null:
		tracker.registrar(self)


func al_obtener() -> void:
	activo = false
	_tiempo_muerte = 0.0
	if visual != null:
		visual.revivir()


func al_devolver() -> void:
	activo = false
	velocity = Vector3.ZERO
	remove_from_group(GRUPO)


## Enemigo de solo lectura para clientes: sin IA, sin daño, sin pool.
func configurar_remoto(elite: bool, ligero := false) -> void:
	es_elite = elite
	es_ligero = ligero
	activo = true
	_configurar_visual(elite, ligero)
	add_to_group(GRUPO)
	set_physics_process(false)


func aplicar_remoto(posicion: Vector3, rotacion: float, vida: float, vida_max: float) -> void:
	global_position = posicion
	rotation.y = rotacion
	salud_maxima = maxf(1.0, vida_max)
	salud_actual = maxf(0.0, vida)
	activo = salud_actual > 0.0


func _physics_process(delta: float) -> void:
	if _tiempo_muerte > 0.0:
		_tiempo_muerte -= delta
		if _tiempo_muerte <= 0.0 and _pool != null:
			_pool.devolver(self)
		return
	if not activo:
		return

	if _provocado > 0.0:
		_provocado -= delta
	if _marca_verdugo > 0.0:
		_marca_verdugo -= delta
	if _vulnerable_magico > 0.0:
		_vulnerable_magico -= delta
	if _aturdido > 0.0:
		_aturdido -= delta
		velocity = Vector3.ZERO
		if visual != null:
			visual.mover(0.0)
		return

	var objetivo := _elegir_objetivo()
	if objetivo == null:
		return

	var distancia := global_position.distance_to(objetivo.global_position)

	# Arquero: mantener distancia y disparar proyectiles
	if es_arquero:
		if distancia > rango_ataque_distancia:
			var direccion := objetivo.global_position - global_position
			direccion.y = 0.0
			if direccion.length_squared() > 0.0004:
				direccion = direccion.normalized()
				velocity = direccion * velocidad
				rotation.y = lerp_angle(rotation.y, atan2(direccion.x, direccion.z), 10.0 * delta)
				move_and_slide()
				if visual != null:
					visual.mover(velocity.length())
			return
		else:
			velocity = Vector3.ZERO
			if visual != null:
				visual.mover(0.0)
			_tiempo_disparo -= delta
			if _tiempo_disparo <= 0.0:
				_tiempo_disparo = cadencia_disparo
				_disparar_proyectil(objetivo)
			return

		# Hechicero: mantener distancia y lanzar magia de área
		if es_hechicero:
			if distancia > rango_ataque_magia:
				var direccion := objetivo.global_position - global_position
				direccion.y = 0.0
				if direccion.length_squared() > 0.0004:
					direccion = direccion.normalized()
					velocity = direccion * velocidad
					rotation.y = lerp_angle(rotation.y, atan2(direccion.x, direccion.z), 10.0 * delta)
					move_and_slide()
					if visual != null:
						visual.mover(velocity.length())
			return
		else:
			velocity = Vector3.ZERO
			if visual != null:
				visual.mover(0.0)
			_tiempo_magia -= delta
			if _tiempo_magia <= 0.0:
				_tiempo_magia = cadencia_magia
				_disparar_magia(objetivo)
			return

	if distancia > rango:
		var direccion := objetivo.global_position - global_position
		direccion.y = 0.0
		if direccion.length_squared() > 0.0004:
			direccion = direccion.normalized()
			velocity = direccion * velocidad
			rotation.y = lerp_angle(rotation.y, atan2(direccion.x, direccion.z), 10.0 * delta)
			move_and_slide()
			if visual != null:
				visual.mover(velocity.length())
		return

	velocity = Vector3.ZERO
	if visual != null:
		visual.mover(0.0)
	_temporizador -= delta
	if _temporizador <= 0.0:
		_temporizador = cadencia
		if visual != null:
			visual.atacar()
		if objetivo.has_method("recibir_dano"):
			objetivo.recibir_dano(dano, &"fisico", self)

	# Tanque: recarga de escudo con el tiempo
	if es_tanque and escudo_tanque_actual < escudo_tanque_maxima:
		_tiempo_recarga_escudo -= delta
		if _tiempo_recarga_escudo <= 0.0:
			escudo_tanque_actual = minf(escudo_tanque_maxima, escudo_tanque_actual + 5.0 * delta)
			if escudo_tanque_actual >= escudo_tanque_maxima:
				_tiempo_recarga_escudo = 2.0  # Pausa antes de volver a recargar


func _disparar_magia(objetivo: Node3D) -> void:
	if objetivo == null:
		return
	var rayo := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.12, 0.12, global_position.distance_to(objetivo.global_position))
	rayo.mesh = caja
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.4, 1.0, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(0.6, 0.2, 1.0)
	material.emission_energy_multiplier = 2.0
	rayo.material_override = material
	add_child(rayo)
	var medio := global_position.lerp(objetivo.global_position, 0.5)
	rayo.global_position = Vector3(medio.x, 1.0, medio.z)
	rayo.look_at(objetivo.global_position, Vector3.UP)
	var tween := rayo.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.25)
	tween.tween_callback(rayo.queue_free)

	# Daño en área mágica alrededor del objetivo
	for nodo in get_tree().get_nodes_in_group("gladiadores"):
		var gladiador := nodo as Node3D
		if gladiador == null or not is_instance_valid(gladiador):
			continue
		if gladiador.global_position.distance_to(objetivo.global_position) <= radio_magia:
			if gladiador.has_method("recibir_dano"):
				gladiador.recibir_dano(dano_magia, GladiatorStats.TIPO_MAGICO, self)
	Sfx.reproducir("magia", -10.0)


func _disparar_proyectil(objetivo: Node3D) -> void:
	if objetivo == null:
		return
	var rayo := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.12, 0.12, global_position.distance_to(objetivo.global_position))
	rayo.mesh = caja
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.6, 0.1, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(1.0, 0.4, 0.0)
	material.emission_energy_multiplier = 2.0
	rayo.material_override = material
	add_child(rayo)
	var medio := global_position.lerp(objetivo.global_position, 0.5)
	rayo.global_position = Vector3(medio.x, 1.0, medio.z)
	rayo.look_at(objetivo.global_position, Vector3.UP)
	var tween := rayo.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.25)
	tween.tween_callback(rayo.queue_free)
	if objetivo.has_method("recibir_dano"):
		objetivo.recibir_dano(dano * 0.9, &"fisico", self)
	Sfx.reproducir("golpe", -10.0)


func _elegir_objetivo() -> Node3D:
	if _provocado > 0.0 and is_instance_valid(_fuente_provocacion):
		return _fuente_provocacion

	var mejor: Node3D = null
	var mejor_distancia := INF
	for nodo in get_tree().get_nodes_in_group(GladiatorController.GRUPO_GLADIADORES):
		var cuerpo := nodo as Node3D
		if cuerpo == null or not is_instance_valid(cuerpo):
			continue
		var muerto = cuerpo.get("esta_muerto")
		if muerto is bool and muerto:
			continue
		var distancia := global_position.distance_squared_to(cuerpo.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = cuerpo

	if mejor != null:
		return mejor
	if _bandera != null and is_instance_valid(_bandera):
		return _bandera
	if _jugador != null and is_instance_valid(_jugador) and not _jugador.esta_muerto:
		return _jugador
	return null


func aplicar_provocacion(fuente: Node3D, duracion: float) -> void:
	if not activo or fuente == null:
		return
	_fuente_provocacion = fuente
	_provocado = maxf(_provocado, duracion)


func esta_provocado() -> bool:
	return _provocado > 0.0


func aplicar_marca(duracion: float) -> void:
	if activo:
		_marca_verdugo = maxf(_marca_verdugo, duracion)


func esta_marcado() -> bool:
	return _marca_verdugo > 0.0


func aplicar_vulnerabilidad(duracion: float) -> void:
	if activo:
		_vulnerable_magico = maxf(_vulnerable_magico, duracion)


func aplicar_aturdimiento(duracion: float) -> void:
	if activo:
		_aturdido = maxf(_aturdido, duracion)


func recibir_dano(cantidad: float, tipo: StringName = &"fisico", _fuente: Node = null, critico := false) -> void:
	if not activo or cantidad <= 0.0:
		return
	if tipo == GladiatorStats.TIPO_MAGICO and _vulnerable_magico > 0.0:
		cantidad *= 1.35

	# Tanque: el escudo absorbe daño primero
	if es_tanque and escudo_tanque_actual > 0.0:
		var absorbido := minf(escudo_tanque_actual, cantidad)
		escudo_tanque_actual -= absorbido
		cantidad -= absorbido
		NumerosDano.mostrar(global_position + Vector3(0, 1.8, 0), absorbido, GladiatorStats.TIPO_VERDADERO, false, true)
		if cantidad <= 0.0:
			_flash = 0.08
			if visual != null:
				visual.recibir_golpe()
			Sfx.reproducir("escudo", -8.0)
			return

	salud_actual = maxf(0.0, salud_actual - cantidad)
	_flash = 0.08
	NumerosDano.mostrar(global_position + Vector3(0, 1.3, 0), cantidad, tipo, critico)
	if visual != null:
		visual.recibir_golpe()

	if salud_actual <= 0.0:
		_morir()


func _morir() -> void:
	if not activo:
		return
	activo = false
	var tracker = get_tree().get_first_node_in_group("enemy_tracker")
	if tracker != null:
		tracker.desregistrar(self)
	remove_from_group(GRUPO)
	if visual != null:
		visual.morir()
	Sfx.reproducir("enemigo", -9.0)
	_tiempo_muerte = 1.1
	murio.emit(recompensa)
	if _gestor != null and is_instance_valid(_gestor) and _gestor.has_method("al_morir_enemigo"):
		_gestor.al_morir_enemigo(recompensa, xp_recompensa)

	# Partículas de muerte: cubos que saltan hacia arriba.
	for i in range(8):
		var p := MeshInstance3D.new()
		var c := BoxMesh.new()
		c.size = Vector3(0.15, 0.15, 0.15)
		p.mesh = c
		var ang := float(i) * TAU / 8.0
		var d := Vector3(cos(ang), 0.7, sin(ang))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.3, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(0.9, 0.3, 0.3)
		mat.emission_energy_multiplier = 2.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p.material_override = mat
		add_child(p)
		var tp := p.create_tween()
		tp.tween_property(p, "global_position", global_position + d * 2.5, 0.6).set_ease(Tween.EASE_OUT)
		tp.tween_property(mat, "emission_energy_multiplier", 0.0, 0.6)
		tp.chain().tween_callback(p.queue_free)
