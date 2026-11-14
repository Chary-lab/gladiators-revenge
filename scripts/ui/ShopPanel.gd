class_name ShopPanel
extends PanelContainer
## Mercader de la Rebelión con ficha fija, al estilo de las tiendas de arena:
## a la izquierda una cuadrícula de objetos por secciones (legendario, épico,
## componentes y forjables) con el precio sobre el icono; a la derecha la ficha
## del objeto elegido con sus bonificaciones, su receta y el botón de acción.
##
## Reglas que no cambian: una sola lista (sin pestañas ni filtros de rareza) y
## el modo VENDER en el mismo panel. Tocar una tarjeta la selecciona; tocarla
## otra vez compra sin pasar por el botón, así en el móvil sigue siendo rápido.
## La lógica de compra vive en Arena/InventoryComponent.

const ANCHO := 1120.0
const ALTO := 560.0
const COLUMNAS := 6
const LADO_TARJETA := 96.0
const ALTO_TARJETA := 112.0
const ANCHO_FICHA := 330.0

var _jugador: GladiatorController
var _arena: Node
var _hud: ArenaHUD
## Primera cuadrícula de la lista (compatibilidad con pruebas y otras pantallas).
var _grid: GridContainer
var _cuadriculas: Array[GridContainer] = []
var _cuerpo: VBoxContainer
var _oro: Label
var _aviso: Label
var _chip_comprar: Button
var _chip_vender: Button
var _campo_busqueda: LineEdit
var _busqueda := ""
var _vender := false
var _pausado := false

var _seleccionado: ItemData
var _seleccion_indice := -1
var _seleccion_forjable := false
var _botones: Dictionary = {}

# Ficha lateral
var _ficha_icono: TextureRect
var _ficha_nombre: Label
var _ficha_rareza: Label
var _ficha_tipo: Label
var _ficha_bonos: Label
var _ficha_receta: Label
var _ficha_precio: Label
var _ficha_accion: Button
var _ficha_vacia: Label
var _ficha_caja: VBoxContainer
## Árbol de construcción: qué ingredientes pide y en qué objetos se convierte.
var _rotulo_entra: Label
var _rotulo_sale: Label
var _arbol_entra: HBoxContainer
var _arbol_sale: HBoxContainer
## Índice inverso `ingrediente -> [objetos que lo usan]`, compartido entre paneles.
static var _padres: Dictionary = {}


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(ANCHO, ALTO)
	size = Vector2(ANCHO, ALTO)
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -ANCHO * 0.5
	offset_right = ANCHO * 0.5
	offset_top = 84.0
	offset_bottom = 84.0 + ALTO
	add_theme_stylebox_override("panel", ForjaTema.estilo_ventana())

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 18)
	margen.add_theme_constant_override("margin_right", 18)
	margen.add_theme_constant_override("margin_top", 12)
	margen.add_theme_constant_override("margin_bottom", 12)
	add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	margen.add_child(columna)

	columna.add_child(_crear_cabecera())
	columna.add_child(_crear_barra_modos())
	columna.add_child(ForjaTema.regla(ANCHO - 36.0))

	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 14)
	columna.add_child(cuerpo)

	cuerpo.add_child(_crear_lista())
	cuerpo.add_child(_crear_ficha())

	_actualizar_chips()
	_actualizar_ficha()


# --- Construcción -----------------------------------------------------------

func _crear_cabecera() -> Control:
	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 10)

	var titulo := ForjaTema.titulo("MERCADER DE LA REBELIÓN", 24, ForjaTema.ORO_CLARO)
	titulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabecera.add_child(titulo)

	var relleno := Control.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(relleno)

	var icono_oro := ForjaTema.IconoStat.new(&"oro", 16.0, ForjaTema.ORO)
	icono_oro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabecera.add_child(icono_oro)
	_oro = ForjaTema.titulo("0", 20, ForjaTema.ORO)
	_oro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabecera.add_child(_oro)

	var cerrar := ForjaTema.boton("CERRAR", 12)
	cerrar.custom_minimum_size = Vector2(104, 34)
	cerrar.pressed.connect(cerrar_panel)
	cabecera.add_child(cerrar)
	return cabecera


