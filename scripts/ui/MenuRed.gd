class_name MenuRed
extends CanvasLayer
## Menú inicial para Web y APK: partida local o unirse a un servidor cooperativo.

signal jugar_solo
signal unirse(url: String)
signal crear_sala

var _url: LineEdit
var _estado_servidores: Label
var _lista_servidores: VBoxContainer
var _boton_crear: Button
var _reintentado := false
var _estado_creacion: Label
var _supabase: Supabase


func configurar(url_inicial: String) -> void:
	layer = 20
	var fondo := ColorRect.new()
	fondo.color = Color(0.04, 0.035, 0.03, 0.94)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.09, 0.08, 0.07, 1.0)
	estilo.border_color = Color(0.62, 0.45, 0.22)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(8)
	estilo.content_margin_left = 30
	estilo.content_margin_right = 30
	estilo.content_margin_top = 24
	estilo.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	panel.add_child(columna)

	var titulo := Label.new()
	titulo.text = "GLADIATORS REVENGE"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 30)
	titulo.add_theme_color_override("font_color", Color(0.92, 0.72, 0.35))
	columna.add_child(titulo)

	var subtitulo := Label.new()
	subtitulo.text = "Cooperativo online · hasta 3 gladiadores"
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.add_theme_font_size_override("font_size", 14)
	subtitulo.add_theme_color_override("font_color", Color(0.78, 0.72, 0.6))
	columna.add_child(subtitulo)

	var cabecera_servidores := HBoxContainer.new()
	columna.add_child(cabecera_servidores)
	var etiqueta_lista := Label.new()
	etiqueta_lista.text = "SERVIDORES DISPONIBLES"
	etiqueta_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etiqueta_lista.add_theme_font_size_override("font_size", 13)
	etiqueta_lista.add_theme_color_override("font_color", Color(0.86, 0.68, 0.32))
	cabecera_servidores.add_child(etiqueta_lista)
	var refrescar := Button.new()
	refrescar.text = "ACTUALIZAR"
	refrescar.focus_mode = Control.FOCUS_NONE
	refrescar.add_theme_font_size_override("font_size", 11)
	refrescar.pressed.connect(_actualizar_servidores)
	cabecera_servidores.add_child(refrescar)

	_estado_servidores = Label.new()
	_estado_servidores.text = "Buscando servidores…"
	_estado_servidores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estado_servidores.add_theme_font_size_override("font_size", 12)
	_estado_servidores.add_theme_color_override("font_color", Color(0.7, 0.66, 0.58))
	columna.add_child(_estado_servidores)

	_lista_servidores = VBoxContainer.new()
	_lista_servidores.add_theme_constant_override("separation", 4)
	columna.add_child(_lista_servidores)

	var solo := Button.new()
	solo.text = "JUGAR SOLO"
	solo.custom_minimum_size = Vector2(340, 46)
	solo.add_theme_font_size_override("font_size", 18)
	solo.pressed.connect(_al_pulsar_solo)
	columna.add_child(solo)

	# En escritorio la sala la levanta el propio juego (túnel + servidor headless);
	# en Web/APK la pide al servidor maestro en la nube.
	if true:
		_boton_crear = Button.new()
		_boton_crear.text = "CREAR SALA"
		_boton_crear.custom_minimum_size = Vector2(340, 46)
		_boton_crear.add_theme_font_size_override("font_size", 18)
		_boton_crear.add_theme_color_override("font_color", Color(0.92, 0.72, 0.35))
		_boton_crear.pressed.connect(_al_pulsar_crear)
		columna.add_child(_boton_crear)

		_estado_creacion = Label.new()
		_estado_creacion.text = (
			"Pide una sala al servidor público y compartí el enlace."
			if OS.has_feature("web") or OS.has_feature("mobile")
			else "Crea una sala y tus amigos la ven en esta lista."
		)
		_estado_creacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_estado_creacion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_estado_creacion.custom_minimum_size = Vector2(340, 0)
		_estado_creacion.add_theme_font_size_override("font_size", 12)
		_estado_creacion.add_theme_color_override("font_color", Color(0.7, 0.66, 0.58))
		columna.add_child(_estado_creacion)

	columna.add_child(HSeparator.new())

	var etiqueta := Label.new()
	etiqueta.text = "Servidor cooperativo (wss://… o ws://IP:9080)"
	etiqueta.add_theme_font_size_override("font_size", 13)
	etiqueta.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
	columna.add_child(etiqueta)

	_url = LineEdit.new()
	_url.custom_minimum_size = Vector2(340, 40)
	_url.placeholder_text = "wss://tu-servidor.ejemplo.com"
	_url.text = url_inicial
	_url.add_theme_font_size_override("font_size", 15)
	columna.add_child(_url)

	var unirse_boton := Button.new()
	unirse_boton.text = "UNIRSE A PARTIDA"
	unirse_boton.custom_minimum_size = Vector2(340, 46)
	unirse_boton.add_theme_font_size_override("font_size", 18)
	unirse_boton.pressed.connect(_al_pulsar_unirse)
	columna.add_child(unirse_boton)

	var ayuda := Label.new()
	ayuda.text = "La clase se elige una sola vez por partida en la armería."
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ayuda.add_theme_font_size_override("font_size", 12)
	ayuda.add_theme_color_override("font_color", Color(0.62, 0.58, 0.5))
	columna.add_child(ayuda)

	_supabase = Supabase.new()
	add_child(_supabase)
	if _supabase.configurado_cliente():
		_actualizar_servidores()
	else:
		_estado_servidores.text = "Supabase sin anon key · escribe la URL del servidor"


