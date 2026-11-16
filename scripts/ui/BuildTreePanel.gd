class_name BuildTreePanel
extends PanelContainer
## Vista completa del árbol de construcción del mercader.
##
## Cada nodo es un objeto del catálogo, colocado en la columna que le toca por
## profundidad de receta (componentes → intermedios → legendarios) y unido a
## sus ingredientes con una línea. Un toque selecciona el nodo y el segundo
## compra; la ficha de la derecha permite lo mismo y muestra las dos mitades
## del árbol (SE FORJA CON / SE CONSTRUYE EN) como botones navegables.
##
## No es una pestaña de la tienda: es una vista ampliada que abre el mercader.
## La tienda conserva la pausa y la lista plana; este panel sólo la complementa.

const ANCHO := 1240.0
const ALTO := 680.0
const ANCHO_GRAFO := 920.0
const ANCHO_DETALLE := 260.0
const ANCHO_NODO := 172.0
const ALTO_NODO := 58.0
const COLUMNA_X := [88.0, 260.0, 432.0, 604.0, 776.0]
const FILA_Y := 10.0
const ESPACIO_FILA := 70.0
const FILAS_POR_COLUMNA := 6
const NIVELES := 4
const COLOR_LINEA := Color(0.58, 0.53, 0.45, 0.95)
const COLOR_LINEA_LISTA := Color(0.55, 0.48, 0.33, 0.9)
const COLOR_LINEA_HECHA := Color(0.35, 0.75, 0.48, 0.95)


## Control que dibuja las conexiones debajo de los botones del árbol.
class LienzoArbol extends Control:
	var segmentos: PackedVector2Array = PackedVector2Array()
	var colores: PackedColorArray = PackedColorArray()

	func _draw() -> void:
		for i in range(0, segmentos.size(), 2):
			var indice := i / 2
			var color: Color = colores[indice] if indice < colores.size() else COLOR_LINEA
			var desde: Vector2 = segmentos[i]
			var hasta: Vector2 = segmentos[i + 1]
			draw_line(desde, hasta, color, 2.0)
			draw_circle(hasta, 3.0, color)


var _jugador: GladiatorController
var _arena: Node
var _tienda: ShopPanel

var _lienzo: LienzoArbol
var _campo_busqueda: LineEdit
var _oro_label: Label
var _busqueda := ""

## id -> {id, nombre, item, nivel, padres, hijos, solo_forja}
var _datos: Dictionary = {}
## id -> Button
var _nodos: Dictionary = {}
var _posiciones: Dictionary = {}
var _seleccionado: StringName = &""

# Ficha lateral
var _detalle_icono: TextureRect
var _detalle_nombre: Label
var _detalle_rareza: Label
var _detalle_descripcion: Label
var _detalle_bonos: Label
var _detalle_precio: Label
var _detalle_boton: Button
var _detalle_entra: HBoxContainer
var _detalle_sale: HBoxContainer
var _rotulo_entra: Label
var _rotulo_sale: Label


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
	offset_top = 20.0
	offset_bottom = 20.0 + ALTO
	add_theme_stylebox_override("panel", ForjaTema.estilo_ventana())
	_construir_interfaz()
	_aplicar_marco()
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_aplicar_marco):
		viewport.size_changed.connect(_aplicar_marco)


func _aplicar_marco() -> void:
	SafeArea.aplicar(self, ANCHO, ALTO)


func configurar(jugador: GladiatorController, arena: Node, tienda: ShopPanel = null) -> void:
	_jugador = jugador
	_arena = arena
	_tienda = tienda
	if _jugador != null and _jugador.inventario != null:
		if not _jugador.inventario.cambiado.is_connected(_al_cambiar_inventario):
			_jugador.inventario.cambiado.connect(_al_cambiar_inventario)


# --- Construcción de la interfaz --------------------------------------------