func _crear_barra_modos() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)

	_chip_comprar = ForjaTema.boton("COMPRAR", 13)
	_chip_comprar.custom_minimum_size = Vector2(140, 34)
	_chip_comprar.pressed.connect(_cambiar_modo.bind(false))
	fila.add_child(_chip_comprar)

	_chip_vender = ForjaTema.boton("VENDER", 13)
	_chip_vender.custom_minimum_size = Vector2(140, 34)
	_chip_vender.pressed.connect(_cambiar_modo.bind(true))
	fila.add_child(_chip_vender)

	_campo_busqueda = LineEdit.new()
	_campo_busqueda.placeholder_text = "Buscar objeto…"
	_campo_busqueda.custom_minimum_size = Vector2(220, 34)
	_campo_busqueda.clear_button_enabled = true
	_campo_busqueda.add_theme_stylebox_override("normal", ForjaTema.estilo_tarjeta(ForjaTema.ORO_OSCURO, false, true))
	_campo_busqueda.add_theme_stylebox_override("focus", ForjaTema.estilo_tarjeta(ForjaTema.ORO, false, true))
	_campo_busqueda.text_changed.connect(_al_buscar)
	fila.add_child(_campo_busqueda)

	_aviso = ForjaTema.etiqueta("Tocá un objeto y después COMPRAR.", 11, ForjaTema.TENUE)
	_aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aviso.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(_aviso)
	return fila


func _crear_lista() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_constant_override("scrollbar_width", 8)

	_cuerpo = VBoxContainer.new()
	_cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cuerpo.add_theme_constant_override("separation", 6)
	scroll.add_child(_cuerpo)
	return scroll


func _crear_ficha() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ANCHO_FICHA, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", ForjaTema.estilo_panel(1.0, ForjaTema.ORO_OSCURO))

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 12)
	margen.add_theme_constant_override("margin_right", 12)
	margen.add_theme_constant_override("margin_top", 12)
	margen.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margen)

	# Columna con scroll para que el árbol de construcción nunca recorte la ficha;
	# el precio y el botón quedan fijos abajo, siempre visibles.
	var columna_ficha := VBoxContainer.new()
	columna_ficha.add_theme_constant_override("separation", 6)
	margen.add_child(columna_ficha)

	var scroll_ficha := ScrollContainer.new()
	scroll_ficha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_ficha.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_ficha.add_theme_constant_override("scrollbar_width", 6)
	columna_ficha.add_child(scroll_ficha)

	_ficha_caja = VBoxContainer.new()
	_ficha_caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ficha_caja.add_theme_constant_override("separation", 6)
	scroll_ficha.add_child(_ficha_caja)

	_ficha_vacia = ForjaTema.etiqueta(
		"Elegí un objeto de la lista para ver sus bonificaciones, su receta y comprarlo.",
		12, ForjaTema.TENUE, true
	)
	_ficha_vacia.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ficha_caja.add_child(_ficha_vacia)

	_ficha_icono = TextureRect.new()
	_ficha_icono.custom_minimum_size = Vector2(76, 76)
	_ficha_icono.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ficha_icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ficha_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ficha_icono.visible = false
	_ficha_caja.add_child(_ficha_icono)

	_ficha_nombre = ForjaTema.titulo("", 20, ForjaTema.ORO_CLARO)
	_ficha_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ficha_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ficha_nombre.visible = false
	_ficha_caja.add_child(_ficha_nombre)

	_ficha_rareza = ForjaTema.rotulo("", 11, ForjaTema.TENUE)
	_ficha_rareza.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ficha_rareza.visible = false
	_ficha_caja.add_child(_ficha_rareza)

	_ficha_tipo = ForjaTema.etiqueta("", 11, ForjaTema.TENUE)
	_ficha_tipo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ficha_tipo.visible = false
	_ficha_caja.add_child(_ficha_tipo)

	# --- Árbol de construcción (se forja con / se construye en) -------------
	var separador := ForjaTema.regla(ANCHO_FICHA - 24.0)
	_ficha_caja.add_child(separador)

	_rotulo_entra = ForjaTema.rotulo("SE FORJA CON", 10, ForjaTema.ORO)
	_rotulo_entra.visible = false
	_ficha_caja.add_child(_rotulo_entra)
	_arbol_entra = HBoxContainer.new()
	_arbol_entra.add_theme_constant_override("separation", 6)
	_arbol_entra.visible = false
	_ficha_caja.add_child(_arbol_entra)

	_rotulo_sale = ForjaTema.rotulo("SE CONSTRUYE EN", 10, ForjaTema.ORO)
	_rotulo_sale.visible = false
	_ficha_caja.add_child(_rotulo_sale)
	_arbol_sale = HBoxContainer.new()
	_arbol_sale.add_theme_constant_override("separation", 6)
	_arbol_sale.visible = false
	_ficha_caja.add_child(_arbol_sale)

	_ficha_bonos = ForjaTema.etiqueta("", 12, ForjaTema.TEXTO)
	_ficha_bonos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ficha_bonos.visible = false
	_ficha_caja.add_child(_ficha_bonos)

	_ficha_receta = ForjaTema.etiqueta("", 11, ForjaTema.TENUE)
	_ficha_receta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ficha_receta.visible = false
	_ficha_caja.add_child(_ficha_receta)

	var relleno := Control.new()
	relleno.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ficha_caja.add_child(relleno)

	columna_ficha.add_child(ForjaTema.regla(ANCHO_FICHA - 24.0))

	_ficha_precio = ForjaTema.titulo("", 20, ForjaTema.ORO)
	_ficha_precio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ficha_precio.visible = false
	columna_ficha.add_child(_ficha_precio)

	_ficha_accion = ForjaTema.boton("COMPRAR", 15, true)
	_ficha_accion.custom_minimum_size = Vector2(0, 42)
	_ficha_accion.visible = false
	_ficha_accion.pressed.connect(_accion_ficha)
	columna_ficha.add_child(_ficha_accion)

	# La descripción va después del árbol: "se forja con / se construye en" queda
	# arriba y se ve sin hacer scroll en la ficha.
	_ficha_caja.move_child(_ficha_tipo, _ficha_bonos.get_index())
	return panel


