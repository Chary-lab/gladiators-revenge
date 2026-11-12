class_name Supabase
extends Node
## Integración mínima con Supabase por REST (PostgREST).
##
## - El cliente usa la anon key + RLS para listar servidores y partidas.
## - El servidor usa SUPABASE_SERVICE_KEY (solo variable de entorno) para
##   registrar su URL, latir cada 20 s y guardar el resultado de la partida.
## - La connection string de Postgres no se usa en tiempo de ejecución; solo
##   para aplicar las migraciones.

const TABLA_SERVIDORES := "servidores"
const TABLA_PARTIDAS := "partidas"
const INTERVALO_LATIDO := 20.0

var _base := ""
var _anon := ""
var _service := ""
var _region := "local"
var _nombre := ""
var _url_publica := ""
var _max_jugadores := 3
var _jugadores := 0
var _timer: Timer


func _ready() -> void:
	_base = _config("supabase/url", "SUPABASE_URL").trim_suffix("/")
	_anon = _config("supabase/anon_key", "SUPABASE_ANON_KEY")
	_service = OS.get_environment("SUPABASE_SERVICE_KEY").strip_edges()
	_region = _config("supabase/region", "SUPABASE_REGION")
	if _region.is_empty():
		_region = "local"


func configurado_cliente() -> bool:
	return not _base.is_empty() and not _anon.is_empty()


func configurado_servidor() -> bool:
	return not _base.is_empty() and not _service.is_empty()


func listar_servidores(callback: Callable) -> void:
	if not configurado_cliente():
		callback.call(false, [])
		return
	var ruta := (
		"/rest/v1/%s?select=nombre,url,region,jugadores,max_jugadores,actualizado_en"
		+ "&activo=eq.true&order=actualizado_en.desc&limit=20"
	) % TABLA_SERVIDORES
	_peticion(HTTPClient.METHOD_GET, ruta, "", false, _parse_servidores.bind(callback))


func iniciar_latido(nombre: String, url_publica: String, max_jugadores := 3) -> void:
	if not configurado_servidor():
		print("[SUPABASE] sin SUPABASE_SERVICE_KEY; no se registra el servidor")
		return
	if url_publica.strip_edges().is_empty():
		print("[SUPABASE] falta SERVER_PUBLIC_URL; no se registra el servidor")
		return
	_nombre = nombre
	_url_publica = url_publica.strip_edges()
	_max_jugadores = max_jugadores
	if _timer == null:
		_timer = Timer.new()
		_timer.wait_time = INTERVALO_LATIDO
		_timer.autostart = true
		_timer.timeout.connect(_latir)
		add_child(_timer)
	_timer.start()
	_latir()


func actualizar_jugadores(cantidad: int) -> void:
	_jugadores = max(0, cantidad)
	if configurado_servidor() and not _url_publica.is_empty():
		_latir()


func detener_latido() -> void:
	if _timer != null:
		_timer.stop()


func marcar_inactivo() -> void:
	if not configurado_servidor() or _url_publica.is_empty():
		return
	var ruta := "/rest/v1/%s?url=eq.%s" % [TABLA_SERVIDORES, _url_publica.uri_encode()]
	_peticion(
		HTTPClient.METHOD_PATCH,
		ruta,
		JSON.stringify({"activo": false}),
		true,
		Callable()
	)


func registrar_partida(
	resultado: String,
	oleada: int,
	duracion_s: int,
	jugadores: Array
) -> void:
	if not configurado_servidor():
		return
	var cuerpo := JSON.stringify({
		"servidor_url": _url_publica,
		"resultado": resultado,
		"oleada": oleada,
		"duracion_s": max(0, duracion_s),
		"jugadores": jugadores,
	})
	_peticion(HTTPClient.METHOD_POST, "/rest/v1/%s" % TABLA_PARTIDAS, cuerpo, true, Callable())


func _latir() -> void:
	if not configurado_servidor() or _url_publica.is_empty():
		return
	var cuerpo := JSON.stringify({
		"nombre": _nombre,
		"url": _url_publica,
		"region": _region,
		"jugadores": _jugadores,
		"max_jugadores": _max_jugadores,
		"activo": true,
	})
	var ruta := "/rest/v1/%s?on_conflict=url" % TABLA_SERVIDORES
	_peticion(HTTPClient.METHOD_POST, ruta, cuerpo, true, Callable())


func _parse_servidores(code: int, body: String, callback: Callable) -> void:
	var ok := code >= 200 and code < 300
	var lista: Array = []
	var limpio := body.strip_edges()
	if ok and (limpio.begins_with("[") or limpio.begins_with("{")):
		var datos = JSON.parse_string(limpio)
		if datos is Array:
			lista = datos
		elif datos is Dictionary:
			lista = [datos]
	else:
		ok = false
	callback.call(ok, lista)


func _peticion(
	metodo: int,
	ruta: String,
	cuerpo: String,
	usar_service: bool,
	callback: Callable
) -> void:
	var clave := _service if usar_service else _anon
	if _base.is_empty() or clave.is_empty():
		if callback.is_valid():
			callback.call(0, "Supabase no configurado")
		return

	var http := HTTPRequest.new()
	http.timeout = 12.0
	http.accept_gzip = false
	add_child(http)
	http.request_completed.connect(_al_responder.bind(http, callback))

	var cabeceras := PackedStringArray([
		"apikey: %s" % clave,
		"Authorization: Bearer %s" % clave,
		"Content-Type: application/json",
		"Accept: application/json",
		"Accept-Encoding: identity",
	])
	if metodo == HTTPClient.METHOD_POST and TABLA_SERVIDORES in ruta:
		cabeceras.append("Prefer: resolution=merge-duplicates,return=minimal")
	else:
		cabeceras.append("Prefer: return=minimal")

	var error := http.request(_base + ruta, cabeceras, metodo, cuerpo)
	if error != OK:
		http.queue_free()
		if callback.is_valid():
			callback.call(0, "Error de red: %s" % error_string(error))


func _al_responder(
	_resultado,
	code: int,
	_cabeceras: PackedStringArray,
	cuerpo: PackedByteArray,
	http: HTTPRequest,
	callback: Callable
) -> void:
	if is_instance_valid(http):
		http.queue_free()
	if callback.is_valid():
		callback.call(code, cuerpo.get_string_from_utf8())


func _config(clave: String, variable_entorno: String) -> String:
	var valor := OS.get_environment(variable_entorno).strip_edges()
	if valor.is_empty():
		valor = str(ProjectSettings.get_setting(clave, "")).strip_edges()
	return valor
