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
var gladiador_tracker: GladiadorTracker

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

## Barra de vida del jefe
var _jefe_barra: ProgressBar
var _jefe_label: Label
var _jefe_actual: ArenaBossAI
var _jefe_barra_nodo: Control
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
## peer -> último bloque estático («est») enviado, para no repetirlo cada tick.
var _estatico_jugador: Dictionary = {}
var _estaba_muerto := false
var _supabase: Supabase
var _menu: MenuRed
var _creador: CrearSala
## Se pone a true al salir al lobby para que la escena recargada abra el menú.
static var volver_al_menu := false
var _maestro: MaestroSalas
var _tactil: TouchControls
var _seleccion: SeleccionCampeon
var _ajustes: Ajustes
var _tactil_moviendo := false
var _tactil_ultimo_envio := 0
var _remota: SalaRemota
var _api_salas := ""
## Sala de espera tal como la manda el servidor: en cliente el WaveManager no
## corre, así que sin esto la cuenta atrás se quedaba clavada en 11 s.
var _lobby_red_activo := false
var _lobby_red_restante := 0.0
var _lobby_red_conectados := 1
var _servidor_publico_url := ""
var _hora_inicio_partida := 0.0


func _ready() -> void:
	Pausa.reanudar()
	# Sistema de diseño compartido: todo Control del árbol hereda la paleta, la
	# tipografía y los estilos de ForjaTema.
	get_tree().root.theme = ForjaTema.tema_global()
	_ajustes = Ajustes.cargar()
	_ajustes.aplicar()
	if "--maestro" in OS.get_cmdline_user_args():
		_iniciar_maestro()
		return
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
	elif _necesita_menu() or volver_al_menu:
		volver_al_menu = false
		_mostrar_menu()
	else:
		_iniciar_local()

	var args := OS.get_cmdline_user_args()
	if "--captura" in args or "--captura-combate" in args or "--captura-cerca" in args or "--captura-talentos" in args or "--captura-habilidad" in args or "--captura-jefe" in args or "--captura-tienda" in args or "--captura-fin" in args or "--captura-campeon" in args or "--captura-menu" in args or "--captura-apodo" in args or "--captura-ficha" in args or "--captura-inicio" in args or "--captura-arquetipos" in args:
		_capturar()

	# Cargar un GLB cuesta ~55 ms la primera vez (medido) y se notaba como tirón
	# al invocar al espíritu o al lanzar ciertas habilidades: se precarga aquí.
	_precalentar_recursos()


func _precalentar_recursos() -> void:
	# En headless las pruebas usan el renderer dummy: instanciar las escenas solo
	# escupe "Parameter \"material\" is null" y no calienta nada útil.
	if DisplayServer.get_name() == "headless":
		return
	var rutas: Array = [
		"res://assets/kaykit/skeletons/Skeleton_Warrior.glb",
		"res://assets/kaykit/skeletons/Skeleton_Rogue.glb",
		"res://assets/kaykit/skeletons/Skeleton_Mage.glb",
		"res://assets/kaykit/adventurers/Knight.glb",
		"res://assets/kaykit/adventurers/Barbarian.glb",
	]
	CharacterVisual.precargar(rutas)
	var escenas: Array[PackedScene] = []
	for arma in WeaponItem.crear_catalogo_base():
		if arma.escena_visual != null:
			escenas.append(arma.escena_visual)
		for hab in arma.habilidades:
			if hab != null and hab.escena_efecto != null:
				escenas.append(hab.escena_efecto)
	for escena in escenas:
		var nodo := escena.instantiate()
		nodo.free()


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
	_api_salas = _resolver_api()
	if es_servidor and _servidor_publico_url.is_empty():
		_servidor_publico_url = OS.get_environment("SERVER_PUBLIC_URL").strip_edges()
		if _servidor_publico_url.is_empty():
			_servidor_publico_url = str(ProjectSettings.get_setting("red/servidor_publico_url", ""))


func _resolver_api() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--api="):
			return arg.substr("--api=".length()).strip_edges()
	var env := OS.get_environment("SALA_API").strip_edges()
	if not env.is_empty():
		return env
	if OS.has_feature("web"):
		var consulta = JavaScriptBridge.eval(
			"(new URLSearchParams(window.location.search)).get('api') || ''"
		)
		if consulta is String and not consulta.is_empty():
			return consulta.strip_edges()
	return str(ProjectSettings.get_setting("red/api_url", "")).strip_edges()


func _necesita_menu() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if "--menu-red" in OS.get_cmdline_user_args():
		return true
	if "--captura-menu" in OS.get_cmdline_user_args():
		return true
	return OS.has_feature("web") or OS.has_feature("mobile")


## Quita el lobby de encima de la arena (sólo si existe).
func _cerrar_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.queue_free()
		_menu = null


func _mostrar_menu() -> void:
	_menu = MenuRed.new()
	add_child(_menu)
	_menu.configurar(url_servidor)
	_menu.jugar_solo.connect(_iniciar_local)
	_menu.unirse.connect(_iniciar_cliente_con_url)
	_menu.crear_sala.connect(_al_crear_sala)


func _al_crear_sala() -> void:
	# En Web y APK la sala la crea el servidor maestro en la nube: el navegador
	# no puede abrir puertos ni lanzar un servidor.
	if OS.has_feature("web") or OS.has_feature("mobile"):
		_al_crear_sala_remota()
		return
	# En escritorio el host no instala nada: el juego descarga cloudflared si
	# falta, abre el túnel y lanza el servidor headless que se anuncia.
	if _creador == null:
		_creador = CrearSala.new()
		_creador.name = "CrearSala"
		add_child(_creador)
		_creador.estado.connect(_al_estado_creacion)
		_creador.lista.connect(_al_sala_lista)
		_creador.fallo.connect(_al_fallo_creacion)
	_creador.crear()


func _al_crear_sala_remota() -> void:
	if _remota == null:
		_remota = SalaRemota.new()
		_remota.name = "SalaRemota"
		add_child(_remota)
		_remota.lista.connect(_al_sala_remota_lista)
		_remota.fallo.connect(_al_fallo_creacion)
	_remota.configurar(_api_salas)
	if _menu != null and is_instance_valid(_menu):
		_menu.estado_creacion("Pidiendo sala al servidor…")
	_remota.crear()