# --- API pública ------------------------------------------------------------

func configurar(jugador: GladiatorController, arena: Node, hud: ArenaHUD = null) -> void:
	_jugador = jugador
	_arena = arena
	_hud = hud
	if _jugador != null and _jugador.inventario != null:
		if not _jugador.inventario.cambiado.is_connected(_reconstruir):
			_jugador.inventario.cambiado.connect(_reconstruir)


func alternar() -> void:
	if visible:
		cerrar_panel()
		return
	visible = true
	modo_abierto()
	_reconstruir()
	if not _pausado:
		_pausado = true
		Pausa.abrir()
	move_to_front()
	Sfx.reproducir(&"click", -12.0)


func cerrar_panel() -> void:
	if not visible and not _pausado:
		return
	visible = false
	if _hud != null:
		_hud.forzar_ocultar_tooltip()
	if _pausado:
		_pausado = false
		Pausa.cerrar()


func modo_abierto() -> void:
	_vender = false
	_seleccionado = null
	_seleccion_indice = -1
	_seleccion_forjable = false
	_busqueda = ""
	if _campo_busqueda != null:
		_campo_busqueda.text = ""
	if _arena != null and _arena.has_method("revisar_forjas_automaticas"):
		_arena.revisar_forjas_automaticas()
	_actualizar_chips()
	_actualizar_ficha()


func _unhandled_input(evento: InputEvent) -> void:
	if not visible or not (evento is InputEventKey):
		return
	var tecla := evento as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode in [KEY_ESCAPE, KEY_F, KEY_T]:
		cerrar_panel()
		get_viewport().set_input_as_handled()


# --- Modos ------------------------------------------------------------------

func _cambiar_modo(vender: bool) -> void:
	if vender == _vender:
		return
	_vender = vender
	_seleccionado = null
	_seleccion_indice = -1
	_seleccion_forjable = false
	_actualizar_chips()
	_reconstruir()
	_actualizar_ficha()
	Sfx.reproducir(&"click", -12.0)


func _actualizar_chips() -> void:
	if _chip_comprar == null:
		return
	_pintar_chip(_chip_comprar, not _vender)
	_pintar_chip(_chip_vender, _vender)
	if _vender:
		_aviso.text = "Tocá un objeto de la mochila para venderlo por la mitad."
	else:
		_aviso.text = "Tocá un objeto y después COMPRAR."


