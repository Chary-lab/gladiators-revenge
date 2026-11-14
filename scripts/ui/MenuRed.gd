class_name MenuRed
extends CanvasLayer
## Lobby principal (Web y APK): escena atmosférica centrada en el campeón,
## acceso directo a la arena, salas públicas y ajustes.
##
## La navegación vive a la izquierda (acciones) y el protagonismo en el centro,
## con el emblema de clase que rota. Todo se monta con contenedores y anclajes
## para que la interfaz no se deforme al cambiar la relación de aspecto.

signal jugar_solo
signal unirse(url: String)
signal crear_sala

const CLASES_HEROE: Array[StringName] = [&"bastion", &"filo", &"cetro"]

var _estado_servidores: Label
var _lista_servidores: VBoxContainer
var _boton_crear: Button
var _boton_solo: Button
var _reintentado := false
var _aviso_version: Label
var _enlace_release := ""
var _estado_creacion: Label
var _supabase: Supabase
var _actualizador: Actualizador
var _heroe_nombre: Label
var _heroe_lema: Label
var _vitrina: VitrinaCampeon
var _indice_heroe := 0
var _reloj := 0.0
var _insignia_red: Label
var _boton_refrescar: Button

## Tinte del campeón en el lobby (el mismo de la piel "Tierra Baldía").
const TINTE_HEROE := Color(0.72, 0.95, 0.55)


func configurar(_url_inicial: String = "") -> void:
	layer = 20

	var raiz := Control.new()
	raiz.name = "Lobby"
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme = ForjaTema.tema_global()
	add_child(raiz)

	var fondo := FondoForja.new()
	fondo.name = "FondoForja"
	raiz.add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 44)
	margen.add_theme_constant_override("margin_right", 44)
	margen.add_theme_constant_override("margin_top", 20)
	margen.add_theme_constant_override("margin_bottom", 20)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 16)
	margen.add_child(columna)

	columna.add_child(_crear_barra_superior())

	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 40)
	columna.add_child(cuerpo)

	cuerpo.add_child(_crear_navegacion())
	cuerpo.add_child(_crear_escenario())

	_actualizador = Actualizador.new()
	add_child(_actualizador)
	_actualizador.disponible.connect(_al_hay_version)
	_actualizador.comprobar()

	_supabase = Supabase.new()
	add_child(_supabase)
	if _supabase.configurado_cliente():
		_actualizar_servidores()
	else:
		_estado_servidores.text = "Supabase sin anon key · revisá la configuración"


# --- Barra superior ---------------------------------------------------------

func _crear_barra_superior() -> Control:
	var barra := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.045, 0.039, 0.034, 0.92)
	estilo.border_color = Color(ForjaTema.ORO_OSCURO.r, ForjaTema.ORO_OSCURO.g, ForjaTema.ORO_OSCURO.b, 0.55)
	estilo.border_width_bottom = 1
	estilo.content_margin_left = 18
	estilo.content_margin_right = 18
	estilo.content_margin_top = 10
	estilo.content_margin_bottom = 10
	barra.add_theme_stylebox_override("panel", estilo)
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 18)
	barra.add_child(fila)

	var marca := ForjaTema.titulo("GLADIATORS REVENGE", 22, ForjaTema.ORO_CLARO)
	fila.add_child(marca)

	var lema := ForjaTema.rotulo("LA FORJA DE LA REBELIÓN", 11, ForjaTema.TENUE)
	lema.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(lema)

	var relleno := Control.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(relleno)

	_insignia_red = ForjaTema.etiqueta("SIN CONEXIÓN AL LOBBY", 11, ForjaTema.TENUE)
	_insignia_red.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(_insignia_red)

	var version := ForjaTema.etiqueta(
		"v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0")), 12, ForjaTema.TENUE
	)
	version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(version)

	var ajustes_btn := ForjaTema.boton("AJUSTES", 13)
	ajustes_btn.custom_minimum_size = Vector2(108, 32)
	ajustes_btn.pressed.connect(_al_pulsar_ajustes)
	fila.add_child(ajustes_btn)

	return barra


# --- Columna de navegación --------------------------------------------------

