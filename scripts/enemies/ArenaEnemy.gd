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
const RUTA_MAGO := "res://assets/kaykit/skeletons/Skeleton_Mage.glb"
const RUTA_BARBARO := "res://assets/kaykit/adventurers/Barbarian.glb"

var es_elite := false
## Espejo de red (cliente): posición autoritativa que llega en cada snapshot.
var _es_remoto := false
var _pos_red := Vector3.ZERO
var _rot_red := 0.0
var es_ligero := false
var activo := false
var salud_maxima := 30.0
var salud_actual := 0.0
var dano := 5.0
var velocidad := 2.5
var rango := 2.2
var cadencia := 1.7
## Arquero: se mantiene a distancia y dispara proyectiles en lugar de cuerpo a cuerpo.
var es_arquero := false
var rango_ataque_distancia := 8.0
var cadencia_disparo := 2.4
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
## Sabueso: hostigador veloz de vida baja que muerde en rápida sucesión.
var es_sabueso := false
## Bruto: golpeador lento y pesado con armadura que recorta el daño físico.
var es_bruto := false
## Nigromante: mago que sostiene a la horda con un ritual de curación en área.
var es_nigromante := false
var _reduccion_fisica := 0.0
var _ritual_restante := 0.0
var _escala_base := 1.0
## Altura local de la barra de vida: se calcula por arquetipo para que quede
## sobre la cabeza aunque el modelo sea 1.4× (bruto) o 0.8× (sabueso).
var _alto_barra := 1.95
## Último factor de escala aplicado a la barra: mientras el enemigo no cambie de
## tamaño (el tween de aparición dura 0,18 s) no hay que reescribir nada.
var _factor_barra := -1.0
## Barra de vida en el mundo: se construye la primera vez y solo se muestra
## cuando el enemigo está herido o es una amenaza (élite, bruto, tanque).
var _barra_raiz: Node3D
var _barra_relleno: MeshInstance3D
var _barra_fondo: MeshInstance3D
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


## Ruta, tinte y perfil de animación de cada arquetipo de enemigo.
const VISUALES := {
	&"esqueleto": {"ruta": RUTA_ESQUELETO, "tinte": Color(0.82, 0.95, 0.90), "perfil": "esqueleto", "escala": 1.0},
	&"espectro": {"ruta": RUTA_ESPECTRO, "tinte": Color(0.74, 0.86, 1.0), "perfil": "esqueleto", "escala": 1.0},
	&"arquero": {"ruta": RUTA_ESPECTRO, "tinte": Color(0.95, 0.45, 0.40), "perfil": "esqueleto", "escala": 1.0},
	&"hechicero": {"ruta": RUTA_MAGO, "tinte": Color(0.80, 0.40, 1.00), "perfil": "esqueleto", "escala": 1.0},
	&"tanque": {"ruta": RUTA_BARBARO, "tinte": Color(0.70, 0.70, 0.80), "perfil": "barbaro", "escala": 1.0},
	&"elite": {"ruta": RUTA_CABALLERO, "tinte": Color(1.0, 0.72, 0.66), "perfil": "caballero", "escala": 1.25},
	&"sabueso": {"ruta": RUTA_ESPECTRO, "tinte": Color(0.62, 0.32, 0.24), "perfil": "esqueleto", "escala": 0.82},
	&"bruto": {"ruta": RUTA_BARBARO, "tinte": Color(0.95, 0.62, 0.32), "perfil": "barbaro", "escala": 1.42},
	&"nigromante": {"ruta": RUTA_MAGO, "tinte": Color(0.42, 0.88, 0.46), "perfil": "mago", "escala": 1.05},
}


## Construye o reutiliza el modelo animado según el arquetipo.
func _configurar_visual(tipo: StringName) -> void:
	var datos: Dictionary = VISUALES.get(tipo, VISUALES[&"esqueleto"])
	var clave := String(tipo)
	var ruta: String = datos["ruta"]
	var tinte: Color = datos["tinte"]

	if visual != null and _tipo_visual == clave:
		visual.aplicar_skin(tinte)
		return
	if visual != null:
		visual.queue_free()
		visual = null
	visual = CharacterVisual.new()
	visual.name = "Visual"
	add_child(visual)
	visual.configurar(ruta, tinte, str(datos["perfil"]))
	_tipo_visual = clave


## Estadísticas base de un enemigo de oleada. El arquetipo y el perfil de la
## oleada (`BalanceOlas`) multiplican estos valores.
const VIDA_BASE := 66.0
const VIDA_POR_RONDA := 24.0
const DANO_BASE := 6.0
const DANO_POR_RONDA := 2.0