func _al_sala_remota_lista(url: String) -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.sala_creada(url)
		_menu.queue_free()
		_menu = null
	_iniciar_cliente_con_url(url)


func _al_estado_creacion(texto: String) -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.estado_creacion(texto)


func _al_sala_lista(url_local: String, url_publica: String) -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.sala_creada(url_publica)
		_menu.queue_free()
		_menu = null
	# El host entra como cliente por localhost: el servidor es headless.
	_iniciar_cliente_con_url(url_local)


func _al_fallo_creacion(motivo: String) -> void:
	push_warning("[SALA] %s" % motivo)
	if _menu != null and is_instance_valid(_menu):
		_menu.sala_fallida(motivo)


func _iniciar_cliente_con_url(direccion: String) -> void:
	es_cliente = true
	url_servidor = direccion
	_cerrar_menu()
	_iniciar_cliente()


func _crear_estado_partida() -> void:
	# Servidor y partida local comparten economía: sin GameState el servidor
	# reventaba al pagar oleadas o al comprar en la tienda.
	if game_state != null:
		return
	game_state = GameState.new()
	game_state.name = "GameState"
	add_child(game_state)
	game_state.oro_cambiado.connect(_al_oro_local)
	game_state.puntos_cambiados.connect(_al_puntos_local)
	game_state.partida_terminada.connect(_finalizar)


func _iniciar_local() -> void:
	# El menú es un CanvasLayer a pantalla completa: si sobrevive al arranque de
	# la partida tapa el HUD (se veía "no aparece el HUD móvil" hasta que se
	# volvía al menú y desde allí se entraba de nuevo).
	_cerrar_menu()
	_crear_estado_partida()

	enemy_tracker = EnemyTracker.new()
	enemy_tracker.name = "EnemyTracker"
	add_child(enemy_tracker)
	enemy_tracker.add_to_group("enemy_tracker")

	gladiador_tracker = GladiadorTracker.new()
	gladiador_tracker.name = "GladiadorTracker"
	add_child(gladiador_tracker)
	gladiador_tracker.add_to_group("gladiador_tracker")

	_crear_jugador_local()
	_crear_camara()
	_crear_armeria()
	_crear_tienda()
	_crear_oleadas()
	_crear_publico()
	_crear_hud()
	if _hud != null:
		_hud.establecer_jugador(Perfil.apodo())
	_crear_controles_tactiles()
	_conectar()
	# Apodo (primera vez) y forja de campeones: también cuando se entra desde el
	# menú del lobby, no sólo en el arranque directo.
	if not _en_captura():
		call_deferred("_pedir_apodo_y_campeon")


func _process(delta: float) -> void:
	_actualizar_pista()
	if es_servidor:
		# Acumulador con resta, no a cero: con frames de 16,6 ms (cap de 60 fps) el
		# umbral de 66,6 ms no se alcanzaba hasta el quinto frame y el tick caía a
		# 12 Hz. Restando se conserva el sobrante y la media vuelve a 15 Hz.
		_tiempo_snapshot += delta
		while _tiempo_snapshot >= 1.0 / 15.0:
			_tiempo_snapshot -= 1.0 / 15.0
			_enviar_snapshot()
		_actualizar_revives(delta)
		_curar_en_zona_segura(delta)
	elif es_cliente:
		pass
	else:
		_curar_en_zona_segura(delta)
	_tiempo_entrada = maxf(0.0, _tiempo_entrada - delta)
	_actualizar_lobby()


# --- Red cooperativa ------------------------------------------------------

func _iniciar_servidor() -> void:
	# El servidor no dibuja: con el frame libre corre a 145 fps y gasta un 23 % de
	# núcleo para nada. La física ya va a 60 Hz fija, así que se limita el bucle.
	Engine.max_fps = 60
	_crear_estado_partida()
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
		_hud.establecer_jugador(Perfil.apodo())
	# En una sala también hay capa táctil: sin esto el móvil entraba al combate
	# con el HUD de escritorio (minimapa y QWER) y sin joystick.
	_crear_controles_tactiles()
	if _hud != null:
		_hud.mostrar_mensaje("Conectando al servidor cooperativo…", 6.0)
	if url_servidor.is_empty():
		url_servidor = "ws://127.0.0.1:%d" % puerto_red
	red.unirse(url_servidor)


func _crear_jugador_local() -> void:
	_jugador = _instanciar_gladiador(Vector3(24.0, 0, 0), 0)
	jugadores.append(_jugador)
	_jugador.murio.connect(_al_morir_jugador.bind(_jugador))
	var tracker = get_tree().get_first_node_in_group("gladiador_tracker")
	if tracker != null:
		tracker.registrar(_jugador)
		_jugador.murio.connect(_al_morir_desregistrar_local)


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
	# El bloque estático viaja solo cuando cambia y el snapshot se difunde a todos:
	# al entrar alguien hay que reenviar el de todos o el nuevo cliente se queda
	# sin las clases/atributos de los que ya estaban.
	_estatico_jugador.clear()
	var indice := jugadores_red.size()
	var posiciones := [Vector3(24.0, 0, 0), Vector3(24.0, 0, 4.0), Vector3(24.0, 0, -4.0)]
	var cuerpo := _instanciar_gladiador(posiciones[indice % posiciones.size()], indice)
	cuerpo.red = red
	jugadores_red[peer] = cuerpo
	jugadores.append(cuerpo)
	cuerpo.murio.connect(_al_morir_jugador.bind(cuerpo))
	var _cb_ataque_red := _al_ataque_red.bind(peer)
	cuerpo.ataque_basico.connect(_cb_ataque_red)
	var tracker = get_tree().get_first_node_in_group("gladiador_tracker")
	if tracker != null:
		tracker.registrar(cuerpo)
		cuerpo.murio.connect(_al_morir_desregistrar_remoto.bind(cuerpo))
	if _oleadas != null:
		_oleadas.agregar_jugador(cuerpo)
		# Si alguien entra con la cuenta atrás casi terminada, se le dan unos
		# segundos para elegir campeón en la forja.
		_oleadas.asegurar_preparacion(8.0)
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
	_estatico_jugador.erase(peer)
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
	if arma == null:
		return
	cuerpo.equipar_arma(arma)
	# Si todos los conectados ya tienen clase, la primera oleada empieza ya.
	if _oleadas != null and _oleadas.en_espera():
		var todos_listos := true
		for otro in jugadores_red.values():
			if otro.arma_actual == null:
				todos_listos = false
				break
		if todos_listos:
			_oleadas.acortar_preparacion(2.0)


