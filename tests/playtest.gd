extends SceneTree
## Playtest automático de oleadas: un bot juega con una clase y mide tiempos de
## muerte reales (sin tocar el editor).
##
## Uso:
##   godot --headless --path . --script res://tests/playtest.gd -- --clase=bastion --oleadas=3
##   godot --headless --path . --script res://tests/playtest.gd -- --clase=filo --oleadas=5 --sin-habilidades
##
## El bot elige el campeón, persigue al enemigo más cercano con ataque-mover,
## lanza habilidades cuando puede y registra por oleada: duración, enemigos,
## tiempo medio de muerte (TTK), vida del gladiador y del estandarte.

## Índice en `WeaponItem.crear_catalogo_base()`; el prisionero se crea aparte.
const CLASES := {
	"bastion": 0,
	"filo": 1,
	"cetro": 2,
}

var _escena: Node
var _jugador: GladiatorController
var _oleadas: WaveManager
var _bandera: Node3D

var _clase := "bastion"
var _max_oleadas := 3
var _usar_habilidades := true
var _time_scale := 4.0

var _nacimiento: Dictionary = {}
var _ttks: Array[float] = []
var _bajas := 0
var _tiempo_juego := 0.0
var _dano_recibido := 0.0
var _golpes_recibidos := 0
var _dano_oleada := 0.0
var _golpes_oleada := 0
var _hp_previo := 0.0

var _oleada_inicio := 0.0
var _oleada_enemigos := 0
var _resumen: Array[Dictionary] = []
var _terminado := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--clase="):
			_clase = arg.get_slice("=", 1)
		elif arg.begins_with("--oleadas="):
			_max_oleadas = int(arg.get_slice("=", 1))
		elif arg == "--sin-habilidades":
			_usar_habilidades = false
		elif arg.begins_with("--escala="):
			_time_scale = float(arg.get_slice("=", 1))
	Engine.time_scale = _time_scale
	_ejecutar()


func _ejecutar() -> void:
	_escena = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_escena)
	await process_frame
	await process_frame

	_jugador = _escena.get("_jugador") as GladiatorController
	_oleadas = _escena.get("_oleadas") as WaveManager
	_bandera = _escena.get("_bandera") as Node3D

	var arma: WeaponItem
	if _clase == "prisionero":
		arma = WeaponItem.crear_prisionero()
	else:
		arma = WeaponItem.crear_catalogo_base()[int(CLASES.get(_clase, 0))]
	_jugador.equipar_arma(arma)
	_jugador.global_position = Vector3(24.0, 0.0, 0.0)
	_jugador.murio.connect(func() -> void:
		print("MUERTE t=%.1f hp=%.0f pos=%s banner=%.0f" % [
			_tiempo_juego, _jugador.salud_actual, str(_jugador.global_position),
			_bandera.get("salud_actual") if _bandera.get("salud_actual") != null else -1.0
		])
		_terminado = true
	)
	_jugador.recibio_dano.connect(_al_recibir_dano)
	_hp_previo = _jugador.salud_actual

	_oleadas.espera_inicial = 0.3
	_oleadas.espera_entre_oleadas = 0.3
	_oleadas.duracion_entrada = 0.1
	_oleadas.intervalo_spawn = 0.75
	_oleadas.oleada_iniciada.connect(_al_iniciar_oleada)
	_oleadas.oleada_terminada.connect(_al_terminar_oleada)

	print("== Playtest: clase=%s oleadas=%d escala=%.1f habilidades=%s ==" % [
		_clase, _max_oleadas, _time_scale, str(_usar_habilidades)
	])

	var fotogramas := 0
	while not _terminado and fotogramas < 200000:
		await physics_frame
		fotogramas += 1
		_tiempo_juego += get_root().get_process_delta_time() * Engine.time_scale
		_medir_vida()
		_gestionar_progresion()
		_pensar()

	Engine.time_scale = 1.0
	_informar()
	quit(0)


## Suma a la oleada el daño recibido de verdad (caída de vida entre frames).
func _medir_vida() -> void:
	var hp := _jugador.salud_actual
	var perdida := _hp_previo - hp
	if perdida > 0.01:
		_dano_recibido += perdida
		_dano_oleada += perdida
	_hp_previo = hp


## Gasta puntos de atributo y de talento como haría un jugador.
func _gestionar_progresion() -> void:
	var e := _jugador.estadisticas
	var principal := &"fuerza"
	if _jugador.arma_actual != null:
		principal = _jugador.arma_actual.atributo_principal
	while e.puntos_libres > 0:
		if not _jugador.gastar_punto_atributo(principal):
			break
	if _jugador.puntos_rojos > 0 and _jugador.arma_actual != null:
		for slot in 4:
			var hab := _jugador.arma_actual.obtener_habilidad(slot)
			if hab == null:
				continue
			for talento in hab.talentos:
				if _jugador.puntos_rojos <= 0:
					return
				if _jugador.rango_talento(talento.id) < talento.rango_maximo:
					_jugador.desbloquear_talento(talento)


