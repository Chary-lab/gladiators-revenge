class_name ArenaHUD
extends CanvasLayer
## HUD único de la arena: consola inferior de 185 px con minimapa, ficha del
## gladiador, estadísticas en vivo, mochila de 6 ranuras y habilidades QWER.
## Todo se construye por código para mantener el proyecto sin escenas extra.

const ANCHO := 1280.0
const ALTO_CONSOLA := 185.0
const ORO := Color(0.86, 0.68, 0.32)
const BRONCE := Color(0.62, 0.45, 0.22)
const HIERRO := Color(0.16, 0.14, 0.13)
const TEXTO := Color(0.93, 0.88, 0.78)
const ROJO := Color(0.78, 0.22, 0.18)
const VERDE := Color(0.35, 0.78, 0.45)
const AZUL := Color(0.35, 0.58, 0.92)
const NOMBRES_CLASE: Array[String] = ["PRISIONERO", "BASTIÓN", "FILO", "CETRO"]
const NOMBRES_ROL: Array[String] = ["—", "TANQUE", "VERDUGO", "CONVOCADOR"]

var _jugador: GladiatorController
var _oleadas: WaveManager
var _bandera: RebellionBanner
var _arena: Node
var _raiz: Control
var _hud_arriba: Control
var _consola: Panel
var _mensaje: Label
var _pista: Label
var _aviso: Label
var _oleada: Label
var _oro: Label
var _enemigos: Label
var _tiempo_oleada: Label
var _texto_puntos: Label
var _barra_bandera: ProgressBar

var _barra_vida: ProgressBar
var _barra_mana: ProgressBar
var _vida_texto: Label
var _mana_texto: Label
var _escudo_texto: Label
var _clase: Label
var _nivel_texto: Label
var _barra_xp: ProgressBar
var _stats: RichTextLabel
var _atributos_nombres: Array[Label] = []
var _atributos_valores: Array[Label] = []
var _oro_ficha: Label
var _buff_iconos: Array[TextureRect] = []
var _icono_dano: TextureRect
var _icono_armadura: TextureRect
var _habilidad_botones: Array[Button] = []
var _habilidad_velos: Array[ColorRect] = []
var _habilidad_cd: Array[Label] = []
var _habilidad_pips: Array = []
var _habilidad_flashes: Array[ColorRect] = []
var _inventario_botones: Array[Button] = []
var _inventario_velos: Array[ColorRect] = []
var _inventario_cantidad: Array[Label] = []
var _ranura_seleccionada_swap: int = -1
var _color_borde_normal: Color = Color(0.45, 0.32, 0.2)
var _color_borde_seleccionado: Color = Color(0.96, 0.82, 0.48)
var _comando_botones: Array[Button] = []
var _contador_atributos: Label
var _contador_talentos: Label
var _retrato: GladiatorPortrait
var _estado: Label
var _minimapa: ArenaMinimap
var _revive_panel: Panel
var _revive_titulo: Label
var _revive_detalle: Label
var _revive_barra: ProgressBar
var _tooltip: TooltipRico
var _capa_tooltip: CanvasLayer
var _comandos_datos: Array = []
var _comando_activo: Array = [false, false, false, false, false, false, false, false]
var _cd_antes: Array = [0.0, 0.0, 0.0, 0.0]
var _overlay: Panel
var _overlay_detalle: VBoxContainer
var _overlay_titulo: Button
var _overlay_vida: Label
var _overlay_mana: Label
var _overlay_dano: Label
var _overlay_recibido: Label
var _overlay_expandido := true
var _talentos: TalentPanel
var _tienda: ShopPanel


func configurar(
	jugador: GladiatorController,
	oleadas: WaveManager,
	bandera: RebellionBanner,
	arena: Node
) -> void:
	_jugador = jugador
	_oleadas = oleadas
	_bandera = bandera
	_arena = arena
	process_mode = Node.PROCESS_MODE_ALWAYS
	construir()
	if _jugador != null and not _jugador.arma_cambiada.is_connected(_al_cambiar_arma_hud):
		_jugador.arma_cambiada.connect(_al_cambiar_arma_hud)
	_actualizar_iconos_habilidades()
	_talentos = TalentPanel.new()
	add_child(_talentos)
	_talentos.configurar(_jugador)
	_tienda = ShopPanel.new()
	add_child(_tienda)
	_tienda.configurar(_jugador, _arena, self)
	if _oleadas != null:
		_oleadas.mensaje.connect(mostrar_mensaje)
	if _jugador != null and not _jugador.nivel_alcanzado.is_connected(_al_subir_nivel):
		_jugador.nivel_alcanzado.connect(_al_subir_nivel)
	if _jugador != null and not _jugador.habilidad_mejorada.is_connected(_al_mejorar_habilidad):
		_jugador.habilidad_mejorada.connect(_al_mejorar_habilidad)


func _al_subir_nivel(nivel: int) -> void:
	mostrar_mensaje("¡NIVEL %d!\nAtributos de clase aumentan" % nivel, 2.2)
	Sfx.reproducir(&"victoria", -10.0)


func _al_mejorar_habilidad(_slot: int, habilidad: AbilityData, rango: int) -> void:
	if habilidad == null:
		return
	mostrar_mensaje(
		"¡NIVEL %d!\n¡%s subió a Nivel %d!" % [
			_jugador.estadisticas.nivel, habilidad.nombre, rango
		],
		2.4
	)
	Sfx.reproducir(&"habilidad", -7.0)


# --- Construcción ---------------------------------------------------------

func construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_hud_arriba = Control.new()
	_hud_arriba.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_arriba.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_hud_arriba)

	_consola = _panel(Vector2(0, 535), Vector2(ANCHO, ALTO_CONSOLA), Color(0.09, 0.08, 0.07, 0.96), BRONCE)
	_raiz.add_child(_consola)

	_crear_retrato()
	_crear_ficha()
	_crear_inventario()
	_crear_habilidades()
	_crear_minimapa()
	_crear_barra_superior()
	_crear_overlay()
	_crear_mensajes()
	_crear_revive()
	_capa_tooltip = CanvasLayer.new()
	_capa_tooltip.layer = 60
	add_child(_capa_tooltip)
	_tooltip = TooltipRico.new()
	_capa_tooltip.add_child(_tooltip)


func _crear_minimapa() -> void:
	_minimapa = ArenaMinimap.new()
	_minimapa.position = Vector2(8, 543)
	_minimapa.size = Vector2(165, 165)
	_minimapa.set_jugador(_jugador)
	_minimapa.set_bandera(_bandera)
	_raiz.add_child(_minimapa)


