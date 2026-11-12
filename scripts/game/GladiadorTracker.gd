class_name GladiadorTracker
extends Node
## Rastrea los gladiadores activos de la arena para evitar consultas
## get_nodes_in_group("gladiadores") por frame en el jefe y enemigos.
##
## GladiatorController se registra al nacer y se desregistra al morir.

signal gladiador_registrado(gladiador: Node3D)
signal gladiador_desregistrado(gladiador: Node3D)

var gladiadores_activos: Array[Node3D] = []

func _ready() -> void:
	pass

func registrar(gladiador: Node3D) -> void:
	if gladiador in gladiadores_activos:
		return
	gladiadores_activos.append(gladiador)
	gladiador_registrado.emit(gladiador)

func desregistrar(gladiador: Node3D) -> void:
	if gladiador in gladiadores_activos:
		gladiadores_activos.erase(gladiador)
		gladiador_desregistrado.emit(gladiador)

func obtener_activos() -> Array[Node3D]:
	return gladiadores_activos.duplicate()

func buscar_mas_cercano(origen: Vector3) -> Node3D:
	var mejor: Node3D = null
	var mejor_distancia := INF
	for gladiador in gladiadores_activos:
		if gladiador == null or not is_instance_valid(gladiador):
			continue
		var distancia := origen.distance_squared_to(gladiador.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = gladiador
	return mejor
