class_name Arena
extends Node3D
## Raíz del prototipo: construye la arena, conecta los sistemas y gestiona la
## economía (oro, puntos de atributo) y la condición de victoria/derrota.
##
## La escena se genera por código para poder iterar sin editor. Los sistemas
## (oleadas, público, HUD, armería) son nodos independientes y sustituibles.

const ANCHO := 60.0
const LARGO := 40.0
const ALTO_MURO := 1.4
const RADIO_PUBLICO := 32.0
const RADIO_INTERACCION := 3.5
const TIEMPO_REVIVIR := 10.0
const RADIO_REVIVIR := 4.0
const FACTOR_REVIVIR_CERCA := 2.5
const BORDE_ARENA := 10.0
const CENTRO_ARENA := Vector3(-8.0, 0, 0)

## Paletas de skin del gladiador: se multiplican sobre la textura base.
const SKIN_TIERRA_BALDIA := Color(0.72, 0.95, 0.55)
const SKIN_CENIZA := Color(0.78, 0.80, 0.78)
const SKIN_SANGRE := Color(1.00, 0.62, 0.55)
const SKIN_HIELO := Color(0.62, 0.82, 1.00)
const SKINS := [
	{"nombre": "Tierra Baldía", "tinte": SKIN_TIERRA_BALDIA},
	{"nombre": "Ceniza", "tinte": SKIN_CENIZA},
	{"nombre": "Sangre", "tinte": SKIN_SANGRE},
	{"nombre": "Hielo", "tinte": SKIN_HIELO},
]

var _terminado_local := false
var _skin_actual := 0

var terminado:
	get:
		return game_state.esta_terminado() if game_state != null else _terminado_local
	set(value):
		_terminado_local = value
		if game_state != null and value:
			game_state.finalizar("DERROTA", "Partida terminada")

var game_state: GameState
var enemy_tracker: EnemyTracker

var _oro_local := 200
var _puntos_local := 0

var oro:
	get:
		return game_state.oro if game_state != null else _oro_local
	set(value):
		_oro_local = value
		if game_state != null:
			game_state.oro = value

var puntos_atributo:
	get:
		return game_state.puntos_atributo if game_state != null else _puntos_local
	set(value):
		_puntos_local = value
		if game_state != null:
			game_state.puntos_atributo = value

var _jugador: GladiatorController
var _camara: ArenaCamera
var _bandera: RebellionBanner
var _oleadas: WaveManager
var _publico: AudienceFury
var _hud: ArenaHUD
var _tienda: ShopPedestal
var _puerta: PuertaArena
var _texto_pista := ""
var _pedestales: Array[ArmoryPedestal] = []
var _puntos_spawn: Array[Vector3] = []
var _en_combate := false
var _fuente := Vector3(26.0, 0, 0)
var _obelisco := Vector3(22.0, 0, -9.0)
var _campeon_elegido := false
var _tiempo_entrada := 0.0

## Modo red cooperativo.
var es_servidor := false
var es_cliente := false
var url_servidor := ""
var puerto_red := NetCoop.PUERTO_POR_DEFECTO
var red: NetCoop
var jugadores: Array[GladiatorController] = []
var jugadores_red: Dictionary = {}
var _jugadores_remotos: Dictionary = {}
var _enemigos_remotos: Dictionary = {}
var _jefes_remotos: Dictionary = {}
var _tiempo_snapshot := 0.0
var _terminado_red := false
var _resultado_red := ""
var _log_snapshot := false
var _eventos_red: Array = []
var _estaba_muerto := false
var _supabase: Supabase
var _servidor_publico_url := ""
var _hora_inicio_partida := 0.0


func _ready() -> void:
	get_tree().paused = false
	_leer_modo_red()

	_crear_entorno()
	_crear_suelo()
	_crear_muros()
	_crear_decoracion()
	_crear_zona_segura()
	_crear_puerta()
	_crear_bandera()

	if es_servidor:
		_iniciar_servidor()
	elif es_cliente:
		_iniciar_cliente()
	elif _necesita_menu():
		_mostrar_menu()
	else:
		_iniciar_local()

	var args := OS.get_cmdline_user_args()
	if "--captura" in args or "--captura-combate" in args or "--captura-cerca" in args or "--captura-talentos" in args or "--captura-habilidad" in args or "--captura-jefe" in args or "--captura-tienda" in args:
		_capturar()


func _leer_modo_red() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg == "--servidor":
			es_servidor = true
		elif arg.begins_with("--cliente="):
			es_cliente = true
			url_servidor = arg.substr("--cliente=".length())
		elif arg.begins_with("--puerto="):
			puerto_red = int(arg.substr("--puerto=".length()))
		elif arg.begins_with("--publico="):
			_servidor_publico_url = arg.substr("--publico=".length())
	if OS.has_feature("web") and not es_servidor:
		var consulta = JavaScriptBridge.eval(
			"(new URLSearchParams(window.location.search)).get('servidor') || ''"
		)
		if consulta is String and not consulta.is_empty():
			es_cliente = true
			url_servidor = consulta
	if not es_servidor and url_servidor.is_empty():
		url_servidor = str(ProjectSettings.get_setting("red/servidor_url", ""))
	if es_servidor and _servidor_publico_url.is_empty():
		_servidor_publico_url = OS.get_environment("SERVER_PUBLIC_URL").strip_edges()
		if _servidor_publico_url.is_empty():
			_servidor_publico_url = str(ProjectSettings.get_setting("red/servidor_publico_url", ""))


func _necesita_menu() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if "--menu-red" in OS.get_cmdline_user_args():
		return true
	return OS.has_feature("web") or OS.has_feature("mobile")


func _mostrar_menu() -> void:
	var menu := MenuRed.new()
	add_child(menu)
	menu.configurar(url_servidor)
	menu.jugar_solo.connect(_iniciar_local)
	menu.unirse.connect(_iniciar_cliente_con_url)


func _iniciar_cliente_con_url(direccion: String) -> void:
	es_cliente = true
	url_servidor = direccion
	_iniciar_cliente()


func _iniciar_local() -> void:
	game_state = GameState.new()
	game_state.name = "GameState"
	add_child(game_state)
	game_state.oro_cambiado.connect(func(cantidad: int): _oro_local = cantidad)
	game_state.puntos_cambiados.connect(func(cantidad: int): _puntos_local = cantidad)
	game_state.partida_terminada.connect(_finalizar)

	enemy_tracker = EnemyTracker.new()
	enemy_tracker.name = "EnemyTracker"
	add_child(enemy_tracker)
	enemy_tracker.add_to_group("enemy_tracker")

	_crear_jugador_local()
	_crear_camara()
	_crear_armeria()
	_crear_tienda()
	_crear_oleadas()
	_crear_publico()
	_crear_hud()
	_conectar()


func _process(delta: float) -> void:
	_actualizar_pista()
	if es_servidor:
		_tiempo_snapshot += delta
		if _tiempo_snapshot >= 1.0 / 15.0:
			_tiempo_snapshot = 0.0
			_enviar_snapshot()
		_actualizar_revives(delta)
		_curar_en_zona_segura(delta)
	elif es_cliente:
		pass
	else:
		_curar_en_zona_segura(delta)
	_tiempo_entrada = maxf(0.0, _tiempo_entrada - delta)


# --- Red cooperativa ------------------------------------------------------

func _iniciar_servidor() -> void:
	red = NetCoop.new()
	red.name = "Red"
	add_child(red)
	red.configurar(self)
	red.iniciar_servidor(puerto_red)
	_hora_inicio_partida = Time.get_unix_time_from_system()
	_supabase = Supabase.new()
	add_child(_supabase)
	_supabase.iniciar_latido("Gladiators Revenge", _servidor_publico_url, 3)