func aplicar_accion_red(peer: int, accion: StringName, datos: Dictionary) -> void:
	var cuerpo: GladiatorController = jugadores_red.get(peer)
	if cuerpo == null:
		return
	# Las acciones de prueba se atienden antes del filtro de muerte: si no,
	# debug_curar nunca podría revivir a un gladiador caído.
	if _aplicar_accion_prueba(cuerpo, accion):
		return
	if cuerpo.esta_muerto:
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
		_:
			pass


## Acciones de prueba (solo con --red-rapida). Devuelve true si la atendió.
func _aplicar_accion_prueba(cuerpo: GladiatorController, accion: StringName) -> bool:
	if not ("--red-rapida" in OS.get_cmdline_user_args()):
		return false
	match accion:
		&"debug_morir":
			cuerpo.recibir_dano(999999.0, GladiatorStats.TIPO_VERDADERO)
		&"debug_curar":
			if cuerpo.esta_muerto:
				cuerpo.revivir_red(cuerpo.global_position, 1.0)
			else:
				cuerpo.salud_actual = cuerpo.estadisticas.salud_maxima
				cuerpo.mana_actual = cuerpo.estadisticas.mana_maximo
				cuerpo.escudo_actual = 0.0
		&"debug_base":
			# Devuelve al gladiador a la base para probar la tienda sin esperar
			# a que la oleada termine y se abra el portón.
			cuerpo.global_position = _fuente + Vector3(-2.0, 0, 0)
			cuerpo.detener()
		_:
			return false
	return true


func _preparar_punto_red(cuerpo: GladiatorController, punto) -> void:
	if punto is Vector3:
		cuerpo.punto_red = punto
		cuerpo.tiene_punto_red = true
	else:
		cuerpo.tiene_punto_red = false


func _al_ataque_red(_objetivo, _dano, critico: bool, peer: int) -> void:
	_eventos_red.append({"tipo": "ataque", "peer": peer, "critico": critico})


## Ficha de cada campeón para la pantalla de selección: números reales del
## sistema de estadísticas con el arma de la clase, no valores inventados.
## Una corrida de captura no debe abrir la forja salvo que se pida.
func _en_captura() -> bool:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--captura"):
			return true
	return false


func _perfiles_campeon() -> Array:
	var salida: Array = []
	for arma in WeaponItem.crear_catalogo_base():
		if arma == null:
			continue
		var clase := arma.id_clase()
		if clase == &"prisionero":
			continue
		var stats := GladiatorStats.new()
		stats.configurar_clase(clase)
		var rango := stats.rango_dano_ataque(arma.dano_ataque_base, arma.atributo_principal)
		var habilidades: Array = []
		for indice in arma.habilidades.size():
			var hab = arma.habilidades[indice]
			if hab != null:
				habilidades.append({
					"id": hab.id,
					"nombre": hab.nombre,
					"descripcion": hab.descripcion,
					"tecla": ["Q", "W", "E", "R"][indice] if indice < 4 else "",
					"coste_mana": hab.coste_mana,
				})
		salida.append({
			"clase": clase,
			"nombre": String(ForjaTema.NOMBRE_EMBLEMA.get(clase, clase)).to_upper(),
			"lema": String(ForjaTema.LEMA_CLASE.get(clase, "")),
			"rol": String(ForjaTema.ROL_CLASE.get(clase, "")),
			"descripcion": String(ForjaTema.DESCRIPCION_CLASE.get(clase, "")),
			"vida": stats.salud_maxima,
			"mana": stats.mana_maximo,
			"dano_min": rango.x,
			"dano_max": rango.y,
			"defensa": stats.mitigacion_fisica,
			"armadura": stats.armadura_total,
			"vel_ataque": stats.velocidad_ataque,
			"critico": stats.probabilidad_critico,
			"atributos": {
				&"fuerza": stats.fuerza_total,
				&"agilidad": stats.agilidad_total,
				&"inteligencia": stats.inteligencia_total,
			},
			"arma": {"nombre": arma.nombre, "base": arma.dano_ataque_base},
			"vis_arma": arma.escena_visual,
			"rot_arma": arma.rotacion_visual,
			"esc_arma": arma.escala_visual,
			"pesada": arma.clase == WeaponItem.Clase.BASTION,
			"xp_requerida": CurvaNivel.xp_requerida(1),
			"piel": nombre_skin(),
			"tinte": SKINS[_skin_actual]["tinte"] if _skin_actual >= 0 and _skin_actual < SKINS.size() else SKIN_TIERRA_BALDIA,
			"habilidades": habilidades,
		})
	return salida


## Abre la forja de campeones (modal). Se puede cerrar y elegir luego en la
## armería, así que no bloquea la partida.
func _mostrar_seleccion_campeon(forzar := false) -> void:
	if _seleccion != null or _jugador == null:
		return
	if _campeon_elegido and not forzar:
		return
	var perfiles := _perfiles_campeon()
	if perfiles.is_empty():
		return
	_seleccion = SeleccionCampeon.new()
	add_child(_seleccion)
	_seleccion.elegido.connect(_al_elegir_campeon)
	_seleccion.cerrado.connect(func() -> void: _seleccion = null)
	_seleccion.piel_siguiente.connect(_ciclar_skin_desde_forja)
	_seleccion.configurar(perfiles, _jugador.arma_actual.id_clase() if _jugador.arma_actual != null else &"")


## Cambiar el aspecto desde la forja de campeones: cicla la piel y refresca la
## etiqueta del modal para que el jugador vea el nombre nuevo.
func _ciclar_skin_desde_forja() -> void:
	_ciclar_skin()
	if _seleccion != null and is_instance_valid(_seleccion):
		_seleccion.actualizar_piel(nombre_skin())


## Primera pantalla: el apodo (sólo la primera vez) y luego la forja.
func _pedir_apodo_y_campeon() -> void:
	if not Perfil.tiene_apodo():
		var modal := NombreJugador.new()
		modal.name = "NombreJugador"
		add_child(modal)
		modal.confirmado.connect(_al_confirmar_apodo)
		modal.configurar()
		return
	if _hud != null:
		_hud.establecer_jugador(Perfil.apodo())
	_mostrar_seleccion_campeon()


