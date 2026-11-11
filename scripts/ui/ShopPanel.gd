class_name ShopPanel
extends PanelContainer
## Mercader de la Rebelión: componentes, pociones, pergaminos y recetario.
## La forja es automática al comprar el ingrediente que completa una receta.

var _jugador: GladiatorController
var _arena: Node
var _lista: GridContainer
var _detalle: Label
var _oro: Label
var _comprar: Button
var _recetas: Button
var _seleccionado: ItemData
var _modo_recetas := false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(920, 410)
	size = Vector2(920, 410)
	anchor_left = 0.5
	anchor_top = 0.0
	anchor_right = 0.5
	anchor_bottom = 0.0
	offset_left = -460.0
	offset_top = 100.0
	offset_right = 460.0
	offset_bottom = 510.0
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.07, 0.06, 0.055, 1.0)
	estilo.border_color = Color(0.62, 0.45, 0.22)
	estilo.set_border_width_all(3)
	estilo.corner_radius_top_left = 6
	estilo.corner_radius_top_right = 6
	estilo.corner_radius_bottom_left = 6
	estilo.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", estilo)

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 16)
	margen.add_theme_constant_override("margin_right", 16)
	margen.add_theme_constant_override("margin_top", 12)
	margen.add_theme_constant_override("margin_bottom", 12)
	add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 6)
	margen.add_child(columna)

	var cabecera := HBoxContainer.new()
	columna.add_child(cabecera)
	var titulo := Label.new()
	titulo.text = "MERCADER DE LA REBELIÓN"
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Color(0.9, 0.72, 0.34))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(titulo)
	_oro = Label.new()
	_oro.add_theme_font_size_override("font_size", 17)
	_oro.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	cabecera.add_child(_oro)
	var cerrar := Button.new()
	cerrar.text = "F / ESC: cerrar"
	cerrar.flat = true
	cerrar.focus_mode = Control.FOCUS_NONE
	cerrar.pressed.connect(cerrar_panel)
	cabecera.add_child(cerrar)

	var filtros := HBoxContainer.new()
	columna.add_child(filtros)
	_recetas = Button.new()
	_recetas.text = "RECETARIO"
	_recetas.focus_mode = Control.FOCUS_NONE
	_recetas.pressed.connect(_alternar_recetario)
	filtros.add_child(_recetas)

	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 12)
	columna.add_child(cuerpo)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(590, 236)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cuerpo.add_child(scroll)
	_lista = GridContainer.new()
	_lista.columns = 3
	_lista.add_theme_constant_override("h_separation", 6)
	_lista.add_theme_constant_override("v_separation", 6)
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lista)

	var panel_detalle := PanelContainer.new()
	panel_detalle.custom_minimum_size = Vector2(290, 236)
	panel_detalle.clip_contents = true
	panel_detalle.add_theme_stylebox_override("panel", _estilo_caja())
	cuerpo.add_child(panel_detalle)
	var scroll_detalle := ScrollContainer.new()
	scroll_detalle.custom_minimum_size = Vector2(290, 236)
	scroll_detalle.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_detalle.add_child(scroll_detalle)
	var margen_detalle := MarginContainer.new()
	margen_detalle.add_theme_constant_override("margin_left", 10)
	margen_detalle.add_theme_constant_override("margin_right", 10)
	margen_detalle.add_theme_constant_override("margin_top", 10)
	margen_detalle.add_theme_constant_override("margin_bottom", 10)
	margen_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_detalle.add_child(margen_detalle)
	_detalle = Label.new()
	_detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalle.custom_minimum_size = Vector2(250, 0)
	_detalle.add_theme_font_size_override("font_size", 12)
	_detalle.add_theme_color_override("font_color", Color(0.9, 0.86, 0.76))
	margen_detalle.add_child(_detalle)

	var pie := HBoxContainer.new()
	columna.add_child(pie)
	_comprar = Button.new()
	_comprar.text = "COMPRAR"
	_comprar.focus_mode = Control.FOCUS_NONE
	_comprar.custom_minimum_size = Vector2(180, 34)
	_comprar.pressed.connect(_comprar_seleccionado)
	pie.add_child(_comprar)
	var aviso := Label.new()
	aviso.text = "Compra el último ingrediente y la forja se completa sola."
	aviso.add_theme_font_size_override("font_size", 11)
	aviso.add_theme_color_override("font_color", Color(0.65, 0.6, 0.5))
	pie.add_child(aviso)


func configurar(jugador: GladiatorController, arena: Node) -> void:
	_jugador = jugador
	_arena = arena
	if _jugador != null and _jugador.inventario != null:
		_jugador.inventario.cambiado.connect(_reconstruir)


func alternar() -> void:
	if visible:
		cerrar_panel()
		return
	visible = true
	modo_abierto()
	_reconstruir()
	get_tree().paused = true
	move_to_front()