func _iniciar_cliente() -> void:
	red = NetCoop.new()
	red.name = "Red"
	add_child(red)
	red.configurar(self)
	red.bienvenida.connect(_al_recibir_bienvenida)
	red.snapshot_recibido.connect(_aplicar_snapshot)
	red.lobby_actualizada.connect(_al_actualizar_lobby)
	red.clase_rechazada.connect(_al_rechazar_clase)
	red.partida_terminada.connect(_al_fin_red)
	red.conexion_cambiada.connect(_al_cambiar_conexion)

	_crear_jugador_mirror()
	_crear_camara()
	_crear_armeria()
	_crear_tienda()

	_oleadas = WaveManager.new()
	_oleadas.name = "OleadasRed"
	add_child(_oleadas)
	_oleadas.set_process(false)

	_publico = AudienceFury.new()
	_publico.name = "PublicoRed"
	add_child(_publico)
	_publico.set_process(false)

	_crear_hud()
	if _hud != null:
		_hud.mostrar_mensaje("Conectando al servidor cooperativo…", 6.0)
	if url_servidor.is_empty():
		url_servidor = "ws://127.0.0.1:%d" % puerto_red
	red.unirse(url_servidor)


func _crear_jugador_local() -> void:
	_jugador = _instanciar_gladiador(Vector3(24.0, 0, 0), 0)
	jugadores.append(_jugador)
	_jugador.murio.connect(_al_morir_jugador)


func _instanciar_gladiador(posicion: Vector3, indice: int) -> GladiatorController:
	var cuerpo := GladiatorController.new()
	cuerpo.name = "Gladiador%d" % indice
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 1

	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.45
	capsula.height = 1.8
	forma.shape = capsula
	forma.position.y = 0.9
	cuerpo.add_child(forma)

	var agente := NavigationAgent3D.new()
	agente.name = "NavigationAgent3D"
	cuerpo.add_child(agente)

	cuerpo.tinte_skin = SKIN_TIERRA_BALDIA
	cuerpo.estadisticas = GladiatorStats.new()
	cuerpo.arma_inicial = WeaponItem.crear_prisionero()
	if red != null:
		cuerpo.red = red

	add_child(cuerpo)
	cuerpo.global_position = posicion

	var inventario := InventoryComponent.new()
	inventario.name = "Inventario"
	cuerpo.add_child(inventario)
	cuerpo.inventario = inventario
	inventario.configurar(cuerpo)
	inventario.agregar(ItemCatalog.obtener(&"pocion_vida"))
	return cuerpo


func _crear_jugador_mirror() -> void:
	_jugador = _instanciar_gladiador(Vector3(24.0, 0, 0), 0)
	_jugador.es_espejo = true
	_jugador.es_local_red = true
	_jugador.red = red
	jugadores.append(_jugador)


func agregar_jugador_red(peer: int) -> void:
	if not es_servidor or jugadores_red.has(peer):
		return
	var indice := jugadores_red.size()
	var posiciones := [Vector3(24.0, 0, 0), Vector3(24.0, 0, 4.0), Vector3(24.0, 0, -4.0)]
	var cuerpo := _instanciar_gladiador(posiciones[indice % posiciones.size()], indice)
	cuerpo.red = red
	jugadores_red[peer] = cuerpo
	jugadores.append(cuerpo)
	cuerpo.murio.connect(_al_morir_jugador)
	cuerpo.ataque_basico.connect(_al_ataque_red.bind(peer))
	if _oleadas != null:
		_oleadas.agregar_jugador(cuerpo)
	if _supabase != null:
		_supabase.actualizar_jugadores(jugadores_red.size())

	if jugadores.size() == 1:
		_jugador = cuerpo
		_crear_oleadas()
		_crear_publico()
		_conectar()


func quitar_jugador_red(peer: int) -> void:
	var cuerpo: GladiatorController = jugadores_red.get(peer)
	if cuerpo == null:
		return
	jugadores_red.erase(peer)
	jugadores.erase(cuerpo)
	if _oleadas != null:
		_oleadas.quitar_jugador(cuerpo)
	cuerpo.queue_free()
	if _supabase != null:
		_supabase.actualizar_jugadores(jugadores_red.size())
	if jugadores.is_empty():
		_reiniciar_servidor()
		return
	var vivos := 0
	for otro in jugadores:
		if otro != null and is_instance_valid(otro) and not otro.esta_muerto:
			vivos += 1
	if vivos == 0:
		_finalizar("DERROTA", "Todos los gladiadores han caído.")


func _reiniciar_servidor() -> void:
	if not es_servidor:
		_finalizar("DERROTA", "Todos los gladiadores han caído.")
		return
	print("[NET] sin jugadores; reiniciando arena del servidor")
	await get_tree().create_timer(0.5).timeout
	get_tree().reload_current_scene()


func equipar_clase_red(peer: int, clase: StringName) -> void:
	var cuerpo: GladiatorController = jugadores_red.get(peer)
	if cuerpo == null:
		return
	var arma := _arma_por_clase(clase)
	if arma != null:
		cuerpo.equipar_arma(arma)


func aplicar_accion_red(peer: int, accion: StringName, datos: Dictionary) -> void:
	var cuerpo: GladiatorController = jugadores_red.get(peer)
	if cuerpo == null or cuerpo.esta_muerto:
		return
	match accion:
		&"mover":
			cuerpo.ordenar_movimiento(datos.get("punto", cuerpo.global_position))
		&"atacar_mover":
			cuerpo.ordenar_ataque_movimiento(datos.get("punto", cuerpo.global_position))
		&"detener":
			cuerpo.detener()
		&"mantener":
			cuerpo.alternar_mantener_posicion()
		&"atacar":
			cuerpo.alternar_modo_ataque()
		&"habilidad":
			var slot := int(datos.get("slot", 0))
			_preparar_punto_red(cuerpo, datos.get("punto"))
			if cuerpo.intentar_habilidad(slot, datos.get("punto")):
				_eventos_red.append({
					"tipo": "habilidad", "peer": peer, "slot": slot,
					"punto": datos.get("punto"),
				})
			cuerpo.tiene_punto_red = false
		&"objeto":
			var indice := int(datos.get("indice", 0))
			var item_usado: ItemData = null
			if cuerpo.inventario != null and indice >= 0 and indice < InventoryComponent.RANURAS:
				item_usado = cuerpo.inventario.ranuras[indice].get("item")
			_preparar_punto_red(cuerpo, datos.get("punto"))
			if cuerpo.usar_objeto(indice) and item_usado != null:
				_eventos_red.append({
					"tipo": "objeto", "peer": peer, "item": item_usado.id,
					"punto": datos.get("punto"),
				})
			cuerpo.tiene_punto_red = false
		&"punto":
			cuerpo.gastar_punto_atributo(StringName(datos.get("atributo", "fuerza")))
		&"talento":
			var talento := _talento_por_id(cuerpo, StringName(datos.get("id", "")))
			if talento != null:
				cuerpo.desbloquear_talento(talento)
		&"comprar":
			var item := ItemCatalog.obtener(StringName(datos.get("id", "")))
			if item != null:
				comprar_para(cuerpo, item)
		&"skin":
			_ciclar_skin()
		&"bandera":
			_interactuar_bandera(cuerpo)
		&"debug_morir":
			if "--red-rapida" in OS.get_cmdline_user_args():
				cuerpo.recibir_dano(999999.0, GladiatorStats.TIPO_VERDADERO)
		&"debug_curar":
			if "--red-rapida" in OS.get_cmdline_user_args():
				if cuerpo.esta_muerto:
					cuerpo.revivir_red(cuerpo.global_position, 1.0)
				else:
					cuerpo.salud_actual = cuerpo.estadisticas.salud_maxima
					cuerpo.mana_actual = cuerpo.estadisticas.mana_maximo
					cuerpo.escudo_actual = 0.0
		_:
			pass


func _preparar_punto_red(cuerpo: GladiatorController, punto) -> void:
	if punto is Vector3:
		cuerpo.punto_red = punto
		cuerpo.tiene_punto_red = true
	else:
		cuerpo.tiene_punto_red = false


func _al_ataque_red(_objetivo, _dano, critico: bool, peer: int) -> void:
	_eventos_red.append({"tipo": "ataque", "peer": peer, "critico": critico})


func _arma_por_clase(clase: StringName) -> WeaponItem:
	for arma in WeaponItem.crear_catalogo_base():
		if arma.id_clase() == clase:
			return arma
	return null


func _talento_por_id(cuerpo: GladiatorController, id: StringName) -> TalentData:
	if cuerpo.arma_actual == null:
		return null
	for habilidad in cuerpo.arma_actual.habilidades:
		if habilidad == null:
			continue
		for talento in habilidad.talentos:
			if talento != null and talento.id == id:
				return talento
	return null


