class_name TouchControls
extends CanvasLayer
## HUD táctil: joystick con anillo de runas a la izquierda, abanico de
## habilidades a la derecha con enfriamiento radial, vida/maná arriba y pausa.
##
## Coordenadas de diseño 1280x720. El joystick emite una dirección normalizada
## que el gladiador usa para moverse de verdad, sin depender de la emulación de
## ratón (eso era lo que "no agarraba" en el teléfono).

signal mover(direccion: Vector2)
signal habilidad(slot: int)
signal interactuar
signal detener
signal pausa
signal tienda
signal talentos
## Ganchos de combate que se conectarán en la Fase 3 (ataque básico y dash).
signal ataque
signal dash

const CLAVES := ["Q", "W", "E", "R"]
const CENTRO_JOY := Vector2(178, 530)
const RADIO_JOY := 94.0
## Rueda de habilidades: INTERACTUAR ocupa el centro y Q/W/E/R la rodean, con
## un hueco abajo para el pulgar. Los ángulos van en grados (270 = arriba).
const CENTRO_RUEDA := Vector2(1058, 522)
const RADIO_RUEDA := 150.0
const LADO_HABILIDAD := 92.0
const LADO_INTERACTUAR := 128.0
const ANGULOS := [200.0, 246.0, 292.0, 338.0]

var _raiz: Control
var _base: Panel
var _aro: ForjaTema.AroRunas
var _perilla: Panel
var _botones: Array = []
var _velos: Array = []
var _cd_textos: Array = []
var _cd_barras: Array[TextureProgressBar] = []
var _cd_anteriores: Array[float] = []

## Cachés para no redibujar barras de vida/maná ni reasignar texto cada frame
## cuando el valor no cambia (mismo patrón que los cooldowns).
var _vida_fraccion_anterior := -1.0
var _mana_fraccion_anterior := -1.0
var _nivel_anterior := -1
var _cd_enfriamiento: Array[bool] = []
var _pulso_tweens: Array = []
static var _textura_barra: Texture2D = null
## Joystick flotante: aparece donde el pulgar toca la mitad inferior izquierda.
var _joy_centro := CENTRO_JOY
var _joy_activo := false
var _joy_indice := -1
## Marco escalado por SafeArea: convierte coordenadas de evento a diseño 1280×720.
var _origen_marco := Vector2.ZERO
var _escala_marco := 1.0
## Botonera derecha ergonómica: ataque y dash al alcance del pulgar.
var _boton_ataque: Button
var _boton_dash: Button
var _panel_vital: PanelContainer
var _barra_vida: ForjaTema.BarraSegmentada
var _barra_mana: ForjaTema.BarraSegmentada
var _texto_vida: Label
var _texto_mana: Label
var _nivel: Label
var _boton_pausa: Button
var _jugador: GladiatorController
## Multiplicador de tamaño configurable desde Ajustes.
var escala := 1.0
var _arrastrando := false
## Mochila táctil: en móvil la consola de escritorio se apaga, así que los seis
## objetos usables viven en este panel desplegable.
var _panel_mochila: PanelContainer
var _slots_mochila: Array = []
var _mochila_abierta := false
var _boton_interactuar: Button
## Nivel de cada habilidad, encima del icono (en el móvil no hay tooltips).
var _niveles: Array = []
## Ficha del campeón: atributos y descripción de las cuatro habilidades.
var _panel_ficha: PanelContainer
var _texto_ficha: RichTextLabel
var _ficha_abierta := false
var _tiempo_ficha := 0.0
## Callable que cierra tienda/talentos (paneles que pausan) al abrir otro.
var al_abrir_panel: Callable