## Modificadores por arquetipo: vida, daño, movimiento y cadencia.
## `armadura` reduce el daño físico recibido (fracción); `ritual` activa el
## pulso de curación en área del nigromante.
const ARQUETIPOS := {
	&"esqueleto": {"vida": 1.00, "dano": 1.00, "vel": 1.00, "cadencia": 1.00, "escudo": false},
	&"espectro": {"vida": 0.75, "dano": 0.90, "vel": 1.30, "cadencia": 0.85, "escudo": false},
	&"arquero": {"vida": 0.70, "dano": 0.80, "vel": 0.90, "cadencia": 1.41, "escudo": false},
	&"hechicero": {"vida": 0.65, "dano": 1.25, "vel": 0.85, "cadencia": 1.10, "escudo": false},
	&"tanque": {"vida": 2.00, "dano": 1.40, "vel": 0.65, "cadencia": 1.35, "escudo": true},
	&"elite": {"vida": 2.40, "dano": 1.50, "vel": 1.00, "cadencia": 1.00, "escudo": false},
	&"sabueso": {"vida": 0.55, "dano": 0.75, "vel": 1.45, "cadencia": 0.70, "escudo": false},
	&"bruto": {"vida": 2.20, "dano": 1.55, "vel": 0.72, "cadencia": 1.28, "escudo": false, "armadura": 0.22},
	&"nigromante": {"vida": 0.95, "dano": 1.05, "vel": 0.82, "cadencia": 1.20, "escudo": false, "ritual": true},
}


func preparar(
	ronda: int,
	elite: bool,
	jugador: GladiatorController,
	bandera: Node3D,
	gestor: Node,
	pool: ObjectPool,
	xp: int = 0,
	tipo: StringName = &"",
	vida_mult: float = 1.0,
	dano_mult: float = 1.0
) -> void:
	es_elite = elite
	xp_recompensa = xp
	activo = true
	_jugador = jugador
	_bandera = bandera
	_gestor = gestor
	_pool = pool

	# Arquetipo: si no llega uno (red/legado) se sortea como antes.
	var arquetipo := tipo
	if arquetipo == &"" or not ARQUETIPOS.has(arquetipo):
		arquetipo = &"esqueleto"
	if tipo == &"":
		var tirada := randf()
		if tirada < 0.10:
			arquetipo = &"tanque"
		elif tirada < 0.22:
			arquetipo = &"hechicero"
		elif tirada < 0.40:
			arquetipo = &"arquero"
		elif tirada < 0.75:
			arquetipo = &"espectro"
	if elite:
		arquetipo = &"elite"

	var mods: Dictionary = ARQUETIPOS[arquetipo]
	es_ligero = arquetipo == &"espectro" or arquetipo == &"sabueso"
	es_arquero = arquetipo == &"arquero"
	es_hechicero = arquetipo == &"hechicero" or arquetipo == &"nigromante"
	es_tanque = arquetipo == &"tanque"
	es_sabueso = arquetipo == &"sabueso"
	es_bruto = arquetipo == &"bruto"
	es_nigromante = arquetipo == &"nigromante"
	_reduccion_fisica = float(mods.get("armadura", 0.0))
	_ritual_restante = 3.0 if es_nigromante else 0.0
	_escala_base = float(VISUALES.get(arquetipo, VISUALES[&"esqueleto"]).get("escala", 1.0))
	# +0,55 m por encima del modelo, en unidades locales (el nodo va escalado).
	_alto_barra = 1.95 + 0.55 / maxf(_escala_base, 0.01)
	_factor_barra = -1.0

	var factor_elite := 2.4 if elite else 1.0
	salud_maxima = (VIDA_BASE + ronda * VIDA_POR_RONDA) * factor_elite * vida_mult * float(mods["vida"])
	dano = (DANO_BASE + ronda * DANO_POR_RONDA) * (1.5 if elite else 1.0) * dano_mult * float(mods["dano"])
	# Los enemigos deben poder alcanzar a un gladiador que kitea: la base
	# queda por debajo de la velocidad del jugador y los espectros la superan.
	velocidad = (3.2 + minf(ronda * 0.05, 1.2)) * float(mods["vel"])
	cadencia = cadencia * float(mods["cadencia"])
	salud_actual = salud_maxima
	# La magia usa el daño del arquetipo como base (golpe en área más fuerte).
	dano_magia = dano * 1.15
	if mods["escudo"]:
		escudo_tanque_maxima = 60.0 + ronda * 6.0
		escudo_tanque_actual = escudo_tanque_maxima
	else:
		escudo_tanque_maxima = 0.0
		escudo_tanque_actual = 0.0
	recompensa = (12 + ronda) * (3 if elite else 1)
	_temporizador = randf_range(0.0, 0.5)
	_provocado = 0.0
	_fuente_provocacion = null
	_flash = 0.0
	_tiempo_muerte = 0.0
	_marca_verdugo = 0.0
	_vulnerable_magico = 0.0
	_aturdido = 0.0
	_configurar_visual(arquetipo)
	scale = Vector3.ONE * _escala_base
	if _barra_raiz != null:
		_barra_raiz.visible = false
	_actualizar_barra_vida()
	add_to_group(GRUPO)
	_aparecer()
	var tracker = get_tree().get_first_node_in_group("enemy_tracker")
	if tracker != null:
		tracker.registrar(self)


