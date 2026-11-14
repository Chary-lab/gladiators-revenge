class_name Perfil
extends RefCounted
## Perfil local del jugador: el apodo con el que entra a la arena.
##
## Vive en `user://perfil.cfg` para que se recuerde entre partidas. No tiene
## relación con la cuenta de red: en co-op el apodo viajará por el servidor
## cuando el lobby reparta nombres.

const RUTA := "user://perfil.cfg"
const LARGO_MAXIMO := 14
## Símbolos que no tienen sentido en un apodo y rompen etiquetas o rutas.
const PROHIBIDOS := "<>/\\{}[]|@#$%&*+=~^`\"'\n\r\t"
static var _apodo := ""
static var _cargado := false


## Apodo guardado (vacío si el jugador todavía no eligió uno).
static func apodo() -> String:
	_cargar()
	return _apodo


static func tiene_apodo() -> bool:
	return not apodo().is_empty()


static func guardar(nombre: String) -> String:
	var limpio := normalizar(nombre)
	if limpio.is_empty():
		return ""
	_apodo = limpio
	_cargado = true
	var config := ConfigFile.new()
	config.set_value("perfil", "apodo", _apodo)
	config.save(RUTA)
	return _apodo


## Limpia el texto: sin símbolos prohibidos, sin espacios repetidos y con tope
## de 14 caracteres. Acepta acentos y eñe (no se filtran letras).
static func normalizar(texto: String) -> String:
	var limpio := ""
	var crudo := texto.strip_edges()
	for i in crudo.length():
		var c := crudo[i]
		if PROHIBIDOS.contains(c):
			continue
		limpio += c
	limpio = limpio.strip_edges()
	while limpio.contains("  "):
		limpio = limpio.replace("  ", " ")
	if limpio.length() > LARGO_MAXIMO:
		limpio = limpio.substr(0, LARGO_MAXIMO).strip_edges()
	return limpio


static func _cargar() -> void:
	if _cargado:
		return
	_cargado = true
	var config := ConfigFile.new()
	if config.load(RUTA) != OK:
		return
	_apodo = normalizar(str(config.get_value("perfil", "apodo", "")))


## Sólo para pruebas: olvida lo leído en memoria (no borra el archivo).
static func reiniciar_cache() -> void:
	_apodo = ""
	_cargado = false
