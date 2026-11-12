class_name CombatComponent
extends Node
## Componente de combate: encapsula estado de vida/maná/escudo, daño,
## curación, cooldowns de habilidades, autoataque básico, regeneración y
## buffs temporales. El GladiatorController es dueño del input, movimiento
## y habilidades; este componente solo gestiona el estado de combate.

signal salud_cambiada(actual: float, maxima: float)
signal mana_cambiada(actual: float, maximo: float)
signal escudo_cambiado(actual: float, maximo: float)
signal ataque_basico(objetivo: Node3D, dano: float, critico: bool)
signal murio
signal estadisticas_combate_cambiadas

## Referencias inyectadas por el controlador
var estadisticas: GladiatorStats
var arma_actual: WeaponItem
var visual: CharacterVisual
var inventario: InventoryComponent

## Referencia al controlador (para posiciones y daño reflejado)
var controlador: Node

## Estado público
var salud_actual := 0.0
var mana_actual := 0.0
var escudo_actual := 0.0
var esta_muerto := false
var dano_infligido := 0.0
var dano_recibido := 0.0

## Cooldowns de habilidades Q/W/E/R
var _cooldowns := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

## Temporizadores y estado interno
var _acumulador_regeneracion := 0.0
var _temporizador_ataque := 0.0
var _reduccion_temporal := 0.0
var _tiempo_reduccion := 0.0
var _critico_asegurado := 0.0
var _autoataque_activo := true
var _tiempo_escudo := 0.0
var _escudo_maximo := 0.0
var _inmunidad_aturdimiento := 0.0
var _inmunidad_daño := 0.0
var _buff_ataque := 0.0
var _buff_robo := 0.0
var _buff_dano := 0.0
var _tiempo_buff := 0.0

const INTERVALO_REGENERACION := 0.25

func _physics_process(delta: float) -> void:
	if esta_muerto:
		return

	_actualizar_cooldowns(delta)
	_actualizar_estados(delta)
	_regenerar(delta)

## --- Cooldowns -----------------------------------------------------------

func _actualizar_cooldowns(delta: float) -> void:
	for i in _cooldowns.size():
		_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)

func cooldown_restante(slot: int) -> float:
	if slot < 0 or slot >= _cooldowns.size():
		return 0.0
	return _cooldowns[slot]

func set_cooldown(slot: int, valor: float) -> void:
	if slot < 0 or slot >= _cooldowns.size():
		return
	_cooldowns[slot] = clampf(valor, 0.0, 999.0)

func reducir_cooldown(slot: int, fraccion: float) -> void:
	if slot < 0 or slot >= _cooldowns.size():
		return
	_cooldowns[slot] = maxf(0.0, _cooldowns[slot] * (1.0 - clampf(fraccion, 0.0, 1.0)))

## --- Estados y temporizadores ------------------------------------------

func _actualizar_estados(delta: float) -> void:
	_tiempo_reduccion = maxf(0.0, _tiempo_reduccion - delta)
	if _tiempo_reduccion <= 0.0:
		_reduccion_temporal = 0.0

	_inmunidad_daño = maxf(0.0, _inmunidad_daño - delta)
	_inmunidad_aturdimiento = maxf(0.0, _inmunidad_aturdimiento - delta)

	if _tiempo_escudo > 0.0:
		_tiempo_escudo -= delta
		if _tiempo_escudo <= 0.0 and escudo_actual > 0.0:
			escudo_actual = 0.0
			_escudo_maximo = 0.0
			escudo_cambiado.emit(0.0, 0.0)

	if _tiempo_buff > 0.0:
		_tiempo_buff -= delta
		if _tiempo_buff <= 0.0:
			_buff_ataque = 0.0
			_buff_robo = 0.0
			_buff_dano = 0.0

## --- Regeneración -------------------------------------------------------