func _construir_interfaz() -> void:
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 16)
	margen.add_theme_constant_override("margin_right", 16)
	margen.add_theme_constant_override("margin_top", 12)
	margen.add_theme_constant_override("margin_bottom", 12)
	add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	margen.add_child(columna)

	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 10)
	cabecera.add_child(ForjaTema.titulo("ÁRBOL DE CONSTRUCCIÓN", 21, ForjaTema.ORO_CLARO))
	var relleno := Control.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(relleno)
	_campo_busqueda = LineEdit.new()
	_campo_busqueda.placeholder_text = "Buscar…"
	_campo_busqueda.custom_minimum_size = Vector2(160, 34)
	_campo_busqueda.clear_button_enabled = true
	_campo_busqueda.add_theme_stylebox_override("normal", ForjaTema.estilo_tarjeta(ForjaTema.ORO_OSCURO, false, true))
	_campo_busqueda.add_theme_stylebox_override("focus", ForjaTema.estilo_tarjeta(ForjaTema.ORO, false, true))
	_campo_busqueda.text_changed.connect(_al_buscar)
	cabecera.add_child(_campo_busqueda)
	cabecera.add_child(ForjaTema.IconoStat.new(&"oro", 16.0, ForjaTema.ORO))
	_oro_label = ForjaTema.titulo("0", 19, ForjaTema.ORO)
	cabecera.add_child(_oro_label)
	var boton_cerrar := ForjaTema.boton("CERRAR", 12)
	boton_cerrar.custom_minimum_size = Vector2(104, 34)
	boton_cerrar.pressed.connect(Callable(self, "cerrar"))
	cabecera.add_child(boton_cerrar)
	columna.add_child(cabecera)
	columna.add_child(ForjaTema.regla(ANCHO - 32.0))

	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 14)
	columna.add_child(cuerpo)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(ANCHO_GRAFO, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_constant_override("scrollbar_width", 8)
	cuerpo.add_child(scroll)

	_lienzo = LienzoArbol.new()
	_lienzo.custom_minimum_size = Vector2(ANCHO_GRAFO, ALTO - 130.0)
	_lienzo.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_lienzo)

	cuerpo.add_child(_construir_ficha())


func _construir_ficha() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ANCHO_DETALLE, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", ForjaTema.estilo_panel(1.0, ForjaTema.ORO_OSCURO))

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 12)
	margen.add_theme_constant_override("margin_right", 12)
	margen.add_theme_constant_override("margin_top", 10)
	margen.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 6)
	margen.add_child(columna)

	_detalle_icono = TextureRect.new()
	_detalle_icono.custom_minimum_size = Vector2(72, 72)
	_detalle_icono.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detalle_icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detalle_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	columna.add_child(_detalle_icono)

	_detalle_nombre = ForjaTema.titulo("", 18, ForjaTema.ORO_CLARO)
	_detalle_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detalle_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_detalle_nombre)

	_detalle_rareza = ForjaTema.rotulo("", 11, ForjaTema.TENUE)
	_detalle_rareza.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(_detalle_rareza)

	_detalle_descripcion = ForjaTema.etiqueta("", 12, ForjaTema.TEXTO, true)
	_detalle_descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_detalle_descripcion)

	columna.add_child(ForjaTema.regla(ANCHO_DETALLE - 24.0))
	_rotulo_entra = ForjaTema.rotulo("SE FORJA CON", 10, ForjaTema.ORO)
	columna.add_child(_rotulo_entra)
	_detalle_entra = HBoxContainer.new()
	_detalle_entra.add_theme_constant_override("separation", 6)
	columna.add_child(_detalle_entra)
	_rotulo_sale = ForjaTema.rotulo("SE CONSTRUYE EN", 10, ForjaTema.ORO)
	columna.add_child(_rotulo_sale)
	_detalle_sale = HBoxContainer.new()
	_detalle_sale.add_theme_constant_override("separation", 6)
	columna.add_child(_detalle_sale)

	_detalle_bonos = ForjaTema.etiqueta("", 12, ForjaTema.TEXTO, true)
	_detalle_bonos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_detalle_bonos)

	var relleno := Control.new()
	relleno.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(relleno)
	columna.add_child(ForjaTema.regla(ANCHO_DETALLE - 24.0))
	_detalle_precio = ForjaTema.titulo("", 19, ForjaTema.ORO)
	_detalle_precio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(_detalle_precio)
	_detalle_boton = ForjaTema.boton("COMPRAR", 14, true)
	_detalle_boton.custom_minimum_size = Vector2(0, 42)
	_detalle_boton.pressed.connect(_comprar_seleccionado)
	columna.add_child(_detalle_boton)
	return panel