func _crear_retrato() -> void:
	var fondo := _panel(Vector2(180, 543), Vector2(160, 167), HIERRO, Color(0.40, 0.33, 0.23))
	_raiz.add_child(fondo)
	_retrato = GladiatorPortrait.new()
	_retrato.position = Vector2(5, 4)
	_retrato.size = Vector2(150, 106)
	fondo.add_child(_retrato)
	_retrato.configurar(_jugador)

	_barra_vida = _barra(fondo, Vector2(8, 113), Vector2(144, 23), VERDE)
	_barra_mana = _barra(fondo, Vector2(8, 139), Vector2(144, 22), AZUL)
	_vida_texto = _texto(fondo, "", Vector2(10, 115), Vector2(140, 19), 10, TEXTO)
	_mana_texto = _texto(fondo, "", Vector2(10, 141), Vector2(140, 18), 10, TEXTO)
	_vida_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mana_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _crear_ficha() -> void:
	var fondo := _panel(Vector2(347, 543), Vector2(545, 167), HIERRO, Color(0.36, 0.30, 0.22))
	_raiz.add_child(fondo)

	_clase = _texto(fondo, "GLADIADOR ORCO", Vector2(10, 4), Vector2(525, 20), 16, ORO)
	_clase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_barra_xp = _barra(fondo, Vector2(10, 24), Vector2(525, 6), Color(0.62, 0.35, 0.92))
	_nivel_texto = _texto(fondo, "", Vector2(10, 33), Vector2(525, 14), 10, Color(0.82, 0.70, 1.0))
	_nivel_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_icono_dano = _icono_estatico(fondo, &"atacar", Vector2(16, 54), Vector2(26, 26))
	_icono_armadura = _icono_estatico(fondo, &"mantener", Vector2(16, 82), Vector2(26, 26))
	_stats = RichTextLabel.new()
	_stats.position = Vector2(48, 50)
	_stats.size = Vector2(220, 84)
	_stats.bbcode_enabled = true
	_stats.scroll_active = false
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.add_theme_font_size_override("normal_font_size", 12)
	_stats.add_theme_color_override("default_color", TEXTO)
	fondo.add_child(_stats)

	var separador := ColorRect.new()
	separador.color = Color(0.42, 0.34, 0.22, 0.8)
	separador.position = Vector2(282, 50)
	separador.size = Vector2(1, 84)
	separador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.add_child(separador)

	var titulo := _texto(fondo, "ATRIBUTOS", Vector2(300, 50), Vector2(230, 15), 11, ORO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(300, 68)
	grid.size = Vector2(230, 66)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 2)
	fondo.add_child(grid)
	for nombre in ["FUERZA", "AGILIDAD", "INTELIGENCIA"]:
		var etiqueta := _texto(grid, nombre, Vector2.ZERO, Vector2(120, 18), 12, TEXTO)
		etiqueta.custom_minimum_size = Vector2(120, 18)
		var valor := _texto(grid, "", Vector2.ZERO, Vector2(80, 18), 12, TEXTO)
		valor.custom_minimum_size = Vector2(80, 18)
		valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_atributos_nombres.append(etiqueta)
		_atributos_valores.append(valor)

	_escudo_texto = _texto(fondo, "", Vector2(12, 121), Vector2(525, 14), 10, Color(0.55, 0.78, 1.0))
	_estado = _texto(fondo, "", Vector2(12, 137), Vector2(300, 18), 11, TEXTO)
	_oro_ficha = _texto(fondo, "", Vector2(390, 137), Vector2(143, 18), 12, ORO)
	_oro_ficha.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for i in 4:
		var icono := _icono_estatico(fondo, &"atacar", Vector2(318 + i * 20, 136), Vector2(18, 18))
		icono.visible = false
		_buff_iconos.append(icono)


