class_name ShopPanel
extends PanelContainer
## Mercader de la Rebelión con tarjetas visuales, rareza, detalle rico y forja.
## La lógica de compra sigue viviendo en Arena/InventoryComponent.

const ANCHO := 980.0
const ALTO := 540.0

var _jugador: GladiatorController
var _arena: Node
var _hud: ArenaHUD
var _lista: GridContainer
var _detalle_panel: PanelContainer
var _detalle_icono: TextureRect
var _detalle_titulo: Label
var _detalle_tipo: Label
var _detalle_desc: Label
var _detalle_stats: RichTextLabel
var _detalle_receta: RichTextLabel
var _oro: Label
var _comprar: Button
var _tab_mercado: Button
var _tab_recetas: Button
var _tab_vender: Button
var _seleccionado: ItemData
var _modo_recetas := false
var _modo_vender := false
var _ranura_seleccionada: int = -1
var _botones: Dictionary = {}
var _detalle_tween: Tween


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(ANCHO, ALTO)
	size = Vector2(ANCHO, ALTO)
	anchor_left = 0.5
	anchor_top = 0.0
	anchor_right = 0.5
	anchor_bottom = 0.0
	offset_left = -ANCHO * 0.5
	offset_top = 80.0
	offset_right = ANCHO * 0.5
	offset_bottom = 80.0 + ALTO
	add_theme_stylebox_override("panel", _estilo_panel())

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 18)
	margen.add_theme_constant_override("margin_right", 18)
	margen.add_theme_constant_override("margin_top", 14)
	margen.add_theme_constant_override("margin_bottom", 12)
	add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	margen.add_child(columna)

	var cabecera := HBoxContainer.new()
	columna.add_child(cabecera)

	var titulo := Label.new()
	titulo.text = "MERCADER DE LA REBELIÓN"
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", Color(0.94, 0.76, 0.38))
	titulo.add_theme_constant_override("outline_size", 4)
	titulo.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(titulo)

	_oro = Label.new()
	_oro.add_theme_font_size_override("font_size", 17)
	_oro.add_theme_color_override("font_color", Color(0.98, 0.84, 0.45))
	cabecera.add_child(_oro)

	var cerrar := Button.new()
	cerrar.text = "F / ESC"
	cerrar.flat = true
	cerrar.focus_mode = Control.FOCUS_NONE
	cerrar.add_theme_font_size_override("font_size", 13)
	cerrar.pressed.connect(cerrar_panel)
	cabecera.add_child(cerrar)

	var subtitulo := Label.new()
	subtitulo.text = "Equipa, forja y convierte el oro en poder"
	subtitulo.add_theme_font_size_override("font_size", 11)
	subtitulo.add_theme_color_override("font_color", Color(0.68, 0.63, 0.54))
	columna.add_child(subtitulo)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	columna.add_child(tabs)
	_tab_mercado = _boton_tab("MERCADO")
	_tab_mercado.pressed.connect(_cambiar_tab.bind(0))
	tabs.add_child(_tab_mercado)
	_tab_recetas = _boton_tab("RECETARIO")
	_tab_recetas.pressed.connect(_cambiar_tab.bind(1))
	tabs.add_child(_tab_recetas)
	_tab_vender = _boton_tab("VENDER")
	_tab_vender.pressed.connect(_cambiar_tab.bind(2))
	tabs.add_child(_tab_vender)

	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 12)
	columna.add_child(cuerpo)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(590, 340)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cuerpo.add_child(scroll)

	_lista = GridContainer.new()
	_lista.columns = 3
	_lista.add_theme_constant_override("h_separation", 8)
	_lista.add_theme_constant_override("v_separation", 8)
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lista)

	_detalle_panel = PanelContainer.new()
	_detalle_panel.custom_minimum_size = Vector2(330, 340)
	_detalle_panel.add_theme_stylebox_override("panel", _estilo_detalle())
	cuerpo.add_child(_detalle_panel)

	var detalle_margen := MarginContainer.new()
	detalle_margen.add_theme_constant_override("margin_left", 12)
	detalle_margen.add_theme_constant_override("margin_right", 12)
	detalle_margen.add_theme_constant_override("margin_top", 12)
	detalle_margen.add_theme_constant_override("margin_bottom", 12)
	_detalle_panel.add_child(detalle_margen)

	var detalle := VBoxContainer.new()
	detalle.add_theme_constant_override("separation", 7)
	detalle_margen.add_child(detalle)

	var cab_detalle := HBoxContainer.new()
	cab_detalle.add_theme_constant_override("separation", 10)
	detalle.add_child(cab_detalle)

	_detalle_icono = TextureRect.new()
	_detalle_icono.custom_minimum_size = Vector2(70, 70)
	_detalle_icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detalle_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detalle_icono.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	cab_detalle.add_child(_detalle_icono)

	var detalle_textos := VBoxContainer.new()
	detalle_textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalle_textos.add_theme_constant_override("separation", 2)
	cab_detalle.add_child(detalle_textos)
	_detalle_titulo = Label.new()
	_detalle_titulo.add_theme_font_size_override("font_size", 18)
	_detalle_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalle_textos.add_child(_detalle_titulo)
	_detalle_tipo = Label.new()
	_detalle_tipo.add_theme_font_size_override("font_size", 11)
	detalle_textos.add_child(_detalle_tipo)
	_detalle_desc = Label.new()
	_detalle_desc.add_theme_font_size_override("font_size", 11)
	_detalle_desc.add_theme_color_override("font_color", Color(0.76, 0.72, 0.64))
	_detalle_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalle_textos.add_child(_detalle_desc)

	detalle.add_child(HSeparator.new())

	var scroll_detalle := ScrollContainer.new()
	scroll_detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_detalle.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detalle.add_child(scroll_detalle)
	var contenido := VBoxContainer.new()
	contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenido.add_theme_constant_override("separation", 8)
	scroll_detalle.add_child(contenido)

	_detalle_stats = RichTextLabel.new()
	_detalle_stats.bbcode_enabled = true
	_detalle_stats.fit_content = true
	_detalle_stats.scroll_active = false
	_detalle_stats.custom_minimum_size = Vector2(296, 0)
	_detalle_stats.add_theme_font_size_override("normal_font_size", 11)
	_detalle_stats.add_theme_color_override("default_color", Color(0.9, 0.86, 0.78))
	contenido.add_child(_detalle_stats)

	_detalle_receta = RichTextLabel.new()
	_detalle_receta.bbcode_enabled = true
	_detalle_receta.fit_content = true
	_detalle_receta.scroll_active = false
	_detalle_receta.custom_minimum_size = Vector2(296, 0)
	_detalle_receta.add_theme_font_size_override("normal_font_size", 10)
	_detalle_receta.add_theme_color_override("default_color", Color(0.82, 0.78, 0.7))
	contenido.add_child(_detalle_receta)

	_comprar = Button.new()
	_comprar.text = "COMPRAR"
	_comprar.custom_minimum_size = Vector2(0, 42)
	_comprar.focus_mode = Control.FOCUS_NONE
	_comprar.add_theme_font_size_override("font_size", 15)
	_comprar.pressed.connect(_comprar_seleccionado)
	detalle.add_child(_comprar)

	var pie := Label.new()
	pie.text = "Compra el ingrediente que falta y la forja se encadena automáticamente."
	pie.add_theme_font_size_override("font_size", 11)
	pie.add_theme_color_override("font_color", Color(0.62, 0.58, 0.5))
	columna.add_child(pie)

	_actualizar_tabs()


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
		_hud.ocultar_tooltip()
	get_tree().paused = false