# --- API pública ------------------------------------------------------------

func abrir() -> void:
	visible = true
	_construir_datos()
	_reconstruir_grafico()
	_oro_label.text = str(_oro_actual())
	if not _datos.has(_seleccionado):
		var primero := _primer_nodo()
		if primero != StringName():
			_seleccionar(primero)
	_actualizar_detalle()
	move_to_front()
	Sfx.reproducir(&"click", -12.0)


func cerrar() -> void:
	if not visible:
		return
	visible = false
	if _tienda != null and _tienda.has_method("forzar_ocultar_tooltip"):
		_tienda.forzar_ocultar_tooltip()


func alternar() -> void:
	if visible:
		cerrar()
	else:
		abrir()


func _unhandled_input(evento: InputEvent) -> void:
	if not visible or not (evento is InputEventKey):
		return
	var tecla := evento as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode in [KEY_ESCAPE, KEY_F, KEY_T]:
		cerrar()
		get_viewport().set_input_as_handled()


func _al_cambiar_inventario() -> void:
	if not visible:
		return
	_oro_label.text = str(_oro_actual())
	_pintar_nodos()
	_actualizar_detalle()


# --- Datos del árbol --------------------------------------------------------

func _construir_datos() -> void:
	_datos.clear()
	var catalogo: Array = ItemCatalog.crear_catalogo()
	var solo_forja: Dictionary = {}
	for item in ItemCatalog.recetas():
		solo_forja[item.id] = true

	var padres: Dictionary = {}
	var hijos: Dictionary = {}
	for item: ItemData in catalogo:
		padres[item.id] = item.receta.duplicate()
		if not hijos.has(item.id):
			hijos[item.id] = []
		for id_padre: StringName in item.receta:
			if not hijos.has(id_padre):
				hijos[id_padre] = []
			var lista: Array = hijos[id_padre]
			if not lista.has(item.id):
				lista.append(item.id)
			hijos[id_padre] = lista

	var memoria: Dictionary = {}
	for id: StringName in padres.keys():
		memoria[id] = _profundidad(id, padres, memoria)

	for item: ItemData in catalogo:
		_datos[item.id] = {
			"id": item.id,
			"item": item,
			"nombre": String(item.nombre),
			"nivel": mini(int(memoria.get(item.id, 0)), NIVELES - 1),
			"padres": padres.get(item.id, []),
			"hijos": hijos.get(item.id, []),
			"solo_forja": solo_forja.has(item.id),
		}


func _profundidad(id: StringName, padres: Dictionary, memoria: Dictionary) -> int:
	if memoria.has(id):
		return int(memoria[id])
	var lista_padres: Array = padres.get(id, [])
	if lista_padres.is_empty():
		memoria[id] = 0
		return 0
	var maxima := 0
	for padre: StringName in lista_padres:
		if padre == id:
			continue
		maxima = maxi(maxima, _profundidad(padre, padres, memoria))
	memoria[id] = maxima + 1
	return maxima + 1


func _primer_nodo() -> StringName:
	var ids: Array = _datos.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids[0] if not ids.is_empty() else StringName()


# --- Grafo ------------------------------------------------------------------