func configurar(jugador: GladiatorController) -> void:
	_jugador = jugador
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS

	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.theme = ForjaTema.tema_global()
	add_child(_raiz)
	_velos.clear()
	_cd_textos.clear()
	_cd_barras.clear()
	_cd_anteriores.clear()
	_cd_enfriamiento.clear()
	_pulso_tweens.clear()
	_botones.clear()
	_niveles.clear()
	_aplicar_marco()
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_aplicar_marco):
		viewport.size_changed.connect(_aplicar_marco)

	_crear_vitales()
	_crear_accesos()
	_crear_mochila()
	_crear_joystick()
	_crear_ficha()

	for i in CLAVES.size():
		var boton := _crear_boton(CLAVES[i], _posicion_rueda(i), LADO_HABILIDAD, 26, true)
		boton.pressed.connect(func() -> void: habilidad.emit(i))
		var velo := ForjaTema.VeloRadial.new()
		velo.visible = false
		boton.add_child(velo)
		_velos.append(velo)
		var cd := ForjaTema.etiqueta("", 20, Color(1.0, 0.88, 0.60), true)
		cd.set_anchors_preset(Control.PRESET_FULL_RECT)
		cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd.add_theme_constant_override("outline_size", 6)
		cd.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.9))
		boton.add_child(cd)
		_cd_textos.append(cd)
		# Barra de recarga en tiempo real, además del velo radial y el número.
		var barra := TextureProgressBar.new()
		barra.min_value = 0.0
		barra.max_value = 1.0
		barra.value = 1.0
		barra.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
		barra.nine_patch_stretch = false
		barra.modulate = Color(0.95, 0.73, 0.32, 1.0)
		barra.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		barra.offset_left = 8.0
		barra.offset_right = -8.0
		barra.offset_top = -34.0
		barra.offset_bottom = -24.0
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boton.add_child(barra)
		barra.texture_progress = _textura_blanca()
		_cd_barras.append(barra)
		_cd_anteriores.append(1.0)
		_cd_enfriamiento.append(false)
		_pulso_tweens.append(null)
		boton.pivot_offset = Vector2(LADO_HABILIDAD * 0.5, LADO_HABILIDAD * 0.5)
		var nv := ForjaTema.rotulo("Nv 1", 10, ForjaTema.ORO_CLARO)
		nv.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		nv.offset_top = -19
		nv.offset_bottom = -1
		nv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boton.add_child(nv)
		_niveles.append(nv)
		_botones.append(boton)

	# INTERACTUAR en el centro de la rueda: el pulgar cae ahí sin soltar el móvil.
	_boton_interactuar = _crear_boton("INTERACTUAR", Vector2.ZERO, LADO_INTERACTUAR, 11, true)
	var estilo_hub := StyleBoxFlat.new()
	estilo_hub.bg_color = Color(0.16, 0.10, 0.05, 0.92)
	estilo_hub.border_color = ForjaTema.ORO
	estilo_hub.set_border_width_all(3)
	estilo_hub.set_corner_radius_all(int(LADO_INTERACTUAR * 0.5))
	_boton_interactuar.add_theme_stylebox_override("normal", estilo_hub)
	var hub_pulsado := estilo_hub.duplicate() as StyleBoxFlat
	hub_pulsado.bg_color = Color(0.34, 0.22, 0.09, 0.96)
	hub_pulsado.border_color = ForjaTema.ORO_CLARO
	_boton_interactuar.add_theme_stylebox_override("pressed", hub_pulsado)
	_boton_interactuar.add_theme_stylebox_override("hover", estilo_hub)
	_boton_interactuar.pressed.connect(func() -> void: interactuar.emit())

	# Botonera derecha: ataque grande abajo, dash un poco más arriba y a la
	# izquierda; las cuatro habilidades quedan en el arco por encima del pulgar.
	_boton_ataque = _crear_boton("ATAQUE", Vector2(1150, 650), 104, 14, true)
	_boton_ataque.pressed.connect(func() -> void: ataque.emit())
	_boton_dash = _crear_boton("DASH", Vector2(960, 650), 78, 13, true)
	_boton_dash.pressed.connect(func() -> void: dash.emit())

	_boton_pausa = ForjaTema.boton("II", 18)
	_boton_pausa.position = Vector2(1216, 96)
	_boton_pausa.custom_minimum_size = Vector2(52, 40)
	_boton_pausa.size = Vector2(52, 40)
	_boton_pausa.pressed.connect(func() -> void: pausa.emit())
	_raiz.add_child(_boton_pausa)

	aplicar_escala(escala)


func _aplicar_marco() -> void:
	var viewport := get_viewport()
	if _raiz == null or viewport == null:
		return
	SafeArea.aplicar(_raiz, 1280.0, 720.0)
	var destino := SafeArea.marco(viewport.size, 1280.0, 720.0)
	_origen_marco = destino.position
	_escala_marco = maxf(destino.size.x / 1280.0, 0.1)


## Textura 1×1 cacheada para las barras: no creamos assets nuevos.
static func _textura_blanca() -> Texture2D:
	if _textura_barra != null:
		return _textura_barra
	var imagen := Image.create(76, 10, false, Image.FORMAT_RGBA8)
	imagen.fill(Color(1, 1, 1, 1))
	_textura_barra = ImageTexture.create_from_image(imagen)
	return _textura_barra


## Coordenada de evento (viewport) -> coordenada de diseño 1280×720.
func _a_diseno(posicion: Vector2) -> Vector2:
	return (posicion - _origen_marco) / _escala_marco


## Factor de radio: al agrandar los botones el anillo crece menos que ellos,
## así el conjunto sigue entrando en la esquina.
func _factor_radio() -> float:
	return 0.55 + 0.45 * escala


