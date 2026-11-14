class_name NetCoop
extends Node
## Transporte cooperativo online sobre WebSocketPeer (compatible con Web/APK).
##
## El servidor es la autoridad: simula Arena completa, recibe acciones JSON de
## los clientes y difunde snapshots. Los clientes no simulan IA ni daño.

signal conexion_cambiada(estado: String, detalle: String)
signal lobby_actualizada(clases_ocupadas: Dictionary)
signal clase_rechazada(clase: StringName)
signal bienvenida(peer_id: int)
signal snapshot_recibido(datos: Dictionary)
signal partida_terminada(titulo: String, detalle: String)

enum Estado { DESCONECTADO, CONECTANDO, CONECTADO, SERVIDOR }

## 2: el estado estático del jugador viaja solo cuando cambia (bloque «est»).
const VERSION_RED := 2
const PUERTO_POR_DEFECTO := 9080
const TAM_BUFFER := 1 << 20
## Reintentos al abrir la conexión: la máquina de Fly puede estar despertando y
## el proceso de la sala tarda un par de segundos en escuchar. Antes se rendía al
## primer intento y el jugador veía "error de conexión" y tenía que volver a entrar.
const INTENTOS_CONEXION := 12

var estado := Estado.DESCONECTADO
var es_servidor := false
var peer_local := 1
var url := ""
var clases_ocupadas: Dictionary = {}
var clase_por_peer: Dictionary = {}
var clientes_listos: Dictionary = {}
var _arena: Node

var _tcp: TCPServer
var _clientes: Dictionary = {}      # id -> WebSocketPeer
var _siguiente_id := 1
var _ws: WebSocketPeer
var _intentos := 0
var _reintento_ms := 0
var _alguna_vez_conectado := false


func configurar(arena: Node) -> void:
	_arena = arena


func iniciar_servidor(puerto: int = PUERTO_POR_DEFECTO) -> bool:
	_tcp = TCPServer.new()
	var error := _tcp.listen(puerto)
	if error != OK:
		push_error("NetCoop: no se pudo abrir el puerto %d (%s)" % [puerto, error_string(error)])
		conexion_cambiada.emit("error", "No se pudo abrir el puerto %d" % puerto)
		return false

	es_servidor = true
	peer_local = 0
	estado = Estado.SERVIDOR
	conexion_cambiada.emit("servidor", "Escuchando en el puerto %d" % puerto)
	print("[NET] servidor escuchando en el puerto ", puerto)
	return true


func unirse(direccion: String) -> bool:
	url = direccion.strip_edges()
	if url.is_empty():
		return false
	_intentos = 0
	_reintento_ms = 0
	_alguna_vez_conectado = false
	return _abrir_websocket()


## Abre (o reabre) el WebSocket contra `url`. Reintentar es seguro: se crea un
## peer nuevo y se descarta el anterior.
func _abrir_websocket() -> bool:
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = TAM_BUFFER
	_ws.outbound_buffer_size = TAM_BUFFER
	var error := _ws.connect_to_url(url)
	if error != OK:
		push_error("NetCoop: no se pudo conectar a %s (%s)" % [url, error_string(error)])
		conexion_cambiada.emit("error", "No se pudo conectar a %s" % url)
		return false

	estado = Estado.CONECTANDO
	conexion_cambiada.emit("conectando", "Conectando a %s" % url)
	return true


## El servidor aún no escucha (máquina despertando o sala reiniciándose): se
## reintenta con espera creciente en vez de dar la partida por perdida.
func _programar_reintento() -> void:
	_intentos += 1
	_ws = null
	estado = Estado.CONECTANDO
	var espera := minf(3.0, 0.6 + 0.35 * float(_intentos))
	_reintento_ms = Time.get_ticks_msec() + int(espera * 1000.0)
	conexion_cambiada.emit(
		"despertando",
		"Despertando la sala… (intento %d de %d)" % [_intentos + 1, INTENTOS_CONEXION]
	)


func cerrar() -> void:
	if _ws != null:
		_ws.close()
		_ws = null
	for id in _clientes.keys():
		var peer: WebSocketPeer = _clientes[id]
		if peer != null:
			peer.close()
	_clientes.clear()
	clientes_listos.clear()
	if _tcp != null:
		_tcp.stop()
		_tcp = null
	estado = Estado.DESCONECTADO
	es_servidor = false
	# Cancela cualquier reintento pendiente: el jugador ya se fue.
	_reintento_ms = 0
	_intentos = INTENTOS_CONEXION
	_alguna_vez_conectado = false