func _pintar_chip(chip: Button, activo: bool) -> void:
	var estilo := ForjaTema.estilo_tarjeta(ForjaTema.ORO if activo else ForjaTema.ORO_OSCURO, activo, true)
	chip.add_theme_stylebox_override("normal", estilo)
	chip.add_theme_stylebox_override("hover", estilo)
	chip.add_theme_stylebox_override("pressed", estilo)
	chip.add_theme_color_override("font_color", Color(0.07, 0.06, 0.05) if activo else ForjaTema.TEXTO)


func _al_buscar(texto: String) -> void:
	_busqueda = _normalizar(texto)
	_reconstruir()


# --- Lista ------------------------------------------------------------------

func _reconstruir() -> void:
	if _cuerpo == null:
		return
	for hijo in _cuerpo.get_children():
		_cuerpo.remove_child(hijo)
		hijo.queue_free()
	_cuadriculas.clear()
	_botones.clear()
	_grid = null
	_oro.text = str(_oro_actual())

	if _vender:
		_reconstruir_venta()
		return

	var legendarios: Array[ItemData] = []
	var epicos: Array[ItemData] = []
	var basicos: Array[ItemData] = []
	for item in ItemCatalog.vendibles():
		if not _pasa_busqueda(item):
			continue
		match item.rareza:
			ItemData.Rareza.LEGENDARIO:
				legendarios.append(item)
			ItemData.Rareza.EPICO:
				epicos.append(item)
			_:
				basicos.append(item)

	if not legendarios.is_empty():
		_seccion("LEGENDARIO", ForjaTema.COLOR_RAREZA[&"legendario"], legendarios, false)
	if not epicos.is_empty():
		_seccion("ÉPICO", ForjaTema.COLOR_RAREZA[&"epico"], epicos, false)
	if not basicos.is_empty():
		_seccion("COMPONENTES Y CONSUMIBLES", ForjaTema.COLOR_RAREZA[&"comun"], basicos, false)

	# Los que no se venden se muestran igual, en gris: así el jugador ve qué puede
	# forjar y qué ingrediente le falta, en vez de comprar a ciegas. Ordenados por
	# coste de forja, que es como se desbloquean.
	var forjables := ItemCatalog.recetas()
	forjables.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.precio_forja < b.precio_forja)
	var visibles: Array[ItemData] = []
	for item in forjables:
		if _pasa_busqueda(item):
			visibles.append(item)
	if not visibles.is_empty():
		_seccion("SE FORJAN EN LA ARENA", ForjaTema.TEXTO, visibles, true)

	if _cuadriculas.is_empty():
		_cuerpo.add_child(ForjaTema.etiqueta("Ningún objeto coincide con la búsqueda.", 13, ForjaTema.TENUE))
	elif _seleccionado == null:
		# La ficha nunca arranca vacía: el primer objeto queda elegido y el panel
		# ya muestra bonificaciones y botón de compra al abrir el mercader.
		var primero := _primer_item_de(legendarios, epicos, basicos, visibles)
		if primero != null:
			_seleccionar_item(primero, -1, primero in visibles)


func _primer_item_de(a: Array[ItemData], b: Array[ItemData], c: Array[ItemData], d: Array[ItemData]) -> ItemData:
	for lista in [a, b, c, d]:
		if not lista.is_empty():
			return lista[0]
	return null


func _reconstruir_venta() -> void:
	if _jugador == null or _jugador.inventario == null:
		return
	var items: Array[ItemData] = []
	var indices: Array[int] = []
	for i in _jugador.inventario.ranuras.size():
		var ranura: Dictionary = _jugador.inventario.ranuras[i]
		var item: ItemData = ranura.get("item")
		if item == null or not _pasa_busqueda(item):
			continue
		items.append(item)
		indices.append(i)
	if items.is_empty():
		_cuerpo.add_child(ForjaTema.etiqueta("No llevás nada que vender.", 13, ForjaTema.TENUE))
		return
	_cuerpo.add_child(ForjaTema.rotulo("TU MOCHILA", 11, ForjaTema.ORO))
	var cuadricula := _nueva_cuadricula()
	_cuadriculas.append(cuadricula)
	_grid = cuadricula
	_cuerpo.add_child(cuadricula)
	for k in items.size():
		var indice := indices[k]
		var carta := _carta(
			items[k],
			int(_jugador.inventario.ranuras[indice].get("cantidad", 1)),
			_jugador.inventario.precio_venta(indice),
			true, indice, false
		)
		cuadricula.add_child(carta)
	if _seleccionado == null and not items.is_empty():
		_seleccionar_item(items[0], indices[0], false)


