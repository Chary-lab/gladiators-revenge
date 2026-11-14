class_name MaestroSalas
extends Node
## Servidor maestro: varias salas cooperativas en un solo contenedor.
##
## Escucha en un puerto público (el que inyecte el hosting) y hace dos cosas:
##   - HTTP:  POST /salas devuelve una sala libre (para el botón CREAR SALA de la
##            web o del APK). GET /salud informa el estado.
##   - Proxy: GET /sala/<n> con Upgrade: websocket se reenvía tal cual al proceso
##            de esa sala (127.0.0.1:puerto_base+n), que es quien habla WebSocket.
##
## Cada sala es un proceso `godot --headless -- --servidor --puerto=…` que se
## anuncia solo en Supabase. Al cerrarse la última conexión de una sala se
## reinicia su proceso para que el siguiente grupo empiece una partida limpia.
##
## Uso: godot --headless -- --maestro [--salas=2] [--puerto=8080] [--puerto-base=9101]
## En la nube basta con PORT/SALAS/SERVER_PUBLIC_URL en el entorno.

const SALAS_POR_DEFECTO := 1
const PUERTO_POR_DEFECTO := 8080
const PUERTO_BASE_POR_DEFECTO := 9101
const MAX_CABECERA := 8192
const ESPERA_RESERVA := 90000

var _puerto := PUERTO_POR_DEFECTO
var _puerto_base := PUERTO_BASE_POR_DEFECTO
var _total := SALAS_POR_DEFECTO
var _base_publica := ""

var _tcp: TCPServer
var _pendientes: Array = []   # {peer, buffer: PackedByteArray, desde: float}
var _relays: Array = []       # {cliente, sala, buffer, conectado}
var _pid_salas: Dictionary = {}   # numero -> pid
var _ocupadas: Dictionary = {}    # numero -> true (relay activo)
var _reservas: Dictionary = {}    # numero -> ms en que se reservó (crear sala)


func iniciar() -> bool:
	_leer_opciones()
	_tcp = TCPServer.new()
	var error := _tcp.listen(_puerto)
	if error != OK:
		push_error("MaestroSalas: no se pudo abrir el puerto %d (%s)" % [_puerto, error_string(error)])
		return false
	print("[MAESTRO] escuchando en el puerto %d · %d salas desde %d" % [_puerto, _total, _puerto_base])
	_limpiar_anuncios_viejos()
	for n in range(1, _total + 1):
		_arrancar_sala(n)
	return true


## Al arrancar, borra de Supabase los anuncios huérfanos (procesos muertos).
func _limpiar_anuncios_viejos() -> void:
	var supabase := Supabase.new()
	supabase.name = "SupabaseLimpieza"
	add_child(supabase)
	supabase.limpiar_viejos(10.0)


func _leer_opciones() -> void:
	_puerto = int(OS.get_environment("PORT")) if not OS.get_environment("PORT").is_empty() else PUERTO_POR_DEFECTO
	_base_publica = OS.get_environment("SERVER_PUBLIC_URL").strip_edges()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--puerto="):
			_puerto = int(arg.substr("--puerto=".length()))
		elif arg.begins_with("--puerto-base="):
			_puerto_base = int(arg.substr("--puerto-base=".length()))
		elif arg.begins_with("--salas="):
			_total = maxi(1, int(arg.substr("--salas=".length())))
	if not OS.get_environment("SALAS").is_empty():
		_total = maxi(1, int(OS.get_environment("SALAS")))


# --- Salas ----------------------------------------------------------------

func _puerto_sala(numero: int) -> int:
	return _puerto_base + numero - 1


## URL pública con la que los clientes entran a una sala.
## En la nube `SERVER_PUBLIC_URL` llega como https://host: el WebSocket necesita
## wss://, así que se cambia el esquema (antes salía https y el cliente no podía
## conectar).
func url_sala(numero: int) -> String:
	return _url_sala(numero)


func _url_sala(numero: int) -> String:
	var base := _base_publica.strip_edges().trim_suffix("/")
	if base.is_empty():
		base = "ws://127.0.0.1:%d" % _puerto
	elif base.begins_with("https://"):
		base = "wss://" + base.substr("https://".length())
	elif base.begins_with("http://"):
		base = "ws://" + base.substr("http://".length())
	elif not (base.begins_with("wss://") or base.begins_with("ws://")):
		base = "wss://" + base
	return "%s/sala/%d" % [base, numero]


func _arrancar_sala(numero: int) -> void:
	var anterior: int = _pid_salas.get(numero, -1)
	if anterior > 0:
		OS.kill(anterior)
	var argumentos: Array = ["--headless"]
	if OS.has_feature("editor"):
		argumentos.append_array(["--path", ProjectSettings.globalize_path("res://")])
	argumentos.append_array([
		"--",
		"--servidor",
		"--puerto=%d" % _puerto_sala(numero),
		"--publico=%s" % _url_sala(numero),
	])
	# Las pruebas del maestro usan oleadas rápidas: se propagan a las salas.
	if "--red-rapida" in OS.get_cmdline_user_args():
		argumentos.append("--red-rapida")
	var pid := OS.create_process(OS.get_executable_path(), argumentos)
	_pid_salas[numero] = pid
	print("[MAESTRO] sala %d en el puerto %d (pid %d)" % [numero, _puerto_sala(numero), pid])