func _enviar_snapshot() -> void:
	if red == null or not es_servidor:
		return
	var datos := {
		"jugadores": [],
		"enemigos": [],
		"jefes": [],
		"bandera": {
			"hp": _bandera.salud_actual if _bandera != null else 0.0,
			"max": _bandera.salud_maxima if _bandera != null else 0.0,
		},
		"oleada": _oleadas.oleada_actual if _oleadas != null else 0,
		"pendientes": _oleadas.get("_pendientes") if _oleadas != null else 0,
		"estado_oleada": int(_oleadas.get("_estado")) if _oleadas != null else 0,
		"tiempo_oleada": _oleadas.tiempo_restante() if _oleadas != null else 0.0,
		"oro": oro,
		"puntos": puntos_atributo,
		"congelando": _publico != null and _publico.congelando,
		"skin": _skin_actual,
		"terminado": terminado,
		"resultado": _resultado_red,
		"eventos": _eventos_red.duplicate(),
	}
	_eventos_red.clear()
	for peer in jugadores_red.keys():
		datos["jugadores"].append(_datos_jugador(peer, jugadores_red[peer]))

	for nodo in get_tree().get_nodes_in_group("enemigos"):
		if nodo is ArenaBossAI:
			var jefe := nodo as ArenaBossAI
			datos["jefes"].append({
				"id": jefe.get_instance_id(),
				"pos": jefe.global_position,
				"rot": jefe.rotation.y,
				"hp": jefe.salud_actual,
				"max": jefe.salud_maxima,
				"ruta": jefe.ruta_modelo,
				"tinte": jefe.tinte_visual,
				"escala": jefe.escala_visual,
				"perfil": jefe.perfil_visual,
			})
		elif nodo is ArenaEnemy:
			var enemigo := nodo as ArenaEnemy
			datos["enemigos"].append({
				"id": enemigo.get_instance_id(),
				"pos": enemigo.global_position,
				"rot": enemigo.rotation.y,
				"hp": enemigo.salud_actual,
				"max": enemigo.salud_maxima,
				"elite": enemigo.es_elite,
				"ligero": enemigo.es_ligero,
			})
	red.difundir_snapshot(datos)


func _datos_jugador(peer: int, cuerpo: GladiatorController) -> Dictionary:
	var inventario: Array = []
	if cuerpo.inventario != null:
		for i in InventoryComponent.RANURAS:
			var ranura: Dictionary = cuerpo.inventario.ranuras[i]
			var item: ItemData = ranura.get("item")
			inventario.append({
				"id": item.id if item != null else &"",
				"cantidad": int(ranura.get("cantidad", 0)),
				"cd": cuerpo.inventario.energia_restante(i),
			})
	var clase := &"prisionero"
	if cuerpo.arma_actual != null:
		clase = cuerpo.arma_actual.id_clase()
	return {
		"id": peer,
		"pos": cuerpo.global_position,
		"rot": cuerpo.rotation.y,
		"clase": clase,
		"base": {
			"fuerza": cuerpo.estadisticas.fuerza,
			"agilidad": cuerpo.estadisticas.agilidad,
			"inteligencia": cuerpo.estadisticas.inteligencia,
		},
		"totales": {
			"fuerza": cuerpo.estadisticas.fuerza_total,
			"agilidad": cuerpo.estadisticas.agilidad_total,
			"inteligencia": cuerpo.estadisticas.inteligencia_total,
		},
		"salud": cuerpo.salud_actual,
		"salud_max": cuerpo.estadisticas.salud_maxima,
		"mana": cuerpo.mana_actual,
		"mana_max": cuerpo.estadisticas.mana_maximo,
		"escudo": cuerpo.escudo_actual,
		"nivel": cuerpo.estadisticas.nivel,
		"xp": cuerpo.estadisticas.experiencia,
		"puntos_libres": cuerpo.estadisticas.puntos_libres,
		"puntos_rojos": cuerpo.puntos_rojos,
		"revive_en": cuerpo.revive_en,
		"cooldowns": [
			cuerpo._cooldowns[0], cuerpo._cooldowns[1],
			cuerpo._cooldowns[2], cuerpo._cooldowns[3],
		],
		"rangos": cuerpo._rangos_habilidad.duplicate(),
		"desbloqueadas": cuerpo._habilidades_desbloqueadas.duplicate(),
		"talentos": cuerpo._talentos_activos.duplicate(),
		"inv": inventario,
		"dano": cuerpo.dano_infligido,
		"recibido": cuerpo.dano_recibido,
		"muerto": cuerpo.esta_muerto,
	}


func _al_recibir_bienvenida(peer: int) -> void:
	_jugadores_remotos[peer] = _jugador
	_jugador.es_local_red = true
	print("[NET] jugador local listo: ", peer)
	if _hud != null:
		_hud.mostrar_mensaje("Conectado. Elige tu campeón en la armería.", 3.0)


func _al_actualizar_lobby(ocupadas: Dictionary) -> void:
	if _jugador == null:
		return
	var mi_clase := &""
	for clase in ocupadas.keys():
		if int(ocupadas[clase]) == red.peer_local:
			mi_clase = StringName(clase)
	if mi_clase != &"":
		_campeon_elegido = true
	for pedestal in _pedestales:
		if int(ocupadas.get(pedestal.arma.id_clase(), 0)) > 0:
			pedestal.desactivar()
		elif _campeon_elegido:
			pedestal.desactivar()


func _al_rechazar_clase(clase: StringName) -> void:
	if _hud != null:
		_hud.mostrar_mensaje("La clase %s ya está ocupada." % String(clase).to_upper(), 2.4)


func _al_cambiar_conexion(estado_red: String, detalle: String) -> void:
	if _hud != null and _jugador != null and not red.es_servidor:
		_hud.mostrar_mensaje(detalle, 2.4)


func _al_fin_red(titulo: String, detalle: String) -> void:
	if _terminado_red:
		return
	_terminado_red = true
	_finalizar(titulo, detalle)


func _aplicar_snapshot(datos: Dictionary) -> void:
	if _jugador == null:
		return
	if not _log_snapshot:
		_log_snapshot = true
		print("[NET] primer snapshot: jugadores=", datos.get("jugadores", []).size(), " enemigos=", datos.get("enemigos", []).size())
	oro = int(datos.get("oro", oro))
	puntos_atributo = int(datos.get("puntos", puntos_atributo))
	_skin_actual = int(datos.get("skin", _skin_actual))
	_resultado_red = str(datos.get("resultado", ""))
	if _publico != null:
		_publico.congelando = bool(datos.get("congelando", false))
	if _oleadas != null:
		_oleadas.aplicar_estado_red(
			int(datos.get("oleada", 0)),
			int(datos.get("pendientes", 0)),
			int(datos.get("estado_oleada", 0)),
			float(datos.get("tiempo_oleada", 0.0))
		)
	if _bandera != null and datos.has("bandera"):
		var banda: Dictionary = datos["bandera"]
		_bandera.salud_actual = float(banda.get("hp", _bandera.salud_actual))
		_bandera.salud_maxima = maxf(1.0, float(banda.get("max", _bandera.salud_maxima)))

	var vistos := {}
	var nivel_antes := _jugador.estadisticas.nivel
	for fila in datos.get("jugadores", []):
		var id := int(fila.get("id", 0))
		vistos[id] = true
		var cuerpo: GladiatorController = _jugadores_remotos.get(id)
		if cuerpo == null and id == red.peer_local:
			cuerpo = _jugador
			_jugadores_remotos[id] = _jugador
		if cuerpo == null:
			cuerpo = _instanciar_gladiador(fila.get("pos", Vector3.ZERO), _jugadores_remotos.size())
			cuerpo.es_espejo = true
			cuerpo.es_local_red = false
			cuerpo.red = red
			_jugadores_remotos[id] = cuerpo
			jugadores.append(cuerpo)
		_aplicar_clase_mirror(cuerpo, StringName(fila.get("clase", &"prisionero")))
		cuerpo.aplicar_estado_red(fila)
		if cuerpo.inventario != null:
			cuerpo.inventario.aplicar_estado_red(fila.get("inv", []))
	for id in _jugadores_remotos.keys():
		if not vistos.has(id):
			if id == red.peer_local:
				continue
			var cuerpo: GladiatorController = _jugadores_remotos[id]
			_jugadores_remotos.erase(id)
			jugadores.erase(cuerpo)
			cuerpo.queue_free()

	_sincronizar_enemigos(datos.get("enemigos", []))
	_sincronizar_jefes(datos.get("jefes", []))
	for evento in datos.get("eventos", []):
		_aplicar_evento_red(evento)

	if _estaba_muerto and not _jugador.esta_muerto and _jugador.revive_en <= 0.0:
		if _hud != null:
			_hud.mostrar_mensaje("¡Has revivido! Sigue peleando.", 2.5)
	_estaba_muerto = _jugador.esta_muerto

	if _jugador.estadisticas.nivel > nivel_antes and _hud != null:
		_hud.mostrar_mensaje("¡NIVEL %d!" % _jugador.estadisticas.nivel, 1.6)