func _reconstruir_grafico() -> void:
	for hijo: Node in _lienzo.get_children():
		_lienzo.remove_child(hijo)
		hijo.queue_free()
	_nodos.clear()
	_posiciones.clear()

	var por_nivel: Array = []
	for i in NIVELES:
		por_nivel.append([])
	for id: StringName in _datos.keys():
		var datos: Dictionary = _datos[id]
		por_nivel[int(datos["nivel"])].append(id)
	for nivel: Array in por_nivel:
		nivel.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))

	var filas := 1
	var columna := 0
	# Un nivel con muchos objetos se reparte entre varias columnas: así los 11
	# componentes y los 9 legendarios caben sin scroll en 1280×720.
	for nivel: int in range(NIVELES):
		var lista: Array = por_nivel[nivel]
		if lista.is_empty():
			continue
		var inicio := 0
		while inicio < lista.size():
			var fin: int = mini(inicio + FILAS_POR_COLUMNA, lista.size())
			filas = maxi(filas, fin - inicio)
			var indice_x: int = mini(columna, COLUMNA_X.size() - 1)
			var x: float = COLUMNA_X[indice_x] + maxi(0, columna - COLUMNA_X.size() + 1) * 188.0
			for i: int in range(inicio, fin):
				var id: StringName = lista[i]
				var pos := Vector2(x, FILA_Y + ALTO_NODO * 0.5 + (i - inicio) * ESPACIO_FILA)
				_posiciones[id] = pos
				_crear_nodo(id, pos)
			inicio = fin
			columna += 1

	_lienzo.custom_minimum_size = Vector2(ANCHO_GRAFO, FILA_Y * 2.0 + ALTO_NODO + ESPACIO_FILA * maxi(0, filas - 1))

	_actualizar_lineas()
	_pintar_nodos()


func _crear_nodo(id: StringName, pos: Vector2) -> void:
	var datos: Dictionary = _datos[id]
	var item: ItemData = datos["item"]
	var boton := Button.new()
	boton.position = pos - Vector2(ANCHO_NODO * 0.5, ALTO_NODO * 0.5)
	boton.custom_minimum_size = Vector2(ANCHO_NODO, ALTO_NODO)
	boton.focus_mode = Control.FOCUS_NONE
	boton.clip_contents = true
	boton.text = ""
	boton.tooltip_text = "%s · %s" % [item.nombre, String(datos["nombre"])]
	boton.set_meta(&"id", id)
	boton.pressed.connect(_al_pulsar_nodo.bind(id))

	var icono := TextureRect.new()
	icono.custom_minimum_size = Vector2(32, 32)
	icono.position = Vector2(5, (ALTO_NODO - 32.0) * 0.5)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.texture = IconStudio.obtener(item.id, IconStudio.CATEGORIA_OBJETO)
	IconStudio.escuchar(item.id, Callable(self, "_icono_listo").bind(icono))
	boton.add_child(icono)

	var textos := VBoxContainer.new()
	textos.position = Vector2(42, 5)
	textos.custom_minimum_size = Vector2(ANCHO_NODO - 46.0, ALTO_NODO - 10.0)
	textos.add_theme_constant_override("separation", 1)
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(textos)

	var nombre := ForjaTema.etiqueta(item.nombre, 11, ForjaTema.TEXTO_FUERTE, true)
	nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nombre.max_lines_visible = 2
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	textos.add_child(nombre)

	var precio := ForjaTema.rotulo(_texto_coste(item), 10, ForjaTema.ORO)
	precio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(precio)
	boton.set_meta(&"precio", precio)
	_lienzo.add_child(boton)
	_nodos[id] = boton


func _texto_coste(item: ItemData) -> String:
	if _es_solo_forja(item):
		return "FORJA %d" % item.precio_forja
	return "%d ORO" % item.precio