func _apagar_salas() -> void:
	for numero in _pid_salas.keys():
		OS.kill(_pid_salas[numero])
	_pid_salas.clear()


func cerrar() -> void:
	_apagar_salas()
	if _tcp != null:
		_tcp.stop()
		_tcp = null


# --- Bucle ----------------------------------------------------------------

func _process(_delta: float) -> void:
	_aceptar()
	_leer_pendientes()
	_bombear_relays()


func _aceptar() -> void:
	while _tcp != null and _tcp.is_connection_available():
		var peer := _tcp.take_connection()
		if peer == null:
			continue
		_pendientes.append({"peer": peer, "buffer": PackedByteArray(), "desde": Time.get_ticks_msec()})


func _leer_pendientes() -> void:
	var seguir: Array = []
	for p in _pendientes:
		var peer: StreamPeerTCP = p["peer"]
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue
		var disponibles := peer.get_available_bytes()
		if disponibles > 0:
			var datos := peer.get_partial_data(mini(disponibles, MAX_CABECERA))
			if datos[0] == OK:
				p["buffer"].append_array(datos[1])
		var texto: String = p["buffer"].get_string_from_utf8()
		if texto.contains("\r\n\r\n"):
			_atender_peticion(peer, p["buffer"], texto)
			continue
		if Time.get_ticks_msec() - int(p["desde"]) > 8000:
			peer.disconnect_from_host()
			continue
		seguir.append(p)
	_pendientes = seguir


# --- Peticiones -----------------------------------------------------------

func _atender_peticion(peer: StreamPeerTCP, crudo: PackedByteArray, texto: String) -> void:
	var primera := texto.split("\r\n")[0] if texto.contains("\r\n") else texto
	var partes: PackedStringArray = primera.split(" ")
	if partes.size() < 2:
		_responder(peer, 400, {"error": "petición inválida"})
		return
	var verbo := partes[0].to_upper()
	var ruta := partes[1]
	var es_websocket := texto.to_lower().contains("upgrade: websocket")

	if verbo == "OPTIONS":
		_responder(peer, 204, {})
		return

	if es_websocket and ruta.begins_with("/sala/"):
		var numero := int(ruta.substr("/sala/".length()).get_slice("?", 0))
		if numero < 1 or numero > _total:
			_responder(peer, 404, {"error": "sala inexistente"})
			return
		_conectar_sala(peer, crudo, numero)
		return

	if verbo == "POST" and ruta.begins_with("/salas"):
		var libre := _sala_libre()
		if libre == 0:
			_responder(peer, 503, {"error": "no hay salas libres, probá en un minuto"})
			return
		# Una sala recién arrancada (o la máquina despertando) no acepta conexiones
		# todavía: si se entrega su URL ya, el jugador entra y recibe "error de
		# conexión". Se espera a que escuche antes de contestar.
		if not _sala_responde(libre):
			_responder(peer, 503, {"error": "la sala está despertando; probá en unos segundos"})
			return
		# Reserva con caducidad: si el cliente nunca llega a conectar, la sala
		# vuelve a quedar disponible.
		_reservas[libre] = Time.get_ticks_msec()
		_responder(peer, 200, {"sala": libre, "url": _url_sala(libre)})
		return

	if ruta == "/" or ruta.begins_with("/salud"):
		_responder(peer, 200, {
			"ok": true,
			"salas": _total,
			"libres": _total - _ocupadas.size() - _reservas.size(),
			"ocupadas": _ocupadas.keys(),
			"reservadas": _reservas.keys(),
		})
		return

	_responder(peer, 404, {"error": "ruta desconocida"})


func _sala_libre() -> int:
	var ahora := Time.get_ticks_msec()
	for n in _reservas.keys():
		if ahora - int(_reservas[n]) > ESPERA_RESERVA:
			_reservas.erase(n)
	for n in range(1, _total + 1):
		if not _ocupadas.has(n) and not _reservas.has(n):
			return n
	return 0


## ¿El proceso de la sala ya acepta TCP? Sondea con un connect real y un presupuesto
## acotado. Se llama sólo al crear sala (bloquea el bucle como máximo `limite_ms`);
## con la sala libre no hay partidas a las que afectar.
func _sala_responde(numero: int, limite_ms := 6000) -> bool:
	var puerto := _puerto_sala(numero)
	var limite := Time.get_ticks_msec() + limite_ms
	while Time.get_ticks_msec() < limite:
		var sonda := StreamPeerTCP.new()
		if sonda.connect_to_host("127.0.0.1", puerto) == OK:
			var fin := Time.get_ticks_msec() + 300
			var listo := false
			while Time.get_ticks_msec() < fin:
				sonda.poll()
				var e := sonda.get_status()
				if e == StreamPeerTCP.STATUS_CONNECTED:
					listo = true
					break
				if e == StreamPeerTCP.STATUS_ERROR:
					break
				OS.delay_msec(10)
			sonda.disconnect_from_host()
			if listo:
				return true
		OS.delay_msec(50)
	return false