func _aplicar_clase_mirror(cuerpo: GladiatorController, clase: StringName) -> void:
	if cuerpo.arma_actual != null and cuerpo.arma_actual.id_clase() == clase:
		return
	var arma := _arma_por_clase(clase)
	if arma == null:
		return
	cuerpo.arma_actual = arma
	cuerpo._arma_progreso_id = arma.id
	if arma.habilidades.size() >= 3:
		cuerpo._orden_desbloqueo = [
			arma.habilidades[0].id, arma.habilidades[1].id, arma.habilidades[2].id
		]
	if cuerpo.visual != null:
		cuerpo.visual.usar_arma_pesada(arma.clase == WeaponItem.Clase.BASTION)
		cuerpo.visual.equipar_arma(arma.escena_visual, arma.rotacion_visual, arma.escala_visual)
	cuerpo.arma_cambiada.emit(arma)


func _sincronizar_enemigos(lista: Array) -> void:
	var vistos := {}
	for fila in lista:
		var id := int(fila.get("id", 0))
		vistos[id] = true
		var enemigo: ArenaEnemy = _enemigos_remotos.get(id)
		if enemigo == null:
			enemigo = ArenaEnemy.crear()
			add_child(enemigo)
			enemigo.configurar_remoto(bool(fila.get("elite", false)), bool(fila.get("ligero", false)))
			_enemigos_remotos[id] = enemigo
		enemigo.aplicar_remoto(
			fila.get("pos", Vector3.ZERO),
			float(fila.get("rot", 0.0)),
			float(fila.get("hp", 1.0)),
			float(fila.get("max", 1.0))
		)
	for id in _enemigos_remotos.keys():
		if not vistos.has(id):
			var enemigo: ArenaEnemy = _enemigos_remotos[id]
			_enemigos_remotos.erase(id)
			enemigo.queue_free()


func _sincronizar_jefes(lista: Array) -> void:
	var vistos := {}
	for fila in lista:
		var id := int(fila.get("id", 0))
		vistos[id] = true
		var jefe: ArenaBossAI = _jefes_remotos.get(id)
		if jefe == null:
			jefe = ArenaBossAI.crear(
				str(fila.get("ruta", "")),
				fila.get("tinte", Color.TRANSPARENT),
				float(fila.get("escala", 0.0)),
				str(fila.get("perfil", "caballero"))
			)
			add_child(jefe)
			jefe.set_physics_process(false)
			_jefes_remotos[id] = jefe
		jefe.global_position = fila.get("pos", Vector3.ZERO)
		jefe.rotation.y = float(fila.get("rot", 0.0))
		jefe.salud_maxima = maxf(1.0, float(fila.get("max", 1.0)))
		jefe.salud_actual = maxf(0.0, float(fila.get("hp", 1.0)))
	for id in _jefes_remotos.keys():
		if not vistos.has(id):
			var jefe: ArenaBossAI = _jefes_remotos[id]
			_jefes_remotos.erase(id)
			jefe.queue_free()


func _aplicar_evento_red(evento: Dictionary) -> void:
	var peer := int(evento.get("peer", 0))
	var cuerpo: GladiatorController = _jugadores_remotos.get(peer)
	if cuerpo == null:
		return
	var tipo := str(evento.get("tipo", ""))
	if tipo == "revivir":
		if cuerpo.visual != null:
			cuerpo.visual.revivir()
		Sfx.reproducir("victoria", -12.0)
		return
	if tipo == "ataque":
		if cuerpo.visual != null:
			cuerpo.visual.atacar()
		Sfx.reproducir("critico" if bool(evento.get("critico", false)) else "golpe", -9.0)
		return
	var habilidad: AbilityData = null
	if tipo == "habilidad" and cuerpo.arma_actual != null:
		habilidad = cuerpo.arma_actual.obtener_habilidad(int(evento.get("slot", 0)))
	elif tipo == "objeto":
		var item := ItemCatalog.obtener(StringName(evento.get("item", &"")))
		if item != null:
			habilidad = item.habilidad
	if habilidad == null:
		return
	var contenedor: Node = get_tree().current_scene
	if contenedor == null:
		contenedor = self
	var efecto: Node = AbilityEffect.new()
	efecto.solo_visual = true
	contenedor.add_child(efecto)
	var punto = evento.get("punto")
	(efecto as Node3D).global_position = punto if punto is Vector3 else cuerpo.global_position
	efecto.configurar(habilidad, cuerpo)
	Sfx.reproducir("magia" if habilidad.tipo_dano == GladiatorStats.TIPO_MAGICO else "habilidad", -8.0)


func _en_base() -> bool:
	return _jugador != null and _jugador.global_position.x > BORDE_ARENA + 1.0


func _curar_en_zona_segura(delta: float) -> void:
	if es_cliente or terminado or _en_combate:
		return
	for jugador in jugadores:
		if jugador == null or not is_instance_valid(jugador) or jugador.esta_muerto:
			continue
		if jugador.global_position.x <= BORDE_ARENA + 1.0:
			continue
		if jugador.global_position.distance_to(_fuente) > 5.5:
			continue
		jugador.curar(jugador.estadisticas.salud_maxima * 0.035 * delta)
		jugador.restaurar_mana(jugador.estadisticas.mana_maximo * 0.05 * delta)


func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey):
		return
	var tecla := evento as InputEventKey
	if not tecla.pressed or tecla.echo:
		return

	if terminado:
		if tecla.physical_keycode == KEY_ENTER:
			get_tree().reload_current_scene()
		return

	match tecla.physical_keycode:
		KEY_F:
			_interactuar_cercano()
		KEY_T:
			_hud.alternar_talentos()
		KEY_K:
			_ciclar_skin()
		KEY_G:
			_alternar_bandera()
		KEY_ESCAPE:
			_hud.cerrar_talentos()
			_hud.cerrar_tienda()
		KEY_1:
			_gastar_punto(&"fuerza")
		KEY_2:
			_gastar_punto(&"agilidad")
		KEY_3:
			_gastar_punto(&"inteligencia")


# --- Construcción del mundo ----------------------------------------------

func _crear_entorno() -> void:
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color(0.07, 0.06, 0.10)
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(0.78, 0.72, 0.88)
	entorno.ambient_light_energy = 0.65
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var mundo := WorldEnvironment.new()
	mundo.environment = entorno
	add_child(mundo)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sol.light_energy = 1.15
	sol.light_color = Color(1.0, 0.93, 0.82)
	sol.shadow_enabled = false
	add_child(sol)

	var relleno := OmniLight3D.new()
	relleno.position = Vector3(0, 8, 0)
	relleno.omni_range = 40.0
	relleno.light_energy = 0.5
	relleno.light_color = Color(1.0, 0.55, 0.30)
	add_child(relleno)


