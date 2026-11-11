class_name ArenaBossAI
extends CharacterBody3D
## Jefe de facción con máquina de estados y sistema Enrage.
##
## Fases (una sola vez cada una, según salud restante):
## - 75 %: Furia 1 -> +20 % velocidad y rugido que interrumpe el ataque.
## - 50 %: Furia 2 -> inmune a aturdimientos y cambia a ataques en área.
##
## La escena del jefe debe incluir un NavigationAgent3D hijo y estar sobre la
## malla de navegación de la arena. Hereda de CharacterBody3D y se mueve en XZ.

signal estado_cambiado(estado: int)
signal furia_activada(nivel: int)
signal salud_cambiada(actual: float, maxima: float)
signal ataque_ejecutado(tipo: StringName)
signal murio

enum Estado {
	INACTIVO,   ## Sin objetivo válido: espera.
	PERSEGUIR,  ## Se acerca al gladiador más cercano.
	ATACAR,     ## En rango: golpea con la cadencia actual.
	FURIA,      ## Rugido de transición de fase (breve).
	ATURDIDO,   ## Control de masas recibido.
	MUERTO,
}

@export_group("Combate")
@export var salud_maxima := 1200.0
@export var dano_ataque := 35.0
@export var cadencia_ataque := 1.6
@export var rango_ataque := 2.4
@export var velocidad_base := 3.2
@export var multiplicador_velocidad_furia := 1.20

@export_group("Fase Enrage")
@export_range(0.1, 0.99, 0.01) var umbral_furia_1 := 0.75
@export_range(0.1, 0.99, 0.01) var umbral_furia_2 := 0.50
@export var duracion_rugido := 1.2
@export var duracion_aturdimiento_maxima := 1.5

@export_group("Ataque en área (Furia 2)")
@export var radio_ataque_area := 6.0
@export var dano_area := 55.0
@export var cooldown_ataque_area := 8.0

@export_group("Objetivo")
@export var objetivo: Node3D

var salud_actual := 0.0
var estado: Estado = Estado.INACTIVO
var nivel_furia := 0
var inmune_aturdimiento := false
var usa_ataques_area := false
var multiplicador_velocidad := 1.0

var _temporizador_ataque := 0.0
var _temporizador_estado := 0.0
var _cooldown_area_actual := 0.0
var _ultimo_destino := Vector3.INF

@onready var agente := $NavigationAgent3D as NavigationAgent3D


func _ready() -> void:
	add_to_group("enemigos")
	salud_actual = salud_maxima
	agente.path_desired_distance = 0.8
	agente.target_desired_distance = rango_ataque * 0.5
	if not _objetivo_valido():
		_elegir_objetivo()


func _physics_process(delta: float) -> void:
	if estado == Estado.MUERTO:
		return

	_actualizar_temporizadores(delta)

	if not _objetivo_valido():
		_elegir_objetivo()
		if objetivo == null:
			_cambiar_estado(Estado.INACTIVO)
			velocity = Vector3.ZERO
			return

	# Solo se recalcula la ruta si el objetivo se ha movido de verdad: en Web
	# cada consulta a NavigationServer3D cuesta y el jefe no necesita precisión
	# de centímetros.
	if _ultimo_destino.distance_squared_to(objetivo.global_position) > 0.25:
		_ultimo_destino = objetivo.global_position
		agente.target_position = _ultimo_destino

	var deseada := Vector3.ZERO

	match estado:
		Estado.INACTIVO:
			_cambiar_estado(Estado.PERSEGUIR)
		Estado.PERSEGUIR:
			deseada = _procesar_persecucion(delta)
		Estado.ATACAR:
			_procesar_ataque(delta)
		Estado.FURIA:
			_procesar_rugido(delta)
		Estado.ATURDIDO:
			_procesar_aturdimiento(delta)
		_:
			deseada = Vector3.ZERO

	velocity = velocity.move_toward(deseada, 24.0 * delta)
	velocity.y = 0.0
	move_and_slide()


# --- Estados --------------------------------------------------------------

