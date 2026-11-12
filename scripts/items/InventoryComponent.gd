class_name InventoryComponent
extends Node
## Mochila de 6 ranuras activas (Z X C V B N).
## Los objetos de equipo otorgan bonus permanentes mientras estén en la mochila;
## pociones/pergaminos se consumen. La forja automática consume la receta.

signal cambiado
signal objeto_usado(indice: int, nombre: String)

const RANURAS := 6
const COOLDOWN_POCION := 8.0

var ranuras: Array[Dictionary] = []
var _cooldowns := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
var _cd_pocion := 0.0
var _jugador: GladiatorController


func _ready() -> void:
	if ranuras.is_empty():
		for i in RANURAS:
			ranuras.append({"item": null, "cantidad": 0})


func configurar(jugador: GladiatorController) -> void:
	_jugador = jugador
	if ranuras.is_empty():
		_ready()
	_recalcular_bonos()


func actualizar(delta: float) -> void:
	for i in _cooldowns.size():
		_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)
	_cd_pocion = maxf(0.0, _cd_pocion - delta)


func energia_restante(indice: int) -> float:
	if indice < 0 or indice >= _cooldowns.size():
		return 0.0
	return _cooldowns[indice]


## Sustituye las ranuras con el estado autoritativo del servidor. No recalcula
## bonos: GladiatorStats recibe los totales dentro del snapshot de red.
func aplicar_estado_red(datos: Array) -> void:
	if ranuras.size() != RANURAS:
		_ready()
	var cambio := false
	for i in RANURAS:
		var item: ItemData = null
		var cantidad := 0
		var cd := 0.0
		if i < datos.size() and datos[i] is Dictionary:
			var fila: Dictionary = datos[i]
			var id := StringName(fila.get("id", &""))
			if id != &"":
				item = ItemCatalog.obtener(id)
			cantidad = int(fila.get("cantidad", 0))
			cd = float(fila.get("cd", 0.0))
		var anterior: ItemData = ranuras[i].get("item")
		var id_anterior: StringName = anterior.id if anterior != null else &""
		var id_nuevo: StringName = item.id if item != null else &""
		if id_anterior != id_nuevo or int(ranuras[i].get("cantidad", 0)) != cantidad:
			cambio = true
		ranuras[i] = {"item": item, "cantidad": cantidad}
		_cooldowns[i] = cd
	if cambio:
		cambiado.emit()


func cooldown_pocion() -> float:
	return _cd_pocion


func espacio_para(item: ItemData) -> bool:
	if item == null:
		return false
	if item.consumible:
		for ranura in ranuras:
			if ranura["item"] != null and ranura["item"].id == item.id and ranura["cantidad"] < item.maximo_pila:
				return true
	for ranura in ranuras:
		if ranura["item"] == null:
			return true
	return false


func agregar(item: ItemData, cantidad := 1) -> bool:
	if item == null or cantidad <= 0:
		return false
	if item.consumible:
		for ranura in ranuras:
			if ranura["item"] != null and ranura["item"].id == item.id and ranura["cantidad"] < item.maximo_pila:
				var espacio: int = item.maximo_pila - int(ranura["cantidad"])
				var meter: int = min(espacio, cantidad)
				ranura["cantidad"] = int(ranura["cantidad"]) + meter
				_recalcular_bonos()
				cambiado.emit()
				return true
	for i in ranuras.size():
		if ranuras[i]["item"] == null:
			ranuras[i] = {"item": item, "cantidad": cantidad}
			_recalcular_bonos()
			cambiado.emit()
			return true
	return false


func tiene(id: StringName, cantidad := 1) -> bool:
	return contar(id) >= cantidad


func contar(id: StringName) -> int:
	var total := 0
	for ranura in ranuras:
		if ranura["item"] != null and ranura["item"].id == id:
			total += int(ranura["cantidad"])
	return total


func consumir(id: StringName, cantidad := 1) -> bool:
	if contar(id) < cantidad:
		return false
	var resto := cantidad
	for i in ranuras.size():
		var ranura: Dictionary = ranuras[i]
		if ranura["item"] == null or ranura["item"].id != id:
			continue
		var quitar: int = min(resto, int(ranura["cantidad"]))
		ranura["cantidad"] = int(ranura["cantidad"]) - quitar
		resto -= quitar
		if int(ranura["cantidad"]) <= 0:
			ranuras[i] = {"item": null, "cantidad": 0}
			_cooldowns[i] = 0.0
		if resto <= 0:
			break
	_recalcular_bonos()
	cambiado.emit()
	return true


## Intercambia el contenido de dos ranuras (para reordenar el inventario).
func intercambiar(i: int, j: int) -> bool:
	if i < 0 or i >= ranuras.size() or j < 0 or j >= ranuras.size():
		return false
	if i == j:
		return true
	var tmp := ranuras[i].duplicate()
	ranuras[i] = ranuras[j].duplicate()
	ranuras[j] = tmp
	var cd_tmp := _cooldowns[i]
	_cooldowns[i] = _cooldowns[j]
	_cooldowns[j] = cd_tmp
	_recalcular_bonos()
	cambiado.emit()
	return true