func _centro_rueda() -> Vector2:
	var radio := RADIO_RUEDA * _factor_radio()
	var lado := LADO_HABILIDAD * escala
	var centro := CENTRO_RUEDA
	centro.x = minf(centro.x, 1280.0 - 22.0 - radio - lado * 0.5)
	# Los botones de la rueda cuelgan hacia arriba: abajo sólo manda el hub,
	# así que se puede bajar sin que se salga de pantalla.
	centro.y = minf(centro.y, 720.0 - 14.0 - LADO_INTERACTUAR * escala * 0.5)
	return centro


func _posicion_rueda(indice: int) -> Vector2:
	var grados: float = ANGULOS[clampi(indice, 0, ANGULOS.size() - 1)]
	var rad := deg_to_rad(grados)
	var lado := LADO_HABILIDAD * escala
	return _centro_rueda() + Vector2(cos(rad), sin(rad)) * RADIO_RUEDA * _factor_radio() - Vector2(lado, lado) * 0.5


## Vida, maná y nivel en una pastilla compacta arriba a la izquierda: en el
## teléfono la consola del HUD queda lejos del pulgar, así que el estado vital
## vive junto al pulgar que mira la esquina superior.
func _crear_vitales() -> void:
	_panel_vital = PanelContainer.new()
	var estilo := ForjaTema.estilo_panel(0.9)
	estilo.content_margin_left = 12
	estilo.content_margin_right = 14
	estilo.content_margin_top = 7
	estilo.content_margin_bottom = 8
	_panel_vital.add_theme_stylebox_override("panel", estilo)
	_panel_vital.position = Vector2(16, 96)
	_panel_vital.custom_minimum_size = Vector2(272, 0)
	_raiz.add_child(_panel_vital)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 4)
	_panel_vital.add_child(columna)

	var cabecera := HBoxContainer.new()
	columna.add_child(cabecera)
	_nivel = ForjaTema.rotulo("NIVEL 1", 10, ForjaTema.TEXTO_FUERTE)
	_nivel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(_nivel)
	var clase := ForjaTema.rotulo("GLADIADOR", 10, ForjaTema.TENUE)
	cabecera.add_child(clase)

	for dato in [["vida", ForjaTema.VIDA], ["mana", ForjaTema.MANA]]:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		var icono := ForjaTema.IconoStat.new(StringName(dato[0]), 13.0, dato[1])
		icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fila.add_child(icono)
		var barra := ForjaTema.BarraSegmentada.new(1.0, dato[1])
		barra.custom_minimum_size = Vector2(166, 12)
		barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fila.add_child(barra)
		var valor := ForjaTema.etiqueta("", 10, ForjaTema.ORO_CLARO)
		valor.custom_minimum_size = Vector2(64, 0)
		valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fila.add_child(valor)
		columna.add_child(fila)
		if String(dato[0]) == "vida":
			_barra_vida = barra
			_texto_vida = valor
		else:
			_barra_mana = barra
			_texto_mana = valor


## Accesos directos que en escritorio viven en la parrilla de comandos: sin
## teclado, el jugador necesita tocar mercader, talentos y mochila.
func _crear_accesos() -> void:
	var columna := VBoxContainer.new()
	columna.position = Vector2(16, 178)
	columna.add_theme_constant_override("separation", 6)
	_raiz.add_child(columna)

	var mercader := _crear_boton("MERCADER", Vector2.ZERO, 0, 14, false, columna)
	mercader.custom_minimum_size = Vector2(196, 44)
	mercader.size = Vector2(196, 44)
	mercader.pressed.connect(func() -> void: tienda.emit())

	var boton_talentos := _crear_boton("TALENTOS", Vector2.ZERO, 0, 14, false, columna)
	boton_talentos.custom_minimum_size = Vector2(196, 44)
	boton_talentos.size = Vector2(196, 44)
	boton_talentos.pressed.connect(func() -> void: talentos.emit())

	var mochila := _crear_boton("MOCHILA", Vector2.ZERO, 0, 14, false, columna)
	mochila.custom_minimum_size = Vector2(196, 44)
	mochila.size = Vector2(196, 44)
	mochila.pressed.connect(alternar_mochila)

	# Ficha: sin tooltips en el móvil, la vida/maná y las habilidades con su
	# nivel y descripción tienen que estar a un toque.
	var ficha := _crear_boton("FICHA", Vector2.ZERO, 0, 14, false, columna)
	ficha.custom_minimum_size = Vector2(196, 44)
	ficha.size = Vector2(196, 44)
	ficha.pressed.connect(alternar_ficha)


