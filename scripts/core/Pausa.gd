class_name Pausa
extends RefCounted
## Pausa del árbol con contador: dos paneles abiertos a la vez no se pisan.
##
## Antes cada panel hacía `get_tree().paused = true/false` por su cuenta y, si se
## abría uno encima de otro (tienda + talentos, tienda + mochila), al cerrar el
## último se reanudaba la partida con el otro todavía abierto, o se quedaba
## pausada para siempre: los enfriamientos se congelaban y el juego "se trababa".

static var _abiertos := 0


static func abrir() -> void:
	_abiertos += 1
	var arbol := _arbol()
	if arbol != null:
		arbol.paused = true


static func cerrar() -> void:
	_abiertos = maxi(0, _abiertos - 1)
	if _abiertos > 0:
		return
	var arbol := _arbol()
	if arbol != null:
		arbol.paused = false


## Vuelve a cero (reinicio de partida, derrota, volver al lobby).
static func reanudar() -> void:
	_abiertos = 0
	var arbol := _arbol()
	if arbol != null:
		arbol.paused = false


static func hay_paneles() -> bool:
	return _abiertos > 0


static func _arbol() -> SceneTree:
	var bucle := Engine.get_main_loop()
	return bucle as SceneTree if bucle is SceneTree else null