func _al_confirmar_apodo(apodo: String) -> void:
	Perfil.guardar(apodo)
	if _hud != null:
		_hud.establecer_jugador(Perfil.apodo())
	call_deferred("_mostrar_seleccion_campeon")


func _al_elegir_campeon(clase: StringName) -> void:
	# Si la elección llega por código (red o pruebas) el modal no se cierra solo:
	# sin esto la forja se quedaba dibujada encima de la arena.
	if _seleccion != null and is_instance_valid(_seleccion):
		_seleccion.queue_free()
	_seleccion = null
	if es_cliente:
		if red != null:
			red.enviar_clase(clase)
		_avisar("Solicitando clase %s…" % String(ForjaTema.NOMBRE_EMBLEMA.get(clase, clase)), 2.5)
		return
	# La clase es permanente: una segunda elección no cambia nada.
	if _campeon_elegido:
		return
	var arma := _arma_por_clase(clase)
	if arma == null or _jugador == null:
		return
	_jugador.equipar_arma(arma)
	_campeon_elegido = true
	# Ya hay campeón: no tiene sentido esperar los 30 s de la sala de espera.
	if _oleadas != null:
		_oleadas.acortar_preparacion(2.0)
	for pedestal in _pedestales:
		pedestal.desactivar()
	_avisar("Campeón: %s" % arma.nombre, 2.8)
	Sfx.reproducir("compra", -3.0)


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
		"bajas": _oleadas.bajas if _oleadas != null else 0,
		"pendientes": _oleadas.get("_pendientes") if _oleadas != null else 0,
		"estado_oleada": int(_oleadas.get("_estado")) if _oleadas != null else 0,
		"tiempo_oleada": _oleadas.tiempo_restante() if _oleadas != null else 0.0,
		"espera": _oleadas.en_espera() if _oleadas != null else false,
		"prep": _oleadas.tiempo_preparacion() if _oleadas != null else 0.0,
		"conectados": maxi(1, jugadores_red.size()),
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
	var fila := {
		"id": peer,
		"pos": cuerpo.global_position,
		"rot": cuerpo.rotation.y,
		"salud": cuerpo.salud_actual,
		"mana": cuerpo.mana_actual,
		"escudo": cuerpo.escudo_actual,
		"revive_en": cuerpo.revive_en,
		# Se leen del componente de combate, que es quien los descuenta. El array
		# `_cooldowns` del controlador solo se escribía al lanzar y quedaba fijo:
		# el cliente recibía 14 s congelados y sobrescribía su cuenta local.
		"cooldowns": [
			cuerpo.cooldown_restante(0), cuerpo.cooldown_restante(1),
			cuerpo.cooldown_restante(2), cuerpo.cooldown_restante(3),
		],
		"inv": inventario,
		"xp": cuerpo.estadisticas.experiencia,
		"dano": cuerpo.dano_infligido,
		"recibido": cuerpo.dano_recibido,
		"muerto": cuerpo.esta_muerto,
	}
	# Lo que solo cambia al subir de nivel, comprar o gastar talentos se manda
	# cuando cambia: eran ~700 B por jugador y por tick (más de la mitad del
	# snapshot con 3 jugadores).
	var clase := &"prisionero"
	if cuerpo.arma_actual != null:
		clase = cuerpo.arma_actual.id_clase()
	var est := {
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
		"salud_max": cuerpo.estadisticas.salud_maxima,
		"mana_max": cuerpo.estadisticas.mana_maximo,
		"nivel": cuerpo.estadisticas.nivel,
		"puntos_libres": cuerpo.estadisticas.puntos_libres,
		"puntos_rojos": cuerpo.puntos_rojos,
		"rangos": cuerpo._rangos_habilidad.duplicate(),
		"desbloqueadas": cuerpo._habilidades_desbloqueadas.duplicate(),
		"talentos": cuerpo._talentos_activos.duplicate(),
	}
	if _estatico_jugador.get(peer, {}) != est:
		_estatico_jugador[peer] = est
		fila["est"] = est
	return fila