func _procesar_persecucion(delta: float) -> Vector3:
	if _distancia_al_objetivo() <= rango_ataque:
		_cambiar_estado(Estado.ATACAR)
		return Vector3.ZERO

	if agente.is_navigation_finished():
		return Vector3.ZERO

	var siguiente := agente.get_next_path_position()
	var direccion := siguiente - global_position
	direccion.y = 0.0
	if direccion.length_squared() < 0.0004:
		return Vector3.ZERO

	direccion = direccion.normalized()
	_orientar(direccion, delta)
	return direccion * velocidad_base * multiplicador_velocidad


func _procesar_ataque(delta: float) -> void:
	if _distancia_al_objetivo() > rango_ataque * 1.15:
		_cambiar_estado(Estado.PERSEGUIR)
		return

	_orientar(_direccion_al_objetivo(), delta)
	_temporizador_ataque = maxf(0.0, _temporizador_ataque - delta)
	if _temporizador_ataque > 0.0:
		return

	_temporizador_ataque = cadencia_ataque
	if usa_ataques_area and _cooldown_area_actual <= 0.0:
		_atacar_area()
	else:
		_atacar_cuerpo()


func _procesar_rugido(delta: float) -> void:
	_temporizador_estado -= delta
	if _temporizador_estado <= 0.0:
		_cambiar_estado(Estado.PERSEGUIR)


func _procesar_aturdimiento(delta: float) -> void:
	_temporizador_estado -= delta
	if _temporizador_estado <= 0.0:
		_cambiar_estado(Estado.PERSEGUIR)


func _cambiar_estado(nuevo: Estado) -> void:
	if estado == nuevo:
		return
	estado = nuevo
	_temporizador_estado = 0.0

	match nuevo:
		Estado.FURIA:
			_temporizador_estado = duracion_rugido
			velocity = Vector3.ZERO
		Estado.ATACAR:
			_temporizador_ataque = 0.35

	estado_cambiado.emit(estado)


# --- Ataques --------------------------------------------------------------

func _atacar_cuerpo() -> void:
	if not _objetivo_valido():
		return
	ataque_ejecutado.emit(&"cuerpo")
	if objetivo.has_method("recibir_dano"):
		objetivo.recibir_dano(dano_ataque, &"fisico", self)


func _atacar_area() -> void:
	_cooldown_area_actual = cooldown_ataque_area
	ataque_ejecutado.emit(&"area")

	for nodo in get_tree().get_nodes_in_group("gladiadores"):
		var cuerpo := nodo as Node3D
		if cuerpo == null:
			continue
		if cuerpo.global_position.distance_to(global_position) > radio_ataque_area:
			continue
		if cuerpo.has_method("recibir_dano"):
			cuerpo.recibir_dano(dano_area, &"fisico", self)


# --- Enrage ---------------------------------------------------------------

func _verificar_fases() -> void:
	var proporcion := salud_actual / maxf(1.0, salud_maxima)

	if nivel_furia < 1 and proporcion <= umbral_furia_1:
		_activar_furia(1)
	if nivel_furia < 2 and proporcion <= umbral_furia_2:
		_activar_furia(2)


func _activar_furia(nivel: int) -> void:
	nivel_furia = nivel

	if nivel == 1:
		multiplicador_velocidad = multiplicador_velocidad_furia
	elif nivel == 2:
		inmune_aturdimiento = true
		usa_ataques_area = true
		_interrumpir_aturdimiento()

	_cambiar_estado(Estado.FURIA)
	furia_activada.emit(nivel)


func aplicar_aturdimiento(duracion: float) -> void:
	if estado == Estado.MUERTO or duracion <= 0.0 or inmune_aturdimiento:
		return
	_cambiar_estado(Estado.ATURDIDO)
	_temporizador_estado = minf(duracion, duracion_aturdimiento_maxima)
	velocity = Vector3.ZERO


func _interrumpir_aturdimiento() -> void:
	if estado == Estado.ATURDIDO:
		_temporizador_estado = 0.0


# --- Daño y muerte --------------------------------------------------------

