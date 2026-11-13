class_name CrearSala
extends Node
## Crea una sala cooperativa sin intervención del host.
##
## 1. Descarga `cloudflared` la primera vez (a user://bin) si no está en el PATH.
## 2. Abre un túnel HTTP de Cloudflare contra el puerto local (acepta WebSocket).
## 3. Lanza un servidor Godot headless que se anuncia solo en Supabase.
## 4. Emite `lista` con la URL local (para el host) y la pública (wss://).
##
## El host no instala nada a mano: el binario viaja con la primera partida y se
## reutiliza después. Al terminar o cerrar el juego, `cerrar()` mata ambos procesos.

signal estado(texto: String)
signal lista(url_local: String, url_publica: String)
signal fallo(motivo: String)

const PUERTO := 9080
const RELEASES := "https://github.com/cloudflare/cloudflared/releases/latest/download/"
const ARCHIVO_CLAVE := "user://supabase.local.cfg"
const ESPERA_TUNEL := 45.0
const ESPERA_SERVIDOR := 1.5

var _pid_tunel := -1
var _pid_servidor := -1
var _url_publica := ""
var _fase := ""  # descarga | tunel | servidor | ""
var _reloj := 0.0
var _log := ""
var _sin_log := 0.0
var _peticion: HTTPRequest


func _process(delta: float) -> void:
	# Sin set_process(): el nodo puede entrar al árbol después de crear() y
	# apagarse solo. La guarda por fase cuesta nada.
	if _fase != "tunel":
		return
	_reloj += delta
	if _reloj > ESPERA_TUNEL:
		fallo.emit("El túnel no respondió en %d s." % int(ESPERA_TUNEL))
		cerrar()
		return
	var url := _url_del_log()
	if url.is_empty():
		_sin_log += delta
		if _sin_log > 25.0:
			# Un cloudflared huérfano de una partida anterior puede tener el
			# registro bloqueado; avisar en vez de esperar en silencio.
			fallo.emit("No se pudo leer el registro del túnel.")
			cerrar()
		return
	_sin_log = 0.0
	_url_publica = url
	_lanzar_servidor()


func crear() -> void:
	if not _fase.is_empty():
		return
	_fase = "descarga"
	estado.emit("Preparando el túnel…")
	var exe := _ejecutable_tunel()
	if not exe.is_empty():
		_lanzar_tunel(exe)
		return
	_descargar()


func cerrar() -> void:
	_fase = ""
	if _pid_servidor > 0:
		OS.kill(_pid_servidor)
		_pid_servidor = -1
	if _pid_tunel > 0:
		OS.kill(_pid_tunel)
		_pid_tunel = -1
	if not _log.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_log))
		_log = ""


func url_publica() -> String:
	return _url_publica


# --- Túnel ----------------------------------------------------------------

func _ruta_local() -> String:
	return "user://bin/" + _nombre_binario()


func _nombre_binario() -> String:
	if OS.has_feature("windows"):
		return "cloudflared.exe"
	if OS.has_feature("macos"):
		return "cloudflared-darwin"
	return "cloudflared-linux"


func _nombre_descarga() -> String:
	if OS.has_feature("windows"):
		return "cloudflared-windows-amd64.exe"
	if OS.has_feature("macos"):
		return "cloudflared-darwin-amd64.tgz"
	return "cloudflared-linux-amd64"


func _ejecutable_tunel() -> String:
	var propio := ProjectSettings.globalize_path(_ruta_local())
	if FileAccess.file_exists(propio):
		return propio
	# Un cloudflared instalado en el sistema también sirve: se resuelve a mano
	# porque OS.execute spamea un error cuando el binario no existe.
	var separador := ";" if OS.has_feature("windows") else ":"
	for carpeta in OS.get_environment("PATH").split(separador):
		var limpia := carpeta.strip_edges().rstrip("/\\")
		if limpia.is_empty():
			continue
		var candidato := limpia + "/" + _nombre_binario()
		if FileAccess.file_exists(candidato):
			return candidato
	return ""