func _actualizar_lineas() -> void:
	var segmentos := PackedVector2Array()
	var colores := PackedColorArray()
	for id: StringName in _datos.keys():
		var pos_hijo: Vector2 = _posiciones.get(id, Vector2.ZERO)
		for padre: StringName in _datos[id].get("padres", []):
			if not _posiciones.has(padre):
				continue
			var pos_padre: Vector2 = _posiciones[padre]
			segmentos.append(pos_padre + Vector2(ANCHO_NODO * 0.5, 0.0))
			segmentos.append(pos_hijo - Vector2(ANCHO_NODO * 0.5, 0.0))
			var requeridos: Array = _datos[id].get("padres", [])
			var hecho: bool = not requeridos.is_empty() and _cantidad(padre) >= requeridos.count(padre)
			var color: Color = COLOR_LINEA_HECHA if hecho else (COLOR_LINEA_LISTA if id == _seleccionado or padre == _seleccionado else COLOR_LINEA)
			colores.append(color)
	_lienzo.segmentos = segmentos
	_lienzo.colores = colores
	_lienzo.queue_redraw()


func _pintar_nodos() -> void:
	for id: StringName in _nodos.keys():
		var boton: Button = _nodos[id]
		if not is_instance_valid(boton):
			continue
		var datos: Dictionary = _datos[id]
		var item: ItemData = datos["item"]
		var cuantos := _cantidad(id)
		boton.visible = _pasa_busqueda(item)
		var seleccionado := id == _seleccionado
		var acento: Color = _rareza_color(item)
		boton.add_theme_stylebox_override("normal", ForjaTema.estilo_tarjeta(acento, seleccionado, true))
		boton.add_theme_stylebox_override("hover", ForjaTema.estilo_tarjeta(acento, true, true))
		boton.add_theme_stylebox_override("pressed", ForjaTema.estilo_tarjeta(ForjaTema.ORO_CLARO, true, true))
		boton.modulate = Color(1, 1, 1, 1) if seleccionado or _puede_comprar(item) else Color(0.66, 0.63, 0.59, 1)
		var precio: Label = boton.get_meta(&"precio")
		if datos["solo_forja"]:
			precio.text = "FORJA %d%s" % [item.precio_forja, " · TIENES %d" % cuantos if cuantos > 0 else ""]
		else:
			precio.text = "%d ORO%s" % [item.precio, " · x%d" % cuantos if cuantos > 0 else ""]


func _al_pulsar_nodo(id: StringName) -> void:
	var repetido := id == _seleccionado
	_seleccionar(id)
	if repetido:
		_comprar_seleccionado()


func _seleccionar(id: StringName) -> void:
	if not _datos.has(id):
		return
	_seleccionado = id
	_pintar_nodos()
	_actualizar_lineas()
	_actualizar_detalle()
	Sfx.reproducir(&"click", -14.0)


func _al_buscar(texto: String) -> void:
	_busqueda = _normalizar(texto)
	_pintar_nodos()
	_actualizar_lineas()


# --- Ficha lateral ----------------------------------------------------------