func _crear_suelo() -> void:
	var region := NavigationRegion3D.new()
	var malla_nav := NavigationMesh.new()
	var mitad := Vector3(ANCHO * 0.5, 0.0, LARGO * 0.5)
	malla_nav.vertices = PackedVector3Array([
		Vector3(-mitad.x, 0, -mitad.z),
		Vector3(mitad.x, 0, -mitad.z),
		Vector3(mitad.x, 0, mitad.z),
		Vector3(-mitad.x, 0, mitad.z),
	])
	malla_nav.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = malla_nav
	add_child(region)

	var suelo := StaticBody3D.new()
	suelo.collision_layer = 1
	suelo.collision_mask = 1

	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(ANCHO, 1.0, LARGO)
	forma.shape = caja
	forma.position.y = -0.5
	suelo.add_child(forma)

	var visual := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(ANCHO, LARGO)
	visual.mesh = plano
	visual.material_override = _material(Color(0.36, 0.29, 0.22))
	suelo.add_child(visual)
	add_child(suelo)

	# Terreno exterior: evita que la cámara enseñe el vacío en las esquinas.
	var exterior := MeshInstance3D.new()
	var plano_exterior := PlaneMesh.new()
	plano_exterior.size = Vector2(ANCHO * 2.4, LARGO * 2.4)
	exterior.mesh = plano_exterior
	exterior.position.y = -0.05
	exterior.material_override = _material(Color(0.33, 0.27, 0.22))
	add_child(exterior)

	# Anillo central bajo el estandarte.
	var anillo := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 5.0
	cilindro.bottom_radius = 5.0
	cilindro.height = 0.04
	anillo.mesh = cilindro
	anillo.position = CENTRO_ARENA + Vector3(0, 0.02, 0)
	anillo.material_override = _material(Color(0.45, 0.32, 0.20))
	add_child(anillo)

	# Losa de la zona segura: más clara para separar base y arena.
	var base := MeshInstance3D.new()
	var plano_base := PlaneMesh.new()
	plano_base.size = Vector2(20.0, LARGO)
	base.mesh = plano_base
	base.position = Vector3(20.0, 0.015, 0)
	base.material_override = _material(Color(0.43, 0.35, 0.27))
	add_child(base)

	# Gradas de la arena: tres graderíos, la base queda abierta al este.
	_crear_prop(Vector3(0, 1.5, -LARGO * 0.5 - 4.0), Vector3(ANCHO, 3.0, 6.0), Color(0.16, 0.14, 0.18))
	_crear_prop(Vector3(0, 1.5, LARGO * 0.5 + 4.0), Vector3(ANCHO, 3.0, 6.0), Color(0.16, 0.14, 0.18))
	_crear_prop(Vector3(-ANCHO * 0.5 - 4.0, 1.5, 0), Vector3(6.0, 3.0, LARGO), Color(0.13, 0.12, 0.16))

	_puntos_spawn = [
		Vector3(-ANCHO * 0.5 + 4.0, 0, -LARGO * 0.5 + 3.0),
		Vector3(-ANCHO * 0.5 + 4.0, 0, LARGO * 0.5 - 3.0),
		Vector3(-10.0, 0, -LARGO * 0.5 + 3.0),
		Vector3(-10.0, 0, LARGO * 0.5 - 3.0),
	]


func _crear_muros() -> void:
	var piedra := Color(0.24, 0.22, 0.21)
	_crear_caja_estatica(Vector3(0, ALTO_MURO * 0.5, -LARGO * 0.5), Vector3(ANCHO, ALTO_MURO, 1.0), piedra)
	_crear_caja_estatica(Vector3(0, ALTO_MURO * 0.5, LARGO * 0.5), Vector3(ANCHO, ALTO_MURO, 1.0), piedra)
	_crear_caja_estatica(Vector3(-ANCHO * 0.5, ALTO_MURO * 0.5, 0), Vector3(1.0, ALTO_MURO, LARGO), piedra)
	_crear_caja_estatica(Vector3(ANCHO * 0.5, ALTO_MURO * 0.5, 0), Vector3(1.0, ALTO_MURO, LARGO), piedra)
	# Muro divisorio entre arena y base, con un portón central de 10 m.
	_crear_caja_estatica(Vector3(BORDE_ARENA, 1.8, -12.5), Vector3(1.0, 3.6, 15.0), piedra)
	_crear_caja_estatica(Vector3(BORDE_ARENA, 1.8, 12.5), Vector3(1.0, 3.6, 15.0), piedra)


## Props modulares de KayKit: columnas, antorchas, estandartes y cobertura.
func _crear_decoracion() -> void:
	var columna := load("res://assets/kaykit/dungeon/column.gltf.glb") as PackedScene
	var antorcha := load("res://assets/kaykit/dungeon/torch_lit.gltf.glb") as PackedScene
	var banderin := load("res://assets/kaykit/dungeon/banner_red.gltf.glb") as PackedScene
	var muro_roto := load("res://assets/kaykit/dungeon/wall_broken.gltf.glb") as PackedScene
	var escombro := load("res://assets/kaykit/dungeon/rubble_large.gltf.glb") as PackedScene

	# Cuatro columnas en las esquinas de la arena, con antorchas cálidas.
	var esquinas := [
		Vector3(-ANCHO * 0.5 + 3.0, 0, -LARGO * 0.5 + 3.0),
		Vector3(-ANCHO * 0.5 + 3.0, 0, LARGO * 0.5 - 3.0),
		Vector3(BORDE_ARENA - 3.0, 0, -LARGO * 0.5 + 3.0),
		Vector3(BORDE_ARENA - 3.0, 0, LARGO * 0.5 - 3.0),
	]
	for punto in esquinas:
		_instanciar_prop(columna, punto, 1.7)
		_instanciar_prop(antorcha, punto + Vector3(0, 2.8, 0), 1.4)
		var luz := OmniLight3D.new()
		luz.position = punto + Vector3(0, 3.1, 0)
		luz.omni_range = 10.0
		luz.light_energy = 1.25
		luz.light_color = Color(1.0, 0.58, 0.26)
		add_child(luz)

	# Ritmo visual en los muros norte y sur de la arena.
	for x in [-22.0, -8.0, 4.0]:
		_instanciar_prop(columna, Vector3(x, 0, -LARGO * 0.5 + 1.6), 1.5)
		_instanciar_prop(columna, Vector3(x, 0, LARGO * 0.5 - 1.6), 1.5)

	for x in [-18.0, 0.0]:
		_instanciar_prop(banderin, Vector3(x, 2.2, -LARGO * 0.5 + 1.1), 1.35)

	# Cobertura: muros derruidos y escombros, siempre fuera del carril central.
	_instanciar_prop(muro_roto, Vector3(-19.0, 0, -6.0), 1.2)
	_instanciar_prop(muro_roto, Vector3(-19.0, 0, 6.0), 1.2)
	_instanciar_prop(escombro, Vector3(-13.0, 0, 10.0), 1.0)
	_instanciar_prop(escombro, Vector3(-4.0, 0, -10.0), 0.9)
	_instanciar_prop(escombro, Vector3(-25.0, 0, 0.0), 1.1)
	_crear_caja_estatica(Vector3(-19.0, 1.0, -6.0), Vector3(2.6, 2.0, 2.0), Color(0.28, 0.25, 0.22))
	_crear_caja_estatica(Vector3(-19.0, 1.0, 6.0), Vector3(2.6, 2.0, 2.0), Color(0.28, 0.25, 0.22))


func _instanciar_prop(escena: PackedScene, pos: Vector3, escala: float) -> void:
	if escena == null:
		return
	var nodo := escena.instantiate() as Node3D
	if nodo == null:
		return
	nodo.position = pos
	nodo.scale = Vector3.ONE * escala
	add_child(nodo)