func _al_recibir_bienvenida(peer: int) -> void:
	_jugadores_remotos[peer] = _jugador
	_jugador.es_local_red = true
	print("[NET] jugador local listo: ", peer)
	if _hud != null:
		_hud.mostrar_mensaje("Conectado. Elegí tu campeón en la forja.", 3.0)
	if not _en_captura() and not _campeon_elegido:
		call_deferred("_pedir_apodo_y_campeon")


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
	if _hud != null and _hud.has_method("establecer_bajas"):
		_hud.establecer_bajas(int(datos.get("bajas", 0)))
	_lobby_red_activo = bool(datos.get("espera", _lobby_red_activo))
	_lobby_red_restante = float(datos.get("prep", _lobby_red_restante))
	_lobby_red_conectados = maxi(1, int(datos.get("conectados", _lobby_red_conectados)))
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
		if fila.has("est"):
			_aplicar_clase_mirror(cuerpo, StringName(fila["est"].get("clase", &"prisionero")))
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

	# Suelo de la arena usando meshes de KayKit para que no se vea plano.
	var suelo_tierra := load("res://assets/kaykit/dungeon/floor_dirt_large.gltf.glb") as PackedScene
	var suelo_baldosa := load("res://assets/kaykit/dungeon/floor_tile_large.gltf.glb") as PackedScene

	# Tiles de tierra en el área de combate principal.
	if suelo_tierra != null:
		for x in range(-int(ANCHO * 0.5), int(ANCHO * 0.5), 6):
			for z in range(-int(LARGO * 0.5), int(LARGO * 0.5), 6):
				var tile := suelo_tierra.instantiate() as Node3D
				if tile != null:
					tile.position = Vector3(float(x) + 3.0, 0.0, float(z) + 3.0)
					tile.scale = Vector3.ONE * 1.05
					# Va dentro del StaticBody del suelo: hereda su colisión.
					suelo.add_child(tile)

	# Baldosas en la zona segura (base).
	if suelo_baldosa != null:
		for x in range(int(BORDE_ARENA + 2), int(ANCHO * 0.5), 6):
			for z in range(-int(LARGO * 0.5), int(LARGO * 0.5), 6):
				var tile := suelo_baldosa.instantiate() as Node3D
				if tile != null:
					tile.position = Vector3(float(x) + 3.0, 0.015, float(z) + 3.0)
					tile.scale = Vector3.ONE * 1.05
					add_child(tile)

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
## La arena se llena con elementos visuales para que no se vea vacía.
func _crear_decoracion() -> void:
	var columna := load("res://assets/kaykit/dungeon/column.gltf.glb") as PackedScene
	var antorcha := load("res://assets/kaykit/dungeon/torch_lit.gltf.glb") as PackedScene
	var banderin := load("res://assets/kaykit/dungeon/banner_red.gltf.glb") as PackedScene
	var banderin_patron := load("res://assets/kaykit/dungeon/banner_patternA_red.gltf.glb") as PackedScene
	var muro_roto := load("res://assets/kaykit/dungeon/wall_broken.gltf.glb") as PackedScene
	var escombro := load("res://assets/kaykit/dungeon/rubble_large.gltf.glb") as PackedScene
	var barrera := load("res://assets/kaykit/dungeon/barrier.gltf.glb") as PackedScene

	# Columnas y antorchas en las cuatro esquinas de la arena.
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

	# Columnas adicionales a lo largo de los muros norte y sur.
	for x in [-26.0, -16.0, -6.0, 4.0, 14.0]:
		_instanciar_prop(columna, Vector3(x, 0, -LARGO * 0.5 + 1.6), 1.5)
		_instanciar_prop(columna, Vector3(x, 0, LARGO * 0.5 - 1.6), 1.5)
		_instanciar_prop(antorcha, Vector3(x, 2.8, -LARGO * 0.5 + 1.6), 1.2)
		_instanciar_prop(antorcha, Vector3(x, 2.8, LARGO * 0.5 - 1.6), 1.2)
		var luz_n := OmniLight3D.new()
		luz_n.position = Vector3(x, 3.1, -LARGO * 0.5 + 1.6)
		luz_n.omni_range = 8.0
		luz_n.light_energy = 1.0
		luz_n.light_color = Color(1.0, 0.55, 0.25)
		add_child(luz_n)
		var luz_s := OmniLight3D.new()
		luz_s.position = Vector3(x, 3.1, LARGO * 0.5 - 1.6)
		luz_s.omni_range = 8.0
		luz_s.light_energy = 1.0
		luz_s.light_color = Color(1.0, 0.55, 0.25)
		add_child(luz_s)

	# Banderas y estandartes en los muros.
	for x in [-22.0, -8.0, 6.0, 20.0]:
		_instanciar_prop(banderin, Vector3(x, 2.2, -LARGO * 0.5 + 1.1), 1.35)
		_instanciar_prop(banderin_patron, Vector3(x, 2.2, LARGO * 0.5 - 1.1), 1.35)

	# Cobertura: muros derruidos y escombros distribuidos por la arena.
	_instanciar_prop(muro_roto, Vector3(-24.0, 0, -10.0), 1.3)
	_instanciar_prop(muro_roto, Vector3(-24.0, 0, 10.0), 1.3)
	_instanciar_prop(muro_roto, Vector3(-19.0, 0, -6.0), 1.2)
	_instanciar_prop(muro_roto, Vector3(-19.0, 0, 6.0), 1.2)
	_instanciar_prop(muro_roto, Vector3(BORDE_ARENA - 2.0, 0, -14.0), 1.1)
	_instanciar_prop(muro_roto, Vector3(BORDE_ARENA - 2.0, 0, 14.0), 1.1)

	_instanciar_prop(escombro, Vector3(-17.0, 0, -14.0), 1.1)
	_instanciar_prop(escombro, Vector3(-13.0, 0, 10.0), 1.0)
	_instanciar_prop(escombro, Vector3(-4.0, 0, -10.0), 0.9)
	_instanciar_prop(escombro, Vector3(4.0, 0, 14.0), 1.0)
	_instanciar_prop(escombro, Vector3(14.0, 0, -14.0), 1.1)
	_instanciar_prop(escombro, Vector3(-25.0, 0, 0.0), 1.1)
	# Barreras bajas en los bordes laterales de la arena.
	_instanciar_prop(barrera, Vector3(-29.0, 0, -8.0), 1.0)
	_instanciar_prop(barrera, Vector3(-29.0, 0, 8.0), 1.0)
	_instanciar_prop(barrera, Vector3(BORDE_ARENA + 2.0, 0, -8.0), 1.0)
	_instanciar_prop(barrera, Vector3(BORDE_ARENA + 2.0, 0, 8.0), 1.0)

	_crear_caja_estatica(Vector3(-19.0, 1.0, -6.0), Vector3(2.6, 2.0, 2.0), Color(0.28, 0.25, 0.22))
	_crear_caja_estatica(Vector3(-19.0, 1.0, 6.0), Vector3(2.6, 2.0, 2.0), Color(0.28, 0.25, 0.22))
	_crear_caja_estatica(Vector3(20.0, 1.0, -12.0), Vector3(2.6, 2.0, 2.0), Color(0.28, 0.25, 0.22))
	_crear_caja_estatica(Vector3(20.0, 1.0, 12.0), Vector3(2.6, 2.0, 2.0), Color(0.28, 0.25, 0.22))


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
	# La elección de campeón vive en su propia pantalla (modal) desde el inicio
	# de la partida. En el mapa no queda nada que tocar: ni pedestales, ni
	# plataformas, ni etiquetas de "elegir".
	pass


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


## Controles táctiles: solo si la pantalla es táctil (o con --tactil para probar).
func _crear_controles_tactiles() -> void:
	if _jugador == null:
		return
	# `is_touchscreen_available()` miente en varios Android (devuelve false y la
	# partida arrancaba con la consola de escritorio, sin joystick). En móvil
	# siempre hay capa táctil.
	var pantalla_tactil := OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	if not pantalla_tactil and OS.has_feature("web"):
		# La web se puede forzar con ?tactil=1 (tablets, portátiles táctiles y las
		# pruebas automatizadas del HUD móvil).
		var consulta = JavaScriptBridge.eval(
			"(new URLSearchParams(window.location.search)).get('tactil') || ''"
		)
		pantalla_tactil = consulta is String and consulta == "1"
	if not pantalla_tactil and not ("--tactil" in OS.get_cmdline_user_args()):
		return
	_tactil = TouchControls.new()
	_tactil.name = "Tactil"
	add_child(_tactil)
	_tactil.configurar(_jugador)
	if _ajustes != null:
		_tactil.aplicar_escala(_ajustes.escala_tactil)
	_tactil.habilidad.connect(_al_habilidad_tactil)
	_tactil.mover.connect(_al_mover_tactil)
	_tactil.pausa.connect(_al_pausa_tactil)
	_tactil.interactuar.connect(_interactuar_cercano)
	_tactil.detener.connect(_al_detener_tactil)
	_tactil.tienda.connect(_al_tienda_tactil)
	# Mochila y ficha no pausan, pero si hay una tienda abierta (que sí pausa)
	# quedaría detrás: al abrir cualquiera de ellas se cierran los paneles.
	_tactil.al_abrir_panel = Callable(self, "_cerrar_paneles_juego")
	_tactil.talentos.connect(_al_talentos_tactil)
	# En móvil manda el HUD táctil: se apaga la consola de escritorio (comandos
	# QWER, ficha y estadísticas) para dejar la arena despejada.
	if _hud != null:
		_hud.establecer_modo_tactil(true)