func _crear_inventario() -> void:
	var titulo := _texto(_raiz, "INVENTARIO", Vector2(900, 537), Vector2(114, 14), 11, ORO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in InventoryComponent.RANURAS:
		var columna := i % 2
		var fila := i / 2
		var pos := Vector2(900 + columna * 60, 552 + fila * 57)
		var boton := _boton(pos, Vector2(54, 54), "")
		boton.pressed.connect(_usar_ranura.bind(i))
		boton.gui_input.connect(_evento_raton_inventario.bind(i, boton))
		boton.mouse_entered.connect(_mostrar_tooltip_inventario.bind(i))
		boton.mouse_exited.connect(_ocultar_tooltip)
		_raiz.add_child(boton)
		_inventario_botones.append(boton)
		_inventario_velos.append(_velo(boton, Vector2(54, 54)))
		_insignia(boton, ["Z", "X", "C", "V", "B", "N"][i], Vector2(3, 1), 18)
		var cantidad := _texto(boton, "", Vector2(28, 37), Vector2(22, 14), 10, TEXTO)
		cantidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cantidad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inventario_cantidad.append(cantidad)


func _crear_habilidades() -> void:
	var titulo := _texto(_raiz, "COMANDOS", Vector2(1024, 537), Vector2(240, 14), 11, ORO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var comandos := [
		["atacar", "A", "Atacar-mover: clic izquierdo sobre el suelo.", _comando_atacar],
		["detener", "S", "Detener: cancela movimiento y objetivo.", _comando_detener],
		["mantener", "H", "Mantener posición: no persigue enemigos.", _comando_mantener],
		["skin", "K", "Cambiar skin del gladiador.", _comando_skin],
		["atributos", "1/2/3", "Subir el atributo principal. Usa 1, 2 o 3 para elegir.", _comando_atributos],
		["talentos", "T", "Árbol de talentos y rangos de habilidad.", _comando_talentos],
		["tienda", "F", "Abrir el mercader de la rebelión.", _comando_tienda],
		["estadisticas", "-", "Mostrar u ocultar estadísticas de combate.", _comando_estadisticas],
	]
	_comandos_datos = comandos
	for i in comandos.size():
		var columna := i % 4
		var fila := i / 4
		var datos: Array = comandos[i]
		var boton := _boton(Vector2(1024 + columna * 62, 552 + fila * 57), Vector2(54, 54), "")
		boton.pressed.connect(datos[3])
		boton.mouse_entered.connect(_mostrar_tooltip_comando.bind(i))
		boton.mouse_exited.connect(_ocultar_tooltip)
		_boton_icono(boton, datos[0], IconStudio.CATEGORIA_COMANDO)
		_raiz.add_child(boton)
		_comando_botones.append(boton)
		_insignia(boton, datos[1], Vector2(3, 1), 28 if datos[0] == "atributos" else 18)
		if datos[0] == "atributos":
			_contador_atributos = _texto(boton, "", Vector2(34, 2), Vector2(17, 13), 9, Color(0.55, 1.0, 0.55))
			_contador_atributos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		elif datos[0] == "talentos":
			_contador_talentos = _texto(boton, "", Vector2(34, 2), Vector2(17, 13), 9, Color(1.0, 0.45, 0.35))
			_contador_talentos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	for i in 4:
		var boton := _boton(Vector2(1024 + i * 62, 666), Vector2(54, 54), "")
		boton.pressed.connect(_lanzar_habilidad.bind(i))
		boton.mouse_entered.connect(_mostrar_tooltip_habilidad.bind(i))
		boton.mouse_exited.connect(_ocultar_tooltip)
		boton.add_theme_font_size_override("font_size", 10)
		_raiz.add_child(boton)
		_habilidad_botones.append(boton)
		_habilidad_velos.append(_velo(boton, Vector2(54, 54)))
		_insignia(boton, ["Q", "W", "E", "R"][i], Vector2(3, 1), 18)
		var cd := _texto(boton, "", Vector2(0, 20), Vector2(54, 14), 10, Color(1.0, 0.86, 0.55))
		cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_habilidad_cd.append(cd)
		_habilidad_pips.append(_crear_pips(boton))
		var flash := ColorRect.new()
		flash.color = Color(1.0, 0.84, 0.35, 0.0)
		flash.position = Vector2.ZERO
		flash.size = Vector2(54, 54)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boton.add_child(flash)
		_habilidad_flashes.append(flash)
		if _jugador != null and _jugador.arma_actual != null:
			var hab := _jugador.arma_actual.obtener_habilidad(i)
			if hab != null:
				_boton_icono(boton, hab.id, IconStudio.CATEGORIA_HABILIDAD)


## Puntos luminosos del rango actual de una habilidad (máximo 4).
func _crear_pips(boton: Button) -> Array:
	var pips: Array = []
	var ancho := 5.0
	var separacion := 2.0
	var total := 4.0 * ancho + 3.0 * separacion
	var x := (boton.size.x - total) * 0.5
	for i in 4:
		var pip := ColorRect.new()
		pip.color = Color(0.28, 0.24, 0.18)
		pip.position = Vector2(x + i * (ancho + separacion), boton.size.y - 9.0)
		pip.size = Vector2(ancho, 4.0)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boton.add_child(pip)
		pips.append(pip)
	return pips


func _crear_barra_superior() -> void:
	# --- Panel decorativo izquierdo: oleada y tiempo ---
	var panel_oleada := _panel(Vector2(12, 10), Vector2(420, 74), Color(0.06, 0.04, 0.03, 0.95), Color(0.86, 0.68, 0.32))
	_hud_arriba.add_child(panel_oleada)

	_oleada = _texto(panel_oleada, "", Vector2(10, 6), Vector2(400, 24), 20, Color(0.96, 0.82, 0.48))
	_oleada.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_tiempo_oleada = _texto(panel_oleada, "", Vector2(10, 32), Vector2(400, 18), 14, Color(0.9, 0.7, 0.4))
	_tiempo_oleada.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_enemigos = _texto(panel_oleada, "", Vector2(10, 52), Vector2(400, 16), 12, Color(0.82, 0.78, 0.7))
	_enemigos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# --- Panel decorativo derecho: oro y puntos ---
	var panel_economia := _panel(Vector2(440, 10), Vector2(260, 74), Color(0.06, 0.04, 0.03, 0.95), Color(0.86, 0.68, 0.32))
	_hud_arriba.add_child(panel_economia)

	_oro = _texto(panel_economia, "", Vector2(10, 10), Vector2(240, 22), 16, ORO)
	_oro.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var texto_puntos := _texto(panel_economia, "", Vector2(10, 34), Vector2(240, 20), 13, Color(0.82, 0.78, 0.7))
	_texto_puntos = texto_puntos
	_texto_puntos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# --- Barra de vida del estandarte (centro-abajo, independiente) ---
	var marco_estandarte := _panel(Vector2(460, 94), Vector2(360, 26), Color(0.08, 0.07, 0.06, 0.9), Color(0.45, 0.32, 0.2))
	_hud_arriba.add_child(marco_estandarte)
	_barra_bandera = _barra(marco_estandarte, Vector2(2, 2), Vector2(356, 18), Color(0.72, 0.18, 0.14))
	_barra_bandera.show_percentage = false
	var etiqueta := _texto(marco_estandarte, "ESTANDARTE DE LA REBELIÓN", Vector2(0, 2), Vector2(360, 16), 10, TEXTO)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_aviso = _texto(_hud_arriba, "", Vector2(12, 130), Vector2(688, 24), 18, Color(1.0, 0.45, 0.25))
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _crear_overlay() -> void:
	_overlay = _panel(Vector2(1032, 10), Vector2(238, 148), Color(0.07, 0.06, 0.06, 0.92), Color(0.4, 0.32, 0.22))
	_hud_arriba.add_child(_overlay)
	_overlay_titulo = Button.new()
	_overlay_titulo.text = "ESTADÍSTICAS  -"
	_overlay_titulo.position = Vector2(4, 3)
	_overlay_titulo.size = Vector2(230, 24)
	_overlay_titulo.flat = true
	_overlay_titulo.add_theme_font_size_override("font_size", 12)
	_overlay_titulo.add_theme_color_override("font_color", ORO)
	_overlay_titulo.focus_mode = Control.FOCUS_NONE
	_overlay_titulo.pressed.connect(_alternar_overlay)
	_overlay.add_child(_overlay_titulo)

	_overlay_detalle = VBoxContainer.new()
	_overlay_detalle.position = Vector2(12, 28)
	_overlay_detalle.size = Vector2(218, 100)
	_overlay_detalle.add_theme_constant_override("separation", 1)
	_overlay.add_child(_overlay_detalle)
	_overlay_vida = _texto(_overlay_detalle, "", Vector2.ZERO, Vector2(214, 18), 12, TEXTO)
	_overlay_mana = _texto(_overlay_detalle, "", Vector2.ZERO, Vector2(214, 18), 12, TEXTO)
	_overlay_dano = _texto(_overlay_detalle, "", Vector2.ZERO, Vector2(214, 18), 12, TEXTO)
	_overlay_recibido = _texto(_overlay_detalle, "", Vector2.ZERO, Vector2(214, 18), 12, TEXTO)


func _crear_mensajes() -> void:
	_mensaje = _texto(_raiz, "", Vector2(240, 250), Vector2(800, 110), 40, TEXTO)
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mensaje.add_theme_constant_override("outline_size", 12)
	_mensaje.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02))

	_pista = _texto(_raiz, "", Vector2(180, 510), Vector2(920, 20), 12, Color(0.8, 0.76, 0.66))
	_pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _crear_revive() -> void:
	_revive_panel = _panel(
		Vector2(430, 402), Vector2(420, 108),
		Color(0.12, 0.055, 0.045, 0.97), Color(0.92, 0.58, 0.22)
	)
	_raiz.add_child(_revive_panel)
	_revive_panel.visible = false

	_icono_estatico(
		_revive_panel, &"pocion_vida", Vector2(14, 20), Vector2(58, 58),
		IconStudio.CATEGORIA_OBJETO
	)
	_revive_titulo = _texto(
		_revive_panel, "HAS CAÍDO", Vector2(84, 8), Vector2(320, 28),
		22, Color(1.0, 0.62, 0.35)
	)
	_revive_detalle = _texto(
		_revive_panel, "", Vector2(84, 36), Vector2(320, 36),
		12, TEXTO
	)
	_revive_detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_revive_barra = _barra(
		_revive_panel, Vector2(84, 82), Vector2(320, 11),
		Color(0.95, 0.42, 0.22)
	)
	_revive_barra.max_value = Arena.TIEMPO_REVIVIR
	_revive_barra.value = 0.0