func al_obtener() -> void:
	activo = false
	_tiempo_muerte = 0.0
	_aturdido = 0.0
	if _barra_raiz != null:
		_barra_raiz.visible = false
	if visual != null:
		visual.revivir()


func al_devolver() -> void:
	activo = false
	velocity = Vector3.ZERO
	remove_from_group(GRUPO)


## Enemigo de solo lectura para clientes: sin IA, sin daño, sin pool.
func configurar_remoto(elite: bool, ligero := false) -> void:
	_es_remoto = true
	es_elite = elite
	es_ligero = ligero
	activo = true
	# Los espejos de red no traen arquetipo: el legado usa esqueleto/espectro.
	_configurar_visual(&"elite" if elite else (&"espectro" if ligero else &"esqueleto"))
	add_to_group(GRUPO)
	set_physics_process(false)


func aplicar_remoto(posicion: Vector3, rotacion: float, vida: float, vida_max: float) -> void:
	_pos_red = posicion
	_rot_red = rotacion
	global_position = posicion
	rotation.y = rotacion
	salud_maxima = maxf(1.0, vida_max)
	salud_actual = maxf(0.0, vida)
	activo = salud_actual > 0.0
	# Sin esto el espejo de red nunca pintaba la barra: el cliente veía enemigos
	# sin vida y no podía leer la oleada.
	_actualizar_barra_vida()


## Espejo de red: el servidor manda 15 posiciones por segundo; sin esto el
## enemigo avanza a saltos de ~1 m y en el móvil se siente trabado.
func _process(delta: float) -> void:
	_sincronizar_barra()
	if not _es_remoto:
		return
	var peso := clampf(16.0 * delta, 0.0, 1.0)
	global_position = global_position.lerp(_pos_red, peso)
	rotation.y = lerp_angle(rotation.y, _rot_red, peso)


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

	# Nigromante: ritual oscuro periódico que sostiene a la horda.
	if es_nigromante:
		_ritual_restante -= delta
		if _ritual_restante <= 0.0:
			_ritual_restante = 6.5
			_ritual_oscuro()

	# Arquero: mantener distancia y disparar proyectiles.
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
		else:
			velocity = Vector3.ZERO
			if visual != null:
				visual.mover(0.0)
			_tiempo_disparo -= delta
			if _tiempo_disparo <= 0.0:
				_tiempo_disparo = cadencia_disparo
				_disparar_proyectil(objetivo)
		return

	# Hechicero / nigromante: mantener distancia y lanzar magia de área.
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
			visual.ajustar_ritmo(1.7 / maxf(cadencia, 0.2))
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

	# Telegráfico: el área se marca en el suelo 0,45 s antes del impacto, así el
	# jugador puede salir del círculo. Sin esto, el mago golpeaba a ciegas y la
	# muerte parecía injusta (y en móvil, con el pulgar tapando el suelo, peor).
	var destino: Vector3 = objetivo.global_position
	_avisar_area(destino, radio_magia, Color(0.85, 0.35, 1.0, 0.55))
	Sfx.reproducir("magia", -10.0)
	await get_tree().create_timer(0.45).timeout
	if not is_instance_valid(self):
		return
	for nodo in get_tree().get_nodes_in_group("gladiadores"):
		var gladiador := nodo as Node3D
		if gladiador == null or not is_instance_valid(gladiador):
			continue
		if gladiador.global_position.distance_to(destino) <= radio_magia:
			if gladiador.has_method("recibir_dano"):
				gladiador.recibir_dano(dano_magia, GladiatorStats.TIPO_MAGICO, self)
	_explosion_aviso(destino, radio_magia, Color(0.8, 0.35, 1.0))


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
	# Bruto: la coraza recorta el daño físico, no el mágico.
	if _reduccion_fisica > 0.0 and tipo != GladiatorStats.TIPO_MAGICO:
		cantidad *= 1.0 - _reduccion_fisica

	# Tanque: el escudo absorbe daño primero
	if es_tanque and escudo_tanque_actual > 0.0:
		var absorbido := minf(escudo_tanque_actual, cantidad)
		escudo_tanque_actual -= absorbido
		cantidad -= absorbido
		NumerosDano.mostrar(global_position + Vector3(0, 1.8, 0), absorbido, GladiatorStats.TIPO_VERDADERO, false, true)
		if cantidad <= 0.0:
			_golpe_visual()
			_actualizar_barra_vida()
			Sfx.reproducir("escudo", -8.0)
			return

	salud_actual = maxf(0.0, salud_actual - cantidad)
	NumerosDano.mostrar(global_position + Vector3(0, 1.3, 0), cantidad, tipo, critico)
	_golpe_visual()
	_actualizar_barra_vida()

	if salud_actual <= 0.0:
		_morir()


