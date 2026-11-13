class_name SalaRemota
extends Node
## Pide una sala al servidor maestro en la nube (POST /salas).
##
## En Web y APK el navegador no puede abrir un servidor ni un túnel, así que la
## sala la crea el servicio desplegado y aquí solo se pide su URL.
## En escritorio se usa HTTPRequest; en Web, el fetch del navegador vía
## JavaScriptBridge (el HTTPRequest nativo no llega a la red en la build web).

signal lista(url: String)
signal fallo(motivo: String)

var _api := ""
var _callback
var _secuencia := 0
var _pidiendo := false


func configurar(url_api: String) -> void:
	_api = url_api.strip_edges().trim_suffix("/")


func crear() -> void:
	if _pidiendo:
		return
	if _api.is_empty():
		fallo.emit("no hay servidor de salas configurado")
		return
	_pidiendo = true
	if OS.has_feature("web"):
		_crear_web()
	else:
		_crear_nativo()


func _crear_web() -> void:
	if _callback == null:
		_callback = JavaScriptBridge.create_callback(_al_respuesta_web)
		JavaScriptBridge.get_interface("window").__sala_resp = _callback
	_secuencia += 1
	var id := _secuencia
	var js := (
		"(async () => { try { const r = await fetch(%s, {method: 'POST'});"
		+ " const t = await r.text(); window.__sala_resp(%d, r.status, t); }"
		+ " catch (e) { window.__sala_resp(%d, 0, String(e)); } })();"
	) % [JSON.stringify(_api + "/salas"), id, id]
	JavaScriptBridge.eval(js, true)


func _al_respuesta_web(args: Array) -> void:
	_interpretar(int(args[1]), str(args[2]))


func _crear_nativo() -> void:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	http.request_completed.connect(_al_respuesta_nativa.bind(http))
	var error := http.request(
		_api + "/salas",
		PackedStringArray(["Accept: application/json"]),
		HTTPClient.METHOD_POST,
		""
	)
	if error != OK:
		http.queue_free()
		_pidiendo = false
		fallo.emit("no se pudo contactar el servidor de salas (%s)" % error_string(error))


func _al_respuesta_nativa(_resultado, codigo: int, _cabeceras: PackedStringArray, cuerpo: PackedByteArray, http: HTTPRequest) -> void:
	if is_instance_valid(http):
		http.queue_free()
	_interpretar(codigo, cuerpo.get_string_from_utf8())


func _interpretar(codigo: int, texto: String) -> void:
	_pidiendo = false
	var datos = JSON.parse_string(texto)
	if codigo == 200 and datos is Dictionary and datos.has("url"):
		lista.emit(str(datos["url"]))
		return
	if datos is Dictionary and datos.has("error"):
		fallo.emit(str(datos["error"]))
	elif codigo == 0:
		fallo.emit("no hubo respuesta del servidor de salas")
	else:
		fallo.emit("el servidor de salas respondió %d" % codigo)