func _crear_zona_segura() -> void:
	# Fuente: cura durante preparación y descanso.
	var base := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 3.2
	cilindro.bottom_radius = 3.4
	cilindro.height = 0.5
	base.mesh = cilindro
	base.position = _fuente + Vector3(0, 0.25, 0)
	base.material_override = _material(Color(0.34, 0.29, 0.23))
	add_child(base)

	var agua := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 2.7
	disco.bottom_radius = 2.7
	disco.height = 0.08
	agua.mesh = disco
	agua.position = _fuente + Vector3(0, 0.53, 0)
	var material_agua := _material(Color(0.18, 0.62, 0.68))
	material_agua.emission_enabled = true
	material_agua.emission = Color(0.15, 0.75, 0.80)
	material_agua.emission_energy_multiplier = 0.8
	agua.material_override = material_agua
	add_child(agua)

	var pilar := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.5, 2.2, 0.5)
	pilar.mesh = caja
	pilar.position = _fuente + Vector3(0, 1.4, 0)
	pilar.material_override = _material(Color(0.45, 0.38, 0.28))
	add_child(pilar)
	_etiqueta_mundo("FUENTE", _fuente + Vector3(0, 2.9, 0), Color(0.55, 0.95, 0.95))
	var luz_agua := OmniLight3D.new()
	luz_agua.position = _fuente + Vector3(0, 2.0, 0)
	luz_agua.omni_range = 7.0
	luz_agua.light_energy = 0.8
	luz_agua.light_color = Color(0.35, 0.85, 0.95)
	add_child(luz_agua)

	# Obelisco de talentos.
	var obelisco := MeshInstance3D.new()
	var prisma := PrismMesh.new()
	prisma.size = Vector3(1.1, 3.2, 1.1)
	obelisco.mesh = prisma
	obelisco.position = _obelisco + Vector3(0, 1.6, 0)
	var material_obelisco := _material(Color(0.38, 0.22, 0.55))
	material_obelisco.emission_enabled = true
	material_obelisco.emission = Color(0.65, 0.30, 0.95)
	material_obelisco.emission_energy_multiplier = 1.2
	obelisco.material_override = material_obelisco
	add_child(obelisco)
	_etiqueta_mundo("TALENTOS", _obelisco + Vector3(0, 3.7, 0), Color(0.82, 0.62, 1.0))
	var luz_obelisco := OmniLight3D.new()
	luz_obelisco.position = _obelisco + Vector3(0, 2.0, 0)
	luz_obelisco.omni_range = 7.0
	luz_obelisco.light_energy = 0.9
	luz_obelisco.light_color = Color(0.65, 0.36, 1.0)
	add_child(luz_obelisco)

	# Círculo de campeones.
	var circulo := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 5.7
	toro.outer_radius = 6.0
	circulo.mesh = toro
	circulo.position = Vector3(18.0, 0.04, 0)
	circulo.material_override = _material(Color(0.64, 0.48, 0.22))
	add_child(circulo)
	_etiqueta_mundo("CAMPEONES", Vector3(18.0, 2.6, 0), Color(1.0, 0.84, 0.45))


func _etiqueta_mundo(texto: String, pos: Vector3, color: Color) -> void:
	var etiqueta := Label3D.new()
	etiqueta.text = texto
	etiqueta.font_size = 56
	etiqueta.pixel_size = 0.006
	etiqueta.outline_size = 10
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.modulate = color
	etiqueta.position = pos
	add_child(etiqueta)


func _crear_puerta() -> void:
	_puerta = PuertaArena.new()
	add_child(_puerta)
	_puerta.global_position = Vector3(BORDE_ARENA, 0, 0)
	_puerta.abrir()


func _crear_bandera() -> void:
	_bandera = RebellionBanner.crear()
	add_child(_bandera)
	_bandera.global_position = CENTRO_ARENA


func _crear_jugador() -> void:
	_crear_jugador_local()


func _crear_tienda() -> void:
	_tienda = ShopPedestal.new()
	add_child(_tienda)
	_tienda.global_position = Vector3(27.0, 0, 8.0)


func _crear_camara() -> void:
	_camara = ArenaCamera.new()
	add_child(_camara)
	_camara.objetivo = _jugador
	_camara.limites = Vector2(ANCHO * 0.5 - 9.0, LARGO * 0.5 - 7.0)
	_camara.size = 26.0
	_camara.global_position = _jugador.global_position + _camara.desplazamiento
	_camara.current = true


func _crear_armeria() -> void:
	var armas := WeaponItem.crear_catalogo_base()
	var posiciones := [Vector3(18.0, 0, 7.0), Vector3(18.0, 0, 0.0), Vector3(18.0, 0, -7.0)]
	for i in armas.size():
		var pedestal := ArmoryPedestal.new()
		add_child(pedestal)
		pedestal.global_position = posiciones[i]
		pedestal.configurar(armas[i])
		pedestal.es_campeon = true
		_pedestales.append(pedestal)


func _crear_oleadas() -> void:
	_oleadas = WaveManager.new()
	if "--red-rapida" in OS.get_cmdline_user_args():
		_oleadas.espera_inicial = 0.5
		_oleadas.espera_entre_oleadas = 1.0
		_oleadas.duracion_entrada = 0.5
		_oleadas.intervalo_spawn = 0.1
	add_child(_oleadas)
	_oleadas.iniciar(jugadores, _bandera, _puntos_spawn, self)


func _crear_publico() -> void:
	_publico = AudienceFury.new()
	add_child(_publico)
	_publico.iniciar(_jugador, CENTRO_ARENA, RADIO_PUBLICO)


func _crear_hud() -> void:
	_hud = ArenaHUD.new()
	add_child(_hud)
	_hud.configurar(_jugador, _oleadas, _bandera, self)


func _conectar() -> void:
	_oleadas.entrada_iniciada.connect(_al_entrada_iniciada)
	_oleadas.oleada_iniciada.connect(_al_iniciar_oleada)
	_oleadas.oleada_terminada.connect(_al_terminar_oleada)
	_oleadas.oro_ganado.connect(_al_ganar_oro)
	_oleadas.victoria.connect(_al_victoria)
	_bandera.destruida.connect(_al_destruir_bandera)
	if not _jugador.murio.is_connected(_al_morir_jugador):
		_jugador.murio.connect(_al_morir_jugador)
	if not _jugador.arma_cambiada.is_connected(_al_cambiar_arma):
		_jugador.arma_cambiada.connect(_al_cambiar_arma)
	_publico.furia_iniciada.connect(_al_furia_iniciada)


# --- Economía y armería ---------------------------------------------------

func _al_entrada_iniciada(duracion: float) -> void:
	_en_combate = false
	_tiempo_entrada = duracion
	if _puerta != null:
		_puerta.abrir()
	for jugador in jugadores:
		if jugador != null and is_instance_valid(jugador):
			jugador.aplicar_impulso_velocidad(1.35, duracion)
	if _hud != null:
		_hud.mostrar_mensaje("¡Corre a la arena! +35 % velocidad", 2.6)


func _al_iniciar_oleada(_numero: int, _total: int) -> void:
	_en_combate = true
	if _puerta != null:
		_puerta.cerrar()
	var dentro := false
	for jugador in jugadores:
		if jugador != null and is_instance_valid(jugador) and jugador.global_position.x > BORDE_ARENA:
			jugador.global_position = Vector3(BORDE_ARENA - 4.0, 0, 0)
			dentro = true
	if dentro and _hud != null:
		_hud.mostrar_mensaje("El portón se cerró: dentro de la arena", 2.2)
	if _bandera != null:
		_bandera.configurar_inmune(5.0)
	Sfx.reproducir("oleada", -5.0)
	if _publico != null:
		_publico.establecer_combate(true)


func _al_terminar_oleada(numero: int) -> void:
	_en_combate = false
	if _puerta != null:
		_puerta.abrir()
	if _publico != null:
		_publico.establecer_combate(false)
	if terminado:
		return
	game_state.agregar_oro(60 + numero * 15)
	game_state.otorgar_puntos_atributo(2)
	for jugador in jugadores:
		if jugador == null or not is_instance_valid(jugador):
			continue
		jugador.estadisticas.otorgar_puntos(2)
		jugador.otorgar_puntos_rojos(1)
		jugador.curar(jugador.estadisticas.salud_maxima * 0.25)
	if _hud != null:
		_hud.mostrar_mensaje("Oleada %d superada  ·  +2 puntos" % numero, 2.5)


func _al_ganar_oro(cantidad: int) -> void:
	if game_state.esta_terminado():
		return
	if _publico != null and _publico.congelando:
		return
	game_state.agregar_oro(cantidad)
	revisar_forjas_automaticas()


func _gastar_punto(atributo: StringName) -> void:
	if terminado:
		return
	if es_cliente:
		if _jugador != null:
			_jugador.gastar_punto_atributo(atributo)
		return
	if game_state.puntos_atributo <= 0:
		return
	if _jugador.gastar_punto_atributo(atributo):
		game_state.gastar_punto_atributo()