func _crear_mochila() -> void:
	_panel_mochila = PanelContainer.new()
	_panel_mochila.visible = false
	_panel_mochila.position = Vector2(430, 196)
	_panel_mochila.custom_minimum_size = Vector2(420, 0)
	_panel_mochila.add_theme_stylebox_override("panel", ForjaTema.estilo_ventana())
	_raiz.add_child(_panel_mochila)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	_panel_mochila.add_child(columna)

	var cabecera := HBoxContainer.new()
	columna.add_child(cabecera)
	var titulo := ForjaTema.titulo("MOCHILA", 20, ForjaTema.ORO_CLARO)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(titulo)
	var cerrar := ForjaTema.boton("CERRAR", 12)
	cerrar.custom_minimum_size = Vector2(104, 34)
	cerrar.pressed.connect(cerrar_mochila)
	cabecera.add_child(cerrar)

	columna.add_child(ForjaTema.etiqueta(
		"Tocá un objeto para usarlo. Los enfriamientos bajan solos.", 11, ForjaTema.TENUE
	))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	columna.add_child(grid)

	for i in InventoryComponent.RANURAS:
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(120, 84)
		boton.focus_mode = Control.FOCUS_NONE
		boton.text = ""
		boton.expand_icon = true
		boton.add_theme_stylebox_override("normal", ForjaTema.estilo_tarjeta(ForjaTema.ORO_OSCURO, false, true))
		boton.add_theme_stylebox_override("hover", ForjaTema.estilo_tarjeta(ForjaTema.ORO, true))
		boton.add_theme_stylebox_override("pressed", ForjaTema.estilo_tarjeta(ForjaTema.ORO_CLARO, true))
		boton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		boton.pressed.connect(_usar_mochila.bind(i))
		var tecla := ForjaTema.rotulo(["Z", "X", "C", "V", "B", "N"][i], 9, ForjaTema.ORO)
		tecla.position = Vector2(4, 3)
		tecla.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boton.add_child(tecla)
		var cantidad := ForjaTema.etiqueta("", 11, ForjaTema.TEXTO_FUERTE)
		cantidad.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		cantidad.position = Vector2(78, 62)
		cantidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cantidad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boton.add_child(cantidad)
		grid.add_child(boton)
		_slots_mochila.append([boton, cantidad])


func alternar_mochila() -> void:
	if _mochila_abierta:
		cerrar_mochila()
		return
	if al_abrir_panel.is_valid():
		al_abrir_panel.call()
	_mochila_abierta = true
	_panel_mochila.visible = true
	_panel_mochila.move_to_front()
	_refrescar_mochila()


func cerrar_mochila() -> void:
	_mochila_abierta = false
	if _panel_mochila != null:
		_panel_mochila.visible = false


func _usar_mochila(indice: int) -> void:
	if _jugador == null:
		return
	_jugador.usar_objeto(indice)
	_refrescar_mochila()


func _refrescar_mochila() -> void:
	if not _mochila_abierta or _jugador == null or _jugador.inventario == null:
		return
	var inventario := _jugador.inventario
	for i in _slots_mochila.size():
		var par: Array = _slots_mochila[i]
		var boton: Button = par[0]
		var cantidad: Label = par[1]
		var ranura: Dictionary = inventario.ranuras[i]
		var item: ItemData = ranura.get("item")
		if item == null:
			boton.icon = null
			boton.disabled = true
			cantidad.text = ""
			continue
		boton.icon = IconStudio.obtener(item.id, IconStudio.CATEGORIA_OBJETO)
		var restante := inventario.energia_restante(i)
		var cuantos := int(ranura.get("cantidad", 1))
		cantidad.text = ("%ds" % int(ceil(restante))) if restante > 0.5 else (("x%d" % cuantos) if cuantos > 1 else "")
		boton.disabled = restante > 0.0


