class_name ObjectPool
extends Node
## Pool genérico para proyectiles, VFX y enemigos.
##
## En Web la instanciación y el garbage collector son caros: se crean los nodos
## una vez, se desactivan y se reutilizan. La fábrica es un Callable que devuelve
## un nodo nuevo (normalmente una función estática `crear()`).

var _fabrica: Callable
var _libres: Array[Node] = []


func _init(fabrica: Callable = Callable()) -> void:
	_fabrica = fabrica


func configurar(fabrica: Callable) -> void:
	_fabrica = fabrica


## Crea nodos inactivos por adelantado. Llamar después de add_child(pool).
func precalentar(cantidad: int) -> void:
	for i in cantidad:
		_libres.append(_instanciar())


func obtener() -> Node:
	var nodo: Node = _libres.pop_back() if not _libres.is_empty() else _instanciar()
	nodo.set_process(true)
	nodo.set_physics_process(true)
	if nodo is Node3D:
		(nodo as Node3D).visible = true
	if nodo is CollisionObject3D and nodo.has_meta("capa_original"):
		(nodo as CollisionObject3D).collision_layer = int(nodo.get_meta("capa_original"))
	if nodo.has_method("al_obtener"):
		nodo.al_obtener()
	return nodo


func devolver(nodo: Node) -> void:
	if nodo == null or not is_instance_valid(nodo):
		return
	if nodo.has_method("al_devolver"):
		nodo.al_devolver()
	_desactivar(nodo)
	if not _libres.has(nodo):
		_libres.append(nodo)


func _instanciar() -> Node:
	assert(_fabrica.is_valid(), "ObjectPool sin fábrica configurada")
	var nodo: Node = _fabrica.call()
	add_child(nodo)
	_desactivar(nodo)
	return nodo


func _desactivar(nodo: Node) -> void:
	nodo.set_process(false)
	nodo.set_physics_process(false)
	if nodo is CollisionObject3D:
		var cuerpo := nodo as CollisionObject3D
		if not nodo.has_meta("capa_original"):
			nodo.set_meta("capa_original", cuerpo.collision_layer)
		cuerpo.collision_layer = 0
	if nodo is Node3D:
		(nodo as Node3D).visible = false