## Rota entre las skins cosméticas del orco (K).
func _ciclar_skin() -> void:
	if es_cliente:
		red.enviar_accion(&"skin", {})
		return
	_skin_actual = (_skin_actual + 1) % SKINS.size()
	var skin: Dictionary = SKINS[_skin_actual]
	for jugador in jugadores:
		if jugador != null and is_instance_valid(jugador):
			jugador.aplicar_skin(skin["tinte"])
	if _hud != null:
		_hud.mostrar_mensaje("Skin: %s" % skin["nombre"], 2.0)


func _alternar_bandera() -> void:
	if es_cliente:
		red.enviar_accion(&"bandera", {})
		return
	_interactuar_bandera(_jugador)


func _interactuar_bandera(jugador: GladiatorController) -> void:
	if terminado or _bandera == null or jugador == null:
		return
	if _bandera.esta_cargada():
		if jugador.global_position.x > BORDE_ARENA - 1.0:
			_avisar("El estandarte solo se coloca dentro de la arena.", 2.4)
			return
		_bandera.colocar(jugador.global_position)
		_avisar("Estandarte colocado. Defiéndelo.", 2.4)
		Sfx.reproducir("compra", -5.0)
		return
	if jugador.global_position.distance_to(_bandera.global_position) > 4.0:
		_avisar("Acércate al estandarte para cargarlo (G).", 2.0)
		return
	if _bandera.recoger(jugador):
		_avisar("Estandarte en mano: G para colocarlo.", 2.5)
		Sfx.reproducir("click", -8.0)


func _avisar(texto: String, duracion := 2.0) -> void:
	if _hud != null:
		_hud.mostrar_mensaje(texto, duracion)


func _interactuar_cercano() -> void:
	if terminado:
		return
	var pedestal := _pedestal_cercano()
	if pedestal != null:
		if _campeon_elegido:
			_avisar("Tu campeón ya está elegido. La clase es permanente.", 2.5)
			return
		if es_cliente:
			red.enviar_clase(pedestal.arma.id_clase())
			_avisar("Solicitando clase %s…" % pedestal.arma.nombre, 2.0)
			return
		if pedestal.comprar(_jugador):
			_campeon_elegido = true
			for otro in _pedestales:
				if otro != pedestal:
					otro.desactivar()
			_avisar("Campeón: %s" % pedestal.arma.nombre, 2.8)
			Sfx.reproducir("compra", -3.0)
		return
	if _tienda_cercana():
		if _hud != null:
			_hud.alternar_tienda()
		return
	if _jugador.global_position.distance_to(_obelisco) <= 4.5:
		if _hud != null:
			_hud.alternar_talentos()
		return
	if _jugador.global_position.distance_to(_fuente) <= 5.5:
		_avisar("La fuente restaura vida y maná fuera de combate.", 2.5)


func _tienda_cercana() -> bool:
	if _tienda == null or _jugador == null:
		return false
	return _jugador.global_position.distance_to(_tienda.global_position) <= RADIO_INTERACCION