func _process(_delta: float) -> void:
	if es_servidor:
		_poll_servidor()
	elif estado == Estado.CONECTANDO or estado == Estado.CONECTADO:
		_poll_cliente()
	if _reintento_ms > 0 and Time.get_ticks_msec() >= _reintento_ms:
		_reintento_ms = 0
		_abrir_websocket()


# --- Servidor -------------------------------------------------------------

func _poll_servidor() -> void:
	while _tcp != null and _tcp.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.inbound_buffer_size = TAM_BUFFER
		ws.outbound_buffer_size = TAM_BUFFER
		var conexion := _tcp.take_connection()
		if conexion == null:
			continue
		if ws.accept_stream(conexion) != OK:
			continue
		var id := _siguiente_id
		_siguiente_id += 1
		_clientes[id] = ws

	for id in _clientes.keys():
		var ws: WebSocketPeer = _clientes[id]
		if ws == null:
			continue
		ws.poll()
		match ws.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				if not clientes_listos.has(id):
					_al_cliente_listo(int(id))
				while ws.get_available_packet_count() > 0:
					_procesar_mensaje_servidor(int(id), ws.get_packet().get_string_from_utf8())
			WebSocketPeer.STATE_CLOSED:
				_quitar_cliente(int(id))


func _al_cliente_listo(id: int) -> void:
	print("[NET] cliente listo: ", id)
	clase_por_peer[id] = &""
	clientes_listos[id] = true
	if _arena != null and _arena.has_method("agregar_jugador_red"):
		_arena.agregar_jugador_red(id)
	_enviar(id, {"t": "bienvenida", "id": id, "v": VERSION_RED})
	_difundir_lobby()


func _quitar_cliente(id: int) -> void:
	if not _clientes.has(id):
		return
	print("[NET] cliente desconectado: ", id)
	var ws: WebSocketPeer = _clientes[id]
	if ws != null:
		ws.close()
	_clientes.erase(id)
	clientes_listos.erase(id)
	clase_por_peer.erase(id)
	for clase in clases_ocupadas.keys():
		if int(clases_ocupadas[clase]) == id:
			clases_ocupadas.erase(clase)
	if _arena != null and _arena.has_method("quitar_jugador_red"):
		_arena.quitar_jugador_red(id)
	_difundir_lobby()


func _procesar_mensaje_servidor(id: int, texto: String) -> void:
	var mensaje = JSON.parse_string(texto)
	if not (mensaje is Dictionary):
		return
	match str(mensaje.get("t", "")):
		"clase":
			_solicitar_clase(id, StringName(mensaje.get("c", "")))
		"accion":
			if _arena != null and _arena.has_method("aplicar_accion_red"):
				_arena.aplicar_accion_red(
					id,
					StringName(mensaje.get("a", "")),
					_decodificar(mensaje.get("d", {}))
				)
		_:
			pass


func _solicitar_clase(id: int, clase: StringName) -> void:
	if not clientes_listos.has(id):
		return
	if clase_por_peer.has(id) and clase_por_peer[id] != &"":
		_enviar(id, {"t": "rechazo", "c": String(clase)})
		return
	if clases_ocupadas.has(clase) and int(clases_ocupadas[clase]) != id:
		_enviar(id, {"t": "rechazo", "c": String(clase)})
		return
	clase_por_peer[id] = clase
	clases_ocupadas[clase] = id
	if _arena != null and _arena.has_method("equipar_clase_red"):
		_arena.equipar_clase_red(id, clase)
	_difundir_lobby()


func _difundir_lobby() -> void:
	var mensaje := {"t": "lobby", "c": _codificar(clases_ocupadas)}
	for id in clientes_listos.keys():
		_enviar(int(id), mensaje)


func _enviar(id: int, mensaje: Dictionary) -> void:
	var ws: WebSocketPeer = _clientes.get(id)
	if ws == null or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	ws.send_text(JSON.stringify(_codificar(mensaje)))


## El servidor difunde solo a los clientes que ya recibieron la bienvenida.
func difundir_snapshot(datos: Dictionary) -> void:
	if not es_servidor:
		return
	var bytes := var_to_bytes(datos)
	for id in clientes_listos.keys():
		var ws: WebSocketPeer = _clientes.get(int(id))
		if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws.send(bytes)