func _crear_navegacion() -> Control:
	var columna := VBoxContainer.new()
	columna.custom_minimum_size = Vector2(360, 0)
	columna.add_theme_constant_override("separation", 10)

	columna.add_child(ForjaTema.rotulo("LA ARENA", 11))
	_boton_solo = ForjaTema.boton("ENTRAR A LA ARENA", 19, true)
	_boton_solo.custom_minimum_size = Vector2(0, 58)
	_boton_solo.pressed.connect(_al_pulsar_solo)
	columna.add_child(_boton_solo)

	var pista := ForjaTema.etiqueta("Juego en solitario · 20 oleadas · elegís campeón en la forja", 11, ForjaTema.TENUE)
	pista.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(pista)

	var separacion := Control.new()
	separacion.custom_minimum_size = Vector2(0, 6)
	columna.add_child(separacion)

	# En escritorio la sala la levanta el propio juego (túnel + servidor headless);
	# en Web/APK la pide al servidor maestro en la nube.
	_boton_crear = ForjaTema.boton("CREAR SALA PRIVADA", 16)
	_boton_crear.custom_minimum_size = Vector2(0, 46)
	_boton_crear.pressed.connect(_al_pulsar_crear)
	columna.add_child(_boton_crear)

	_estado_creacion = ForjaTema.etiqueta("", 11, ForjaTema.TENUE)
	_estado_creacion.text = (
		"Pedimos una sala al servidor público y te damos el enlace."
		if OS.has_feature("web") or OS.has_feature("mobile")
		else "Crea una sala y tus amigos la ven en esta lista."
	)
	_estado_creacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estado_creacion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_estado_creacion)

	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 8)
	columna.add_child(cabecera)
	var rotulo_lista := ForjaTema.rotulo("SALAS PÚBLICAS", 11)
	rotulo_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo_lista.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabecera.add_child(rotulo_lista)
	_boton_refrescar = ForjaTema.boton("ACTUALIZAR", 11)
	_boton_refrescar.custom_minimum_size = Vector2(120, 30)
	_boton_refrescar.pressed.connect(_actualizar_servidores)
	cabecera.add_child(_boton_refrescar)

	_estado_servidores = ForjaTema.etiqueta("Buscando salas…", 11, ForjaTema.TENUE)
	_estado_servidores.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_estado_servidores)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 150)
	# En el teléfono no hay rueda: la barra visible es la única pista de que hay
	# más salas abajo.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	columna.add_child(scroll)

	_lista_servidores = VBoxContainer.new()
	_lista_servidores.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_servidores.add_theme_constant_override("separation", 6)
	scroll.add_child(_lista_servidores)

	_aviso_version = ForjaTema.etiqueta("", 11, Color(0.92, 0.72, 0.36))
	_aviso_version.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso_version.mouse_filter = Control.MOUSE_FILTER_STOP
	_aviso_version.gui_input.connect(_al_pulsar_aviso)
	columna.add_child(_aviso_version)

	var ayuda := ForjaTema.etiqueta(
		"La clase se elige una sola vez por partida, en la forja de campeones.", 10, ForjaTema.TENUE
	)
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(ayuda)

	return columna


# --- Escenario del héroe ----------------------------------------------------