func modo_abierto() -> void:
	_seleccionado = null
	_modo_recetas = false
	_modo_vender = false
	_ranura_seleccionada = -1
	if _arena != null and _arena.has_method("revisar_forjas_automaticas"):
		_arena.revisar_forjas_automaticas()
	if _tab_mercado != null:
		_actualizar_tabs()


func _unhandled_input(evento: InputEvent) -> void:
	if not visible or not (evento is InputEventKey):
		return
	var tecla := evento as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode in [KEY_ESCAPE, KEY_F, KEY_T]:
		cerrar_panel()
		get_viewport().set_input_as_handled()


func _cambiar_tab(modo: int) -> void:
	var era_recetas := _modo_recetas
	var era_vender := _modo_vender
	_modo_recetas = modo == 1
	_modo_vender = modo == 2
	if _modo_recetas == era_recetas and _modo_vender == era_vender:
		return
	_seleccionado = null
	_ranura_seleccionada = -1
	if _hud != null:
		_hud.ocultar_tooltip()
	_actualizar_tabs()
	_reconstruir()


func _actualizar_tabs() -> void:
	if _tab_mercado == null or _tab_recetas == null or _tab_vender == null:
		return
	var activo_mercado := not _modo_recetas and not _modo_vender
	_tab_mercado.add_theme_stylebox_override("normal", _estilo_tab(activo_mercado))
	_tab_recetas.add_theme_stylebox_override("normal", _estilo_tab(_modo_recetas))
	_tab_vender.add_theme_stylebox_override("normal", _estilo_tab(_modo_vender))
	_tab_mercado.add_theme_stylebox_override("hover", _estilo_tab(activo_mercado))
	_tab_recetas.add_theme_stylebox_override("hover", _estilo_tab(_modo_recetas))
	_tab_vender.add_theme_stylebox_override("hover", _estilo_tab(_modo_vender))
	_tab_mercado.add_theme_color_override("font_color", Color(0.08, 0.07, 0.06) if activo_mercado else Color(0.75, 0.70, 0.62))
	_tab_recetas.add_theme_color_override("font_color", Color(0.08, 0.07, 0.06) if _modo_recetas else Color(0.75, 0.70, 0.62))
	_tab_vender.add_theme_color_override("font_color", Color(0.08, 0.07, 0.06) if _modo_vender else Color(0.75, 0.70, 0.62))