func _seccion(titulo: String, color: Color, items: Array[ItemData], forjable: bool) -> void:
	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 8)
	cabecera.add_child(ForjaTema.rotulo(titulo, 11, color))
	var linea := ColorRect.new()
	linea.color = Color(color.r, color.g, color.b, 0.28)
	linea.custom_minimum_size = Vector2(0, 1)
	linea.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linea.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabecera.add_child(linea)
	_cuerpo.add_child(cabecera)

	var cuadricula := _nueva_cuadricula()
	_cuadriculas.append(cuadricula)
	if _grid == null:
		_grid = cuadricula
	_cuerpo.add_child(cuadricula)

	for item in items:
		var cuantos := _en_mochila(item.id) if not forjable else 0
		var precio := item.precio_forja if forjable else item.precio
		cuadricula.add_child(_carta(item, cuantos, precio, false, -1, forjable))


func _nueva_cuadricula() -> GridContainer:
	var cuadricula := GridContainer.new()
	cuadricula.columns = COLUMNAS
	cuadricula.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cuadricula.add_theme_constant_override("h_separation", 8)
	cuadricula.add_theme_constant_override("v_separation", 8)
	return cuadricula


## Tarjeta cuadrada: icono grande, nombre debajo y precio sobre el icono, como
## las tiendas de arena. `forjable` la deja informativa (gris, sin acción).
func _carta(item: ItemData, cuantos: int, precio: int, vender: bool, indice: int, forjable := false) -> Button:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(LADO_TARJETA, ALTO_TARJETA)
	boton.focus_mode = Control.FOCUS_NONE
	boton.text = ""
	boton.clip_contents = true
	var acento := _rareza_color(item)
	_pintar_carta(boton, acento, false)

	var columna := VBoxContainer.new()
	columna.set_anchors_preset(Control.PRESET_FULL_RECT)
	columna.offset_left = 6
	columna.offset_right = -6
	columna.offset_top = 5
	columna.offset_bottom = -5
	columna.add_theme_constant_override("separation", 2)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(columna)

	var icono := TextureRect.new()
	icono.custom_minimum_size = Vector2(LADO_TARJETA - 24, 54)
	icono.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.texture = IconStudio.obtener(item.id, IconStudio.CATEGORIA_OBJETO)
	IconStudio.escuchar(item.id, Callable(self, "_icono_listo").bind(icono))
	columna.add_child(icono)

	var nombre := ForjaTema.etiqueta(item.nombre, 10, ForjaTema.TEXTO_FUERTE, true)
	nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nombre.max_lines_visible = 2
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(nombre)

	# Precio sobre la esquina inferior derecha del icono.
	var placa := PanelContainer.new()
	placa.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	placa.offset_left = -58.0
	placa.offset_top = -19.0
	placa.offset_right = -3.0
	placa.offset_bottom = -3.0
	placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo_placa := StyleBoxFlat.new()
	estilo_placa.bg_color = Color(0.05, 0.04, 0.03, 0.82)
	estilo_placa.set_corner_radius_all(3)
	estilo_placa.content_margin_left = 4
	estilo_placa.content_margin_right = 4
	placa.add_theme_stylebox_override("panel", estilo_placa)
	var texto_precio := ForjaTema.rotulo(
		("FORJA %d" % precio) if forjable else ("VENTA %d" % precio if vender else "%d" % precio),
		10, acento
	)
	texto_precio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	texto_precio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placa.add_child(texto_precio)
	boton.add_child(placa)

	if cuantos > 1:
		var marca := ForjaTema.rotulo("x%d" % cuantos, 9, ForjaTema.ORO)
		marca.set_anchors_preset(Control.PRESET_TOP_LEFT)
		marca.offset_left = 4
		marca.offset_top = 2
		marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boton.add_child(marca)

	boton.set_meta(&"item", item.id)
	_botones[_clave(item.id, indice)] = boton

	if forjable:
		boton.disabled = true
		boton.mouse_default_cursor_shape = Control.CURSOR_ARROW
		boton.modulate = Color(0.62, 0.60, 0.56, 1)
		boton.set_meta(&"forjable", true)
		boton.pressed.connect(_seleccionar_item.bind(item, indice, true))
		return boton

	if not vender:
		var alcanza: bool = _puede_comprar(item)
		boton.modulate = Color(1, 1, 1, 1) if alcanza else Color(0.62, 0.60, 0.56, 1)
	boton.pressed.connect(_al_pulsar_carta.bind(item, indice, vender, forjable))
	return boton