func _actualizar_revive() -> void:
	if _revive_panel == null or _jugador == null:
		return
	var mostrar := _jugador.esta_muerto and _jugador.revive_en > 0.0
	_revive_panel.visible = mostrar
	if not mostrar:
		_revive_panel.modulate.a = 1.0
		return
	var restante: float = maxf(0.0, _jugador.revive_en)
	_revive_detalle.text = "Revives en %.1f s\nAcércate a un aliado vivo para acelerar." % restante
	_revive_barra.max_value = Arena.TIEMPO_REVIVIR
	_revive_barra.value = restante
	_revive_panel.modulate.a = 0.84 + 0.16 * sin(Time.get_ticks_msec() * 0.006)


# --- Actualización --------------------------------------------------------

func _process(_delta: float) -> void:
	if _jugador == null:
		return
	_actualizar_ficha()
	_actualizar_estadisticas()
	_actualizar_habilidades()
	_actualizar_inventario()
	_actualizar_overlay()
	_actualizar_superior()
	_actualizar_aviso()
	_actualizar_revive()
	_actualizar_comandos()


func _actualizar_ficha() -> void:
	var salud_max := _jugador.estadisticas.salud_maxima
	_barra_vida.max_value = salud_max
	_barra_vida.value = _jugador.salud_actual
	_barra_mana.max_value = _jugador.estadisticas.mana_maximo
	_barra_mana.value = _jugador.mana_actual
	_vida_texto.text = "VIDA  %d / %d" % [int(round(_jugador.salud_actual)), int(round(salud_max))]
	_mana_texto.text = "MANÁ  %d / %d" % [int(round(_jugador.mana_actual)), int(round(_jugador.estadisticas.mana_maximo))]
	if _jugador.escudo_actual > 0.0:
		_escudo_texto.text = "Escudo  +%d" % int(round(_jugador.escudo_actual))
	else:
		_escudo_texto.text = ""

	var arma := _jugador.arma_actual
	var nombre_clase := "GLADIADOR"
	if arma != null:
		nombre_clase = NOMBRES_CLASE[arma.clase] if arma.clase < NOMBRES_CLASE.size() else "GLADIADOR"
	var nivel := _jugador.estadisticas.nivel
	_clase.text = "%s  ·  Nv %d  ·  Piel: %s" % [nombre_clase, nivel, _nombre_skin()]

	var estados: Array[String] = []
	if _jugador.escudo_actual > 0.0:
		estados.append("Escudo")
	if bool(_jugador.get("mantener_posicion")):
		estados.append("Firme")
	if bool(_jugador.get("modo_ataque_movimiento")):
		estados.append("Ataque-mover")
	if float(_jugador.get("_buff_ataque")) > 0.0:
		estados.append("Furia")
	_estado.text = "Estado: " + (" · ".join(estados) if not estados.is_empty() else "Normal")
	var buffs := [
		_jugador.escudo_actual > 0.0,
		bool(_jugador.get("mantener_posicion")),
		bool(_jugador.get("modo_ataque_movimiento")),
		float(_jugador.get("_buff_ataque")) > 0.0,
	]
	for i in _buff_iconos.size():
		_buff_iconos[i].visible = bool(buffs[i])

	var requerida := _jugador.estadisticas.experiencia_requerida
	var ola := _oleadas.oleada_actual if _oleadas != null else 0
	if requerida <= 0:
		_nivel_texto.text = "XP MÁX  ·  Oleada %d" % ola
		_barra_xp.max_value = 1.0
		_barra_xp.value = 1.0
	else:
		_nivel_texto.text = "XP %d / %d   ·   Oleada %d" % [
			_jugador.estadisticas.experiencia, requerida, ola
		]
		_barra_xp.max_value = float(requerida)
		_barra_xp.value = float(_jugador.estadisticas.experiencia)

	_oro_ficha.text = "ORO %d" % _oro_arena()
	if _contador_atributos != null:
		_contador_atributos.text = str(_puntos_atributo()) if _puntos_atributo() > 0 else ""
	if _contador_talentos != null:
		_contador_talentos.text = str(_jugador.puntos_rojos) if _jugador.puntos_rojos > 0 else ""


func _actualizar_habilidades() -> void:
	var arma := _jugador.arma_actual
	for i in 4:
		var boton := _habilidad_botones[i]
		var cd := _habilidad_cd[i]
		var pips: Array = _habilidad_pips[i]
		boton.text = ""
		boton.tooltip_text = ""
		if arma == null:
			boton.icon = null
			cd.text = ""
			_actualizar_velo(_habilidad_velos[i], 0.0)
			_actualizar_pips(pips, 0, 0, false)
			continue
		var habilidad := arma.obtener_habilidad(i)
		if habilidad == null:
			boton.icon = null
			cd.text = ""
			_actualizar_velo(_habilidad_velos[i], 0.0)
			_actualizar_pips(pips, 0, 0, false)
			continue
		if not _jugador.habilidad_desbloqueada(i):
			var nivel_libre := _jugador.nivel_desbloqueo_habilidad(i)
			_boton_icono(boton, habilidad.id, IconStudio.CATEGORIA_HABILIDAD)
			boton.modulate = Color(0.48, 0.46, 0.44, 1.0)
			boton.disabled = true
			cd.text = "Nv %d" % nivel_libre
			_actualizar_velo(_habilidad_velos[i], 0.55)
			_actualizar_pips(pips, 0, 0, false)
			continue
		boton.modulate = Color.WHITE
		_boton_icono(boton, habilidad.id, IconStudio.CATEGORIA_HABILIDAD)
		var restante := _jugador.cooldown_restante(i)
		var rango := _jugador.rango_habilidad(habilidad.id)
		cd.text = ("%ds" % int(ceil(restante))) if restante > 0.0 else ""
		_actualizar_velo(_habilidad_velos[i], restante / maxf(0.01, _jugador.cooldown_habilidad(habilidad)))
		_actualizar_pips(pips, rango, max(1, habilidad.rango_maximo), true)
		if _cd_antes[i] > 0.0 and restante <= 0.0:
			_destello_habilidad(i)
		_cd_antes[i] = restante
		boton.disabled = restante > 0.0 or _jugador.mana_actual < habilidad.coste_mana


func _actualizar_pips(pips: Array, rango: int, maximo: int, visible: bool) -> void:
	for j in pips.size():
		var pip := pips[j] as ColorRect
		pip.visible = visible and j < maximo
		if pip.visible:
			pip.color = ORO if j < rango else Color(0.28, 0.24, 0.18)


