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

var es_elite := false
var activo := false
var salud_maxima := 30.0
var salud_actual := 0.0
var dano := 5.0
var velocidad := 2.5
var rango := 2.2
var cadencia := 1.5
var recompensa := 8

var _jugador: GladiatorController
var _bandera: Node3D
var _gestor: Node
var _pool: ObjectPool
var _fuente_provocacion: Node3D
var _provocado := 0.0
var _temporizador := 0.0
var _flash := 0.0
var _material: StandardMaterial3D
var _color_base := Color(0.52, 0.20, 0.18)


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

	_material = StandardMaterial3D.new()
	_material.albedo_color = _color_base
	_material.roughness = 0.9

	var cuerpo := MeshInstance3D.new()
	var malla := CapsuleMesh.new()
	malla.radius = 0.45
	malla.height = 1.5
	cuerpo.mesh = malla
	cuerpo.position.y = 0.75
	cuerpo.material_override = _material
	add_child(cuerpo)

	var cabeza := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.28
	esfera.height = 0.56
	cabeza.mesh = esfera
	cabeza.position = Vector3(0, 1.55, 0.08)
	var piel := StandardMaterial3D.new()
	piel.albedo_color = Color(0.66, 0.55, 0.44)
	piel.roughness = 0.85
	cabeza.material_override = piel
	add_child(cabeza)

	var arma := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.08, 0.08, 1.1)
	arma.mesh = caja
	arma.position = Vector3(0.42, 1.0, 0.35)
	var acero := StandardMaterial3D.new()
	acero.albedo_color = Color(0.62, 0.62, 0.66)
	acero.metallic = 0.6
	arma.material_override = acero
	add_child(arma)


func preparar(
	ronda: int,
	elite: bool,
	jugador: GladiatorController,
	bandera: Node3D,
	gestor: Node,
	pool: ObjectPool
) -> void:
	es_elite = elite
	activo = true
	_jugador = jugador
	_bandera = bandera
	_gestor = gestor
	_pool = pool

	var factor_elite := 2.4 if elite else 1.0
	salud_maxima = (26.0 + ronda * 10.0) * factor_elite
	salud_actual = salud_maxima
	dano = (4.0 + ronda * 1.5) * (1.5 if elite else 1.0)
	velocidad = 2.3 + minf(ronda * 0.04, 0.9)
	recompensa = (8 + ronda) * (3 if elite else 1)
	_temporizador = randf_range(0.0, 0.5)
	_provocado = 0.0
	_fuente_provocacion = null
	_flash = 0.0
	_color_base = Color(0.62, 0.22, 0.12) if elite else Color(0.52, 0.20, 0.18)
	_material.albedo_color = _color_base
	scale = Vector3.ONE * (1.25 if elite else 1.0)
	add_to_group(GRUPO)


func al_obtener() -> void:
	activo = false


func al_devolver() -> void:
	activo = false
	velocity = Vector3.ZERO
	remove_from_group(GRUPO)


func _physics_process(delta: float) -> void:
	if not activo:
		return

	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_material.albedo_color = _color_base
	if _provocado > 0.0:
		_provocado -= delta

	var objetivo := _elegir_objetivo()
	if objetivo == null:
		return

	var distancia := global_position.distance_to(objetivo.global_position)
	if distancia > rango:
		var direccion := objetivo.global_position - global_position
		direccion.y = 0.0
		if direccion.length_squared() > 0.0004:
			direccion = direccion.normalized()
			velocity = direccion * velocidad
			rotation.y = lerp_angle(rotation.y, atan2(direccion.x, direccion.z), 10.0 * delta)
			move_and_slide()
		return

	velocity = Vector3.ZERO
	_temporizador -= delta
	if _temporizador <= 0.0:
		_temporizador = cadencia
		if objetivo.has_method("recibir_dano"):
			objetivo.recibir_dano(dano, &"fisico", self)


func _elegir_objetivo() -> Node3D:
	if _provocado > 0.0 and is_instance_valid(_fuente_provocacion):
		return _fuente_provocacion

	if _jugador != null and is_instance_valid(_jugador) and not _jugador.esta_muerto:
		if global_position.distance_to(_jugador.global_position) < 5.5:
			return _jugador

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


func recibir_dano(cantidad: float, _tipo: StringName = &"fisico", _fuente: Node = null) -> void:
	if not activo or cantidad <= 0.0:
		return

	salud_actual = maxf(0.0, salud_actual - cantidad)
	_flash = 0.08
	_material.albedo_color = Color(1.0, 0.95, 0.85)

	if salud_actual <= 0.0:
		_morir()


func _morir() -> void:
	if not activo:
		return
	activo = false
	murio.emit(recompensa)
	if _gestor != null and is_instance_valid(_gestor) and _gestor.has_method("al_morir_enemigo"):
		_gestor.al_morir_enemigo(recompensa)
	if _pool != null:
		_pool.devolver(self)