func _pintar_carta(boton: Button, acento: Color, seleccionada: bool) -> void:
	boton.add_theme_stylebox_override("normal", ForjaTema.estilo_tarjeta(acento, seleccionada, true))
	boton.add_theme_stylebox_override("hover", ForjaTema.estilo_tarjeta(acento, true, true))
	boton.add_theme_stylebox_override("pressed", ForjaTema.estilo_tarjeta(ForjaTema.ORO_CLARO, true, true))
	boton.add_theme_stylebox_override("disabled", ForjaTema.estilo_tarjeta(acento, false, true))
	boton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _clave(id: StringName, indice: int) -> String:
	return "%s:%d" % [id, indice]


# --- Selección y ficha ------------------------------------------------------

## Un toque elige y muestra la ficha; otro toque sobre la misma tarjeta compra.
func _al_pulsar_carta(item: ItemData, indice: int, vender: bool, forjable: bool) -> void:
	var repetido := _seleccionado != null and _seleccionado.id == item.id and _seleccion_indice == indice
	_seleccionar_item(item, indice, forjable)
	if not repetido:
		return
	if vender:
		_vender_ranura(indice)
	else:
		_comprar(item)


func _seleccionar_item(item: ItemData, indice: int, forjable: bool) -> void:
	_seleccionado = item
	_seleccion_indice = indice
	_seleccion_forjable = forjable
	for clave in _botones:
		var boton := _botones[clave] as Button
		if boton == null or not is_instance_valid(boton):
			continue
		var otro := ItemCatalog.obtener(boton.get_meta(&"item", &""))
		var es_este := String(clave) == _clave(item.id, indice)
		_pintar_carta(boton, _rareza_color(otro) if otro != null else ForjaTema.TEXTO, es_este)
	_actualizar_ficha()
	Sfx.reproducir(&"click", -14.0)


func _actualizar_ficha() -> void:
	if _ficha_caja == null:
		return
	var hay := _seleccionado != null
	_ficha_vacia.visible = not hay
	_ficha_icono.visible = hay
	_ficha_nombre.visible = hay
	_ficha_rareza.visible = hay
	_ficha_tipo.visible = hay
	_ficha_bonos.visible = hay
	_ficha_precio.visible = hay
	_ficha_accion.visible = hay
	if not hay:
		_ficha_receta.visible = false
		_rotulo_entra.visible = false
		_rotulo_sale.visible = false
		_arbol_entra.visible = false
		_arbol_sale.visible = false
		return

	var item := _seleccionado
	var acento := _rareza_color(item)
	_ficha_icono.texture = IconStudio.obtener(item.id, IconStudio.CATEGORIA_OBJETO)
	IconStudio.escuchar(item.id, Callable(self, "_icono_listo").bind(_ficha_icono))
	_ficha_nombre.text = item.nombre
	_ficha_nombre.add_theme_color_override("font_color", acento)
	_ficha_rareza.text = "%s · %s" % [_nombre_rareza(item), _nombre_tipo(item)] if _nombre_rareza(item) != _nombre_tipo(item).to_upper() else _nombre_rareza(item)
	_ficha_rareza.add_theme_color_override("font_color", acento)
	_ficha_tipo.text = item.descripcion

	var bonos := item.descripcion_bonos()
	_ficha_bonos.text = bonos if not bonos.is_empty() else "Sin bonificaciones de equipo."

	# Receta: el árbol de construcción muestra ingredientes y objetos padre.
	_actualizar_arbol(item)
	_ficha_receta.visible = item.precio_forja > 0
	if item.precio_forja > 0:
		_ficha_receta.text = "Coste de forja: %d de oro" % item.precio_forja

	if _seleccion_forjable:
		_ficha_precio.text = "%d de oro" % item.precio_forja
		_ficha_accion.text = "SOLO FORJA"
		_ficha_accion.disabled = true
	elif _vender:
		var precio_venta := 0
		if _jugador != null and _jugador.inventario != null and _seleccion_indice >= 0:
			precio_venta = _jugador.inventario.precio_venta(_seleccion_indice)
		_ficha_precio.text = "%d de oro" % precio_venta
		_ficha_accion.text = "VENDER"
		_ficha_accion.disabled = false
	else:
		_ficha_precio.text = "%d de oro" % item.precio
		_ficha_accion.text = "COMPRAR"
		_ficha_accion.disabled = not _puede_comprar(item)