func _reconstruir() -> void:
	if _lista == null:
		return
	for hijo in _lista.get_children():
		hijo.queue_free()
	_botones.clear()
	_oro.text = "ORO  %d" % _oro_actual()

	var items: Array[ItemData] = []
	if _modo_recetas:
		items = ItemCatalog.recetas()
	elif _modo_vender:
		items = []  # modo vender: se construye desde las ranuras abajo
	else:
		items = ItemCatalog.vendibles()
	for item in items:
		_crear_carta(item)

	# Modo vender: mostrar ranuras del inventario del jugador
	if _modo_vender and _jugador != null and _jugador.inventario != null:
		for i in _jugador.inventario.ranuras.size():
			var ranura := _jugador.inventario.ranuras[i]
			var item: ItemData = ranura.get("item")
			if item == null:
				continue
			_crear_carta_venta(item, i)

	if not _modo_vender and (_seleccionado == null or not items.has(_seleccionado)):
		_seleccionado = items[0] if not items.is_empty() else null
	for item in items:
		if _botones.has(item.id):
			_aplicar_estilo_carta(_botones[item.id], item)
	_actualizar_detalle()


func _crear_carta(item: ItemData) -> void:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(188, 98)
	boton.size = Vector2(188, 98)
	boton.focus_mode = Control.FOCUS_NONE
	boton.text = ""
	boton.clip_contents = true
	_aplicar_estilo_carta(boton, item)

	var icono := TextureRect.new()
	icono.position = Vector2(8, 8)
	icono.size = Vector2(42, 42)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icono.texture = IconStudio.obtener(item.id, IconStudio.CATEGORIA_OBJETO)
	IconStudio.escuchar(item.id, Callable(self, "_icono_listo").bind(icono))
	boton.add_child(icono)

	var nombre := Label.new()
	nombre.position = Vector2(56, 5)
	nombre.size = Vector2(124, 18)
	nombre.text = item.nombre
	nombre.add_theme_font_size_override("font_size", 11)
	nombre.add_theme_color_override("font_color", _rareza_color(item))
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(nombre)

	var precio := Label.new()
	precio.position = Vector2(56, 24)
	precio.size = Vector2(124, 15)
	precio.text = ("Forja %d" % item.precio_forja) if _modo_recetas else ("%d oro" % item.precio)
	precio.add_theme_font_size_override("font_size", 10)
	precio.add_theme_color_override("font_color", Color(0.95, 0.78, 0.38))
	precio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(precio)

	var resumen := Label.new()
	resumen.position = Vector2(8, 54)
	resumen.size = Vector2(172, 38)
	resumen.text = _resumen_bonos(item)
	resumen.add_theme_font_size_override("font_size", 9)
	resumen.add_theme_color_override("font_color", Color(0.72, 0.76, 0.66))
	resumen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resumen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(resumen)

	boton.mouse_entered.connect(_al_entrar_carta.bind(item, boton))
	boton.mouse_exited.connect(_al_salir_carta.bind(boton))
	boton.pressed.connect(_seleccionar.bind(item, boton))
	_lista.add_child(boton)
	_botones[item.id] = boton


