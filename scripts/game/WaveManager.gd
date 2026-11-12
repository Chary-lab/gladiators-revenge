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
signal preparacion_iniciada(duracion: float)
signal entrada_iniciada(duracion: float)
signal entrada_terminada
signal victoria
signal jefe_invocado(jefe: ArenaBossAI)

enum Estado { ESPERA, ENTRADA, COMBATE, FIN }

@export var total_oleadas := 20
@export var espera_inicial := 30.0
@export var espera_entre_oleadas := 30.0
@export var duracion_entrada := 8.0
@export var intervalo_spawn := 0.45
@export var oleadas_con_jefe := 5

var oleada_actual := 0

var _estado: Estado = Estado.FIN
var _pendientes := 0
var _temporizador := 0.0
var _pool: ObjectPool
var _jugador: GladiatorController
var _jugadores: Array[GladiatorController] = []
var _bandera: Node3D
var _contenedor: Node3D
var _puntos_spawn: Array[Vector3] = []
var _xp_presupuesto := 0
var _xp_peso_total := 0.0
var _xp_jefe := 0


func _ready() -> void:
	set_process(false)


func iniciar(
	jugadores,
	bandera: Node3D,
	puntos_spawn: Array[Vector3],
	contenedor: Node3D
) -> void:
	_jugadores.clear()
	if jugadores is Array:
		for jugador in jugadores:
			if jugador is GladiatorController:
				_jugadores.append(jugador)
	elif jugadores is GladiatorController:
		_jugadores.append(jugadores)
	_jugador = _jugadores[0] if not _jugadores.is_empty() else null
	_bandera = bandera
	_puntos_spawn = puntos_spawn
	_contenedor = contenedor

	_pool = ObjectPool.new(Callable(ArenaEnemy, "crear"))
	add_child(_pool)
	_pool.precalentar(24)

	_estado = Estado.ESPERA
	_temporizador = espera_inicial
	set_process(true)
	preparacion_iniciada.emit(espera_inicial)
	mensaje.emit("Preparación: compra, forja y elige talentos. La arena abre en 30 s.", 5.0)


func enemigos_restantes() -> int:
	return _pendientes + get_tree().get_nodes_in_group("enemigos").size()


func agregar_jugador(jugador: GladiatorController) -> void:
	if jugador == null or _jugadores.has(jugador):
		return
	_jugadores.append(jugador)
	if _jugador == null:
		_jugador = jugador


func quitar_jugador(jugador: GladiatorController) -> void:
	_jugadores.erase(jugador)
	if _jugador == jugador:
		_jugador = _jugadores[0] if not _jugadores.is_empty() else null


func _process(delta: float) -> void:
	match _estado:
		Estado.ESPERA:
			_temporizador -= delta
			if _temporizador <= 0.0:
				_iniciar_oleada()
		Estado.ENTRADA:
			_temporizador -= delta
			if _temporizador <= 0.0:
				_comenzar_combate()
		Estado.COMBATE:
			_procesar_combate(delta)


func en_combate() -> bool:
	return _estado == Estado.COMBATE


func en_entrada() -> bool:
	return _estado == Estado.ENTRADA


func tiempo_restante() -> float:
	if _estado == Estado.ESPERA or _estado == Estado.ENTRADA:
		return maxf(0.0, _temporizador)
	return 0.0


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
	_estado = Estado.ENTRADA
	_temporizador = duracion_entrada
	entrada_iniciada.emit(duracion_entrada)
	mensaje.emit("¡Portones abiertos! Entra a la arena: %d s" % int(duracion_entrada), 3.0)


func _comenzar_combate() -> void:
	_pendientes = 5 + oleada_actual * 2
	_estado = Estado.COMBATE
	_temporizador = 0.0

	_xp_presupuesto = CurvaNivel.xp_oleada(oleada_actual)
	var jefe := oleada_actual % oleadas_con_jefe == 0
	var elite_estimados := int(round(float(_pendientes) * _probabilidad_elite()))
	var normales := _pendientes - elite_estimados
	_xp_peso_total = float(normales) + float(elite_estimados) * CurvaNivel.PESO_ELITE
	if jefe:
		_xp_peso_total += CurvaNivel.PESO_JEFE
	_xp_jefe = CurvaNivel.xp_enemigo(_xp_presupuesto, CurvaNivel.PESO_JEFE, _xp_peso_total) if jefe else 0

	entrada_terminada.emit()
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
	preparacion_iniciada.emit(espera_entre_oleadas)
	mensaje.emit("Oleada superada. 30 s para comprar, forjar y subir habilidades.", 4.0)


func _invocar_enemigo() -> void:
	if _puntos_spawn.is_empty():
		return

	var enemigo := _pool.obtener() as ArenaEnemy
	if enemigo == null:
		return

	var punto := _puntos_spawn[randi() % _puntos_spawn.size()]
	punto += Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
	enemigo.global_position = punto
	var elite := randf() < _probabilidad_elite()
	var peso := CurvaNivel.PESO_ELITE if elite else CurvaNivel.PESO_NORMAL
	var xp := CurvaNivel.xp_enemigo(_xp_presupuesto, peso, _xp_peso_total)
	enemigo.preparar(
		oleada_actual,
		elite,
		_jugador,
		_bandera,
		self,
		_pool,
		xp
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
	jefe.salud_cambiada.connect(_cb_jefe_salud_cambiada.bind(jefe))
	jefe_invocado.emit(jefe)

	mensaje.emit("¡El Liche de la Arena despierta!" if lich else "¡Un campeón del Imperio entra en la arena!", 3.0)


func _probabilidad_elite() -> float:
	return clampf((oleada_actual - 3) * 0.04, 0.0, 0.22)


func al_morir_enemigo(oro: int, xp: int = 0) -> void:
	oro_ganado.emit(oro)
	_otorgar_xp(xp)


func _al_morir_jefe() -> void:
	oro_ganado.emit(120 + oleada_actual * 20)
	_otorgar_xp(_xp_jefe)
	mensaje.emit("¡Campeón del Imperio derrotado!", 3.0)


func _otorgar_xp(cantidad: int) -> void:
	if cantidad <= 0:
		return
	var excedente_total := 0
	for jugador in _jugadores:
		if jugador == null or not is_instance_valid(jugador):
			continue
		jugador.otorgar_experiencia(cantidad)
		excedente_total += jugador.estadisticas.reclamar_excedente()
	if excedente_total > 0:
		oro_ganado.emit(max(1, excedente_total / 4))
		mensaje.emit("Nivel máximo: %d XP convertida en oro." % excedente_total, 2.0)


func aplicar_estado_red(numero: int, pendientes: int, estado: int, tiempo: float) -> void:
	oleada_actual = numero
	_pendientes = pendientes
	_estado = estado as Estado
	_temporizador = tiempo

func _cb_jefe_salud_cambiada(actual: float, maxima: float, jefe: ArenaBossAI) -> void:
	jefe_invocado.emit(jefe)


func tiempo_preparacion() -> float:
	if _estado != Estado.ESPERA:
		return 0.0
	return maxf(0.0, _temporizador)
