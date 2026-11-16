class_name EnemyBase
extends CharacterBody3D
## Base de los enemigos con NavigationAgent3D sobre el NavigationRegion3D de la
## arena. Mantiene el agente y el destino en caché: actualizar `target_position`
## cada frame para decenas de enemigos es el pico clásico de navegación en Web.
##
## `ArenaEnemy` hereda de aquí y conserva toda su IA de arquetipos.

var agente: NavigationAgent3D
var _destino_nav := Vector3.INF
var _reloj_nav := 0.0
var _intervalo_nav := 0.25
var usa_navegacion := true


func _ready() -> void:
	agente = NavigationAgent3D.new()
	agente.name = "NavigationAgent3D"
	agente.path_desired_distance = 0.5
	agente.target_desired_distance = 0.9
	agente.avoidance_enabled = false
	add_child(agente)
	# Reparto aleatorio de la primera actualización: no todos los agentes piden
	# camino en el mismo fotograma.
	_reloj_nav = randf() * _intervalo_nav


## Dirección normalizada en el plano XZ hacia `destino`. Si la navegación aún
## no tiene camino (o está desactivada) cae a la persecución directa de siempre.
func direccion_hacia(destino: Vector3, delta: float) -> Vector3:
	var directa := destino - global_position
	directa.y = 0.0
	if directa.length_squared() < 0.0004:
		return Vector3.ZERO
	directa = directa.normalized()
	if not usa_navegacion or agente == null:
		return directa

	_reloj_nav -= delta
	if _reloj_nav <= 0.0 or destino.distance_squared_to(_destino_nav) > 1.0:
		agente.target_position = destino
		_destino_nav = destino
		_reloj_nav = _intervalo_nav

	if not agente.is_navigation_finished():
		var siguiente := agente.get_next_path_position()
		var navegada := siguiente - global_position
		navegada.y = 0.0
		if navegada.length_squared() > 0.0004:
			return navegada.normalized()
	return directa


func reiniciar_navegacion() -> void:
	_destino_nav = Vector3.INF
	_reloj_nav = 0.0
	if agente != null:
		agente.target_position = global_position
