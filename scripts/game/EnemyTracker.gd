class_name EnemyTracker
extends Node
## Rastrea los enemigos activos de la arena para evitar consultas
## get_nodes_in_group("enemigos") por frame en cada frame de combate.
##
## ArenaEnemy se registra al prepararse y se desregistra al morir.
## GladiatorController y AbilityEffect leen esta lista en lugar de recorrer el árbol.

signal enemigo_registrado(enemigo: Node3D)
signal enemigo_desregistrado(enemigo: Node3D)

var enemigos_activos: Array[Node3D] = []

func _ready() -> void:
	pass

func registrar(enemigo: Node3D) -> void:
	if enemigo in enemigos_activos:
		return
	enemigos_activos.append(enemigo)
	enemigo_registrado.emit(enemigo)

func desregistrar(enemigo: Node3D) -> void:
	if enemigo in enemigos_activos:
		enemigos_activos.erase(enemigo)
		enemigo_desregistrado.emit(enemigo)

func obtener_activos() -> Array[Node3D]:
	return enemigos_activos.duplicate()

func buscar_mas_cercano(origen: Vector3, radio: float) -> Node3D:
	var mejor: Node3D = null
	var mejor_distancia := radio
	for enemigo in enemigos_activos:
		if enemigo == null or not is_instance_valid(enemigo):
			continue
		var distancia := origen.distance_to(enemigo.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = enemigo
	return mejor

func hay_alguno_en_radio(origen: Vector3, radio: float, condicion = null) -> bool:
	for enemigo in enemigos_activos:
		if enemigo == null or not is_instance_valid(enemigo):
			continue
		if origen.distance_to(enemigo.global_position) > radio:
			continue
		if condicion != null and not condicion.call(enemigo):
			continue
		return true
	return false