func _crear_escenario() -> Control:
	var centro := VBoxContainer.new()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.add_theme_constant_override("separation", 0)
	centro.alignment = BoxContainer.ALIGNMENT_CENTER

	var caja_vitrina := CenterContainer.new()
	caja_vitrina.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centro.add_child(caja_vitrina)

	_vitrina = VitrinaCampeon.new()
	_vitrina.configurar(Vector2(360, 384))
	caja_vitrina.add_child(_vitrina)

	_heroe_nombre = ForjaTema.titulo("", 38, ForjaTema.ORO_CLARO)
	_heroe_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centro.add_child(_heroe_nombre)

	_heroe_lema = ForjaTema.etiqueta("", 13, ForjaTema.TEXTO, true)
	_heroe_lema.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	centro.add_child(_heroe_lema)

	var regla := CenterContainer.new()
	centro.add_child(regla)
	regla.add_child(ForjaTema.regla(200))

	var datos := HBoxContainer.new()
	datos.alignment = BoxContainer.ALIGNMENT_CENTER
	datos.add_theme_constant_override("separation", 26)
	centro.add_child(datos)
	for texto in ["3 CLASES", "20 OLEADAS", "COOPERATIVO 3 JUGADORES"]:
		datos.add_child(ForjaTema.rotulo(texto, 11, ForjaTema.TENUE))

	var relleno := Control.new()
	relleno.custom_minimum_size = Vector2(0, 4)
	centro.add_child(relleno)

	# Tarjeta de cómo se juega: llena el costado derecho con información útil.
	var tarjeta := PanelContainer.new()
	tarjeta.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Ancho mínimo: las etiquetas con autowrap miden 1 px de ancho y, sin esto,
	# parten el texto letra a letra y estiran la columna fuera de pantalla.
	tarjeta.custom_minimum_size = Vector2(470, 0)
	tarjeta.add_theme_stylebox_override("panel", ForjaTema.estilo_panel(0.86))
	centro.add_child(tarjeta)

	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 4)
	tarjeta.add_child(contenido)
	contenido.add_child(ForjaTema.rotulo("CÓMO SE JUEGA", 11))
	var tactil := DisplayServer.is_touchscreen_available()
	var lineas := [
		"Joystick a la izquierda: mover · habilidades a la derecha" if tactil
		else "Ratón: clic para atacar-mover · Q W E R habilidades",
		"Mercader, talentos y mochila: botones a la izquierda" if tactil
		else "Móvil: joystick abajo a la izquierda y habilidades a la derecha",
		"Tocá tus objetos en la mochila para usarlos" if tactil
		else "F mercader · T talentos · Z X C V B N objetos",
		"Sobrevive 20 oleadas y protegé el estandarte",
	]
	for linea in lineas:
		var item := ForjaTema.etiqueta(linea, 11, ForjaTema.TENUE)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		contenido.add_child(item)

	_actualizar_heroe()
	return centro


func _process(delta: float) -> void:
	if _vitrina == null:
		return
	_reloj += delta
	if _reloj < 6.0:
		return
	_reloj = 0.0
	_indice_heroe = (_indice_heroe + 1) % CLASES_HEROE.size()
	_actualizar_heroe()


func _actualizar_heroe() -> void:
	var clase := CLASES_HEROE[_indice_heroe]
	var arma := _arma_de_clase(clase)
	if _vitrina != null:
		_vitrina.mostrar(
			clase,
			TINTE_HEROE,
			arma.escena_visual if arma != null else null,
			arma.rotacion_visual if arma != null else Vector3.ZERO,
			arma.escala_visual if arma != null else 1.0,
			clase == &"bastion"
		)
	_heroe_nombre.text = String(ForjaTema.NOMBRE_EMBLEMA.get(clase, "")).to_upper()
	_heroe_nombre.modulate.a = 0.0
	_heroe_lema.text = String(ForjaTema.LEMA_CLASE.get(clase, ""))
	_heroe_lema.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_heroe_nombre, "modulate:a", 1.0, 0.35)
	tween.tween_property(_heroe_lema, "modulate:a", 1.0, 0.35)


func _arma_de_clase(clase: StringName) -> WeaponItem:
	for arma in WeaponItem.crear_catalogo_base():
		if arma != null and arma.id_clase() == clase:
			return arma
	return null


# --- Salas ------------------------------------------------------------------

func _actualizar_servidores() -> void:
	if _supabase == null:
		return
	if not _supabase.configurado_cliente():
		_estado_servidores.text = "Supabase sin anon key · revisá la configuración"
		return
	_estado_servidores.text = "Buscando salas…"
	_insignia_red.text = "CONECTANDO…"
	_supabase.listar_servidores(_al_recibir_servidores)


func _al_recibir_servidores(ok: bool, lista: Array) -> void:
	for hijo in _lista_servidores.get_children():
		hijo.queue_free()
	if not ok:
		var causa := ""
		if _supabase != null and not _supabase.ultimo_error.is_empty():
			causa = _supabase.ultimo_error
		_estado_servidores.text = _texto_error_lobby(causa)
		if _boton_refrescar != null:
			_boton_refrescar.text = "REINTENTAR"
			_boton_refrescar.add_theme_color_override("font_color", Color(1.0, 0.62, 0.42))
		_insignia_red.text = "LOBBY NO DISPONIBLE"
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
		_lista_servidores.add_child(_tarjeta_sala(fila, url))
		mostrados += 1
		if mostrados >= 6:
			break

	if mostrados == 0:
		_estado_servidores.text = "No hay salas activas · creá una"
		_insignia_red.text = "LOBBY VACÍO"
	else:
		_estado_servidores.text = "%d sala(s) disponibles" % mostrados
		if _boton_refrescar != null:
			_boton_refrescar.text = "ACTUALIZAR"
			_boton_refrescar.add_theme_color_override("font_color", ForjaTema.ORO_CLARO)
		_insignia_red.text = "LOBBY ACTIVO · %d" % mostrados


