class_name TalentPanel
extends PanelContainer
## Árbol de talentos de combate: lista las habilidades del arma equipada y
## permite invertir puntos rojos en sus ranuras. Se abre con T.

const ANCHO := 760.0
const ALTO := 500.0

var _jugador: GladiatorController
var _lista: VBoxContainer
var _puntos: Label


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
	offset_top = 16.0
	offset_right = ANCHO * 0.5
	offset_bottom = 16.0 + ALTO
	add_theme_stylebox_override("panel", _estilo())

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 22)
	margen.add_theme_constant_override("margin_right", 22)
	margen.add_theme_constant_override("margin_top", 16)
	margen.add_theme_constant_override("margin_bottom", 16)
	add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	margen.add_child(columna)

	var cabecera := HBoxContainer.new()
	columna.add_child(cabecera)

	var titulo := Label.new()
	titulo.text = "TALENTOS DE COMBATE"
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Color(0.96, 0.82, 0.45))
	cabecera.add_child(titulo)

	var relleno := Control.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(relleno)

	_puntos = Label.new()
	_puntos.add_theme_font_size_override("font_size", 16)
	_puntos.add_theme_color_override("font_color", Color(0.95, 0.40, 0.32))
	cabecera.add_child(_puntos)

	var cerrar := Button.new()
	cerrar.text = "T: cerrar"
	cerrar.add_theme_font_size_override("font_size", 14)
	cerrar.pressed.connect(cerrar_panel)
	cabecera.add_child(cerrar)

	columna.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columna.add_child(scroll)

	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	scroll.add_child(_lista)


func configurar(jugador: GladiatorController) -> void:
	_jugador = jugador
	if _jugador != null:
		if not _jugador.talentos_cambiados.is_connected(_reconstruir):
			_jugador.talentos_cambiados.connect(_reconstruir)
		if not _jugador.arma_cambiada.is_connected(_al_cambiar_arma):
			_jugador.arma_cambiada.connect(_al_cambiar_arma)
		if not _jugador.habilidades_cambiadas.is_connected(_reconstruir):
			_jugador.habilidades_cambiadas.connect(_reconstruir)


func alternar() -> void:
	if visible:
		cerrar_panel()
		return
	visible = true
	_reconstruir()
	move_to_front()
	get_tree().paused = true
	Sfx.reproducir(&"click", -12.0)


func cerrar_panel() -> void:
	visible = false
	if is_inside_tree():
		get_tree().paused = false


## ESC y T cierran el panel incluso con el árbol en pausa.
func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		return
	var tecla := evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode == KEY_ESCAPE or tecla.physical_keycode == KEY_T:
		cerrar_panel()
		get_viewport().set_input_as_handled()


func _al_cambiar_arma(_arma: WeaponItem) -> void:
	if visible:
		_reconstruir()


func _reconstruir() -> void:
	if _lista == null:
		return
	for hijo in _lista.get_children():
		hijo.queue_free()

	if _jugador == null or _jugador.arma_actual == null:
		_lista.add_child(_texto("Equipa un arma en la armería para desbloquear talentos.", 15))
		return

	_puntos.text = "Rojos: %d" % _jugador.puntos_rojos
	var arma := _jugador.arma_actual

	var titulo_habilidades := _texto("RANGOS DE HABILIDAD  ·  suben al azar al subir de nivel", 15)
	titulo_habilidades.add_theme_color_override("font_color", Color(0.96, 0.82, 0.45))
	_lista.add_child(titulo_habilidades)
	for indice in arma.habilidades.size():
		var habilidad := arma.habilidades[indice]
		if habilidad != null:
			_lista.add_child(_fila_rango(habilidad, indice))
	_lista.add_child(HSeparator.new())

	var mostrados := 0
	for indice in arma.habilidades.size():
		var habilidad := arma.habilidades[indice]
		if habilidad == null or habilidad.talentos.is_empty():
			continue

		mostrados += 1
		var separador := HSeparator.new()
		_lista.add_child(separador)

		var cabecera := Label.new()
		cabecera.text = "%s  ·  %s" % [["Q", "W", "E", "R"][indice], habilidad.nombre]
		cabecera.add_theme_font_size_override("font_size", 17)
		cabecera.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))
		_lista.add_child(cabecera)

		for talento in habilidad.talentos:
			if talento != null:
				_lista.add_child(_fila_talento(talento))

	if mostrados == 0:
		_lista.add_child(_texto("Esta arma no tiene talentos. Compra una en la armería y gana puntos rojos al terminar cada oleada.", 15))


