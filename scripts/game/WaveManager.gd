class_name WaveManager
extends Node
## Bucle de 20 oleadas con jefes cada 5. Los enemigos salen de los portones y
## atacan el estandarte central; el jugador debe rotar para defenderlo.
##
## Los enemigos se sirven desde ObjectPool; el jefe se instancia una vez por
## oleada de jefe (es singular y su coste es despreciable).

signal oleada_iniciada(numero: int, total: int)
signal oleada_terminada(numero: int)
signal oro_ganado(cantidad: int)
signal mensaje(texto: String, duracion: float)
signal victoria

enum Estado { ESPERA, COMBATE, FIN }

@export var total_oleadas := 20
@export var espera_inicial := 8.0
@export var espera_entre_oleadas := 6.0
@export var intervalo_spawn := 0.45
@export var oleadas_con_jefe := 5

var oleada_actual := 0

var _estado: Estado = Estado.FIN
var _pendientes := 0
var _temporizador := 0.0
var _pool: ObjectPool
var _jugador: GladiatorController
var _bandera: Node3D
var _contenedor: Node3D
var _puntos_spawn: Array[Vector3] = []


func _ready() -> void:
	set_process(false)


func iniciar(
	jugador: GladiatorController,
	bandera: Node3D,
	puntos_spawn: Array[Vector3],
	contenedor: Node3D
) -> void:
	_jugador = jugador
	_bandera = bandera
	_puntos_spawn = puntos_spawn
	_contenedor = contenedor

	_pool = ObjectPool.new(Callable(ArenaEnemy, "crear"))
	add_child(_pool)
	_pool.precalentar(24)

	_estado = Estado.ESPERA
	_temporizador = espera_inicial
	set_process(true)
	mensaje.emit("La arena despierta. Defiende el estandarte.", 4.0)


func enemigos_restantes() -> int:
	return _pendientes + get_tree().get_nodes_in_group("enemigos").size()


func _process(delta: float) -> void:
	match _estado:
		Estado.ESPERA:
			_temporizador -= delta
			if _temporizador <= 0.0:
				_iniciar_oleada()
		Estado.COMBATE:
			_procesar_combate(delta)


func _procesar_combate(delta: float) -> void:
	if _pendientes > 0:
		_temporizador -= delta
		if _temporizador <= 0.0:
			_temporizador = intervalo_spawn
			_invocar_enemigo()
			_pendientes -= 1

	if _pendientes == 0 and get_tree().get_nodes_in_group("enemigos").is_empty():
		_terminar_oleada()


func _iniciar_oleada() -> void:
	oleada_actual += 1
	_pendientes = 5 + oleada_actual * 2
	_estado = Estado.COMBATE
	_temporizador = 0.0

	oleada_iniciada.emit(oleada_actual, total_oleadas)
	mensaje.emit("Oleada %d / %d" % [oleada_actual, total_oleadas], 2.5)

	if oleada_actual % oleadas_con_jefe == 0:
		_invocar_jefe()


func _terminar_oleada() -> void:
	oleada_terminada.emit(oleada_actual)
	if oleada_actual >= total_oleadas:
		_estado = Estado.FIN
		set_process(false)
		victoria.emit()
		return

	_estado = Estado.ESPERA
	_temporizador = espera_entre_oleadas
	mensaje.emit("Oleada superada. Reagrupa y gasta puntos.", 3.0)


func _invocar_enemigo() -> void:
	if _puntos_spawn.is_empty():
		return

	var enemigo := _pool.obtener() as ArenaEnemy
	if enemigo == null:
		return

	var punto := _puntos_spawn[randi() % _puntos_spawn.size()]
	punto += Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
	enemigo.global_position = punto
	enemigo.preparar(
		oleada_actual,
		randf() < _probabilidad_elite(),
		_jugador,
		_bandera,
		self,
		_pool
	)


func _invocar_jefe() -> void:
	var lich := oleada_actual % 10 == 0
	var jefe := ArenaBossAI.crear(
		"res://assets/kaykit/skeletons/Skeleton_Mage.glb" if lich else "",
		Color(0.55, 0.95, 0.72) if lich else Color.TRANSPARENT,
		1.5 if lich else 0.0,
		"mago" if lich else "caballero"
	)
	jefe.configurar_para_ronda(oleada_actual)
	_contenedor.add_child(jefe)

	var punto := _puntos_spawn[randi() % _puntos_spawn.size()]
	jefe.global_position = punto + Vector3(0, 0, 2.5)
	jefe.objetivo = _jugador
	jefe.murio.connect(_al_morir_jefe)

	mensaje.emit("¡El Liche de la Arena despierta!" if lich else "¡Un campeón del Imperio entra en la arena!", 3.0)


func _probabilidad_elite() -> float:
	return clampf((oleada_actual - 3) * 0.04, 0.0, 0.22)


func al_morir_enemigo(oro: int) -> void:
	oro_ganado.emit(oro)


func _al_morir_jefe() -> void:
	oro_ganado.emit(120 + oleada_actual * 20)
	mensaje.emit("¡Campeón del Imperio derrotado!", 3.0)