func _actualizar_servidores() -> void:
	if _supabase == null:
		return
	if not _supabase.configurado_cliente():
		_estado_servidores.text = "Supabase sin anon key · escribe la URL del servidor"
		return
	_estado_servidores.text = "Buscando servidores…"
	_supabase.listar_servidores(_al_recibir_servidores)


func _al_recibir_servidores(ok: bool, lista: Array) -> void:
	for hijo in _lista_servidores.get_children():
		hijo.queue_free()
	if not ok:
		var causa := ""
		if _supabase != null and not _supabase.ultimo_error.is_empty():
			causa = " (%s)" % _supabase.ultimo_error
		_estado_servidores.text = "No se pudo consultar Supabase%s · escribe la URL" % causa
		# Un reintento automático: el primer intento de la Web puede llegar antes
		# de que el motor tenga listo el backend de red.
		if not _reintentado:
			_reintentado = true
			await get_tree().create_timer(1.5).timeout
			_actualizar_servidores()
		return

	var ahora := Time.get_unix_time_from_system()
	var mostrados := 0
	for fila in lista:
		if not (fila is Dictionary):
			continue
		var marca := str(fila.get("actualizado_en", ""))
		var epoch := Time.get_unix_time_from_datetime_string(marca)
		if epoch > 0.0 and ahora - epoch > 120.0:
			continue
		var url := str(fila.get("url", ""))
		if url.is_empty():
			continue
		var boton := Button.new()
		boton.text = "%s  ·  %d/%d  ·  %s" % [
			str(fila.get("nombre", "Servidor")),
			int(fila.get("jugadores", 0)),
			int(fila.get("max_jugadores", 3)),
			str(fila.get("region", "")),
		]
		boton.custom_minimum_size = Vector2(340, 34)
		boton.add_theme_font_size_override("font_size", 13)
		boton.pressed.connect(_unirse_a.bind(url))
		_lista_servidores.add_child(boton)
		mostrados += 1
		if mostrados >= 6:
			break

	if mostrados == 0:
		_estado_servidores.text = "No hay servidores activos · escribe una URL"
	else:
		_estado_servidores.text = "%d servidor(es) activo(s)" % mostrados


func _unirse_a(url: String) -> void:
	_url.text = url
	_al_pulsar_unirse()


func _al_pulsar_solo() -> void:
	queue_free()
	jugar_solo.emit()


func _al_pulsar_unirse() -> void:
	var destino := _url.text.strip_edges()
	if destino.is_empty():
		return
	queue_free()
	unirse.emit(destino)


func _al_pulsar_crear() -> void:
	if _boton_crear != null:
		_boton_crear.disabled = true
	crear_sala.emit()


func estado_creacion(texto: String) -> void:
	if _estado_creacion != null:
		_estado_creacion.text = texto


func sala_creada(url_publica: String) -> void:
	estado_creacion("Sala pública lista: %s" % url_publica)
	if _boton_crear != null:
		_boton_crear.disabled = false
	if _url != null and _url.text.strip_edges().is_empty():
		_url.text = url_publica


func sala_fallida(motivo: String) -> void:
	estado_creacion("No se pudo crear la sala · %s" % motivo)
	if _boton_crear != null:
		_boton_crear.disabled = false