## Ficha del campeón: una tarjeta semitransparente con los números y las cuatro
## habilidades (nivel, coste, recarga y descripción). Se abre y se cierra a
## voluntad para no tapar la arena.
func _crear_ficha() -> void:
	_panel_ficha = PanelContainer.new()
	_panel_ficha.visible = false
	_panel_ficha.position = Vector2(300, 92)
	_panel_ficha.custom_minimum_size = Vector2(520, 0)
	var estilo := ForjaTema.estilo_panel(0.975)
	estilo.content_margin_left = 14
	estilo.content_margin_right = 14
	estilo.content_margin_top = 10
	estilo.content_margin_bottom = 12
	_panel_ficha.add_theme_stylebox_override("panel", estilo)
	_raiz.add_child(_panel_ficha)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 6)
	_panel_ficha.add_child(columna)

	var cabecera := HBoxContainer.new()
	columna.add_child(cabecera)
	var titulo := ForjaTema.titulo("FICHA DEL CAMPEÓN", 18, ForjaTema.ORO_CLARO)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(titulo)
	var cerrar := ForjaTema.boton("CERRAR", 11)
	cerrar.custom_minimum_size = Vector2(96, 30)
	cerrar.pressed.connect(cerrar_ficha)
	cabecera.add_child(cerrar)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(492, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columna.add_child(scroll)

	_texto_ficha = RichTextLabel.new()
	_texto_ficha.bbcode_enabled = true
	_texto_ficha.fit_content = true
	_texto_ficha.scroll_active = false
	_texto_ficha.custom_minimum_size = Vector2(486, 0)
	_texto_ficha.add_theme_font_size_override("normal_font_size", 13)
	_texto_ficha.add_theme_font_size_override("bold_font_size", 14)
	_texto_ficha.add_theme_color_override("default_color", ForjaTema.TEXTO)
	scroll.add_child(_texto_ficha)


func alternar_ficha() -> void:
	if _ficha_abierta:
		cerrar_ficha()
		return
	if al_abrir_panel.is_valid():
		al_abrir_panel.call()
	_ficha_abierta = true
	_panel_ficha.visible = true
	_panel_ficha.move_to_front()
	if _mochila_abierta:
		cerrar_mochila()
	_refrescar_ficha()


func cerrar_ficha() -> void:
	_ficha_abierta = false
	if _panel_ficha != null:
		_panel_ficha.visible = false


## Texto de la ficha: atributos arriba y una entrada por habilidad.
func _refrescar_ficha() -> void:
	if _texto_ficha == null or _jugador == null:
		return
	var e := _jugador.estadisticas
	var arma := _jugador.arma_actual
	var lineas: Array = []
	var clase := "GLADIADOR"
	if arma != null:
		clase = String(ForjaTema.NOMBRE_EMBLEMA.get(arma.clase, clase))
	lineas.append("[b][color=#e8c76a]%s[/color][/b]   ·   Nv %d   ·   XP %d/%d" % [
		clase, e.nivel, e.experiencia, CurvaNivel.xp_requerida(e.nivel),
	])
	lineas.append("[color=#b8ae9a]VIDA[/color] %d/%d      [color=#b8ae9a]MANÁ[/color] %d/%d" % [
		int(ceil(_jugador.salud_actual)), int(e.salud_maxima),
		int(ceil(_jugador.mana_actual)), int(e.mana_maximo),
	])
	if arma != null:
		var rango := e.rango_dano_ataque(arma.dano_ataque_base, arma.atributo_principal)
		lineas.append("[color=#b8ae9a]DAÑO[/color] %d-%d      [color=#b8ae9a]ARMADURA[/color] %d (%.0f%%)      [color=#b8ae9a]CRÍT[/color] %d%%" % [
			int(rango.x), int(rango.y), int(round(e.armadura_total)),
			e.mitigacion_fisica * 100.0, int(round(e.probabilidad_critico * 100.0)),
		])
		lineas.append("[color=#b8ae9a]VEL. ATAQUE[/color] %.2f/s      [color=#b8ae9a]FUE[/color] %d   [color=#b8ae9a]AGI[/color] %d   [color=#b8ae9a]INT[/color] %d" % [
			e.velocidad_ataque, e.fuerza_total, e.agilidad_total, e.inteligencia_total,
		])
	lineas.append("")
	lineas.append("[b][color=#e8c76a]HABILIDADES[/color][/b]")
	for i in CLAVES.size():
		var habilidad: AbilityData = arma.obtener_habilidad(i) if arma != null else null
		if habilidad == null:
			lineas.append("[color=#8f8778]%s · vacía[/color]" % CLAVES[i])
			continue
		if not _jugador.habilidad_desbloqueada(i):
			lineas.append("[b][color=#8f8778]%s · %s[/color][/b]   [color=#8f8778]se abre al nivel %d[/color]" % [
				CLAVES[i], habilidad.nombre, _jugador.nivel_desbloqueo_habilidad(i),
			])
			var bloqueada := habilidad.descripcion.strip_edges().replace("
", " ")
			if not bloqueada.is_empty():
				lineas.append("[color=#7e776a]%s[/color]" % bloqueada)
			continue
		var rango_nivel := _jugador.rango_habilidad(habilidad.id)
		lineas.append("[b][color=#e8c76a]%s[/color][/b] · %s   [color=#9ad0ff]Nv %d/%d[/color]   [color=#8fb7e0]%d maná[/color]   [color=#b8ae9a]%.0f s[/color]" % [
			CLAVES[i], habilidad.nombre, rango_nivel, int(max(1, habilidad.rango_maximo)),
			int(habilidad.coste_mana), habilidad.cooldown,
		])
		var descripcion := habilidad.descripcion.strip_edges().replace("\n", " ")
		if not descripcion.is_empty():
			lineas.append("[color=#a8a08e]%s[/color]" % descripcion)
	_texto_ficha.text = "\n".join(lineas)


func _crear_joystick() -> void:
	_base = Panel.new()
	_base.size = Vector2(RADIO_JOY, RADIO_JOY) * 2.0
	_base.position = _joy_centro - Vector2(RADIO_JOY, RADIO_JOY)
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.visible = false
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0, 0, 0, 0)
	estilo.border_color = Color(ForjaTema.ORO_OSCURO.r, ForjaTema.ORO_OSCURO.g, ForjaTema.ORO_OSCURO.b, 0.55)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(int(RADIO_JOY))
	_base.add_theme_stylebox_override("panel", estilo)
	_raiz.add_child(_base)

	_aro = ForjaTema.AroRunas.new(RADIO_JOY)
	_aro.position = _joy_centro - Vector2(RADIO_JOY, RADIO_JOY)
	_aro.visible = false
	_raiz.add_child(_aro)

	_perilla = Panel.new()
	_perilla.size = Vector2(RADIO_JOY, RADIO_JOY)
	_perilla.position = _joy_centro - _perilla.size * 0.5
	_perilla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_perilla.visible = false
	var estilo_perilla := StyleBoxFlat.new()
	estilo_perilla.bg_color = Color(0.72, 0.58, 0.30, 0.32)
	estilo_perilla.border_color = ForjaTema.ORO
	estilo_perilla.set_border_width_all(2)
	estilo_perilla.set_corner_radius_all(int(RADIO_JOY * 0.5))
	_perilla.add_theme_stylebox_override("panel", estilo_perilla)
	_raiz.add_child(_perilla)


func _crear_boton(
	texto: String, posicion: Vector2, tamano: float, letra: int, circular: bool, contenedor: Node = null
) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.position = posicion
	boton.size = Vector2(tamano, tamano)
	boton.custom_minimum_size = boton.size
	boton.focus_mode = Control.FOCUS_NONE
	boton.add_theme_font_size_override("font_size", letra)
	boton.add_theme_color_override("font_color", ForjaTema.ORO_CLARO)
	boton.add_theme_color_override("font_pressed_color", Color(0.09, 0.08, 0.06))
	boton.add_theme_color_override("font_disabled_color", Color(0.45, 0.40, 0.33))

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.07, 0.06, 0.05, 0.86)
	estilo.border_color = ForjaTema.ORO_OSCURO
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(int(tamano * 0.5) if circular else 4)
	estilo.shadow_color = Color(0, 0, 0, 0.45)
	estilo.shadow_size = 4
	boton.add_theme_stylebox_override("normal", estilo)

	var pulsado := estilo.duplicate() as StyleBoxFlat
	pulsado.bg_color = Color(0.30, 0.22, 0.10, 0.95)
	pulsado.border_color = ForjaTema.ORO_CLARO
	boton.add_theme_stylebox_override("pressed", pulsado)
	boton.add_theme_stylebox_override("hover", estilo)
	boton.add_theme_stylebox_override("disabled", estilo)
	boton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# `add_child` una sola vez: re-parentarlo después imprime "already has a
	# parent" y el botón queda en el sitio equivocado.
	var padre := contenedor if contenedor != null else _raiz
	padre.add_child(boton)
	return boton


