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
var activo := false
var salud_maxima := 30.0
var salud_actual := 0.0
var dano := 5.0
var velocidad := 2.5
var rango := 2.2
var cadencia := 1.5
var recompensa := 8
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
	pool: ObjectPool
) -> void:
	es_elite = elite
	activo = true
	_jugador = jugador
	_bandera = bandera
	_gestor = gestor
	_pool = pool

	var factor_elite := 2.4 if elite else 1.0
	var ligero := not elite and randf() < 0.35
	salud_maxima = (26.0 + ronda * 10.0) * factor_elite
	dano = (4.0 + ronda * 1.5) * (1.5 if elite else 1.0)
	velocidad = 2.3 + minf(ronda * 0.04, 0.9)
	if ligero:
		salud_maxima *= 0.85
		velocidad *= 1.12
	salud_actual = salud_maxima
	recompensa = (8 + ronda) * (3 if elite else 1)
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


func al_obtener() -> void:
	activo = false
	_tiempo_muerte = 0.0
	if visual != null:
		visual.revivir()


func al_devolver() -> void:
	activo = false
	velocity = Vector3.ZERO
	remove_from_group(GRUPO)


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
	remove_from_group(GRUPO)
	if visual != null:
		visual.morir()
	Sfx.reproducir("enemigo", -9.0)
	_tiempo_muerte = 1.1
	murio.emit(recompensa)
	if _gestor != null and is_instance_valid(_gestor) and _gestor.has_method("al_morir_enemigo"):
		_gestor.al_morir_enemigo(recompensa)