## Cierra tienda y talentos (deja el árbol jugable) antes de abrir otro panel.
func _cerrar_paneles_juego() -> void:
	if _hud != null:
		_hud.cerrar_tienda()
		_hud.cerrar_talentos()


func _al_tienda_tactil() -> void:
	if _hud != null:
		_hud.alternar_tienda()


func _al_talentos_tactil() -> void:
	if _hud != null:
		_hud.alternar_talentos()


## Con el dedo no hay ratón para apuntar: la habilidad va al enemigo más cercano
## y, si no hay ninguno, hacia donde mira el gladiador.
func _punto_habilidad() -> Vector3:
	var origen := _jugador.global_position if _jugador != null else Vector3.ZERO
	var mejor: Node3D = null
	var mejor_distancia := INF
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		var cuerpo := enemigo as Node3D
		if cuerpo == null or not is_instance_valid(cuerpo) or not cuerpo.visible:
			continue
		var distancia := origen.distance_squared_to(cuerpo.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = cuerpo
	if mejor != null:
		return mejor.global_position
	if _jugador == null:
		return origen
	return origen - _jugador.global_transform.basis.z * 3.0


## Joystick: en local mueve directo; en red se manda la orden al servidor a
## 8 Hz mientras se mantiene la dirección (reutiliza la acción "mover").
func _al_mover_tactil(direccion: Vector2) -> void:
	if _jugador == null or _jugador.esta_muerto:
		return
	if es_cliente:
		var ahora := Time.get_ticks_msec()
		if direccion.length_squared() < 0.04:
			if _tactil_moviendo:
				_tactil_moviendo = false
				red.enviar_accion(&"detener", {})
				_jugador.mover_tactil(Vector2.ZERO)
			return
		if ahora - _tactil_ultimo_envio < 120:
			return
		_tactil_ultimo_envio = ahora
		_tactil_moviendo = true
		# Predicción: el avatar se mueve ya con el dedo; el servidor confirma.
		_jugador.mover_tactil(direccion)
		var punto := _jugador.global_position + Vector3(direccion.x, 0.0, direccion.y) * 3.0
		red.enviar_accion(&"mover", {"punto": punto})
		return
	_jugador.mover_tactil(direccion)


## Pausa táctil: abre Ajustes (volumen y tamaño de botones) sobre la partida.
func _al_pausa_tactil() -> void:
	if get_tree().paused:
		return
	var panel := SettingsPanel.new()
	add_child(panel)
	panel.configurar()
	panel.cerrado.connect(func() -> void:
		if _tactil != null and _ajustes != null:
			_tactil.aplicar_escala(_ajustes.escala_tactil)
	)


func _al_habilidad_tactil(slot: int) -> void:
	if _jugador == null or _jugador.esta_muerto:
		return
	_jugador.intentar_habilidad(slot, _punto_habilidad())


func _al_detener_tactil() -> void:
	if _jugador != null:
		_jugador.detener()


func _crear_hud() -> void:
	_hud = ArenaHUD.new()
	add_child(_hud)
	_hud.configurar(_jugador, _oleadas, _bandera, self)
	_hud.terminar_partida.connect(_al_pulsar_terminar)
	_hud.reintentar.connect(_al_reintentar)
	_hud.salir_lobby.connect(_al_salir_lobby)
	# Ficha del jugador: las bajas las cuenta el gestor de oleadas.
	if _oleadas != null and _hud.has_method("establecer_bajas"):
		_oleadas.enemigo_abatido.connect(_hud.establecer_bajas)

	# Barra de vida del jefe (oculta por defecto)
	_jefe_barra_nodo = Control.new()
	_jefe_barra_nodo.name = "JefeVida"
	_jefe_barra_nodo.visible = false
	_jefe_barra_nodo.anchor_left = 0.5
	_jefe_barra_nodo.anchor_right = 0.5
	_jefe_barra_nodo.anchor_top = 0.0
	_jefe_barra_nodo.anchor_bottom = 0.0
	_jefe_barra_nodo.offset_left = -250.0
	_jefe_barra_nodo.offset_right = 250.0
	_jefe_barra_nodo.offset_top = 40.0
	_jefe_barra_nodo.offset_bottom = 80.0
	_jefe_barra_nodo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_jefe_barra_nodo)

	var fondo := ColorRect.new()
	fondo.name = "Fondo"
	fondo.size = Vector2(500, 24)
	fondo.position = Vector2(0, 10)
	fondo.color = Color(0.2, 0.2, 0.2, 0.8)
	_jefe_barra_nodo.add_child(fondo)

	_jefe_barra = ProgressBar.new()
	_jefe_barra.name = "Barra"
	_jefe_barra.size = Vector2(480, 16)
	_jefe_barra.position = Vector2(10, 18)
	_jefe_barra.min_value = 0.0
	_jefe_barra.max_value = 100.0
	_jefe_barra.value = 100.0
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.1, 0.1, 0.1, 0.6)
	estilo.border_color = Color(0.5, 0.5, 0.5, 1.0)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	_jefe_barra.add_theme_stylebox_override("bg", estilo)
	var estilo_progreso := StyleBoxFlat.new()
	estilo_progreso.bg_color = Color(0.9, 0.3, 0.3, 1.0)
	estilo_progreso.set_corner_radius_all(3)
	_jefe_barra.add_theme_stylebox_override("fill", estilo_progreso)
	_jefe_barra_nodo.add_child(_jefe_barra)

	_jefe_label = Label.new()
	_jefe_label.name = "Label"
	_jefe_label.size = Vector2(480, 16)
	_jefe_label.position = Vector2(10, -4)
	_jefe_label.horizontal_alignment = 1
	_jefe_label.add_theme_font_size_override("font_size", 12)
	_jefe_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
	_jefe_label.text = "JEFE"
	_jefe_barra_nodo.add_child(_jefe_label)


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
	if _jugador != null and _camara != null:
		_jugador.recibio_dano.connect(_camara.agitar)
	_oleadas.jefe_invocado.connect(_al_jefe_invocado)
	if _jugador != null:
		_jugador.habilidad_mejorada.connect(_al_habilidad_mejorada)