func _pedestal_cercano() -> ArmoryPedestal:
	var mejor: ArmoryPedestal = null
	var mejor_distancia := RADIO_INTERACCION
	for pedestal in _pedestales:
		if pedestal.vendida:
			continue
		var distancia := _jugador.global_position.distance_to(pedestal.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = pedestal
	return mejor


func puede_comprar_objeto(item: ItemData) -> bool:
	return puede_comprar_para(_jugador, item)


func puede_comprar_para(jugador: GladiatorController, item: ItemData) -> bool:
	if item == null or terminado or jugador == null or jugador.inventario == null:
		return false
	if jugador.global_position.x <= BORDE_ARENA + 1.0:
		return false
	var inventario := jugador.inventario
	var receta := inventario.receta_completada_por(item)
	var coste := item.precio + (receta.precio_forja if receta != null else 0)
	if game_state.oro < coste:
		return false
	if receta != null:
		return true
	return inventario.espacio_para(item)


## Compra un objeto y ejecuta la forja automática en cadena.
func comprar_objeto(item: ItemData) -> bool:
	if es_cliente:
		if not puede_comprar_objeto(item):
			_avisar("No puedes comprar ese objeto ahora.", 2.0)
			return false
		red.enviar_accion(&"comprar", {"id": item.id})
		_avisar("Compra solicitada: %s" % item.nombre, 2.0)
		return true
	return comprar_para(_jugador, item)


func comprar_para(jugador: GladiatorController, item: ItemData) -> bool:
	if not puede_comprar_para(jugador, item):
		if jugador != null and game_state.oro < item.precio:
			_avisar("Necesitas %d de oro" % item.precio, 2.0)
		else:
			_avisar("La mochila está llena y no completa ninguna receta", 2.5)
		return false
	var inventario := jugador.inventario
	var receta := inventario.receta_completada_por(item)
	var forjados: PackedStringArray = []

	if receta != null:
		oro -= item.precio + receta.precio_forja
		var creado := inventario.forjar_con(item, receta)
		if creado == null:
			oro += item.precio + receta.precio_forja
			_avisar("No se pudo completar la forja", 2.0)
			return false
		forjados.append(creado.nombre)
		var actual := creado
		for i in 4:
			var siguiente := inventario.receta_completada_por(actual)
			if siguiente == null or game_state.oro < siguiente.precio_forja:
				break
			game_state.gastar_oro(siguiente.precio_forja)
			var encadenado := inventario.forjar_con(actual, siguiente)
			if encadenado == null:
				game_state.agregar_oro(siguiente.precio_forja)
				break
			forjados.append(encadenado.nombre)
			actual = encadenado
		_avisar("Forjado: %s" % " > ".join(forjados), 3.0)
	else:
		if not inventario.agregar(item):
			_avisar("La mochila está llena", 2.0)
			return false
		game_state.gastar_oro(item.precio)
		_avisar("Comprado: %s" % item.nombre, 2.0)

	if not es_servidor:
		Sfx.reproducir("compra", -3.0)
	return true


## Vende un objeto del inventario del jugador y suma su precio de venta al oro.
func vender_objeto(jugador: GladiatorController, indice: int) -> bool:
		if jugador == null or jugador.inventario == null:
			return false
		var item := jugador.inventario.extraer(indice)
		if item == null:
			return false
		var ganancia := maxi(1, int(item.precio / 2.0))
		oro += ganancia
		_avisar("Vendido: %s  ·  +%d oro" % [item.nombre, ganancia], 2.0)
		Sfx.reproducir("venta", -3.0)
		return true

## Revisa si algún objeto del inventario completa una receta y hay oro para forjar.
## Se llama al ganar oro y al entrar a la tienda. Forja en cadena hasta que no sea posible.
func revisar_forjas_automaticas() -> void:
		var jugador := _jugador
		if jugador == null or jugador.inventario == null:
			return
		var inventario := jugador.inventario
		var hizo_algo := true
		var iteraciones := 0
		while hizo_algo and iteraciones < 10:
			hizo_algo = false
			iteraciones += 1
			for i in inventario.ranuras.size():
				var ranura := inventario.ranuras[i]
				var item: ItemData = ranura.get("item")
				if item == null:
					continue
				var receta := inventario.receta_completada_por(item)
				if receta == null:
					continue
				var coste := receta.precio_forja
				if oro < coste:
					continue
				oro -= coste
				var creado := inventario.forjar_con(item, receta)
				if creado == null:
					oro += coste
					continue
				hizo_algo = true
				_avisar("Forjado automático: %s" % creado.nombre, 2.5)
				break


func _actualizar_pista() -> void:
	if _hud == null or _jugador == null or terminado:
		return
	var pedestal := _pedestal_cercano()
	if pedestal != null:
		if _campeon_elegido:
			_texto_pista = "Campeón elegido  ·  la clase es permanente"
		else:
			_texto_pista = "F — Elegir campeón: %s (gratis)" % pedestal.arma.nombre
		_hud.establecer_pista(_texto_pista)
		return
	if _tienda_cercana():
		_texto_pista = "F — Mercader de la Rebelión: objetos y forja"
	elif _jugador.global_position.distance_to(_obelisco) <= 4.5:
		_texto_pista = "F — Obelisco de talentos (T)"
	elif _jugador.global_position.distance_to(_fuente) <= 5.5:
		_texto_pista = "Fuente: restaura vida y maná fuera de combate"
	else:
		_texto_pista = ""
	_hud.establecer_pista(_texto_pista)


func pista_actual() -> String:
	return _texto_pista


func nombre_skin() -> String:
	if _skin_actual >= 0 and _skin_actual < SKINS.size():
		return str(SKINS[_skin_actual]["nombre"])
	return "Tierra Baldía"


# --- Final de partida -----------------------------------------------------

func _al_cambiar_arma(arma: WeaponItem) -> void:
	if _hud != null and arma != null:
		_hud.mostrar_mensaje("Equipado: %s" % arma.nombre, 2.0)


func _al_furia_iniciada(duracion: float) -> void:
	_avisar("¡El público se aburre! Muévete. (%.0f s)" % duracion, 2.0)


func _al_morir_jugador() -> void:
	var vivos := 0
	for jugador in jugadores:
		if jugador != null and is_instance_valid(jugador) and not jugador.esta_muerto:
			vivos += 1
	if vivos == 0:
		_finalizar("DERROTA", "Todos los gladiadores han caído.")
		return
	if not es_servidor:
		return
	for jugador in jugadores:
		if jugador != null and is_instance_valid(jugador) and jugador.esta_muerto and jugador.revive_en <= 0.0:
			jugador.revive_en = TIEMPO_REVIVIR


func _actualizar_revives(delta: float) -> void:
	if not es_servidor:
		return
	for peer in jugadores_red.keys():
		var cuerpo: GladiatorController = jugadores_red[peer]
		if cuerpo == null or not is_instance_valid(cuerpo):
			continue
		if not cuerpo.esta_muerto or cuerpo.revive_en <= 0.0:
			continue
		var aliado := _aliado_vivo_mas_cercano(cuerpo)
		if aliado == null:
			cuerpo.revive_en = 0.0
			continue
		var cerca := cuerpo.global_position.distance_to(aliado.global_position) <= RADIO_REVIVIR
		var factor := FACTOR_REVIVIR_CERCA if cerca else 1.0
		cuerpo.revive_en = maxf(0.0, cuerpo.revive_en - delta * factor)
		if cuerpo.revive_en > 0.0:
			continue
		var destino := aliado.global_position + Vector3(1.2, 0.0, 1.2)
		cuerpo.revivir_red(destino, 0.6)
		_eventos_red.append({
			"tipo": "revivir",
			"peer": peer,
			"punto": destino,
		})


func _aliado_vivo_mas_cercano(caido: GladiatorController) -> GladiatorController:
	var mejor: GladiatorController = null
	var mejor_distancia := INF
	for otro in jugadores_red.values():
		var cuerpo := otro as GladiatorController
		if cuerpo == null or cuerpo == caido or cuerpo.esta_muerto:
			continue
		var distancia := caido.global_position.distance_squared_to(cuerpo.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = cuerpo
	return mejor


func _al_destruir_bandera() -> void:
	_finalizar("DERROTA", "El estandarte de la rebelión ha caído.")


func _al_victoria() -> void:
	_finalizar("VICTORIA", "Las 20 oleadas han sido superadas.")


func _finalizar(titulo: String, detalle: String) -> void:
	if game_state.esta_terminado():
		return
	game_state.finalizar(titulo, detalle)
	for jugador in jugadores:
		if jugador != null and is_instance_valid(jugador):
			jugador.puede_moverse = false
	if _oleadas != null:
		_oleadas.set_process(false)
	if _publico != null:
		_publico.set_process(false)
	if _hud != null:
		_hud.cerrar_talentos()
		_hud.cerrar_tienda()
		_hud.mostrar_final("%s\n%s\n\nEnter para reintentar" % [titulo, detalle])
	if es_servidor:
		if red != null:
			red.difundir_fin(titulo, detalle)
		if _supabase != null:
			var lista: Array = []
			for peer in jugadores_red.keys():
				var cuerpo: GladiatorController = jugadores_red[peer]
				if cuerpo == null:
					continue
				lista.append({
					"clase": String(cuerpo.arma_actual.id_clase()) if cuerpo.arma_actual != null else "prisionero",
					"nivel": cuerpo.estadisticas.nivel,
				})
			_supabase.detener_latido()
			_supabase.registrar_partida(
				titulo,
				_oleadas.oleada_actual if _oleadas != null else 0,
				int(Time.get_unix_time_from_system() - _hora_inicio_partida),
				lista
			)
			_supabase.marcar_inactivo()
	else:
		Sfx.reproducir("victoria" if titulo == "VICTORIA" else "derrota")


func _exit_tree() -> void:
	if es_servidor and _supabase != null:
		_supabase.detener_latido()


func esta_congelado() -> bool:
	return _publico != null and _publico.congelando


# --- Utilidades -----------------------------------------------------------

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


func _crear_prop(pos: Vector3, tam: Vector3, color: Color) -> void:
	var nodo := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	nodo.mesh = caja
	nodo.position = pos
	nodo.material_override = _material(color)
	add_child(nodo)


func _crear_caja_estatica(pos: Vector3, tam: Vector3, color: Color) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.position = pos
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 1

	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tam
	forma.shape = caja
	cuerpo.add_child(forma)

	var visual := MeshInstance3D.new()
	var malla := BoxMesh.new()
	malla.size = tam
	visual.mesh = malla
	visual.material_override = _material(color)
	cuerpo.add_child(visual)
	add_child(cuerpo)


## Captura una imagen para revisar la dirección visual sin abrir el editor.
func _capturar() -> void:
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	var cerca := "--captura-cerca" in args
	var talentos := "--captura-talentos" in args
	var habilidad := "--captura-habilidad" in args
	var capturar_jefe := "--captura-jefe" in args
	var tienda := "--captura-tienda" in args
	var combate := "--captura-combate" in args or cerca or talentos or habilidad or capturar_jefe or tienda
	if combate:
		var sin_arma: bool = _jugador != null and _jugador.arma_actual != null and _jugador.arma_actual.clase == WeaponItem.Clase.PRISIONERO
		if sin_arma:
			var catalogo := WeaponItem.crear_catalogo_base()
			_jugador.equipar_arma(catalogo[2] if habilidad else catalogo[0])
		if talentos:
			_jugador.otorgar_puntos_rojos(8)
			_hud.alternar_talentos()
		if habilidad:
			_jugador.mana_actual = _jugador.estadisticas.mana_maximo
			var hab := _jugador.arma_actual.obtener_habilidad(3)
			if hab != null:
				_jugador._invocar_espiritu(hab, _jugador.global_position + Vector3(1.8, 0, 1.2))
			if _camara != null:
				_camara.size = 14.0
		elif capturar_jefe:
			var jefe := ArenaBossAI.crear(
				"res://assets/kaykit/skeletons/Skeleton_Mage.glb",
				Color(0.55, 0.95, 0.72), 1.5, "mago"
			)
			jefe.configurar_para_ronda(10)
			add_child(jefe)
			jefe.global_position = _jugador.global_position + Vector3(2.0, 0, -1.5)
			jefe.objetivo = _jugador
			if _camara != null:
				_camara.size = 14.0
		elif tienda:
			oro = 1600
			_jugador.inventario.agregar(ItemCatalog.obtener(&"brasa_forja"))
			_hud.alternar_tienda()
		elif cerca and _camara != null:
			_camara.size = 7.0
		await get_tree().create_timer(3.0 if (cerca or talentos or habilidad or capturar_jefe or tienda) else 8.5).timeout
	else:
		await get_tree().create_timer(2.5).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	var imagen := get_viewport().get_texture().get_image()
	var ruta := "res://captura.png"
	if cerca:
		ruta = "res://captura_cerca.png"
	elif talentos:
		ruta = "res://captura_talentos.png"
	elif habilidad:
		ruta = "res://captura_habilidad.png"
	elif capturar_jefe:
		ruta = "res://captura_jefe.png"
	elif tienda:
		ruta = "res://captura_tienda.png"
	elif combate:
		ruta = "res://captura_combate.png"
	var error := imagen.save_png(ProjectSettings.globalize_path(ruta))
	print("CAPTURA: guardada en ", ruta, " error=", error, " tamaño=", imagen.get_size())
	get_tree().quit()