func _morir() -> void:
	if not activo:
		return
	activo = false
	if _barra_raiz != null:
		_barra_raiz.visible = false
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


# --- Visibilidad: barra de vida, telegráficos y reacciones -----------------


## Aparición con rebote al salir del pool: sin esto los enemigos brotaban de
## golpe y en oleadas densas era imposible leer de dónde venía la presión.
func _aparecer() -> void:
	if not is_inside_tree():
		return
	scale = Vector3.ONE * (_escala_base * 0.72)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * _escala_base, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Golpe recibido: animación del modelo + pulso de escala corto (el `_flash`
## anterior solo guardaba un contador que nadie leía).
func _golpe_visual() -> void:
	if visual != null:
		visual.recibir_golpe()
	if _escala_base <= 0.0:
		return
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * (_escala_base * 1.09), 0.05)
	tween.tween_property(self, "scale", Vector3.ONE * _escala_base, 0.10)


func _barra_color() -> Color:
	if es_elite:
		return Color(1.0, 0.80, 0.30)
	if es_bruto:
		return Color(0.95, 0.55, 0.22)
	if es_tanque:
		return Color(0.55, 0.72, 1.0)
	if es_nigromante:
		return Color(0.42, 0.95, 0.52)
	if es_sabueso:
		return Color(0.92, 0.42, 0.28)
	if es_arquero:
		return Color(1.0, 0.52, 0.45)
	if es_hechicero:
		return Color(0.78, 0.48, 1.0)
	return Color(0.92, 0.35, 0.32)