func _accion_ficha() -> void:
	if _seleccionado == null or _seleccion_forjable:
		return
	if _vender:
		_vender_ranura(_seleccion_indice)
	else:
		_comprar(_seleccionado)


# --- Árbol de construcción --------------------------------------------------

## Rellena "SE FORJA CON" (ingredientes que pide) y "SE CONSTRUYE EN" (objetos
## que lo usan como pieza). Cada chip es un botón: tocarlo salta a ese objeto,
## así se navega la cadena de forja sin volver a buscar en la lista.
func _actualizar_arbol(item: ItemData) -> void:
	_construir_padres()
	for caja in [_arbol_entra, _arbol_sale]:
		for hijo in caja.get_children():
			caja.remove_child(hijo)
			hijo.queue_free()

	var receta := item.receta
	var vistos: Array[StringName] = []
	for id in receta:
		if vistos.has(id):
			continue
		vistos.append(id)
		if _arbol_entra.get_child_count() >= 4:
			break
		_arbol_entra.add_child(_chip_arbol(id, receta.count(id)))
	var hay_entra := not vistos.is_empty()
	_rotulo_entra.visible = hay_entra
	_arbol_entra.visible = hay_entra

	var padres: Array = _padres.get(item.id, [])
	for i in mini(padres.size(), 4):
		_arbol_sale.add_child(_chip_arbol(StringName(padres[i]), 0))
	var hay_sale := not padres.is_empty()
	_rotulo_sale.visible = hay_sale
	_arbol_sale.visible = hay_sale


## Chip 70×74 con icono, precio (o `tienes/necesitas`) y color de rareza.
func _chip_arbol(id: StringName, requerido: int) -> Button:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(70, 68)
	boton.focus_mode = Control.FOCUS_NONE
	boton.text = ""
	var item := ItemCatalog.obtener(id)
	if item == null:
		boton.disabled = true
		return boton
	boton.tooltip_text = "%s · %s" % [item.nombre, _nombre_rareza(item)]
	var acento := _rareza_color(item)
	_pintar_carta(boton, acento, false)

	var columna := VBoxContainer.new()
	columna.set_anchors_preset(Control.PRESET_FULL_RECT)
	columna.offset_left = 3
	columna.offset_right = -3
	columna.offset_top = 3
	columna.offset_bottom = -3
	columna.add_theme_constant_override("separation", 0)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(columna)

	var icono := TextureRect.new()
	icono.custom_minimum_size = Vector2(0, 38)
	icono.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.texture = IconStudio.obtener(item.id, IconStudio.CATEGORIA_OBJETO)
	IconStudio.escuchar(item.id, Callable(self, "_icono_listo").bind(icono))
	columna.add_child(icono)

	var texto := ""
	var color_pie := ForjaTema.ORO
	if requerido > 0:
		var tiene := mini(_en_mochila(id), 99)
		texto = "%d/%d" % [tiene, requerido]
		color_pie = Color(0.45, 0.90, 0.55) if tiene >= requerido else Color(0.95, 0.55, 0.45)
	else:
		texto = str(item.precio_forja if item.precio_forja > 0 else item.precio)
	var pie := ForjaTema.rotulo(texto, 10, color_pie)
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(pie)

	boton.pressed.connect(_seleccionar_por_id.bind(id))
	return boton


func _seleccionar_por_id(id: StringName) -> void:
	var item := ItemCatalog.obtener(id)
	if item == null:
		return
	var indice := -1
	if _jugador != null and _jugador.inventario != null:
		for i in _jugador.inventario.ranuras.size():
			var ranura: Dictionary = _jugador.inventario.ranuras[i]
			var en_ranura: ItemData = ranura.get("item")
			if en_ranura != null and en_ranura.id == id:
				indice = i
				break
	_seleccionar_item(item, indice, _es_solo_forja(item))