func _regenerar(delta: float) -> void:
	_acumulador_regeneracion += delta
	if _acumulador_regeneracion < INTERVALO_REGENERACION:
		return

	var paso := _acumulador_regeneracion
	_acumulador_regeneracion = 0.0

	if salud_actual < estadisticas.salud_maxima:
		salud_actual = minf(
			estadisticas.salud_maxima,
			salud_actual + estadisticas.regeneracion_salud * paso
		)
		salud_cambiada.emit(salud_actual, estadisticas.salud_maxima)

	if mana_actual < estadisticas.mana_maximo:
		mana_actual = minf(
			estadisticas.mana_maximo,
			mana_actual + estadisticas.regeneracion_mana * paso
		)
		mana_cambiada.emit(mana_actual, estadisticas.mana_maximo)

## --- Escudo -------------------------------------------------------------

func otorgar_escudo(cantidad: float, duracion: float) -> void:
	if cantidad <= 0.0:
		return
	escudo_actual = maxf(escudo_actual, cantidad)
	_escudo_maximo = maxf(_escudo_maximo, escudo_actual)
	_tiempo_escudo = maxf(_tiempo_escudo, duracion)
	escudo_cambiado.emit(escudo_actual, _escudo_maximo)

## --- Daño ---------------------------------------------------------------

## Punto único de entrada del daño recibido. `fuente` permite atribuir
## muertes y aggro. Devuelve true si se aplicó daño.
func recibir_dano(
	cantidad: float,
	tipo: StringName = GladiatorStats.TIPO_FISICO,
	fuente: Node = null
) -> bool:
	if esta_muerto or cantidad <= 0.0:
		return false
	if _inmunidad_daño > 0.0:
		return false

	var mitigacion := 0.0
	match tipo:
		GladiatorStats.TIPO_FISICO:
			mitigacion = estadisticas.mitigacion_fisica
		GladiatorStats.TIPO_MAGICO:
			mitigacion = estadisticas.mitigacion_magica
		_:
			mitigacion = 0.0

	var recibido := cantidad * (1.0 - clampf(mitigacion, 0.0, 0.9))
	recibido *= 1.0 - clampf(_reduccion_temporal, 0.0, 0.9)

	if escudo_actual > 0.0:
		var absorbido := minf(escudo_actual, recibido)
		escudo_actual -= absorbido
		recibido -= absorbido
		escudo_cambiado.emit(escudo_actual, _escudo_maximo)
		NumerosDano.mostrar(controlador.global_position + Vector3(0, 1.9, 0), absorbido, GladiatorStats.TIPO_VERDADERO)

	# Bastión R: la Égida devuelve daño físico proporcional a la Fuerza.
	if _tiempo_escudo > 0.0 and tipo == GladiatorStats.TIPO_FISICO and fuente != null:
		if is_instance_valid(fuente) and fuente.has_method("recibir_dano"):
			var reflejo := estadisticas.fuerza_total * 0.8
			fuente.recibir_dano(reflejo, GladiatorStats.TIPO_VERDADERO, self)
			estadisticas_combate_cambiadas.emit()

	if recibido <= 0.0:
		return true

	salud_actual = maxf(0.0, salud_actual - recibido)
	dano_recibido += recibido
	if salud_actual > 0.0:
		NumerosDano.mostrar(controlador.global_position + Vector3(0, 1.8, 0), recibido, tipo)
	salud_cambiada.emit(salud_actual, estadisticas.salud_maxima)
	estadisticas_combate_cambiadas.emit()

	if visual != null:
		visual.recibir_golpe()
	Sfx.reproducir("dano", -6.0)

	if salud_actual <= 0.0:
		_morir()

	return true

## --- Curación -----------------------------------------------------------

func curar(cantidad: float) -> void:
	if esta_muerto or cantidad <= 0.0:
		return
	var antes := salud_actual
	salud_actual = minf(estadisticas.salud_maxima, salud_actual + cantidad)
	var curado := salud_actual - antes
	if curado > 0.5:
		NumerosDano.mostrar(controlador.global_position + Vector3(0, 1.9, 0), curado, GladiatorStats.TIPO_VERDADERO, false, true)
	salud_cambiada.emit(salud_actual, estadisticas.salud_maxima)