func _responder(peer: StreamPeerTCP, codigo: int, cuerpo: Dictionary) -> void:
	var texto: String = JSON.stringify(cuerpo)
	var motivo := "OK"
	match codigo:
		204: motivo = "No Content"
		400: motivo = "Bad Request"
		404: motivo = "Not Found"
		503: motivo = "Service Unavailable"
	var cabecera := (
		"HTTP/1.1 %d %s\r\n" % [codigo, motivo]
		+ "Content-Type: application/json\r\n"
		+ "Content-Length: %d\r\n" % texto.to_utf8_buffer().size()
		+ "Access-Control-Allow-Origin: *\r\n"
		+ "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
		+ "Access-Control-Allow-Headers: Content-Type\r\n"
		+ "Connection: close\r\n\r\n"
	)
	peer.put_data(cabecera.to_utf8_buffer())
	if codigo != 204:
		peer.put_data(texto.to_utf8_buffer())
	peer.disconnect_from_host()


# --- Proxy WebSocket ------------------------------------------------------

func _conectar_sala(cliente: StreamPeerTCP, crudo: PackedByteArray, numero: int) -> void:
	var sala := StreamPeerTCP.new()
	if sala.connect_to_host("127.0.0.1", _puerto_sala(numero)) != OK:
		_responder(cliente, 503, {"error": "la sala no está disponible"})
		return
	_ocupadas[numero] = true
	_reservas.erase(numero)
	_relays.append({
		"desde": Time.get_ticks_msec(),
		"intentos": 0,
		"ultimo": 0,
		"cliente": cliente,
		"sala": sala,
		"numero": numero,
		"pendiente": crudo,
	})
	print("[MAESTRO] sala %d: cliente conectado" % numero)


func _bombear_relays() -> void:
	var activos: Array = []
	for r in _relays:
		var cliente: StreamPeerTCP = r["cliente"]
		var sala: StreamPeerTCP = r["sala"]
		var numero: int = r["numero"]
		cliente.poll()
		sala.poll()
		var e_cliente := cliente.get_status()
		var e_sala := sala.get_status()

		# Mientras la sala aún está conectando, no se toca nada: cerrar aquí fue
		# lo que cortaba la conexión justo al entrar.
		if e_sala == StreamPeerTCP.STATUS_CONNECTING:
			activos.append(r)
			continue
		# En frío (el contenedor acaba de despertar) la sala puede no estar
		# escuchando todavía: se reintenta unos segundos antes de rendirse.
		if e_sala == StreamPeerTCP.STATUS_ERROR and int(r.get("intentos", 0)) < 12:
			var ahora := Time.get_ticks_msec()
			if ahora - int(r.get("ultimo", 0)) > 400:
				r["intentos"] = int(r.get("intentos", 0)) + 1
				r["ultimo"] = ahora
				var nueva := StreamPeerTCP.new()
				if nueva.connect_to_host("127.0.0.1", _puerto_sala(numero)) == OK:
					r["sala"] = nueva
				activos.append(r)
				continue
		if e_cliente != StreamPeerTCP.STATUS_CONNECTED or e_sala != StreamPeerTCP.STATUS_CONNECTED:
			print("[MAESTRO] sala %d: cierre (cliente=%d sala=%d tras %d ms)" % [
				numero, e_cliente, e_sala, Time.get_ticks_msec() - int(r.get("desde", 0))])
			_cerrar_relay(cliente, sala, numero)
			continue

		if not r["pendiente"].is_empty():
			sala.put_data(r["pendiente"])
			r["pendiente"] = PackedByteArray()

		var a_sala := _leer_de(cliente)
		if not a_sala.is_empty():
			sala.put_data(a_sala)
		var a_cliente := _leer_de(sala)
		if not a_cliente.is_empty():
			cliente.put_data(a_cliente)
		activos.append(r)
	_relays = activos


func _leer_de(peer: StreamPeerTCP) -> PackedByteArray:
	var disponibles := peer.get_available_bytes()
	if disponibles <= 0:
		return PackedByteArray()
	var datos := peer.get_partial_data(disponibles)
	return datos[1] if datos[0] == OK else PackedByteArray()


func _cerrar_relay(cliente: StreamPeerTCP, sala: StreamPeerTCP, numero: int) -> void:
	cliente.disconnect_from_host()
	sala.disconnect_from_host()
	_ocupadas.erase(numero)
	print("[MAESTRO] sala %d: queda libre, reiniciando partida" % numero)
	_arrancar_sala(numero)