func _actualizar_inventario() -> void:
	var inventario := _jugador.inventario
	for i in _inventario_botones.size():
		var boton := _inventario_botones[i]
		var cantidad_texto := _inventario_cantidad[i]
		boton.tooltip_text = ""
		if inventario == null:
			boton.icon = null
			cantidad_texto.text = ""
			continue
		var ranura: Dictionary = inventario.ranuras[i]
		var item: ItemData = ranura["item"]
		if item == null:
			boton.icon = null
			boton.disabled = true
			cantidad_texto.text = ""
			_actualizar_velo(_inventario_velos[i], 0.0)
			continue
		_boton_icono(boton, item.id, IconStudio.CATEGORIA_OBJETO)
		var restante := inventario.energia_restante(i)
		var cantidad := int(ranura["cantidad"])
		var cd_max := 8.0
		if item.habilidad != null:
			cd_max = maxf(0.1, item.habilidad.cooldown)
		_actualizar_velo(_inventario_velos[i], restante / cd_max)
		if restante > 0.0:
			cantidad_texto.text = "%ds" % int(ceil(restante))
		elif cantidad > 1:
			cantidad_texto.text = "x%d" % cantidad
		else:
			cantidad_texto.text = ""
		boton.disabled = restante > 0.0

		# Borde dorado si está seleccionada para swap
		if _ranura_seleccionada_swap == i:
			var borde := StyleBoxFlat.new()
			borde.bg_color = Color(0.0, 0.0, 0.0, 0.0)
			borde.border_color = _color_borde_seleccionado
			borde.set_border_width_all(3)
			borde.set_corner_radius_all(4)
			boton.add_theme_stylebox_override("focus", borde)
		else:
			boton.remove_theme_stylebox_override("focus")


func _evento_raton_inventario(indice: int, boton: Button, evento: InputEvent) -> void:
	if evento is InputEventMouseButton:
		var clic := evento as InputEventMouseButton
		if clic.button_index == MOUSE_BUTTON_RIGHT and clic.pressed:
			if _ranura_seleccionada_swap == indice:
				# Deseleccionar
				_ranura_seleccionada_swap = -1
				_actualizar_inventario()
			elif _ranura_seleccionada_swap >= 0:
				# Swap entre las dos ranuras
				if _jugador != null and _jugador.inventario != null:
					_jugador.inventario.intercambiar(_ranura_seleccionada_swap, indice)
				_ranura_seleccionada_swap = -1
				_actualizar_inventario()
			else:
				# Seleccionar esta ranura para swap
				_ranura_seleccionada_swap = indice
				_actualizar_inventario()


func _limpiar_seleccion_swap() -> void:
	_ranura_seleccionada_swap = -1


func _actualizar_overlay() -> void:
	var salud_max := maxf(1.0, _jugador.estadisticas.salud_maxima)
	var mana_max := maxf(1.0, _jugador.estadisticas.mana_maximo)
	_overlay_vida.text = "Vida      %d %%" % int(round(_jugador.salud_actual / salud_max * 100.0))
	_overlay_mana.text = "Maná      %d %%" % int(round(_jugador.mana_actual / mana_max * 100.0))
	_overlay_dano.text = "Infligido %d" % int(round(_jugador.dano_infligido))
	_overlay_recibido.text = "Recibido  %d" % int(round(_jugador.dano_recibido))


func _actualizar_superior() -> void:
	if _oleadas != null:
		_oleada.text = "OLEADA %d / 20" % _oleadas.oleada_actual
		_enemigos.text = "%d enemigos en la arena   ·   %d restantes" % [
			_contar_enemigos(), _oleadas.enemigos_restantes()
		]
		var tiempo := _oleadas.tiempo_restante()
		if tiempo > 0.0:
			_tiempo_oleada.text = "Tiempo: %d s" % int(ceil(tiempo))
		else:
			_tiempo_oleada.text = ""
	_oro.text = "ORO %d" % _oro_arena()
	_texto_puntos.text = "PUNTOS %d" % _puntos_atributo()
	if _bandera != null:
		_barra_bandera.max_value = maxf(1.0, _bandera.salud_maxima)
		_barra_bandera.value = _bandera.salud_actual


func _actualizar_aviso() -> void:
	if _arena != null and _arena.has_method("esta_congelado") and _arena.esta_congelado():
		_aviso.text = "¡EL PÚBLICO ABUCHEA! Muévete para romper la furia"
	else:
		_aviso.text = ""


func _actualizar_estadisticas() -> void:
	if _jugador == null:
		return
	var e := _jugador.estadisticas
	var arma := _jugador.arma_actual
	var dano_min := 0
	var dano_max := 0
	if arma != null:
		var rango := e.rango_dano_ataque(arma.dano_ataque_base, arma.atributo_principal)
		dano_min = int(rango.x)
		dano_max = int(rango.y)
	var aps := maxf(0.01, e.velocidad_ataque)
	_stats.text = "Daño        %d-%d\nArmadura    %d (%.1f%% red.)\nVel. ataque %.2f golpes/s (%.2f s)\nCrítico     %d %%" % [
		dano_min, dano_max, int(round(e.armadura_total)), e.mitigacion_fisica * 100.0,
		aps, 1.0 / aps, int(round(e.probabilidad_critico * 100.0))
	]

	var principal := _atributo_principal()
	var claves := [&"fuerza", &"agilidad", &"inteligencia"]
	var nombres := ["FUE", "AGI", "INT"]
	var totales := [e.fuerza_total, e.agilidad_total, e.inteligencia_total]
	var bases := [e.fuerza, e.agilidad, e.inteligencia]
	for i in 3:
		var es_principal: bool = claves[i] == principal
		var color := ORO if es_principal else TEXTO
		# U+25C6 no existe en la fuente por defecto (sale como caja tofu): usamos un punto.
		_atributos_nombres[i].text = ("• " + nombres[i]) if es_principal else nombres[i]
		_atributos_nombres[i].add_theme_color_override("font_color", color)
		var bono := int(totales[i]) - int(bases[i])
		_atributos_valores[i].text = "%d%s" % [
			int(totales[i]), (" (+%d)" % bono) if bono > 0 else ""
		]
		_atributos_valores[i].add_theme_color_override("font_color", color)


func _actualizar_pista() -> void:
	if _arena == null or _jugador == null:
		return
	if _arena.has_method("pista_actual"):
		_pista.text = _arena.pista_actual()


# --- API usada por Arena --------------------------------------------------

func mostrar_mensaje(texto: String, duracion := 2.5) -> void:
	_mensaje.text = texto
	_mensaje.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(duracion)
	tween.tween_property(_mensaje, "modulate:a", 0.0, 0.6)


func mostrar_final(texto: String) -> void:
	_mensaje.text = texto
	_mensaje.modulate.a = 1.0
	_mensaje.add_theme_font_size_override("font_size", 32)


func establecer_pista(texto: String) -> void:
	_pista.text = texto


func alternar_talentos() -> void:
	if _tienda != null:
		_tienda.cerrar_panel()
	_talentos.alternar()


func cerrar_talentos() -> void:
	_talentos.cerrar_panel()


func alternar_tienda() -> void:
	if _talentos != null:
		_talentos.cerrar_panel()
	_tienda.alternar()