func restaurar_mana(cantidad: float) -> void:
	if esta_muerto or cantidad <= 0.0:
		return
	mana_actual = minf(estadisticas.mana_maximo, mana_actual + cantidad)
	mana_cambiada.emit(mana_actual, estadisticas.mana_maximo)

## --- Buffs --------------------------------------------------------------

func aplicar_grito_guerra(duracion: float, bonus_ataque: float, robo: float) -> void:
	_buff_ataque = maxf(_buff_ataque, bonus_ataque)
	_buff_robo = maxf(_buff_robo, robo)
	_buff_dano = maxf(_buff_dano, 0.15)
	_tiempo_buff = maxf(_tiempo_buff, duracion)
	# El grito también cura al estandarte y a las invocaciones cercanas.
	var cantidad := estadisticas.escalar_invocacion(60.0 + estadisticas.inteligencia_total * 1.2)
	for grupo in ["banderas", "aliados"]:
		for nodo in get_tree().get_nodes_in_group(grupo):
			var aliado := nodo as Node3D
			if aliado == null:
				continue
			if aliado.global_position.distance_to(controlador.global_position) > 10.0:
				continue
			if aliado.has_method("curar"):
				aliado.curar(cantidad)
			if aliado.has_method("aplicar_buff"):
				aliado.aplicar_buff(duracion, bonus_ataque, robo)
	estadisticas_combate_cambiadas.emit()

func aplicar_furia_temporal(duracion: float, bonus_ataque: float, robo: float) -> void:
	_buff_ataque = maxf(_buff_ataque, bonus_ataque)
	_buff_robo = maxf(_buff_robo, robo)
	_buff_dano = maxf(_buff_dano, 0.15)
	_tiempo_buff = maxf(_tiempo_buff, duracion)
	estadisticas_combate_cambiadas.emit()

## --- Inmunidades --------------------------------------------------------

func otorgar_inmunidad_aturdimiento(duracion: float) -> void:
	_inmunidad_aturdimiento = maxf(_inmunidad_aturdimiento, duracion)

func otorgar_inmunidad_daño(duracion: float) -> void:
	_inmunidad_daño = maxf(_inmunidad_daño, duracion)

## --- Daño infligido -----------------------------------------------------

func registrar_dano(cantidad: float) -> void:
	dano_infligido += cantidad
	estadisticas_combate_cambiadas.emit()

## --- Muerte -------------------------------------------------------------

func _morir() -> void:
	if esta_muerto:
		return
	esta_muerto = true
	_remove_from_gladiadores_group()
	if visual != null:
		visual.morir()
	Sfx.reproducir("muerte", -3.0)
	murio.emit()

func _remove_from_gladiadores_group() -> void:
	# Se llama desde el controlador, que tiene acceso al árbol
	pass

## --- Sincronización -----------------------------------------------------

func aplicar_estado_red(datos: Dictionary) -> void:
	salud_actual = float(datos.get("salud", salud_actual))
	mana_actual = float(datos.get("mana", mana_actual))
	escudo_actual = float(datos.get("escudo", 0.0))
	dano_infligido = float(datos.get("dano", dano_infligido))
	dano_recibido = float(datos.get("recibido", dano_recibido))

	var cds: Array = datos.get("cooldowns", [])
	for i in min(4, cds.size()):
		_cooldowns[i] = float(cds[i])

	if salud_actual <= 0.0:
		esta_muerto = true
	else:
		esta_muerto = false

	salud_cambiada.emit(salud_actual, estadisticas.salud_maxima)
	mana_cambiada.emit(mana_actual, estadisticas.mana_maximo)
	escudo_cambiado.emit(escudo_actual, _escudo_maximo)
	estadisticas_combate_cambiadas.emit()

func inicializar_estado() -> void:
	salud_actual = estadisticas.salud_maxima
	mana_actual = estadisticas.mana_maximo
	salud_cambiada.emit(salud_actual, estadisticas.salud_maxima)
	mana_cambiada.emit(mana_actual, estadisticas.mana_maximo)