func _actualizar_detalle() -> void:
	if not _datos.has(_seleccionado):
		return
	var datos: Dictionary = _datos[_seleccionado]
	var item: ItemData = datos["item"]
	var acento := _rareza_color(item)
	_detalle_icono.texture = IconStudio.obtener(item.id, IconStudio.CATEGORIA_OBJETO)
	IconStudio.escuchar(item.id, Callable(self, "_icono_listo").bind(_detalle_icono))
	_detalle_nombre.text = item.nombre
	_detalle_nombre.add_theme_color_override("font_color", acento)
	_detalle_rareza.text = "%s · Nv %d" % [_nombre_rareza(item), item.nivel]
	_detalle_descripcion.text = item.descripcion
	var bonos := item.descripcion_bonos()
	_detalle_bonos.text = bonos if not bonos.is_empty() else "Sin bonificaciones de equipo."

	_llenar_chips(_detalle_entra, datos.get("padres", []), true)
	_llenar_chips(_detalle_sale, datos.get("hijos", []), false)
	_rotulo_entra.visible = not _detalle_entra.get_children().is_empty()
	_detalle_entra.visible = _rotulo_entra.visible
	_rotulo_sale.visible = not _detalle_sale.get_children().is_empty()
	_detalle_sale.visible = _rotulo_sale.visible

	if datos["solo_forja"]:
		_detalle_precio.text = "FORJA %d" % item.precio_forja
		_detalle_boton.text = "SOLO FORJA"
		_detalle_boton.disabled = true
	elif _cantidad(item.id) > 0 and item.maximo_pila == 1:
		_detalle_precio.text = "EN MOCHILA"
		_detalle_boton.text = "COMPRADO"
		_detalle_boton.disabled = true
	else:
		_detalle_precio.text = "%d de oro" % item.precio
		var oro := _oro_actual()
		_detalle_boton.text = "COMPRAR" if oro >= item.precio else "ORO INSUFICIENTE (%d/%d)" % [oro, item.precio]
		_detalle_boton.disabled = not _puede_comprar(item)


func _llenar_chips(caja: HBoxContainer, ids: Array, requerido: bool) -> void:
	for hijo: Node in caja.get_children():
		caja.remove_child(hijo)
		hijo.queue_free()
	var vistos: Array[StringName] = []
	for id: StringName in ids:
		if vistos.has(id):
			continue
		vistos.append(id)
		var item := ItemCatalog.obtener(id)
		if item == null:
			continue
		var texto := item.nombre
		if requerido:
			texto = "x%d %s" % [ids.count(id), item.nombre]
		if texto.length() > 15:
			texto = texto.substr(0, 14) + "…"
		var chip := ForjaTema.boton(texto, 10)
		chip.custom_minimum_size = Vector2(0, 30)
		chip.clip_contents = true
		chip.tooltip_text = "%s · %s" % [item.nombre, _nombre_rareza(item)]
		chip.pressed.connect(_seleccionar.bind(id))
		caja.add_child(chip)


func _comprar_seleccionado() -> void:
	if not _datos.has(_seleccionado):
		return
	var datos: Dictionary = _datos[_seleccionado]
	if datos["solo_forja"]:
		return
	var item: ItemData = datos["item"]
	if _arena != null and _arena.has_method("comprar_objeto"):
		_arena.comprar_objeto(item)
	_oro_label.text = str(_oro_actual())
	_pintar_nodos()
	_actualizar_lineas()
	_actualizar_detalle()


# --- Utilidades -------------------------------------------------------------

func _cantidad(id: StringName) -> int:
	if _jugador == null or _jugador.inventario == null:
		return 0
	return _jugador.inventario.contar(id)


func _puede_comprar(item: ItemData) -> bool:
	if _arena != null and _arena.has_method("puede_comprar_objeto"):
		return _arena.puede_comprar_objeto(item)
	return false


func _es_solo_forja(item: ItemData) -> bool:
	return bool(_datos.get(item.id, {}).get("solo_forja", false))


func _oro_actual() -> int:
	if _arena == null:
		return 0
	var valor: Variant = _arena.get("oro")
	return int(valor) if valor != null else 0


func _icono_listo(textura: Texture2D, destino) -> void:
	if is_instance_valid(destino):
		destino.texture = textura


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


# --- Getters para pruebas y otras pantallas ---------------------------------

func cantidad_nodos() -> int:
	return _nodos.size()


func cantidad_conexiones() -> int:
	return _lienzo.segmentos.size() / 2 if _lienzo != null else 0


func nodo_visible(id: StringName) -> bool:
	var boton: Button = _nodos.get(id)
	return boton != null and is_instance_valid(boton) and boton.visible


func seleccion_actual() -> StringName:
	return _seleccionado


func seleccionar_por_id(id: StringName) -> void:
	_seleccionar(id)