func _es_solo_forja(item: ItemData) -> bool:
	for otro in ItemCatalog.recetas():
		if otro.id == item.id:
			return true
	return false


## Índice inverso: para cada ingrediente, los objetos que lo piden. Se construye
## una vez y se comparte entre paneles (la tienda se abre muchas veces).
static func _construir_padres() -> void:
	if not _padres.is_empty():
		return
	for item in ItemCatalog.crear_catalogo():
		for id in item.receta:
			if not _padres.has(id):
				_padres[id] = []
			var lista: Array = _padres[id]
			if not lista.has(item.id):
				lista.append(item.id)
			_padres[id] = lista


# --- Acciones de compra/venta ------------------------------------------------

func _comprar(item: ItemData) -> void:
	if _arena == null or not _arena.has_method("comprar_objeto"):
		return
	_arena.comprar_objeto(item)
	_reconstruir()
	_actualizar_ficha()


func _vender_ranura(indice: int) -> void:
	if _arena == null or not _arena.has_method("vender_objeto"):
		return
	_arena.vender_objeto(_jugador, indice)
	_reconstruir()
	_actualizar_ficha()


func _puede_comprar(item: ItemData) -> bool:
	if _arena != null and _arena.has_method("puede_comprar_objeto"):
		return _arena.puede_comprar_objeto(item)
	return false


func _en_mochila(id: StringName) -> int:
	if _jugador == null or _jugador.inventario == null:
		return 0
	return _jugador.inventario.contar(id)


func _oro_actual() -> int:
	if _arena == null:
		return 0
	var valor = _arena.get("oro")
	return int(valor) if valor != null else 0


func _icono_listo(textura: Texture2D, destino) -> void:
	# `destino` puede estar liberado si la lista se reconstruyó mientras el icono
	# se renderizaba: sin anotar el tipo no hay error de conversión.
	if is_instance_valid(destino):
		destino.texture = textura


# --- Textos y colores -------------------------------------------------------

func _pasa_busqueda(item: ItemData) -> bool:
	if _busqueda.is_empty():
		return true
	return _normalizar(item.nombre).contains(_busqueda)


func _normalizar(texto: String) -> String:
	var minuscula := texto.to_lower()
	var equivalencias := {
		"á": "a", "à": "a", "ä": "a", "â": "a",
		"é": "e", "è": "e", "ë": "e", "ê": "e",
		"í": "i", "ì": "i", "ï": "i", "î": "i",
		"ó": "o", "ò": "o", "ö": "o", "ô": "o",
		"ú": "u", "ù": "u", "ü": "u", "û": "u",
		"ñ": "n", "ç": "c",
	}
	for clave in equivalencias:
		minuscula = minuscula.replace(clave, equivalencias[clave])
	return minuscula


func _nombre_rareza(item: ItemData) -> String:
	match item.rareza:
		ItemData.Rareza.LEGENDARIO:
			return "LEGENDARIO"
		ItemData.Rareza.EPICO:
			return "ÉPICO"
	return "COMÚN"


func _nombre_tipo(item: ItemData) -> String:
	match item.tipo:
		ItemData.Tipo.POCION:
			return "Poción"
		ItemData.Tipo.PERGAMINO:
			return "Pergamino"
		ItemData.Tipo.COMPONENTE:
			return "Componente"
		ItemData.Tipo.INTERMEDIO:
			return "Intermedio"
		ItemData.Tipo.LEGENDARIO:
			return "Legendario"
	return "Objeto"


func _rareza_color(item: ItemData) -> Color:
	if item == null:
		return ForjaTema.TEXTO
	match item.rareza:
		ItemData.Rareza.EPICO:
			return Color(0.72, 0.52, 1.0)
		ItemData.Rareza.LEGENDARIO:
			return Color(1.0, 0.78, 0.30)
	match item.tipo:
		ItemData.Tipo.POCION:
			return Color(0.45, 0.90, 0.55)
		ItemData.Tipo.PERGAMINO:
			return Color(0.72, 0.52, 1.0)
		ItemData.Tipo.COMPONENTE:
			return Color(0.38, 0.72, 1.0)
	return ForjaTema.TEXTO