func _descargar() -> void:
	# En --script el nodo puede llamar antes de entrar al árbol; HTTPRequest
	# necesita estar dentro para emitir la petición.
	if not is_inside_tree():
		await tree_entered
	estado.emit("Descargando cloudflared (solo la primera vez)…")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://bin"))
	_peticion = HTTPRequest.new()
	_peticion.download_file = ProjectSettings.globalize_path(_ruta_local())
	_peticion.timeout = 120.0
	_peticion.request_completed.connect(_al_descargar)
	add_child(_peticion)
	var error := _peticion.request(RELEASES + _nombre_descarga())
	if error != OK:
		fallo.emit("No se pudo iniciar la descarga de cloudflared (%d)." % error)
		_fase = ""


func _al_descargar(_resultado: int, codigo: int, _cabeceras: PackedStringArray, _cuerpo: PackedByteArray) -> void:
	if _peticion != null:
		_peticion.queue_free()
		_peticion = null
	var ruta := ProjectSettings.globalize_path(_ruta_local())
	if codigo != 200 or not FileAccess.file_exists(ruta):
		fallo.emit("La descarga de cloudflared falló (HTTP %d)." % codigo)
		_fase = ""
		return
	if not OS.has_feature("windows"):
		OS.execute("chmod", ["+x", ruta], [])
	_lanzar_tunel(ruta)


func _lanzar_tunel(exe: String) -> void:
	_fase = "tunel"
	_sin_log = 0.0
	# Un registro por intento: dos cloudflared (o uno huérfano) pelearían por el
	# mismo archivo y en Windows el segundo no podría ni abrirlo.
	_log = "user://tunel-%d.log" % Time.get_ticks_usec()
	var log_nativo := ProjectSettings.globalize_path(_log)
	estado.emit("Abriendo el túnel de Cloudflare…")
	# http:// y no tcp://: el navegador necesita el handshake WebSocket sobre TLS.
	_pid_tunel = OS.create_process(exe, [
		"tunnel",
		"--url", "http://localhost:%d" % PUERTO,
		"--no-autoupdate",
		"--loglevel", "info",
		"--logfile", log_nativo,
	])
	if _pid_tunel <= 0:
		fallo.emit("No se pudo iniciar cloudflared.")
		_fase = ""
		return
	_reloj = 0.0


func _url_del_log() -> String:
	if _log.is_empty():
		return ""
	var log_nativo := ProjectSettings.globalize_path(_log)
	if not FileAccess.file_exists(log_nativo):
		return ""
	var archivo := FileAccess.open(log_nativo, FileAccess.READ)
	if archivo == null:
		return ""
	var texto := archivo.get_as_text()
	archivo.close()
	if texto.is_empty():
		return ""
	var regex := RegEx.new()
	if regex.compile("https://[a-zA-Z0-9-]+\\.trycloudflare\\.com") != OK:
		return ""
	var resultado := regex.search(texto)
	if resultado == null:
		return ""
	return "wss://" + resultado.get_string().substr("https://".length())


# --- Servidor -------------------------------------------------------------

func _lanzar_servidor() -> void:
	_fase = "servidor"
	estado.emit("Levantando el servidor…")
	var argumentos: Array = ["--headless"]
	if OS.has_feature("editor"):
		argumentos.append_array(["--path", ProjectSettings.globalize_path("res://")])
	argumentos.append_array([
		"--",
		"--servidor",
		"--puerto=%d" % PUERTO,
		"--publico=%s" % _url_publica,
	])
	var clave := _clave_servicio()
	if not clave.is_empty():
		argumentos.append("--clave-supabase=" + clave)
	_pid_servidor = OS.create_process(OS.get_executable_path(), argumentos)
	if _pid_servidor <= 0:
		fallo.emit("No se pudo lanzar el servidor.")
		cerrar()
		return
	await get_tree().create_timer(ESPERA_SERVIDOR).timeout
	_fase = ""
	estado.emit("Sala lista: %s" % _url_publica)
	lista.emit("ws://127.0.0.1:%d" % PUERTO, _url_publica)


func _clave_servicio() -> String:
	var clave := OS.get_environment("SUPABASE_SERVICE_KEY").strip_edges()
	if not clave.is_empty():
		return clave
	# Archivo local del host (user://, nunca en el repo ni en el cliente exportado).
	if FileAccess.file_exists(ARCHIVO_CLAVE):
		var archivo := FileAccess.open(ARCHIVO_CLAVE, FileAccess.READ)
		if archivo != null:
			clave = archivo.get_as_text().strip_edges()
			archivo.close()
	return clave