func difundir_fin(titulo: String, detalle: String) -> void:
	if not es_servidor:
		return
	var mensaje := {"t": "fin", "titulo": titulo, "detalle": detalle}
	for id in clientes_listos.keys():
		_enviar(int(id), mensaje)


# --- Cliente --------------------------------------------------------------

func _poll_cliente() -> void:
	if _ws == null:
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			while _ws.get_available_packet_count() > 0:
				var paquete := _ws.get_packet()
				if _ws.was_string_packet():
					_procesar_mensaje_cliente(paquete.get_string_from_utf8())
				else:
					var datos = bytes_to_var(paquete)
					if datos is Dictionary:
						snapshot_recibido.emit(datos)
		WebSocketPeer.STATE_CLOSED:
			# Si nunca llegó a entrar (máquina despertando o sala arrancando) se
			# reintenta; si ya estaba jugando, la conexión se perdió de verdad.
			if not _alguna_vez_conectado and _intentos < INTENTOS_CONEXION:
				_programar_reintento()
			elif estado != Estado.DESCONECTADO:
				estado = Estado.DESCONECTADO
				conexion_cambiada.emit("desconectado", "El servidor cerró la conexión")


func _procesar_mensaje_cliente(texto: String) -> void:
	var mensaje = JSON.parse_string(texto)
	if not (mensaje is Dictionary):
		return
	match str(mensaje.get("t", "")):
		"bienvenida":
			if int(mensaje.get("v", 0)) != VERSION_RED:
				conexion_cambiada.emit("error", "Versión de red incompatible")
				return
			peer_local = int(mensaje.get("id", 1))
			estado = Estado.CONECTADO
			_alguna_vez_conectado = true
			_intentos = 0
			_reintento_ms = 0
			print("[NET] bienvenida del servidor, peer=", peer_local)
			bienvenida.emit(peer_local)
			conexion_cambiada.emit("conectado", "Conectado como jugador %d" % peer_local)
		"lobby":
			var ocupadas = _decodificar(mensaje.get("c", {}))
			clases_ocupadas.clear()
			if ocupadas is Dictionary:
				for clave in ocupadas:
					clases_ocupadas[StringName(clave)] = ocupadas[clave]
			lobby_actualizada.emit(clases_ocupadas)
		"rechazo":
			clase_rechazada.emit(StringName(mensaje.get("c", "")))
		"snapshot":
			snapshot_recibido.emit(_decodificar(mensaje.get("d", {})))
		"fin":
			partida_terminada.emit(str(mensaje.get("titulo", "")), str(mensaje.get("detalle", "")))
		_:
			pass


## Envoltorios de cliente: envían un mensaje JSON al servidor.
func enviar_accion(accion: StringName, datos: Dictionary) -> void:
	if es_servidor or _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_ws.send_text(JSON.stringify({
		"t": "accion",
		"a": String(accion),
		"d": _codificar(datos),
	}))


func enviar_clase(clase: StringName) -> void:
	if es_servidor or _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_ws.send_text(JSON.stringify({"t": "clase", "c": String(clase)}))


# --- Serialización JSON segura para Vector3/Color/StringName --------------

func _codificar(valor):
	match typeof(valor):
		TYPE_VECTOR3:
			return {"__v": [valor.x, valor.y, valor.z]}
		TYPE_COLOR:
			return {"__c": [valor.r, valor.g, valor.b, valor.a]}
		TYPE_STRING_NAME:
			return String(valor)
		TYPE_DICTIONARY:
			var salida := {}
			for clave in valor:
				salida[str(clave)] = _codificar(valor[clave])
			return salida
		TYPE_ARRAY:
			var lista := []
			for item in valor:
				lista.append(_codificar(item))
			return lista
		TYPE_PACKED_FLOAT32_ARRAY:
			var flotantes := []
			for item in valor:
				flotantes.append(float(item))
			return flotantes
		TYPE_OBJECT:
			return null
		_:
			return valor


func _decodificar(valor):
	if valor is Dictionary:
		if valor.has("__v"):
			var v: Array = valor["__v"]
			return Vector3(float(v[0]), float(v[1]), float(v[2]))
		if valor.has("__c"):
			var c: Array = valor["__c"]
			return Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]))
		var salida := {}
		for clave in valor:
			salida[str(clave)] = _decodificar(valor[clave])
		return salida
	if valor is Array:
		var lista := []
		for item in valor:
			lista.append(_decodificar(item))
		return lista
	return valor
