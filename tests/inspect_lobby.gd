extends SceneTree
## Sonda: ¿el menú de red carga la lista de servidores sin pulsar ACTUALIZAR?
## Uso: godot --headless --script res://tests/inspect_lobby.gd

var _listo := false
var _menu: MenuRed


func _initialize() -> void:
	print("== sonda lobby ==")
	await create_timer(0.5).timeout
	# Igual que Arena._mostrar_menu: crear el menú y configurarlo de una vez.
	_menu = MenuRed.new()
	root.add_child(_menu)
	_menu.configurar("")
	await create_timer(6.0).timeout
	var etiqueta: Label = _menu.get("_estado_servidores")
	print("estado del menú: ", etiqueta.text if etiqueta != null else "(sin etiqueta)")
	var lista: VBoxContainer = _menu.get("_lista_servidores")
	print("botones de servidor: ", lista.get_child_count() if lista != null else -1)
	_listo = true


func _process(_delta: float) -> bool:
	return _listo