func _crear_carta_venta(item: ItemData, indice: int) -> void:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(188, 98)
	boton.size = Vector2(188, 98)
	boton.focus_mode = Control.FOCUS_NONE
	boton.text = ""
	boton.clip_contents = true
	_aplicar_estilo_carta(boton, item)

	var icono := TextureRect.new()
	icono.position = Vector2(8, 8)
	icono.size = Vector2(42, 42)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icono.texture = IconStudio.obtener(item.id, IconStudio.CATEGORIA_OBJETO)
	IconStudio.escuchar(item.id, Callable(self, "_icono_listo").bind(icono))
	boton.add_child(icono)

	var nombre := Label.new()
	nombre.position = Vector2(56, 5)
	nombre.size = Vector2(124, 18)
	nombre.text = item.nombre
	nombre.add_theme_font_size_override("font_size", 11)
	nombre.add_theme_color_override("font_color", _rareza_color(item))
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(nombre)

	var precio := Label.new()
	precio.position = Vector2(56, 24)
	precio.size = Vector2(124, 15)
	precio.text = "Vende %d" % _jugador.inventario.precio_venta(indice)
	precio.add_theme_font_size_override("font_size", 10)
	precio.add_theme_color_override("font_color", Color(0.72, 0.76, 0.66))
	precio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(precio)

	var btn_vender := Button.new()
	btn_vender.text = "VENDER"
	btn_vender.position = Vector2(56, 50)
	btn_vender.size = Vector2(124, 32)
	btn_vender.focus_mode = Control.FOCUS_NONE
	btn_vender.add_theme_font_size_override("font_size", 11)
	btn_vender.pressed.connect(_vender_ranura.bind(indice))
	boton.add_child(btn_vender)

	boton.pressed.connect(_seleccionar_ranura.bind(indice))
	boton.mouse_entered.connect(_al_entrar_carta.bind(item, boton))
	boton.mouse_exited.connect(_al_salir_carta.bind(boton))
	_lista.add_child(boton)

	# Resaltar si esta ranura esta seleccionada
	if _ranura_seleccionada == indice:
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0.96, 0.78, 0.30)
		estilo.border_color = Color(1.0, 0.9, 0.6)
		estilo.set_border_width_all(3)
		estilo.set_corner_radius_all(6)
		boton.add_theme_stylebox_override("normal", estilo)

func _seleccionar_ranura(indice: int) -> void:
	if _jugador == null or _jugador.inventario == null:
		return
	if _ranura_seleccionada == indice:
		_ranura_seleccionada = -1
	elif _ranura_seleccionada >= 0:
		_jugador.inventario.intercambiar(_ranura_seleccionada, indice)
		_ranura_seleccionada = -1
	else:
		_ranura_seleccionada = indice
	_reconstruir()

func _vender_ranura(indice: int) -> void:
	if _jugador == null or _jugador.inventario == null or _arena == null:
		return
	if _arena.has_method("vender_objeto"):
		_arena.vender_objeto(_jugador, indice)
	_ranura_seleccionada = -1
	_reconstruir()

func _al_entrar_carta(item: ItemData, boton: Button) -> void:
	boton.pivot_offset = boton.size * 0.5
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(boton, "scale", Vector2(1.035, 1.035), 0.12).set_trans(Tween.TRANS_QUAD)
	if _hud != null:
		_hud.mostrar_tooltip_item(item)


func _al_salir_carta(boton: Button) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(boton, "scale", Vector2.ONE, 0.12)
	if _hud != null:
		_hud.ocultar_tooltip()


func _seleccionar(item: ItemData, _boton: Button) -> void:
	_seleccionado = item
	for id in _botones.keys():
		_aplicar_estilo_carta(_botones[id], _item_por_id(id, item))
	_actualizar_detalle()
	if _detalle_tween != null and _detalle_tween.is_valid():
		_detalle_tween.kill()
	_detalle_panel.modulate.a = 0.55
	_detalle_tween = create_tween()
	_detalle_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_detalle_tween.tween_property(_detalle_panel, "modulate:a", 1.0, 0.18)
	Sfx.reproducir(&"click", -10.0)


func _item_por_id(id: StringName, referencia: ItemData) -> ItemData:
	var item := ItemCatalog.obtener(id)
	return item if item != null else referencia