func cerrar_tienda() -> void:
	_tienda.cerrar_panel()
	forzar_ocultar_tooltip()
	_limpiar_seleccion_swap()


func tienda_abierta() -> bool:
	return _tienda != null and _tienda.visible


# --- Acciones -------------------------------------------------------------

func _usar_ranura(indice: int) -> void:
	if _jugador != null:
		_jugador.usar_objeto(indice)


func _lanzar_habilidad(slot: int) -> void:
	if _jugador != null:
		_jugador.intentar_habilidad(slot)


func _alternar_overlay() -> void:
	_overlay_expandido = not _overlay_expandido
	_overlay_detalle.visible = _overlay_expandido
	_overlay.size = Vector2(238, 148 if _overlay_expandido else 30)
	_overlay_titulo.text = "ESTADÍSTICAS  %s" % ("-" if _overlay_expandido else "+")


# --- Utilidades -----------------------------------------------------------

func _tooltip_habilidad(habilidad: AbilityData, slot: int) -> String:
	var lineas: PackedStringArray = []
	lineas.append("%s  [%s]" % [habilidad.nombre, ["Q", "W", "E", "R"][slot]])
	lineas.append(habilidad.descripcion)
	if habilidad.dano_base > 0.0:
		var tipo := "físico" if habilidad.tipo_dano == GladiatorStats.TIPO_FISICO else "mágico"
		var real := int(round(_jugador.estadisticas.escalar_dano(habilidad.dano_base, habilidad.tipo_dano)))
		lineas.append("Daño: %d base  ·  ≈ %d con tus atributos (%s)" % [int(habilidad.dano_base), real, tipo])
	if habilidad.curacion_base > 0.0:
		lineas.append("Curación base: %d" % int(habilidad.curacion_base))
	lineas.append("Maná: %d   ·   Enfriamiento: %.0f s" % [int(habilidad.coste_mana), habilidad.cooldown])
	if habilidad.duracion > 0.0:
		lineas.append("Duración: %.1f s" % habilidad.duracion)
	if not habilidad.talentos.is_empty():
		lineas.append("Talentos: %d ranuras (T)" % habilidad.talentos.size())
	return "\n".join(lineas)


func _tooltip_item(item: ItemData) -> String:
	var lineas: PackedStringArray = []
	lineas.append(item.nombre)
	lineas.append(item.descripcion)
	var bonos := item.descripcion_bonos()
	if not bonos.is_empty():
		lineas.append(bonos)
	if item.habilidad != null:
		lineas.append("ACTIVO: %s · %d maná · %.0f s" % [
			item.habilidad.nombre, int(item.habilidad.coste_mana), item.habilidad.cooldown
		])
	if not item.receta.is_empty():
		var nombres: PackedStringArray = []
		for ingrediente in item.receta:
			var otro := ItemCatalog.obtener(ingrediente)
			nombres.append(otro.nombre if otro != null else String(ingrediente))
		lineas.append("Forja: %s + %d oro" % [" + ".join(nombres), item.precio_forja])
	return "\n".join(lineas)


func _nombre_skin() -> String:
	if _arena != null and _arena.has_method("nombre_skin"):
		return _arena.nombre_skin()
	return "Tierra Baldía"


func _oro_arena() -> int:
	if _arena != null:
		var valor = _arena.get("oro")
		if valor != null:
			return int(valor)
	return 0


func _puntos_atributo() -> int:
	if _arena != null:
		var valor = _arena.get("puntos_atributo")
		if valor != null:
			return int(valor)
	return 0


func _contar_enemigos() -> int:
	return get_tree().get_nodes_in_group("enemigos").size()


func _cd(segundos: float) -> String:
	if segundos <= 0.0:
		return "listo"
	if segundos < 10.0:
		return "%.1f s" % segundos
	return "%d s" % int(round(segundos))


## Velo de enfriamiento: rectángulo semitransparente que baja con el tiempo.
func _velo(boton: Button, tam: Vector2) -> ColorRect:
	var velo := ColorRect.new()
	velo.color = Color(0.0, 0.0, 0.0, 0.55)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.position = Vector2.ZERO
	velo.size = tam
	velo.visible = false
	boton.add_child(velo)
	return velo


func _actualizar_velo(velo: ColorRect, fraccion: float) -> void:
	if velo == null:
		return
	var alto := (velo.get_parent() as Control).size.y
	var f := clampf(fraccion, 0.0, 1.0)
	velo.visible = f > 0.01
	velo.size = Vector2(velo.size.x, alto * f)
	velo.position = Vector2(0.0, alto - velo.size.y)


# --- Constructores visuales ----------------------------------------------

func _panel(pos: Vector2, tam: Vector2, color: Color, borde: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = tam
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = borde
	estilo.set_border_width_all(2)
	estilo.corner_radius_top_left = 4
	estilo.corner_radius_top_right = 4
	estilo.corner_radius_bottom_left = 4
	estilo.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", estilo)
	return panel


func _texto(
	padre: Node,
	texto: String,
	pos: Vector2,
	tam: Vector2,
	fuente: int,
	color: Color
) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.position = pos
	etiqueta.size = tam
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_size_override("font_size", fuente)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_constant_override("outline_size", 4)
	etiqueta.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.8))
	padre.add_child(etiqueta)
	return etiqueta


func _barra(padre: Node, pos: Vector2, tam: Vector2, color: Color) -> ProgressBar:
	var barra := ProgressBar.new()
	barra.position = pos
	barra.size = tam
	barra.show_percentage = false
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.05, 0.04, 0.04, 0.9)
	fondo.corner_radius_top_left = 3
	fondo.corner_radius_top_right = 3
	fondo.corner_radius_bottom_left = 3
	fondo.corner_radius_bottom_right = 3
	barra.add_theme_stylebox_override("background", fondo)
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = color
	relleno.corner_radius_top_left = 3
	relleno.corner_radius_top_right = 3
	relleno.corner_radius_bottom_left = 3
	relleno.corner_radius_bottom_right = 3
	barra.add_theme_stylebox_override("fill", relleno)
	padre.add_child(barra)
	return barra


func _boton(pos: Vector2, tam: Vector2, texto: String) -> Button:
	var boton := Button.new()
	boton.position = pos
	boton.size = tam
	boton.text = texto
	boton.focus_mode = Control.FOCUS_NONE
	boton.add_theme_font_size_override("font_size", 12)
	boton.add_theme_color_override("font_color", TEXTO)
	boton.add_theme_color_override("font_disabled_color", Color(0.55, 0.5, 0.44))
	_aplicar_estilo_boton(boton, false)
	return boton


func _aplicar_estilo_boton(boton: Button, activo: bool) -> void:
	if boton == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.20, 0.14, 0.06) if activo else Color(0.12, 0.10, 0.09)
	normal.border_color = ORO if activo else Color(0.42, 0.31, 0.18)
	normal.set_border_width_all(2)
	normal.corner_radius_top_left = 5
	normal.corner_radius_top_right = 5
	normal.corner_radius_bottom_left = 5
	normal.corner_radius_bottom_right = 5
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 3
	normal.shadow_offset = Vector2(0, 1)
	boton.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.26, 0.20, 0.11)
	hover.border_color = ORO
	hover.shadow_size = 5
	boton.add_theme_stylebox_override("hover", hover)

	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.32, 0.24, 0.12)
	boton.add_theme_stylebox_override("pressed", pressed)


