class_name ShopPanel
extends PanelContainer
## Mercader de la Rebelión, versión simple: una sola lista de tarjetas y un
## toque para comprar. Sin pestañas de rarezas, sin ficha lateral y sin dos
## pasos (seleccionar y después confirmar): nombre, precio y listo.
## La lógica de compra sigue viviendo en Arena/InventoryComponent.

const ANCHO := 760.0
const ALTO := 470.0
const COLUMNAS := 3

var _jugador: GladiatorController
var _arena: Node
var _hud: ArenaHUD
var _grid: GridContainer
var _oro: Label
var _aviso: Label
var _chip_comprar: Button
var _chip_vender: Button
var _vender := false


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
	offset_top = 96.0
	offset_bottom = 96.0 + ALTO
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

	# --- Cabecera: título, oro y cerrar ---
	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 10)
	columna.add_child(cabecera)

	var titulo := ForjaTema.titulo("MERCADER", 24, ForjaTema.ORO_CLARO)
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

	# --- Dos modos nada más ---
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	columna.add_child(chips)

	_chip_comprar = ForjaTema.boton("COMPRAR", 13)
	_chip_comprar.custom_minimum_size = Vector2(140, 34)
	_chip_comprar.pressed.connect(_cambiar_modo.bind(false))
	chips.add_child(_chip_comprar)

	_chip_vender = ForjaTema.boton("VENDER", 13)
	_chip_vender.custom_minimum_size = Vector2(140, 34)
	_chip_vender.pressed.connect(_cambiar_modo.bind(true))
	chips.add_child(_chip_vender)

	_aviso = ForjaTema.etiqueta("Tocá un objeto para comprarlo.", 11, ForjaTema.TENUE)
	_aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aviso.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chips.add_child(_aviso)

	columna.add_child(ForjaTema.regla(ANCHO - 36.0))

	# --- Una sola lista con scroll ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columna.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = COLUMNAS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)

	_actualizar_chips()


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
	get_tree().paused = true
	move_to_front()
	Sfx.reproducir(&"click", -12.0)


func cerrar_panel() -> void:
	if not visible:
		return
	visible = false
	if _hud != null:
		_hud.forzar_ocultar_tooltip()
	get_tree().paused = false


func modo_abierto() -> void:
	_vender = false
	if _arena != null and _arena.has_method("revisar_forjas_automaticas"):
		_arena.revisar_forjas_automaticas()
	_actualizar_chips()


func _unhandled_input(evento: InputEvent) -> void:
	if not visible or not (evento is InputEventKey):
		return
	var tecla := evento as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode in [KEY_ESCAPE, KEY_F, KEY_T]:
		cerrar_panel()
		get_viewport().set_input_as_handled()


func _cambiar_modo(vender: bool) -> void:
	if vender == _vender:
		return
	_vender = vender
	_actualizar_chips()
	_reconstruir()
	Sfx.reproducir(&"click", -12.0)


func _actualizar_chips() -> void:
	if _chip_comprar == null:
		return
	_pintar_chip(_chip_comprar, not _vender)
	_pintar_chip(_chip_vender, _vender)
	_aviso.text = "Tocá un objeto para venderlo por la mitad." if _vender else "Tocá un objeto para comprarlo."


func _pintar_chip(chip: Button, activo: bool) -> void:
	var estilo := ForjaTema.estilo_tarjeta(ForjaTema.ORO if activo else ForjaTema.ORO_OSCURO, activo, true)
	chip.add_theme_stylebox_override("normal", estilo)
	chip.add_theme_stylebox_override("hover", estilo)
	chip.add_theme_stylebox_override("pressed", estilo)
	chip.add_theme_color_override("font_color", Color(0.07, 0.06, 0.05) if activo else ForjaTema.TEXTO)


func _reconstruir() -> void:
	if _grid == null:
		return
	for hijo in _grid.get_children():
		hijo.queue_free()
	_oro.text = str(_oro_actual())

	if _vender:
		if _jugador == null or _jugador.inventario == null:
			return
		var algo := false
		for i in _jugador.inventario.ranuras.size():
			var ranura: Dictionary = _jugador.inventario.ranuras[i]
			var item: ItemData = ranura.get("item")
			if item == null:
				continue
			algo = true
			_grid.add_child(_carta(item, int(ranura.get("cantidad", 1)), _jugador.inventario.precio_venta(i), true, i))
		if not algo:
			_grid.add_child(ForjaTema.etiqueta("No llevás nada que vender.", 13, ForjaTema.TENUE))
		return

	for item in ItemCatalog.vendibles():
		_grid.add_child(_carta(item, _en_mochila(item.id), item.precio, false, -1))


## Tarjeta: icono, nombre y precio. Un toque compra o vende.
func _carta(item: ItemData, cuantos: int, precio: int, vender: bool, indice: int) -> Button:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(226, 74)
	boton.focus_mode = Control.FOCUS_NONE
	boton.text = ""
	boton.clip_contents = true
	var acento := _rareza_color(item)
	boton.add_theme_stylebox_override("normal", ForjaTema.estilo_tarjeta(acento, false, true))
	boton.add_theme_stylebox_override("hover", ForjaTema.estilo_tarjeta(acento, true, true))
	boton.add_theme_stylebox_override("pressed", ForjaTema.estilo_tarjeta(ForjaTema.ORO_CLARO, true, true))
	boton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var fila := HBoxContainer.new()
	fila.set_anchors_preset(Control.PRESET_FULL_RECT)
	fila.offset_left = 8
	fila.offset_right = -8
	fila.add_theme_constant_override("separation", 8)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(fila)

	var icono := TextureRect.new()
	icono.custom_minimum_size = Vector2(44, 44)
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.texture = IconStudio.obtener(item.id, IconStudio.CATEGORIA_OBJETO)
	IconStudio.escuchar(item.id, Callable(self, "_icono_listo").bind(icono))
	fila.add_child(icono)

	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	textos.add_theme_constant_override("separation", 1)
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(textos)

	var nombre := ForjaTema.etiqueta(item.nombre, 13, ForjaTema.TEXTO_FUERTE)
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(nombre)

	var precio_fila := HBoxContainer.new()
	precio_fila.add_theme_constant_override("separation", 4)
	precio_fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(precio_fila)

	var moneda := ForjaTema.IconoStat.new(&"oro", 12.0, acento)
	moneda.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	precio_fila.add_child(moneda)
	precio_fila.add_child(ForjaTema.rotulo("%d" % precio, 11, acento))
	if cuantos > 1:
		precio_fila.add_child(ForjaTema.rotulo("x%d" % cuantos, 10, ForjaTema.TENUE))
	if vender:
		precio_fila.add_child(ForjaTema.rotulo("VENTA", 9, ForjaTema.TENUE))

	if not vender:
		var alcanza: bool = _puede_comprar(item)
		boton.disabled = not alcanza
		boton.modulate = Color(1, 1, 1, 1) if alcanza else Color(0.62, 0.60, 0.56, 1)
		boton.pressed.connect(_comprar.bind(item))
	else:
		boton.pressed.connect(_vender_ranura.bind(indice))
	return boton


func _comprar(item: ItemData) -> void:
	if _arena == null or not _arena.has_method("comprar_objeto"):
		return
	_arena.comprar_objeto(item)
	_reconstruir()


func _vender_ranura(indice: int) -> void:
	if _arena == null or not _arena.has_method("vender_objeto"):
		return
	_arena.vender_objeto(_jugador, indice)
	_reconstruir()


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


func _rareza_color(item: ItemData) -> Color:
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