## Bot: persigue al enemigo más cercano y usa habilidades en cuanto puede.
func _pensar() -> void:
	if _jugador == null or _jugador.esta_muerto:
		return
	var enemigos := get_nodes_in_group("enemigos")
	_registrar_bajas(enemigos)
	if _usar_habilidades:
		for slot in 4:
			_jugador.intentar_habilidad(slot)
	if enemigos.is_empty():
		return
	var objetivo: Node3D = null
	var mejor := 1e20
	for enemigo in enemigos:
		if not (enemigo is Node3D) or not enemigo.has_method("recibir_dano"):
			continue
		var distancia: float = _jugador.global_position.distance_to(enemigo.global_position)
		if distancia < mejor:
			mejor = distancia
			objetivo = enemigo as Node3D
	if objetivo == null:
		return
	# Respeta el alcance del arma: los cetros pegan a 7,5 m y no deben acercarse.
	var alcance := 2.0
	if _jugador.arma_actual != null:
		alcance = maxf(1.5, _jugador.arma_actual.alcance_ataque - 0.8)
	if mejor > alcance:
		_jugador.ordenar_ataque_movimiento(objetivo.global_position)
	elif mejor < alcance * 0.55:
		var huida: Vector3 = _jugador.global_position + (_jugador.global_position - objetivo.global_position).normalized() * 3.0
		_jugador.ordenar_movimiento(huida)


## Detecta enemigos que dejan de existir para medir su tiempo de muerte.
func _registrar_bajas(enemigos: Array) -> void:
	var vivos: Dictionary = {}
	for enemigo in enemigos:
		if not (enemigo is Node3D) or not is_instance_valid(enemigo):
			continue
		var id: int = enemigo.get_instance_id()
		vivos[id] = true
		if not _nacimiento.has(id):
			_nacimiento[id] = _tiempo_juego
	for id: int in _nacimiento.keys():
		if vivos.has(id):
			continue
		_ttks.append(_tiempo_juego - float(_nacimiento[id]))
		_nacimiento.erase(id)
		_bajas += 1


## El controlador emite `recibio_dano` con intensidad 1.0 (para la cámara), así
## que el daño real se mide por la caída de vida, no por este contador.
func _al_recibir_dano(_intensidad: float) -> void:
	_golpes_recibidos += 1
	_golpes_oleada += 1


func _al_iniciar_oleada(numero: int, _total: int) -> void:
	_oleada_inicio = _tiempo_juego
	_oleada_enemigos = _oleadas.enemigos_restantes()
	_dano_oleada = 0.0
	_golpes_oleada = 0


func _al_terminar_oleada(numero: int) -> void:
	var duracion := _tiempo_juego - _oleada_inicio
	var ttk := 0.0
	if not _ttks.is_empty():
		for valor in _ttks:
			ttk += valor
		ttk /= float(_ttks.size())
	_resumen.append({
		"oleada": numero,
		"duracion": duracion,
		"enemigos": _oleada_enemigos,
		"ttk": ttk,
		"vida": _jugador.salud_actual / maxf(1.0, _jugador.estadisticas.salud_maxima),
		"estandarte": _bandera.get("salud_actual") if _bandera.get("salud_actual") != null else 0.0,
		"dano": _dano_oleada,
		"golpes": _golpes_oleada,
	})
	_ttks.clear()
	if numero >= _max_oleadas:
		_terminado = true


func _informar() -> void:
	print("ola | enemigos | duracion | ttk_medio | bajas/s | vida | dano_recibido | golpes | estandarte")
	for fila in _resumen:
		var bajas_por_seg := float(fila["enemigos"]) / maxf(0.1, float(fila["duracion"]))
		print("%3d | %8d | %6.1f s | %7.1f s | %6.2f | %4.0f%% | %13.0f | %6d | %6.0f" % [
			fila["oleada"], fila["enemigos"], fila["duracion"], fila["ttk"],
			bajas_por_seg, float(fila["vida"]) * 100.0, float(fila["dano"]), int(fila["golpes"]),
			float(fila["estandarte"])
		])
	var total := 0.0
	for fila in _resumen:
		total += float(fila["duracion"])
	print("tiempo total de combate: %.1f s · bajas: %d · daño recibido: %.0f · golpes: %d · murió: %s" % [
		total, _bajas, _dano_recibido, _golpes_recibidos, str(_jugador.esta_muerto)
	])
	print("== fin del playtest ==")