# --- Notificaciones de habilidad ------------------------------------------

func _al_habilidad_mejorada(slot: int, habilidad: AbilityData, rango: int) -> void:
	var nombres_slot := ["Q", "W", "E", "R"]
	var nombre_slot: String = nombres_slot[slot] if slot < nombres_slot.size() else str(slot)
	var nombre_habilidad := habilidad.nombre if habilidad != null else "?"
	_avisar("¡%s subió a rango %d! (%s)" % [nombre_habilidad, rango, nombre_slot], 3.0)


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
	# En el cliente no existe GameState: la bolsa es el oro del snapshot. Sin esto,
	# aplicar un snapshot con la tienda abierta reventaba en `game_state.oro`.
	if item == null or terminado or jugador == null or jugador.inventario == null:
		return false
	if jugador.global_position.x <= BORDE_ARENA + 1.0:
		return false
	var inventario := jugador.inventario
	var receta := inventario.receta_completada_por(item)
	var coste := item.precio + (receta.precio_forja if receta != null else 0)
	var bolsa: int = game_state.oro if game_state != null else oro
	if bolsa < coste:
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
		if jugador != null and game_state != null and game_state.oro < item.precio:
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
		revisar_forjas_automaticas()
	else:
		if not inventario.agregar(item):
			_avisar("La mochila está llena", 2.0)
			return false
		game_state.gastar_oro(item.precio)
		_avisar("Comprado: %s" % item.nombre, 2.0)
		revisar_forjas_automaticas()

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
	if game_state != null:
		game_state.agregar_oro(ganancia)
	else:
		_oro_local += ganancia
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


## Sala de espera con cuenta atrás: se muestra mientras la partida prepara la
## primera oleada y desaparece al empezar el combate.
func _actualizar_lobby() -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	var terminado_ya: bool = game_state != null and game_state.esta_terminado()
	# En cliente el WaveManager está apagado a propósito: la espera viene en el
	# snapshot. Antes se leía `_oleadas.tiempo_preparacion()` sin arrancar y la
	# cuenta atrás se quedaba en 11 s para siempre (la partida parecía trabada).
	if es_cliente:
		if _lobby_red_activo and not terminado_ya:
			_hud.establecer_lobby(true, _lobby_red_restante, _lobby_red_conectados, 3, false)
		else:
			_hud.establecer_lobby(false, 0.0, 0, 0, false)
		return
	if _oleadas == null:
		return
	var visible := _oleadas.en_espera() and not terminado_ya and not _publico_bloquea_lobby()
	if not visible:
		_hud.establecer_lobby(false, 0.0, 0, 0, false)
		return
	var conectados := 1
	if es_servidor:
		conectados = maxi(1, jugadores_red.size())
	_hud.establecer_lobby(true, _oleadas.tiempo_preparacion(), conectados, 3, not (es_servidor or es_cliente))


func _publico_bloquea_lobby() -> bool:
	return false


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


## Barra de vida del jefe --------------------------------------------------

func _al_jefe_invocado(jefe: ArenaBossAI) -> void:
	if _jefe_actual != null and is_instance_valid(_jefe_actual):
		_jefe_actual.salud_cambiada.disconnect(_actualizar_barra_jefe)
		_jefe_actual.furia_activada.disconnect(_al_jefe_furia)
		_jefe_actual.murio.disconnect(_al_jefe_murio)

	_jefe_actual = jefe
	_jefe_barra_nodo.visible = true
	_jefe_barra.max_value = jefe.salud_maxima
	_jefe_barra.value = jefe.salud_actual
	_jefe_label.text = "JEFE · FASE 1"

	jefe.salud_cambiada.connect(_actualizar_barra_jefe)
	jefe.furia_activada.connect(_al_jefe_furia)
	jefe.murio.connect(_al_jefe_murio)


func _actualizar_barra_jefe(actual: float, maxima: float) -> void:
	if _jefe_barra_nodo == null or not _jefe_barra_nodo.visible:
		return
	_jefe_barra.max_value = maxima
	_jefe_barra.value = actual
	if actual <= 0.0:
		_jefe_barra_nodo.visible = false


func _al_jefe_furia(nivel: int) -> void:
	if _jefe_label != null:
		_jefe_label.text = "JEFE · FURIA %d" % nivel
	if _jefe_barra != null:
		var estilo_progreso := StyleBoxFlat.new()
		if nivel == 1:
			estilo_progreso.bg_color = Color(1.0, 0.6, 0.0, 1.0)  # naranja
		else:
			estilo_progreso.bg_color = Color(1.0, 0.1, 0.1, 1.0)  # rojo
		estilo_progreso.set_corner_radius_all(3)
		_jefe_barra.add_theme_stylebox_override("fill", estilo_progreso)


func _al_jefe_murio() -> void:
	if _jefe_barra_nodo != null:
		_jefe_barra_nodo.visible = false
	_jefe_actual = null


func _al_morir_jugador(caido: GladiatorController = null) -> void:
	# La señal `murio` sale antes de que el controlador copie `esta_muerto`, así
	# que el que acaba de caer se cuenta aparte con `caido` en lugar de mirar su
	# bandera (si no, nadie quedaba vivo y la cuenta atrás de revivir nunca
	# arrancaba).
	var vivos := 0
	for jugador in jugadores:
		if jugador == null or not is_instance_valid(jugador):
			continue
		if jugador == caido or jugador.esta_muerto:
			continue
		vivos += 1
	if vivos == 0:
		_finalizar("DERROTA", "Todos los gladiadores han caído.")
		return
	if not es_servidor:
		return
	for jugador in jugadores:
		if jugador == null or not is_instance_valid(jugador):
			continue
		if not (jugador == caido or jugador.esta_muerto):
			continue
		if jugador.revive_en <= 0.0:
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
	# En cliente `game_state` es null (la bolsa y los puntos vienen del snapshot):
	# no hay estado que marcar, pero los paneles y el cartel sí hay que ponerlos.
	if game_state != null:
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
		_hud.mostrar_final("%s\n%s" % [titulo, detalle], not es_cliente)
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
			if red != null:
				# Cerrar de inmediato pisaba el mensaje de fin: el cliente veía
				# "el servidor cerró la conexión" en vez de la pantalla de derrota.
				_cerrar_red_mas_tarde()
	else:
		Sfx.reproducir("victoria" if titulo == "VICTORIA" else "derrota")