## Reubica y escala todo el bloque táctil (Ajustes → tamaño de botones).
func aplicar_escala(nueva: float) -> void:
	escala = clampf(nueva, 0.75, 1.6)
	if _raiz == null or _aro == null:
		return
	var base_tam := Vector2(RADIO_JOY, RADIO_JOY) * 2.0 * escala
	_base.size = base_tam
	_base.position = _joy_centro - base_tam * 0.5
	if _aro != null:
		_aro.escala = escala
		_aro.position = _joy_centro - base_tam * 0.5
		_aro.queue_redraw()
	if _perilla != null:
		_perilla.size = Vector2(RADIO_JOY, RADIO_JOY) * escala
		_perilla.position = _joy_centro - _perilla.size * 0.5
	for i in _botones.size():
		var boton: Button = _botones[i]
		boton.size = Vector2(LADO_HABILIDAD, LADO_HABILIDAD) * escala
		boton.custom_minimum_size = boton.size
		boton.position = _posicion_rueda(i)
		boton.pivot_offset = boton.size * 0.5
		boton.add_theme_font_size_override("font_size", int(26 * escala))
	if _boton_interactuar != null:
		_boton_interactuar.size = Vector2(LADO_INTERACTUAR, LADO_INTERACTUAR) * escala
		_boton_interactuar.custom_minimum_size = _boton_interactuar.size
		_boton_interactuar.position = _centro_rueda() - _boton_interactuar.size * 0.5
		_boton_interactuar.add_theme_font_size_override("font_size", int(11 * escala))
	if _boton_ataque != null:
		_boton_ataque.size = Vector2(104, 104) * escala
		_boton_ataque.custom_minimum_size = _boton_ataque.size
		_boton_ataque.position = Vector2(1150, 650) - _boton_ataque.size * 0.5
		_boton_ataque.add_theme_font_size_override("font_size", int(14 * escala))
	if _boton_dash != null:
		_boton_dash.size = Vector2(78, 78) * escala
		_boton_dash.custom_minimum_size = _boton_dash.size
		_boton_dash.position = Vector2(960, 650) - _boton_dash.size * 0.5
		_boton_dash.add_theme_font_size_override("font_size", int(13 * escala))


