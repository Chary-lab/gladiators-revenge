class_name GameState
extends Node
## Estado de partida: oro, puntos de atributo, victoria/derrota y piel.
## Extraído de Arena para desacoplar la economía del mundo y la red.
##
## Invariant: un GameState por partida; Arena es quien lo consulta y actualiza.

signal oro_cambiado(cantidad: int)
signal puntos_cambiados(cantidad: int)
signal partida_terminada(titulo: String, detalle: String)

var oro := 200
var puntos_atributo := 0
var terminado := false
var _skin_actual := 0
var _resultado_red := ""

func _ready() -> void:
	pass

## Devuelve true si se pudo gastar el oro.
func gastar_oro(cantidad: int) -> bool:
	if cantidad <= 0:
		return true
	if oro < cantidad:
		return false
	oro -= cantidad
	oro_cambiado.emit(oro)
	return true

func agregar_oro(cantidad: int) -> void:
	if cantidad <= 0:
		return
	oro += cantidad
	oro_cambiado.emit(oro)

## Gasta un punto de atributo si queda alguno.
func gastar_punto_atributo() -> bool:
	if puntos_atributo <= 0:
		return false
	puntos_atributo -= 1
	puntos_cambiados.emit(puntos_atributo)
	return true

func otorgar_puntos_atributo(cantidad: int) -> void:
	if cantidad <= 0:
		return
	puntos_atributo += cantidad
	puntos_cambiados.emit(puntos_atributo)

## Vende un objeto del inventario y suma el precio de venta al oro.
func vender_objeto(item_precio: int) -> int:
	var ganancia := maxi(1, int(item_precio / 2.0))
	agregar_oro(ganancia)
	return ganancia

## Marca la partida como terminada y emite la señal.
func finalizar(titulo: String, detalle: String) -> void:
	if terminado:
		return
	terminado = true
	_resultado_red = "%s\n%s" % [titulo, detalle]
	partida_terminada.emit(titulo, detalle)

func esta_terminado() -> bool:
	return terminado

func resultado_red() -> String:
	return _resultado_red

func obtener_skin() -> int:
	return _skin_actual

func ciclar_skin(cantidad_skins: int) -> Dictionary:
	_skin_actual = (_skin_actual + 1) % cantidad_skins
	return {"indice": _skin_actual}