## Quita el objeto de una ranura y lo devuelve (para vender o mover).
func extraer(indice: int) -> ItemData:
	if indice < 0 or indice >= ranuras.size():
		return null
	var ranura := ranuras[indice]
	var item: ItemData = ranura.get("item")
	ranuras[indice] = {"item": null, "cantidad": 0}
	_cooldowns[indice] = 0.0
	_recalcular_bonos()
	cambiado.emit()
	return item

## Precio de venta: mitad del precio de compra, mínimo 1 de oro.
func precio_venta(indice: int) -> int:
	if indice < 0 or indice >= ranuras.size():
		return 0
	var item: ItemData = ranuras[indice].get("item")
	if item == null:
		return 0
	return max(1, int(item.precio / 2.0))


## Devuelve la receta que se completaría comprando `item` (el ingrediente que
## falta), o null si no hay ninguna.
func receta_completada_por(item: ItemData) -> ItemData:
	if item == null:
		return null
	var mejor: ItemData = null
	for receta in ItemCatalog.recetas():
		if not receta.receta.has(item.id):
			continue
		var completa := true
		for ingrediente in receta.receta:
			if ingrediente == item.id:
				continue
			if not tiene(ingrediente):
				completa = false
				break
		if completa and (mejor == null or receta.nivel > mejor.nivel):
			mejor = receta
	return mejor


func forjar_con(item_nuevo: ItemData, receta: ItemData) -> ItemData:
	## Consume los ingredientes que ya estaban en la mochila y crea la receta.
	## `item_nuevo` se asume ya pagado; si ya está en el inventario (porque fue
	## comprado o forjado previamente) no se duplica, solo se consume como
	## ingrediente junto con los demás.
	if receta == null:
		return null
	var ya_esta := false
	for ranura in ranuras:
		if ranura["item"] != null and ranura["item"].id == item_nuevo.id:
			ya_esta = true
			break
	if not ya_esta:
		## Agregar el item comprado al inventario para que forme parte de la forja
		if not agregar(item_nuevo):
			return null
	for ingrediente in receta.receta:
		if not consumir(ingrediente):
			return null
	var creado := receta
	if not agregar(creado):
		return null
	_recalcular_bonos()
	cambiado.emit()
	return creado


func usar(indice: int, jugador: GladiatorController) -> bool:
	if jugador == null or jugador.esta_muerto:
		return false
	if indice < 0 or indice >= ranuras.size():
		return false
	var ranura: Dictionary = ranuras[indice]
	var item: ItemData = ranura["item"]
	if item == null:
		return false
	if _cooldowns[indice] > 0.0:
		return false

	if item.es_pocion() and _cd_pocion > 0.0:
		return false

	if item.consumible:
		if item.curacion_vida > 0.0:
			jugador.curar(item.curacion_vida + jugador.estadisticas.fuerza_total * 0.4)
		if item.curacion_mana > 0.0:
			jugador.restaurar_mana(item.curacion_mana + jugador.estadisticas.inteligencia_total * 0.3)
		if item.efecto_especial == &"escudo_estandarte":
			jugador.otorgar_escudo(120.0, 8.0)
			for nodo in get_tree().get_nodes_in_group("banderas"):
				if nodo.has_method("curar"):
					nodo.curar(220.0)
		elif item.efecto_especial == &"furia_temporal":
			jugador.aplicar_furia_temporal(8.0, 0.35, 0.15)
		elif item.habilidad != null:
			if not jugador.lanzar_habilidad_item(item.habilidad):
				return false
		_cooldowns[indice] = COOLDOWN_POCION if item.es_pocion() else 6.0
		if item.es_pocion():
			_cd_pocion = COOLDOWN_POCION
		consumir(item.id)
		objeto_usado.emit(indice, item.nombre)
		return true

	if item.habilidad != null:
		if not jugador.lanzar_habilidad_item(item.habilidad):
			return false
		_cooldowns[indice] = maxf(6.0, item.habilidad.cooldown)
		objeto_usado.emit(indice, item.nombre)
		return true

	return false


func _recalcular_bonos() -> void:
	var totales: Dictionary = {}
	for ranura in ranuras:
		var item: ItemData = ranura["item"]
		if item == null:
			continue
		for clave in item.bonificaciones:
			totales[clave] = float(totales.get(clave, 0.0)) + float(item.bonificaciones[clave])
	if _jugador != null and _jugador.estadisticas != null:
		var vida_antes := _jugador.estadisticas.salud_maxima
		_jugador.estadisticas.aplicar_bonos_inventario(totales)
		var vida_despues := _jugador.estadisticas.salud_maxima
		var ganancia := vida_despues - vida_antes
		if ganancia > 0.0:
			# Un objeto que da vida máxima también entrega esa vida al campeón:
			# no se queda "sin llenar" al comprar o forjar.
			_jugador.curar(ganancia)