func _input(evento: InputEvent) -> void:
	if not visible:
		return
	# Joystick flotante: cualquier toque de la mitad inferior izquierda mueve
	# el aro hasta el dedo. Se sigue aceptando ratón para probar en escritorio.
	if evento is InputEventScreenTouch:
		var toque := evento as InputEventScreenTouch
		var local := _a_diseno(toque.position)
		if not toque.pressed:
			if _joy_indice != -1 and toque.index != _joy_indice:
				return
			_soltar_joystick()
			return
		if _joy_activo:
			return
		if local.x > 588.0 or local.y < 324.0:
			return
		_joy_centro = local
		_joy_activo = true
		_joy_indice = toque.index
		_arrastrando = true
		_ubicar_joystick()
		_mover_perilla(local)
		return
	if evento is InputEventScreenDrag:
		if not _arrastrando or _joy_indice == -1:
			return
		var arrastre := evento as InputEventScreenDrag
		if arrastre.index != _joy_indice:
			return
		_mover_perilla(_a_diseno(arrastre.position))
		return
	if evento is InputEventMouseButton:
		var clic := evento as InputEventMouseButton
		if clic.button_index != MOUSE_BUTTON_LEFT:
			return
		var local := _a_diseno(clic.position)
		if not clic.pressed:
			_soltar_joystick()
			return
		if _joy_activo or local.x > 588.0 or local.y < 324.0:
			return
		_joy_centro = local
		_joy_activo = true
		_joy_indice = -1
		_arrastrando = true
		_ubicar_joystick()
		_mover_perilla(local)
		return
	if evento is InputEventMouseMotion and _arrastrando and _joy_indice == -1:
		_mover_perilla(_a_diseno((evento as InputEventMouseMotion).position))


## Estado global (GameManager): fuera de PLAYING el HUD táctil desaparece y
## deja de recibir input, así la tienda no recibe toques fantasma del joystick.
func sincronizar_estado(jugable: bool) -> void:
	visible = jugable
	set_process(jugable)
	set_process_input(jugable)
	if not jugable:
		_soltar_joystick()


func _ubicar_joystick() -> void:
	if _base == null or _aro == null or _perilla == null:
		return
	var base_tam := Vector2(RADIO_JOY, RADIO_JOY) * 2.0 * escala
	_base.position = _joy_centro - base_tam * 0.5
	_aro.position = _joy_centro - base_tam * 0.5
	_perilla.position = _joy_centro - _perilla.size * 0.5
	_base.visible = true
	_aro.visible = true
	_perilla.visible = true


func _mover_perilla(posicion: Vector2) -> void:
	var delta := posicion - _joy_centro
	var limite := RADIO_JOY * escala
	if delta.length() > limite:
		delta = delta.normalized() * limite
	_perilla.position = _joy_centro + delta - _perilla.size * 0.5
	var direccion := delta / limite
	if direccion.length() < 0.16:
		direccion = Vector2.ZERO
	_aro.direccion = direccion
	_aro.queue_redraw()
	mover.emit(direccion)


func _soltar_joystick() -> void:
	_arrastrando = false
	_joy_activo = false
	_joy_indice = -1
	if _base != null:
		_base.visible = false
	if _aro != null:
		_aro.visible = false
		_aro.direccion = Vector2.ZERO
		_aro.queue_redraw()
	if _perilla != null:
		_perilla.visible = false
		_perilla.position = _joy_centro - _perilla.size * 0.5
	mover.emit(Vector2.ZERO)