func _insignia(boton: Control, texto: String, pos: Vector2, ancho: float) -> void:
	var placa := Panel.new()
	placa.position = pos
	placa.size = Vector2(ancho, 14)
	placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.035, 0.03, 0.025, 0.94)
	estilo.border_color = Color(0.62, 0.47, 0.24)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(3)
	placa.add_theme_stylebox_override("panel", estilo)
	boton.add_child(placa)
	var etiqueta := _texto(placa, texto, Vector2.ZERO, Vector2(ancho, 14), 9, ORO)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- Iconos y comandos ----------------------------------------------------

func _atributo_principal() -> StringName:
	if _jugador == null or _jugador.arma_actual == null:
		return &"fuerza"
	match _jugador.arma_actual.clase:
		WeaponItem.Clase.FILO:
			return &"agilidad"
		WeaponItem.Clase.CETRO:
			return &"inteligencia"
		_:
			return &"fuerza"


func _boton_icono(boton: Button, id: StringName, categoria: StringName) -> void:
	if boton == null or id == &"":
		return
	if boton.get_meta("icono_id", &"") == id:
		return
	boton.set_meta("icono_id", id)
	boton.text = ""
	boton.icon = IconStudio.obtener(id, categoria)
	boton.expand_icon = true
	boton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boton.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	IconStudio.escuchar(id, Callable(self, "_icono_listo").bind(id))


func _icono_listo(textura: Texture2D, id: StringName) -> void:
	for lista in [_comando_botones, _habilidad_botones, _inventario_botones]:
		for boton in lista:
			if is_instance_valid(boton) and boton.get_meta("icono_id", &"") == id:
				boton.icon = textura
	for rect in [_icono_dano, _icono_armadura]:
		if is_instance_valid(rect) and rect.get_meta("icono_id", &"") == id:
			rect.texture = textura


func _icono_estatico(
	padre: Node,
	id: StringName,
	pos: Vector2,
	tam: Vector2,
	categoria: StringName = IconStudio.CATEGORIA_COMANDO
) -> TextureRect:
	var rect := TextureRect.new()
	rect.position = pos
	rect.size = tam
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.set_meta("icono_id", id)
	rect.set_meta("icono_categoria", categoria)
	rect.texture = IconStudio.obtener(id, categoria)
	padre.add_child(rect)
	IconStudio.escuchar(id, Callable(self, "_icono_listo").bind(id))
	return rect


func _actualizar_iconos_habilidades() -> void:
	if _jugador == null or _jugador.arma_actual == null:
		return
	for i in min(4, _habilidad_botones.size()):
		var habilidad := _jugador.arma_actual.obtener_habilidad(i)
		if habilidad != null:
			_boton_icono(_habilidad_botones[i], habilidad.id, IconStudio.CATEGORIA_HABILIDAD)


func _al_cambiar_arma_hud(_arma: WeaponItem = null) -> void:
	_actualizar_iconos_habilidades()


func _comando_atacar() -> void:
	if _jugador != null:
		_jugador.alternar_modo_ataque()


func _comando_detener() -> void:
	if _jugador != null:
		_jugador.detener()


func _comando_mantener() -> void:
	if _jugador != null:
		_jugador.alternar_mantener_posicion()


func _comando_skin() -> void:
	if _arena != null and _arena.has_method("_ciclar_skin"):
		_arena.call("_ciclar_skin")


func _comando_atributos() -> void:
	if _jugador == null:
		return
	if _jugador.estadisticas.gastar_punto(_atributo_principal()):
		mostrar_mensaje("+1 %s" % String(_atributo_principal()).to_upper(), 1.2)
		Sfx.reproducir(&"click", -10.0)
	else:
		mostrar_mensaje("No quedan puntos de atributo", 1.2)


func _comando_talentos() -> void:
	alternar_talentos()


func _comando_tienda() -> void:
	alternar_tienda()


func _comando_estadisticas() -> void:
	_alternar_overlay()


# --- Tooltips ricos -------------------------------------------------------

func mostrar_tooltip_item(item: ItemData, subtitulo := "") -> void:
	if _tooltip == null or item == null:
		return
	var sub := subtitulo
	if sub.is_empty():
		sub = "%s  ·  %d oro" % [_tipo_item(item), item.precio]
	_tooltip.mostrar(
		item.nombre,
		sub,
		_bbcode_item(item),
		item.id,
		IconStudio.CATEGORIA_OBJETO,
		_rareza_color(item)
	)


func _ocultar_tooltip() -> void:
	if _tooltip != null:
		_tooltip.ocultar()

## API pública para paneles externos (tienda): oculta el tooltip sin forzarlo.
func ocultar_tooltip() -> void:
	_ocultar_tooltip()

func forzar_ocultar_tooltip() -> void:
	if _tooltip != null:
		_tooltip.forzar_ocultar()


func _mostrar_tooltip_comando(indice: int) -> void:
	if _tooltip == null or _jugador == null or indice >= _comandos_datos.size():
		return
	var datos: Array = _comandos_datos[indice]
	var id := str(datos[0])
	var lineas: PackedStringArray = []
	lineas.append(str(datos[2]))
	var estado := _estado_comando(id)
	if not estado.is_empty():
		lineas.append("")
		lineas.append("[color=#d8b45a]Estado[/color]  %s" % estado)
	var acento := ORO
	if id == "atributos":
		acento = Color(0.55, 0.95, 0.62)
	elif id == "talentos":
		acento = Color(1.0, 0.52, 0.38)
	elif id == "tienda":
		acento = Color(0.95, 0.78, 0.38)
	_tooltip.mostrar(
		_nombre_comando(id),
		"Tecla %s" % datos[1],
		"\n".join(lineas),
		StringName(id),
		IconStudio.CATEGORIA_COMANDO,
		acento
	)


func _mostrar_tooltip_habilidad(indice: int) -> void:
	if _tooltip == null or _jugador == null or _jugador.arma_actual == null:
		return
	var habilidad := _jugador.arma_actual.obtener_habilidad(indice)
	if habilidad == null:
		return
	var tecla: String = ["Q", "W", "E", "R"][indice]
	if not _jugador.habilidad_desbloqueada(indice):
		var nivel := _jugador.nivel_desbloqueo_habilidad(indice)
		_tooltip.mostrar(
			habilidad.nombre,
			"%s  ·  Bloqueada" % tecla,
			"%s\n\n[color=#c8c0ae]Se desbloquea al nivel %d.[/color]" % [habilidad.descripcion, nivel],
			habilidad.id,
			IconStudio.CATEGORIA_HABILIDAD,
			Color(0.58, 0.55, 0.5)
		)
		return
	var rango := _jugador.rango_habilidad(habilidad.id)
	var maximo := int(max(1, habilidad.rango_maximo))
	var acento := ORO
	match _jugador.arma_actual.clase:
		WeaponItem.Clase.FILO:
			acento = Color(0.38, 0.88, 0.96)
		WeaponItem.Clase.CETRO:
			acento = Color(0.75, 0.50, 1.0)
	_tooltip.mostrar(
		habilidad.nombre,
		"%s  ·  Rango %d/%d" % [tecla, rango, maximo],
		_bbcode_habilidad(habilidad, rango, maximo),
		habilidad.id,
		IconStudio.CATEGORIA_HABILIDAD,
		acento
	)


