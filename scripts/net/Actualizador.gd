class_name Actualizador
extends Node
## Comprueba si hay una versión más nueva en GitHub y avisa al menú.
##
## No reemplaza el APK por sí solo (eso necesita un plugin nativo de Android y
## permisos de instalación): muestra el aviso y abre la página del release para
## descargar. En Web la "actualización" es recargar la página.

signal disponible(version: String, url: String)
signal al_dia

const API := "https://api.github.com/repos/Chary-lab/gladiators-revenge/releases/latest"

var _callback
var _secuencia := 0


func comprobar() -> void:
	if OS.has_feature("web"):
		_comprobar_web()
		return
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	http.request_completed.connect(_al_responder_http.bind(http))
	http.request(
		API,
		PackedStringArray(["Accept: application/vnd.github+json", "User-Agent: gladiators-revenge"]),
		HTTPClient.METHOD_GET,
		""
	)


func _comprobar_web() -> void:
	if _callback == null:
		_callback = JavaScriptBridge.create_callback(_al_responder_web)
		JavaScriptBridge.get_interface("window").__act_resp = _callback
	_secuencia += 1
	var js := (
		"(async () => { try { const r = await fetch(%s, {headers: {'Accept': 'application/vnd.github+json'}});"
		+ " const t = await r.text(); window.__act_resp(r.status, t); }"
		+ " catch (e) { window.__act_resp(0, String(e)); } })();"
	) % JSON.stringify(API)
	JavaScriptBridge.eval(js, true)


func _al_responder_web(args: Array) -> void:
	_interpretar(int(args[0]), str(args[1]))


func _al_responder_http(_resultado, codigo: int, _cabeceras: PackedStringArray, cuerpo: PackedByteArray, http: HTTPRequest) -> void:
	if is_instance_valid(http):
		http.queue_free()
	_interpretar(codigo, cuerpo.get_string_from_utf8())


func _interpretar(codigo: int, texto: String) -> void:
	if codigo != 200:
		return
	var datos = JSON.parse_string(texto)
	if not (datos is Dictionary) or not datos.has("tag_name"):
		return
	var ultima := str(datos.get("tag_name", "")).trim_prefix("v")
	var actual := str(ProjectSettings.get_setting("config/version", "0"))
	var enlace := str(datos.get("html_url", ""))
	if _es_mas_nueva(ultima, actual) and not enlace.is_empty():
		disponible.emit(ultima, enlace)
	else:
		al_dia.emit()


func _es_mas_nueva(ultima: String, actual: String) -> bool:
	var a := ultima.split(".")
	var b := actual.split(".")
	for i in maxi(a.size(), b.size()):
		var x := int(a[i]) if i < a.size() else 0
		var y := int(b[i]) if i < b.size() else 0
		if x != y:
			return x > y
	return false


## Abre el release en el navegador (Android/escritorio) o en una pestaña (Web).
func abrir_enlace(url: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open(%s, '_blank')" % JSON.stringify(url), true)
	else:
		OS.shell_open(url)