func _process(_delta: float) -> void:
	if _jugador == null:
		return
	if _mochila_abierta:
		_refrescar_mochila()
	var vida_max := maxf(1.0, _jugador.estadisticas.salud_maxima)
	var vida_fraccion := clampf(_jugador.salud_actual / vida_max, 0.0, 1.0)
	if absf(vida_fraccion - _vida_fraccion_anterior) > 0.001:
		_vida_fraccion_anterior = vida_fraccion
		_barra_vida.valor = vida_fraccion
		_barra_vida.queue_redraw()
		_texto_vida.text = "%d/%d" % [int(ceil(_jugador.salud_actual)), int(vida_max)]
	var mana_max := maxf(1.0, _jugador.estadisticas.mana_maximo)
	var mana_fraccion := clampf(_jugador.mana_actual / mana_max, 0.0, 1.0)
	if absf(mana_fraccion - _mana_fraccion_anterior) > 0.001:
		_mana_fraccion_anterior = mana_fraccion
		_barra_mana.valor = mana_fraccion
		_barra_mana.queue_redraw()
		_texto_mana.text = "%d/%d" % [int(ceil(_jugador.mana_actual)), int(mana_max)]
	if _nivel != null and _jugador.estadisticas.nivel != _nivel_anterior:
		_nivel_anterior = _jugador.estadisticas.nivel
		_nivel.text = "NIVEL %d" % _nivel_anterior

	for i in mini(_botones.size(), CLAVES.size()):
		var boton: Button = _botones[i]
		if boton == null:
			continue
		var restante := _jugador.cooldown_restante(i) if not _jugador.esta_muerto else 0.0
		var total := 1.0
		if _jugador.arma_actual != null and i < _jugador.arma_actual.habilidades.size():
			var habilidad = _jugador.arma_actual.habilidades[i]
			if habilidad != null:
				total = maxf(0.01, _jugador.cooldown_habilidad(habilidad))
		var fraccion := clampf(restante / total, 0.0, 1.0)
		var velo: ForjaTema.VeloRadial = _velos[i]
		if velo != null:
			velo.fijar(fraccion)
		var cd: Label = _cd_textos[i]
		if cd != null:
			cd.text = ("%d" % int(ceil(restante))) if restante > 0.5 else ""
		if i < _cd_barras.size():
			var barra: TextureProgressBar = _cd_barras[i]
			var listo := 1.0 - fraccion
			if absf(listo - _cd_anteriores[i]) > 0.01:
				barra.value = listo
				_cd_anteriores[i] = listo
			var enfriando := restante > 0.05
			if _cd_enfriamiento[i] and not enfriando and total > 1.0:
				_pulso_recarga(i)
			_cd_enfriamiento[i] = enfriando
		boton.modulate = Color(1, 1, 1, 1) if _disponible(i) else Color(0.55, 0.52, 0.46, 0.8)
		if i < _niveles.size():
			_actualizar_nivel_habilidad(i)


## Un solo tween por recarga completada: escala arriba y vuelve, sin crear un
## Tween por fotograma (eso costaba más que el propio cooldown).
func _pulso_recarga(slot: int) -> void:
	if slot >= _botones.size():
		return
	var boton: Button = _botones[slot]
	if boton == null or not is_instance_valid(boton):
		return
	if slot < _pulso_tweens.size():
		var anterior = _pulso_tweens[slot]
		if anterior != null and is_instance_valid(anterior):
			anterior.kill()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(boton, "scale", Vector2(1.12, 1.12), 0.10)
	tween.tween_property(boton, "scale", Vector2(1.0, 1.0), 0.18)
	if slot < _pulso_tweens.size():
		_pulso_tweens[slot] = tween


## Rótulo de nivel bajo cada habilidad: el rango actual o, si está bloqueada,
## el nivel en que se abre. En el móvil no hay tooltips que lo expliquen.
func _actualizar_nivel_habilidad(slot: int) -> void:
	var etiqueta: Label = _niveles[slot]
	if etiqueta == null or _jugador == null or _jugador.arma_actual == null:
		return
	var habilidad := _jugador.arma_actual.obtener_habilidad(slot)
	if habilidad == null:
		etiqueta.text = ""
		return
	if not _jugador.habilidad_desbloqueada(slot):
		etiqueta.text = "Nv %d" % _jugador.nivel_desbloqueo_habilidad(slot)
		etiqueta.add_theme_color_override("font_color", Color(0.52, 0.48, 0.42))
		return
	etiqueta.text = "Nv %d" % _jugador.rango_habilidad(habilidad.id)
	etiqueta.add_theme_color_override("font_color", ForjaTema.ORO_CLARO)


func _disponible(slot: int) -> bool:
	if _jugador == null or _jugador.esta_muerto:
		return false
	if _jugador.cooldown_restante(slot) > 0.0:
		return false
	if _jugador.arma_actual == null or slot >= _jugador.arma_actual.habilidades.size():
		return true
	var habilidad = _jugador.arma_actual.habilidades[slot]
	if habilidad == null:
		return true
	return _jugador.mana_actual >= habilidad.coste_mana