## Mensaje de error útil: dice qué falló y qué puede hacer el jugador, en vez
## de un "HTTP 0" que no explica nada.
func _texto_error_lobby(causa: String) -> String:
	if causa.contains("401") or causa.to_lower().contains("api key"):
		return "El lobby rechazó la clave pública del servidor. Avisá al anfitrión."
	if causa.contains("0") or causa.to_lower().contains("red") or causa.is_empty():
		return "Sin conexión con el lobby. Revisá los datos y tocá REINTENTAR."
	return "No se pudo consultar el lobby (%s). Tocá REINTENTAR." % causa


func _tarjeta_sala(fila: Dictionary, url: String) -> Control:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(0, 50)
	boton.focus_mode = Control.FOCUS_NONE
	boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	boton.text = ""
	boton.add_theme_stylebox_override("normal", ForjaTema.estilo_panel(0.75))
	var hover := ForjaTema.estilo_panel(0.95, ForjaTema.ORO)
	boton.add_theme_stylebox_override("hover", hover)
	boton.add_theme_stylebox_override("pressed", hover)

	var fila_texto := HBoxContainer.new()
	fila_texto.set_anchors_preset(Control.PRESET_FULL_RECT)
	fila_texto.offset_left = 12
	fila_texto.offset_right = -12
	fila_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila_texto.add_theme_constant_override("separation", 10)
	boton.add_child(fila_texto)

	var nombre := ForjaTema.etiqueta(str(fila.get("nombre", "Sala")), 13, ForjaTema.TEXTO_FUERTE)
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	fila_texto.add_child(nombre)

	var jugadores := int(fila.get("jugadores", 0))
	var maximo := int(fila.get("max_jugadores", 3))
	var ocupacion := ForjaTema.etiqueta(
		"%d/%d" % [jugadores, maximo], 12,
		ForjaTema.VERDE if jugadores < maximo else ForjaTema.SANGRE
	)
	ocupacion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila_texto.add_child(ocupacion)

	var region := str(fila.get("region", "local"))
	var etiqueta_region := ForjaTema.etiqueta(region.to_upper(), 10, ForjaTema.TENUE)
	etiqueta_region.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila_texto.add_child(etiqueta_region)

	boton.pressed.connect(_unirse_a.bind(url))
	return boton


func _unirse_a(url: String) -> void:
	queue_free()
	unirse.emit(url)


func _al_pulsar_ajustes() -> void:
	var panel := SettingsPanel.new()
	add_child(panel)
	panel.configurar()


func _al_hay_version(version: String, url: String) -> void:
	if _aviso_version == null:
		return
	_enlace_release = url
	_aviso_version.text = "Nueva versión v%s disponible · tocar para descargar" % version


func _al_pulsar_aviso(evento: InputEvent) -> void:
	if _enlace_release.is_empty():
		return
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
		_actualizador.abrir_enlace(_enlace_release)
	elif evento is InputEventScreenTouch and (evento as InputEventScreenTouch).pressed:
		_actualizador.abrir_enlace(_enlace_release)


func _al_pulsar_solo() -> void:
	queue_free()
	jugar_solo.emit()


func _al_pulsar_crear() -> void:
	if _boton_crear != null:
		_boton_crear.disabled = true
	crear_sala.emit()


func estado_creacion(texto: String) -> void:
	if _estado_creacion != null:
		_estado_creacion.text = texto


func sala_creada(url_publica: String) -> void:
	estado_creacion("Sala lista: %s" % url_publica)
	if _boton_crear != null:
		_boton_crear.disabled = false


func sala_fallida(motivo: String) -> void:
	estado_creacion("No se pudo crear la sala · %s" % motivo)
	if _boton_crear != null:
		_boton_crear.disabled = false