func _cerrar_red_mas_tarde() -> void:
	if red == null:
		return
	await get_tree().create_timer(1.0).timeout
	if red != null:
		red.cerrar()


func _iniciar_maestro() -> void:
	_maestro = MaestroSalas.new()
	_maestro.name = "Maestro"
	add_child(_maestro)
	if not _maestro.iniciar():
		push_error("No se pudo iniciar el maestro de salas")


func _exit_tree() -> void:
	if es_servidor and _supabase != null:
		_supabase.detener_latido()
	# Al salir (o al pulsar TERMINAR, que recarga la escena) el host apaga el
	# servidor headless y el túnel que abrió el botón CREAR SALA.
	if _creador != null and is_instance_valid(_creador):
		_creador.cerrar()
	if _maestro != null and is_instance_valid(_maestro):
		_maestro.cerrar()
	if _remota != null and is_instance_valid(_remota):
		_remota.queue_free()

## Volver a jugar: recarga la escena (en local arranca otra partida; el host de
## una sala la rearma con la misma configuración).
func _al_reintentar() -> void:
	if es_servidor:
		_al_pulsar_terminar()
		return
	if es_cliente and red != null:
		red.cerrar()
	get_tree().reload_current_scene()


## Salir al lobby: recarga mostrando el menú de red (en Web/APK siempre; en
## escritorio se fuerza).
func _al_salir_lobby() -> void:
	volver_al_menu = true
	if es_servidor:
		_al_pulsar_terminar()
		return
	if es_cliente and red != null:
		red.cerrar()
	get_tree().reload_current_scene()


func _al_pulsar_terminar() -> void:
	if es_servidor:
		if red != null:
			red.cerrar()
		if _supabase != null:
			_supabase.marcar_inactivo()
			_supabase.detener_latido()
	get_tree().reload_current_scene()


func esta_congelado() -> bool:
	return _publico != null and _publico.congelando

func _al_oro_local(cantidad: int) -> void:
	_oro_local = cantidad

func _al_puntos_local(cantidad: int) -> void:
	_puntos_local = cantidad

func _al_morir_desregistrar_local() -> void:
	var tracker = get_tree().get_first_node_in_group("gladiador_tracker")
	if tracker != null:
		tracker.desregistrar(_jugador)

func _al_morir_desregistrar_remoto(cuerpo: GladiatorController) -> void:
	var tracker = get_tree().get_first_node_in_group("gladiador_tracker")
	if tracker != null:
		tracker.desregistrar(cuerpo)


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
	var fin := "--captura-fin" in args
	var campeon := "--captura-campeon" in args
	var menu_red := "--captura-menu" in args
	var capturar_apodo := "--captura-apodo" in args
	var capturar_ficha := "--captura-ficha" in args
	var arquetipos := "--captura-arquetipos" in args
	var combate := "--captura-combate" in args or cerca or talentos or habilidad or capturar_jefe or tienda or fin or campeon or menu_red or capturar_apodo or capturar_ficha or arquetipos
	# Permite fotografiar cualquier campeón: --captura-cerca --clase=saeta.
	var clase_forzada := ""
	for arg in args:
		var texto := String(arg)
		if texto.begins_with("--clase="):
			clase_forzada = texto.trim_prefix("--clase=")
	if clase_forzada != "":
		_al_elegir_campeon(StringName(clase_forzada))
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
		if arquetipos:
			# Foto de familia de los arquetipos nuevos: sabueso, bruto y
			# nigromante delante del gladiador con su barra de vida visible.
			var tipos: Array[StringName] = [&"sabueso", &"bruto", &"nigromante"]
			var indice := 0
			var pool := _oleadas.get("_pool") as ObjectPool
			for tipo in tipos:
				var enemigo := ArenaEnemy.crear()
				add_child(enemigo)
				enemigo.global_position = _jugador.global_position + Vector3(-2.6 + indice * 2.6, 0.0, -2.8)
				enemigo.preparar(12, false, _jugador, _bandera, _oleadas, pool, 0, tipo, 1.0, 1.0)
				enemigo.set_physics_process(false)
				enemigo.salud_actual = enemigo.salud_maxima * 0.55
				enemigo.call("_actualizar_barra_vida")
				indice += 1
			if _camara != null:
				_camara.size = 11.0
		if capturar_ficha and _tactil != null:
			_tactil.alternar_ficha()
			await get_tree().create_timer(0.6).timeout
		if capturar_apodo:
			var modal := NombreJugador.new()
			add_child(modal)
			modal.configurar()
			await get_tree().create_timer(0.8).timeout
		if campeon:
			_mostrar_seleccion_campeon(true)
			print("SELECCION: ", _seleccion != null, " perfiles=", _perfiles_campeon().size())
			await get_tree().create_timer(0.8).timeout
		if fin:
			_finalizar("DERROTA", "Los gladiadores han caído en la arena.")
			await get_tree().create_timer(1.2).timeout
		await get_tree().create_timer(3.0 if (cerca or talentos or habilidad or capturar_jefe or tienda or fin or campeon or menu_red or capturar_apodo or capturar_ficha or arquetipos) else 8.5).timeout
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
	elif fin:
		ruta = "res://captura_fin.png"
	elif campeon:
		ruta = "res://captura_campeon.png"
	elif menu_red:
		ruta = "res://captura_menu.png"
	elif capturar_apodo:
		ruta = "res://captura_apodo.png"
	elif capturar_ficha:
		ruta = "res://captura_ficha.png"
	elif arquetipos:
		ruta = "res://captura_arquetipos.png"
	elif combate:
		ruta = "res://captura_combate.png"
	var error := imagen.save_png(ProjectSettings.globalize_path(ruta))
	print("CAPTURA: guardada en ", ruta, " error=", error, " tamaño=", imagen.get_size())
	get_tree().quit()