func _material_barra(color: Color, prioridad := 0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Con decenas de enemigos, fondo y relleno quedaban a la misma profundidad y
	# el orden de dibujado era arbitrario: la placa negra tapaba el color y todas
	# las barras se veían como rectángulos negros. Con prioridad fija y sin test
	# de profundidad el relleno siempre va encima y se lee a cualquier distancia.
	material.no_depth_test = true
	material.render_priority = prioridad
	return material


func _construir_barra() -> void:
	if _barra_raiz != null:
		return
	var raiz := Node3D.new()
	raiz.name = "BarraVida"
	raiz.position = Vector3(0, _alto_barra, 0)
	add_child(raiz)
	_barra_raiz = raiz

	# Una sola barra, sin placa negra detrás: el fondo oscuro se comía el relleno
	# en cuanto había enemigos (se veían rectángulos negros). La fracción se lee
	# por el ancho y por el color (verdoso arriba, rojo al borde de la muerte).
	var cuadro := QuadMesh.new()
	cuadro.size = Vector2(1.15, 0.18)

	var relleno := MeshInstance3D.new()
	relleno.mesh = cuadro
	relleno.material_override = _material_barra(_barra_color(), 1)
	raiz.add_child(relleno)
	_barra_relleno = relleno
	_barra_fondo = null


## Siempre visible mientras el enemigo esté vivo: con la oleada llena, el
## jugador necesita leer de un vistazo cuánta vida le queda a cada uno.
func _barra_visible(_frac: float) -> bool:
	return true


func _actualizar_barra_vida() -> void:
	if _barra_raiz == null:
		_construir_barra()
	var frac := clampf(salud_actual / maxf(1.0, salud_maxima), 0.0, 1.0)
	if _barra_relleno != null:
		_barra_relleno.scale.x = maxf(0.02, frac)
		_barra_relleno.position.x = -(1.0 - frac) * 0.575
		var material := _barra_relleno.material_override as StandardMaterial3D
		if material != null:
			# Color por arquetipo, pero virando a rojo cuando queda poca vida.
			var base := _barra_color()
			material.albedo_color = base.lerp(Color(1.0, 0.22, 0.18), clampf(1.0 - frac * 2.2, 0.0, 1.0))
	_barra_raiz.visible = activo and _barra_visible(frac)


## El enemigo se escala por arquetipo (bruto 1.42, sabueso 0.82): el cuadro se
## contrarresta para que todos midan lo mismo en pantalla, pero la altura NO se
## divide: `_alto_barra` ya está en unidades locales, y dividirla dejaba la barra
## del bruto dentro de la cabeza (era el único que no la mostraba).
func _sincronizar_barra() -> void:
	if _barra_raiz == null:
		return
	var factor := maxf(scale.x, 0.01)
	if is_equal_approx(factor, _factor_barra):
		return
	_factor_barra = factor
	_barra_raiz.scale = Vector3.ONE / factor
	_barra_raiz.position = Vector3(0, _alto_barra, 0)


## Nigromante: cura un 12 % de la vida máxima a los enemigos en 6 m.
func _ritual_oscuro() -> void:
	var curados := 0
	for nodo in get_tree().get_nodes_in_group(GRUPO):
		var otro := nodo as ArenaEnemy
		if otro == null or otro == self or not is_instance_valid(otro) or not otro.activo:
			continue
		if otro.global_position.distance_to(global_position) > 6.0:
			continue
		if otro.salud_actual >= otro.salud_maxima:
			continue
		var curacion := otro.salud_maxima * 0.12
		otro.salud_actual = minf(otro.salud_maxima, otro.salud_actual + curacion)
		otro._actualizar_barra_vida()
		NumerosDano.mostrar(
			otro.global_position + Vector3(0, 1.5, 0), curacion,
			GladiatorStats.TIPO_VERDADERO, false, true
		)
		curados += 1
	_marca_suelo(Color(0.35, 0.95, 0.45), 6.0, 0.65)
	if curados > 0:
		Sfx.reproducir("magia", -12.0)


## Marca un círculo en el suelo (aviso de área). Se ancla al mundo, no al mago,
## para que no se mueva si el lanzador retrocede mientras carga.
func _marca_suelo(color: Color, radio: float, duracion: float) -> void:
	var padre := get_parent()
	if padre == null:
		return
	var ancla := Node3D.new()
	padre.add_child(ancla)
	ancla.global_position = Vector3(global_position.x, 0.07, global_position.z)

	var disco := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = radio
	cilindro.bottom_radius = radio
	cilindro.height = 0.02
	cilindro.radial_segments = 28
	disco.mesh = cilindro
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.28)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.2
	disco.material_override = material
	ancla.add_child(disco)

	var borde := MeshInstance3D.new()
	var aro := TorusMesh.new()
	aro.inner_radius = maxf(0.05, radio - 0.10)
	aro.outer_radius = radio
	aro.rings = 32
	aro.ring_segments = 6
	borde.mesh = aro
	borde.material_override = material
	ancla.add_child(borde)

	var tween := ancla.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, duracion)
	tween.tween_callback(ancla.queue_free)


## Aviso previo al impacto mágico.
func _avisar_area(destino: Vector3, radio: float, color: Color) -> void:
	var padre := get_parent()
	if padre == null:
		return
	var ancla := Node3D.new()
	padre.add_child(ancla)
	ancla.global_position = Vector3(destino.x, 0.07, destino.z)

	var disco := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = radio
	cilindro.bottom_radius = radio
	cilindro.height = 0.02
	cilindro.radial_segments = 28
	disco.mesh = cilindro
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 1.8
	disco.material_override = material
	disco.scale = Vector3(0.35, 1.0, 0.35)
	ancla.add_child(disco)

	var tween := ancla.create_tween()
	tween.set_parallel(true)
	tween.tween_property(disco, "scale", Vector3.ONE, 0.40).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.10, 0.40)
	tween.chain().tween_callback(ancla.queue_free)


## Destello del impacto real, para que el área se lea también al recibir.
func _explosion_aviso(destino: Vector3, radio: float, color: Color) -> void:
	var padre := get_parent()
	if padre == null:
		return
	var ancla := Node3D.new()
	padre.add_child(ancla)
	ancla.global_position = Vector3(destino.x, 0.09, destino.z)
	var borde := MeshInstance3D.new()
	var aro := TorusMesh.new()
	aro.inner_radius = 0.85
	aro.outer_radius = 1.0
	aro.rings = 32
	aro.ring_segments = 6
	borde.mesh = aro
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	borde.material_override = material
	ancla.add_child(borde)
	var tween := ancla.create_tween()
	tween.set_parallel(true)
	tween.tween_property(borde, "scale", Vector3(radio, 1.0, radio), 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(ancla.queue_free)