func _mostrar_tooltip_inventario(indice: int) -> void:
	if _tooltip == null or _jugador == null or _jugador.inventario == null:
		return
	var tecla: String = ["Z", "X", "C", "V", "B", "N"][indice]
	var ranura: Dictionary = _jugador.inventario.ranuras[indice]
	var item: ItemData = ranura.get("item")
	if item == null:
		_tooltip.mostrar(
			"Ranura vacía",
			"Tecla %s" % tecla,
			"Compra pociones, pergaminos y componentes en el [color=#d8b45a]Mercader de la Rebelión[/color] (F).",
			&"",
			IconStudio.CATEGORIA_OBJETO,
			BRONCE
		)
		return
	mostrar_tooltip_item(item, "Ranura %s  ·  x%d" % [tecla, int(ranura.get("cantidad", 1))])


func _actualizar_comandos() -> void:
	if _jugador == null or _comando_botones.size() < 3:
		return
	var estados := [
		bool(_jugador.get("_modo_ataque_armado")),
		false,
		bool(_jugador.get("mantener_posicion")),
	]
	for i in 3:
		if estados[i] == _comando_activo[i]:
			continue
		_comando_activo[i] = estados[i]
		_aplicar_estilo_boton(_comando_botones[i], estados[i])


func _destello_habilidad(indice: int) -> void:
	if indice < 0 or indice >= _habilidad_flashes.size():
		return
	var flash := _habilidad_flashes[indice]
	flash.color.a = 0.55
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(flash, "color:a", 0.0, 0.5)


func _nombre_comando(id: String) -> String:
	match id:
		"atacar": return "Atacar-mover"
		"detener": return "Detener"
		"mantener": return "Mantener posición"
		"skin": return "Cambiar piel"
		"atributos": return "Subir atributo"
		"talentos": return "Talentos"
		"tienda": return "Mercader"
		"estadisticas": return "Estadísticas"
	return id.capitalize()


func _estado_comando(id: String) -> String:
	match id:
		"atacar":
			return "ARMADO" if bool(_jugador.get("_modo_ataque_armado")) else "inactivo"
		"mantener":
			return "ACTIVO" if bool(_jugador.get("mantener_posicion")) else "inactivo"
		"skin":
			return "Piel: %s" % _nombre_skin()
		"atributos":
			return "Puntos: %d  ·  Principal: %s" % [_puntos_atributo(), _nombre_atributo(_atributo_principal())]
		"talentos":
			return "Puntos rojos: %d" % _jugador.puntos_rojos
		"tienda":
			return "Oro: %d" % _oro_arena()
		"estadisticas":
			return "Infligido %d  ·  Recibido %d" % [int(_jugador.dano_infligido), int(_jugador.dano_recibido)]
	return ""


func _nombre_atributo(atributo: StringName) -> String:
	match atributo:
		&"agilidad": return "AGI"
		&"inteligencia": return "INT"
	return "FUE"


func _bbcode_habilidad(habilidad: AbilityData, rango: int, maximo: int) -> String:
	var lineas: PackedStringArray = []
	lineas.append(habilidad.descripcion)
	lineas.append("")
	if habilidad.dano_base > 0.0:
		var real := int(round(_jugador.estadisticas.escalar_dano(habilidad.dano_base, habilidad.tipo_dano)))
		var tipo := "físico" if habilidad.tipo_dano == GladiatorStats.TIPO_FISICO else "mágico"
		lineas.append("[color=#d8b45a]Daño[/color]  %d base  ·  [color=#7dff9a]%d[/color] con tus atributos (%s)" % [
			int(habilidad.dano_base), real, tipo
		])
	if habilidad.curacion_base > 0.0:
		lineas.append("[color=#d8b45a]Curación[/color]  %d base" % int(habilidad.curacion_base))
	lineas.append("[color=#d8b45a]Maná[/color]  %d  ·  [color=#d8b45a]Recarga[/color]  %.1f s" % [
		int(habilidad.coste_mana), _jugador.cooldown_habilidad(habilidad)
	])
	if habilidad.radio > 0.0:
		lineas.append("[color=#d8b45a]Radio[/color]  %.1f m" % _jugador.radio_habilidad(habilidad))
	if habilidad.duracion > 0.0:
		lineas.append("[color=#d8b45a]Duración[/color]  %.1f s" % _jugador.duracion_habilidad(habilidad))
	lineas.append("[color=#d8b45a]Rango[/color]  %d/%d" % [rango, maximo])
	var siguiente := habilidad.descripcion_siguiente_rango(rango)
	if not siguiente.is_empty() and rango < maximo:
		lineas.append("[color=#7dff9a]Siguiente rango:[/color] %s" % siguiente)
	if not habilidad.talentos.is_empty():
		lineas.append("[color=#c792ff]Talentos:[/color] %d ranuras (T)" % habilidad.talentos.size())
	return "\n".join(lineas)


func _bbcode_item(item: ItemData) -> String:
	var lineas: PackedStringArray = []
	lineas.append(item.descripcion)
	var bonos := item.descripcion_bonos()
	if not bonos.is_empty():
		lineas.append("")
		for linea in bonos.split("\n"):
			lineas.append("[color=#7dff9a]%s[/color]" % linea)
	if item.habilidad != null:
		lineas.append("")
		lineas.append("[color=#d8b45a]ACTIVO[/color]  %s  ·  %d maná  ·  %.0f s" % [
			item.habilidad.nombre, int(item.habilidad.coste_mana), item.habilidad.cooldown
		])
	if not item.receta.is_empty():
		lineas.append("")
		lineas.append("[color=#d8b45a]RECETA[/color]")
		for ingrediente in item.receta:
			var otro := ItemCatalog.obtener(ingrediente)
			var nombre := otro.nombre if otro != null else String(ingrediente)
			var tiene := _jugador != null and _jugador.inventario != null and _jugador.inventario.tiene(ingrediente)
			lineas.append(("%s %s" % ["[color=#7dff9a]•[/color]" if tiene else "[color=#ff8a6a]×[/color]", nombre]))
		lineas.append("[color=#d8b45a]Forja[/color]  %d oro" % item.precio_forja)
	else:
		lineas.append("")
		lineas.append("[color=#d8b45a]Precio[/color]  %d oro" % item.precio)
	return "\n".join(lineas)


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