func cerrar_panel() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


func modo_abierto() -> void:
	_seleccionado = null
	_modo_recetas = false
	_recetas.text = "RECETARIO"


func _unhandled_input(evento: InputEvent) -> void:
	if not visible or not (evento is InputEventKey):
		return
	var tecla := evento as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode in [KEY_ESCAPE, KEY_F, KEY_T]:
		cerrar_panel()
		get_viewport().set_input_as_handled()


func _alternar_recetario() -> void:
	_modo_recetas = not _modo_recetas
	_recetas.text = "COMPRAR" if _modo_recetas else "RECETARIO"
	_seleccionado = null
	_reconstruir()


func _reconstruir() -> void:
	if _lista == null:
		return
	for hijo in _lista.get_children():
		hijo.queue_free()
	_oro.text = "ORO  %d" % _oro_actual()

	var items: Array[ItemData] = []
	if _modo_recetas:
		items = ItemCatalog.recetas()
	else:
		items = ItemCatalog.vendibles()
	for item in items:
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(188, 58)
		boton.focus_mode = Control.FOCUS_NONE
		boton.add_theme_font_size_override("font_size", 11)
		var precio := "FORJA %d" % item.precio_forja if _modo_recetas else "%d oro" % item.precio
		boton.text = "%s\n%s" % [item.nombre, precio]
		boton.tooltip_text = _texto_item(item)
		boton.pressed.connect(_seleccionar.bind(item))
		_lista.add_child(boton)

	if _seleccionado == null and not items.is_empty():
		_seleccionado = items[0]

	if _seleccionado == null:
		_detalle.text = "Elige un objeto para ver sus stats, su receta y sus mejoras."
		_comprar.disabled = true
	else:
		_detalle.text = _texto_item(_seleccionado)
		_comprar.disabled = _modo_recetas or not _puede_comprar(_seleccionado)


func _seleccionar(item: ItemData) -> void:
	_seleccionado = item
	_detalle.text = _texto_item(item)
	_comprar.disabled = _modo_recetas or not _puede_comprar(item)


func _comprar_seleccionado() -> void:
	if _seleccionado == null or _arena == null:
		return
	if _arena.has_method("comprar_objeto"):
		_arena.comprar_objeto(_seleccionado)
	_reconstruir()


func _puede_comprar(item: ItemData) -> bool:
	if _arena != null and _arena.has_method("puede_comprar_objeto"):
		return _arena.puede_comprar_objeto(item)
	return false


func _oro_actual() -> int:
	if _arena == null:
		return 0
	var valor = _arena.get("oro")
	return int(valor) if valor != null else 0


func _texto_item(item: ItemData) -> String:
	var lineas: PackedStringArray = []
	lineas.append(item.nombre)
	lineas.append(item.descripcion)
	var bonos := item.descripcion_bonos()
	if not bonos.is_empty():
		lineas.append("")
		lineas.append(bonos)
	if item.habilidad != null:
		lineas.append("")
		lineas.append("ACTIVO: %s" % item.habilidad.nombre)
		lineas.append("Maná %d · Enfriamiento %.0f s" % [int(item.habilidad.coste_mana), item.habilidad.cooldown])
		if item.habilidad.dano_base > 0.0:
			lineas.append("Daño base %d + escalado" % int(item.habilidad.dano_base))
	if not item.receta.is_empty():
		lineas.append("")
		lineas.append("SE CONSTRUYE CON:")
		for ingrediente in item.receta:
			var otro := ItemCatalog.obtener(ingrediente)
			var nombre := otro.nombre if otro != null else String(ingrediente)
			var tiene := _jugador != null and _jugador.inventario != null and _jugador.inventario.tiene(ingrediente)
			lineas.append("%s %s" % ["+" if tiene else "-", nombre])
		lineas.append("Coste de forja: %d oro" % item.precio_forja)
	var mejoras := _mejoras(item.id)
	if not mejoras.is_empty():
		lineas.append("")
		lineas.append("MEJORA A:")
		for mejora in mejoras:
			lineas.append("> %s" % mejora.nombre)
	if item.tipo == ItemData.Tipo.COMPONENTE:
		lineas.append("")
		lineas.append("Compra el ingrediente que falta para forjar automáticamente.")
	return "\n".join(lineas)


func _mejoras(id: StringName) -> Array[ItemData]:
	var lista: Array[ItemData] = []
	for receta in ItemCatalog.recetas():
		if receta.receta.has(id):
			lista.append(receta)
	return lista


func _estilo_caja() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.1, 0.09, 0.08)
	estilo.border_color = Color(0.35, 0.28, 0.18)
	estilo.set_border_width_all(1)
	estilo.corner_radius_top_left = 4
	estilo.corner_radius_top_right = 4
	estilo.corner_radius_bottom_left = 4
	estilo.corner_radius_bottom_right = 4
	return estilo