func _actualizar_detalle() -> void:
	if _seleccionado == null:
		_detalle_titulo.text = "Sin selección"
		_detalle_tipo.text = ""
		_detalle_desc.text = "Elige un objeto para ver stats, receta y mejoras."
		_detalle_stats.text = ""
		_detalle_receta.text = ""
		_detalle_icono.texture = null
		_comprar.disabled = true
		_comprar.text = "SIN SELECCIÓN"
		return

	var item := _seleccionado
	_detalle_icono.texture = IconStudio.obtener(item.id, IconStudio.CATEGORIA_OBJETO)
	IconStudio.escuchar(item.id, Callable(self, "_icono_listo").bind(_detalle_icono))
	_detalle_titulo.text = item.nombre
	_detalle_titulo.add_theme_color_override("font_color", _rareza_color(item))
	_detalle_tipo.text = "%s  ·  Nivel %d  ·  %s" % [
		_tipo_item(item), item.nivel,
		("Forja %d oro" % item.precio_forja) if _modo_recetas else ("%d oro" % item.precio)
	]
	_detalle_tipo.add_theme_color_override("font_color", _rareza_color(item))
	_detalle_desc.text = item.descripcion
	_detalle_stats.text = _bbcode_stats(item)
	_detalle_receta.text = _bbcode_receta(item)

	var coste := item.precio + _precio_forja(item)
	var puede := not _modo_recetas and _puede_comprar(item)
	if _modo_vender:
		_comprar.disabled = _ranura_seleccionada < 0
		_comprar.text = "VENDER SELECCIONADO"
	else:
		_comprar.disabled = not puede
		_comprar.text = ("FORJAR · %d ORO" if _modo_recetas else "COMPRAR · %d ORO") % coste
	_comprar.add_theme_color_override("font_color", Color(0.05, 0.06, 0.04) if puede else Color(0.55, 0.52, 0.46))
	var estilo := _estilo_compra(puede)
	_comprar.add_theme_stylebox_override("normal", estilo)
	_comprar.add_theme_stylebox_override("hover", estilo)
	_comprar.add_theme_stylebox_override("pressed", estilo)
	_detalle_panel.add_theme_stylebox_override("panel", _estilo_detalle(_rareza_color(item)))


func _comprar_seleccionado() -> void:
	if _arena == null:
		return
	if _modo_vender and _ranura_seleccionada >= 0:
		_arena.vender_objeto(_jugador, _ranura_seleccionada)
		_ranura_seleccionada = -1
	elif _seleccionado != null and _arena.has_method("comprar_objeto"):
		_arena.comprar_objeto(_seleccionado)
	_reconstruir()


func _puede_comprar(item: ItemData) -> bool:
	if _arena != null and _arena.has_method("puede_comprar_objeto"):
		return _arena.puede_comprar_objeto(item)
	return false


func _precio_forja(item: ItemData) -> int:
	if _jugador == null or _jugador.inventario == null:
		return 0
	var receta: ItemData = _jugador.inventario.receta_completada_por(item)
	return receta.precio_forja if receta != null else 0


func _oro_actual() -> int:
	if _arena == null:
		return 0
	var valor = _arena.get("oro")
	return int(valor) if valor != null else 0


func _bbcode_stats(item: ItemData) -> String:
	var lineas: PackedStringArray = []
	var bonos := item.descripcion_bonos()
	if not bonos.is_empty():
		for linea in bonos.split("\n"):
			lineas.append("[color=#7dff9a]%s[/color]" % linea)
	if item.habilidad != null:
		if not lineas.is_empty():
			lineas.append("")
		lineas.append("[color=#d8b45a]ACTIVO[/color]  %s" % item.habilidad.nombre)
		lineas.append("Maná %d  ·  Recarga %.0f s" % [int(item.habilidad.coste_mana), item.habilidad.cooldown])
		if item.habilidad.dano_base > 0.0:
			lineas.append("Daño base %d + escalado" % int(item.habilidad.dano_base))
	return "\n".join(lineas)


func _bbcode_receta(item: ItemData) -> String:
	var lineas: PackedStringArray = []
	if item.receta.is_empty():
		lineas.append("[color=#c8c0ae]Se compra directamente en el mercado.[/color]")
	else:
		lineas.append("[color=#d8b45a]RECETA[/color]")
		for ingrediente in item.receta:
			var otro := ItemCatalog.obtener(ingrediente)
			var nombre := otro.nombre if otro != null else String(ingrediente)
			var tiene := _jugador != null and _jugador.inventario != null and _jugador.inventario.tiene(ingrediente)
			lineas.append("%s %s" % ["[color=#7dff9a]✔[/color]" if tiene else "[color=#ff8a6a]✘[/color]", nombre])
		lineas.append("[color=#d8b45a]Forja[/color]  %d oro" % item.precio_forja)
	var mejoras := _mejoras(item.id)
	if not mejoras.is_empty():
		lineas.append("")
		lineas.append("[color=#d8b45a]MEJORA A[/color]")
		for mejora in mejoras:
			lineas.append("[color=#c792ff]› %s[/color]" % mejora.nombre)
	return "\n".join(lineas)