func _fila_rango(habilidad: AbilityData, indice: int) -> Control:
	var tecla: String = ["Q", "W", "E", "R"][indice]
	var rango := _jugador.rango_habilidad(habilidad.id)
	var maximo := maxi(1, habilidad.rango_maximo)
	var desbloqueada := _jugador.habilidad_desbloqueada(indice)

	var etiqueta := _texto("", 14)
	etiqueta.custom_minimum_size = Vector2(0, 28)
	if not desbloqueada:
		etiqueta.text = "  %s   %s   —   BLOQUEADA (Nv %d)" % [
			tecla, habilidad.nombre, _jugador.nivel_desbloqueo_habilidad(indice)
		]
		etiqueta.add_theme_color_override("font_color", Color(0.58, 0.58, 0.60))
	elif rango >= maximo:
		etiqueta.text = "  %s   %s   [%d/%d]   MÁXIMO" % [tecla, habilidad.nombre, rango, maximo]
		etiqueta.add_theme_color_override("font_color", Color(0.55, 0.90, 0.55))
	else:
		var siguiente := habilidad.descripcion_siguiente_rango(rango)
		etiqueta.text = "  %s   %s   [%d/%d]%s" % [
			tecla, habilidad.nombre, rango, maximo,
			("   ·   " + siguiente) if not siguiente.is_empty() else ""
		]
	return etiqueta


func _fila_talento(talento: TalentData) -> Control:
	var rango := _jugador.rango_talento(talento.id)
	var maximo := maxi(1, talento.rango_maximo)
	var requisito_ok := talento.talento_requerido == &"" or _jugador.tiene_talento(talento.talento_requerido)
	var comprable := rango < maximo and requisito_ok and _jugador.puntos_rojos >= talento.coste_puntos_rojos

	var boton := Button.new()
	boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	boton.custom_minimum_size = Vector2(0, 44)
	boton.text = "  %s   [%d/%d]   ·   %d pts" % [
		talento.nombre, rango, maximo, talento.coste_puntos_rojos
	]
	boton.tooltip_text = talento.descripcion
	boton.disabled = not comprable
	boton.pressed.connect(_comprar.bind(talento))

	if rango >= maximo:
		boton.add_theme_color_override("font_color", Color(0.55, 0.90, 0.55))
	elif not requisito_ok:
		boton.text += "   (requiere %s)" % _nombre_talento(talento.talento_requerido)
	elif _jugador.puntos_rojos < talento.coste_puntos_rojos:
		boton.add_theme_color_override("font_color", Color(0.62, 0.62, 0.62))

	return boton


func _nombre_talento(id: StringName) -> String:
	if _jugador == null or _jugador.arma_actual == null:
		return str(id)
	for habilidad in _jugador.arma_actual.habilidades:
		if habilidad == null:
			continue
		for talento in habilidad.talentos:
			if talento != null and talento.id == id:
				return talento.nombre
	return str(id)


func _comprar(talento: TalentData) -> void:
	if _jugador != null and _jugador.desbloquear_talento(talento):
		Sfx.reproducir(&"click", -8.0)
		_reconstruir()


func _texto(contenido: String, tamano: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = contenido
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.add_theme_font_size_override("font_size", tamano)
	return etiqueta


func _estilo() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.07, 0.06, 0.08, 1.0)
	estilo.border_color = Color(0.55, 0.40, 0.20)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	estilo.content_margin_left = 0
	estilo.content_margin_right = 0
	return estilo