func recibir_dano(cantidad: float, _tipo: StringName = &"fisico", _fuente: Node = null) -> void:
	if estado == Estado.MUERTO or cantidad <= 0.0:
		return

	salud_actual = maxf(0.0, salud_actual - cantidad)
	salud_cambiada.emit(salud_actual, salud_maxima)

	if salud_actual <= 0.0:
		_morir()
		return

	_verificar_fases()


func _morir() -> void:
	if estado == Estado.MUERTO:
		return
	_cambiar_estado(Estado.MUERTO)
	velocity = Vector3.ZERO
	remove_from_group("enemigos")
	set_physics_process(false)
	murio.emit()


# --- Soporte --------------------------------------------------------------

## Escala el jefe para una oleada del 1 al 20. Llama antes de mostrarlo.
func configurar_para_ronda(ronda: int) -> void:
	var factor := 1.0 + 0.12 * maxf(0.0, float(ronda - 1))
	salud_maxima *= factor
	dano_ataque *= factor
	dano_area *= factor

	salud_actual = salud_maxima
	nivel_furia = 0
	inmune_aturdimiento = false
	usa_ataques_area = false
	multiplicador_velocidad = 1.0
	_cambiar_estado(Estado.INACTIVO)
	salud_cambiada.emit(salud_actual, salud_maxima)


func _elegir_objetivo() -> void:
	var mejor: Node3D = null
	var mejor_distancia := INF

	for nodo in get_tree().get_nodes_in_group("gladiadores"):
		var cuerpo := nodo as Node3D
		if cuerpo == null:
			continue
		var distancia := global_position.distance_squared_to(cuerpo.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = cuerpo

	objetivo = mejor


func _objetivo_valido() -> bool:
	if objetivo == null or not is_instance_valid(objetivo):
		return false
	if not objetivo.is_inside_tree():
		return false
	var muerto = objetivo.get("esta_muerto")
	if muerto is bool and muerto:
		return false
	return true


func _distancia_al_objetivo() -> float:
	return global_position.distance_to(objetivo.global_position)


func _direccion_al_objetivo() -> Vector3:
	var direccion := objetivo.global_position - global_position
	direccion.y = 0.0
	return direccion.normalized()


func _orientar(direccion: Vector3, delta: float) -> void:
	if direccion.length_squared() < 0.0004:
		return
	var angulo := atan2(direccion.x, direccion.z)
	rotation.y = lerp_angle(rotation.y, angulo, 10.0 * delta)


func _actualizar_temporizadores(delta: float) -> void:
	_cooldown_area_actual = maxf(0.0, _cooldown_area_actual - delta)


# --- Construcción programática -------------------------------------------

## Fábrica del jefe con malla y colisión, para prototipar sin escena .tscn.
static func crear() -> ArenaBossAI:
	var jefe := ArenaBossAI.new()
	jefe._construir_visual()
	return jefe


func _construir_visual() -> void:
	collision_layer = 2
	collision_mask = 0

	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.8
	capsula.height = 2.6
	forma.shape = capsula
	forma.position.y = 1.3
	add_child(forma)

	var cuerpo := MeshInstance3D.new()
	var malla := CapsuleMesh.new()
	malla.radius = 0.8
	malla.height = 2.6
	cuerpo.mesh = malla
	cuerpo.position.y = 1.3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.10, 0.10)
	material.roughness = 0.8
	cuerpo.material_override = material
	add_child(cuerpo)

	var hombreras := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(1.9, 0.35, 0.7)
	hombreras.mesh = caja
	hombreras.position.y = 2.45
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.55, 0.45, 0.20)
	metal.metallic = 0.7
	hombreras.material_override = metal
	add_child(hombreras)

	var ojo := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.14
	esfera.height = 0.28
	ojo.mesh = esfera
	ojo.position = Vector3(0.3, 2.75, 0.55)
	var brillo := StandardMaterial3D.new()
	brillo.albedo_color = Color(1.0, 0.25, 0.05)
	brillo.emission_enabled = true
	brillo.emission = Color(1.0, 0.25, 0.05)
	brillo.emission_energy_multiplier = 3.0
	ojo.material_override = brillo
	add_child(ojo)

	var agente_nav := NavigationAgent3D.new()
	agente_nav.name = "NavigationAgent3D"
	add_child(agente_nav)
