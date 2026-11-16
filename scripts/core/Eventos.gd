class_name Eventos
extends RefCounted
## Puente opcional al autoload EventBus.
##
## Los scripts del juego se compilan en `--script` (suites headless), donde los
## autoloads no existen. Referenciar `EventBus` por identificador rompería la
## compilación, así que todas las emisiones pasan por aquí y se resuelven en
## tiempo de ejecución.

static func bus() -> Node:
	var bucle := Engine.get_main_loop() as SceneTree
	if bucle == null or bucle.root == null:
		return null
	return bucle.root.get_node_or_null("EventBus")


static func emitir(nombre: StringName, argumentos: Array = []) -> void:
	var bus := bus()
	if bus == null:
		return
	# GDScript no tiene splat: despachamos por aridad (todas las señales del
	# EventBus tienen 0, 1, 2 o 3 argumentos).
	match argumentos.size():
		0:
			bus.emit_signal(nombre)
		1:
			bus.emit_signal(nombre, argumentos[0])
		2:
			bus.emit_signal(nombre, argumentos[0], argumentos[1])
		3:
			bus.emit_signal(nombre, argumentos[0], argumentos[1], argumentos[2])
		_:
			push_warning("Eventos: demasiados argumentos para %s" % String(nombre))


static func mensaje(texto: String, duracion: float = 2.5) -> void:
	emitir(&"mensaje", [texto, duracion])


static func oleada_iniciada(numero: int, total: int) -> void:
	emitir(&"oleada_iniciada", [numero, total])


static func oleada_terminada(numero: int) -> void:
	emitir(&"oleada_terminada", [numero])


static func oro(cantidad: int) -> void:
	emitir(&"oro_cambiado", [cantidad])


static func inventario() -> void:
	emitir(&"inventario_cambiado", [])


static func talentos() -> void:
	emitir(&"talentos_cambiados", [])


static func bajas(total: int) -> void:
	emitir(&"enemigo_abatido", [total])


static func habilidad(slot: int, dato: AbilityData) -> void:
	emitir(&"habilidad_lanzada", [slot, dato])


static func dano(objetivo: Node3D, cantidad: float, critico: bool) -> void:
	emitir(&"dano_infligido", [objetivo, cantidad, critico])