func _resumen_bonos(item: ItemData) -> String:
	var partes: PackedStringArray = []
	for clave in item.bonificaciones:
		partes.append("+%d %s" % [int(round(float(item.bonificaciones[clave]))), _abrev_bono(clave)])
		if partes.size() >= 3:
			break
	if partes.is_empty() and item.habilidad != null:
		return "Activo"
	return "  ".join(partes)


func _abrev_bono(clave: StringName) -> String:
	match clave:
		&"fuerza": return "FUE"
		&"agilidad": return "AGI"
		&"inteligencia": return "INT"
		&"vida": return "VID"
		&"armadura": return "ARM"
		&"dano_fisico", &"dano_magico": return "DAÑO"
		&"critico": return "CRIT"
		&"velocidad_ataque": return "V.ATQ"
		&"velocidad_movimiento": return "V.MOV"
		&"regeneracion", &"regeneracion_mana": return "REG"
		&"robo_vida": return "ROBO"
	return String(clave).to_upper()


func _mejoras(id: StringName) -> Array[ItemData]:
	var lista: Array[ItemData] = []
	for receta in ItemCatalog.recetas():
		if receta.receta.has(id):
			lista.append(receta)
	return lista


func _tipo_item(item: ItemData) -> String:
	match item.tipo:
		ItemData.Tipo.POCION: return "Poción"
		ItemData.Tipo.PERGAMINO: return "Pergamino"
		ItemData.Tipo.COMPONENTE: return "Componente"
		ItemData.Tipo.INTERMEDIO: return "Intermedio"
		ItemData.Tipo.LEGENDARIO: return "Legendario"
	return "Objeto"


func _rareza_color(item: ItemData) -> Color:
	match item.tipo:
		ItemData.Tipo.POCION: return Color(0.45, 0.90, 0.55)
		ItemData.Tipo.PERGAMINO: return Color(0.72, 0.52, 1.0)
		ItemData.Tipo.INTERMEDIO: return Color(0.38, 0.72, 1.0)
		ItemData.Tipo.LEGENDARIO: return Color(1.0, 0.78, 0.30)
	return Color(0.70, 0.66, 0.58)


func _aplicar_estilo_carta(boton: Button, item: ItemData) -> void:
	var seleccionada := _seleccionado != null and _seleccionado.id == item.id
	var borde := Color(0.96, 0.78, 0.30) if seleccionada else _rareza_color(item)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.19, 0.14, 0.07) if seleccionada else Color(0.10, 0.09, 0.08)
	normal.border_color = borde
	normal.set_border_width_all(2 if seleccionada else 1)
	normal.set_corner_radius_all(6)
	normal.shadow_color = Color(0, 0, 0, 0.4)
	normal.shadow_size = 3
	boton.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.19, 0.10)
	hover.border_color = borde
	hover.shadow_size = 6
	boton.add_theme_stylebox_override("hover", hover)
	boton.add_theme_stylebox_override("pressed", hover)


func _estilo_compra(activo: bool) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.32, 0.62, 0.29) if activo else Color(0.16, 0.15, 0.13)
	estilo.border_color = Color(0.65, 0.95, 0.52) if activo else Color(0.32, 0.30, 0.26)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(6)
	estilo.shadow_color = Color(0, 0, 0, 0.35)
	estilo.shadow_size = 3
	return estilo


func _boton_tab(texto: String) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.focus_mode = Control.FOCUS_NONE
	boton.custom_minimum_size = Vector2(130, 30)
	boton.add_theme_font_size_override("font_size", 12)
	return boton


func _estilo_tab(activo: bool) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.85, 0.66, 0.28) if activo else Color(0.13, 0.11, 0.09)
	estilo.border_color = Color(0.95, 0.78, 0.38) if activo else Color(0.38, 0.30, 0.20)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	return estilo


func _icono_listo(textura: Texture2D, destino: TextureRect) -> void:
	if is_instance_valid(destino):
		destino.texture = textura


func _estilo_panel() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.065, 0.058, 0.05, 1.0)
	estilo.border_color = Color(0.72, 0.52, 0.24)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(10)
	estilo.shadow_color = Color(0, 0, 0, 0.55)
	estilo.shadow_size = 12
	estilo.shadow_offset = Vector2(0, 5)
	return estilo


func _estilo_detalle(acento := Color(0.36, 0.30, 0.22)) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.095, 0.085, 0.075)
	estilo.border_color = acento
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(6)
	return estilo
