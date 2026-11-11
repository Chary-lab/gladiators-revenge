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
var _barra_bandera: ProgressBar

var _barra_vida: ProgressBar
var _barra_mana: ProgressBar
var _vida_texto: Label
var _mana_texto: Label
var _escudo_texto: Label
var _clase: Label
var _skin: Label
var _nivel_texto: Label
var _barra_xp: ProgressBar
var _stats: RichTextLabel
var _atributos: Label
var _economia: Label
var _icono_dano: TextureRect
var _icono_armadura: TextureRect
var _habilidad_etiquetas: Array[Label] = []
var _habilidad_botones: Array[Button] = []
var _habilidad_velos: Array[ColorRect] = []
var _habilidad_cd: Array[Label] = []
var _inventario_botones: Array[Button] = []
var _inventario_velos: Array[ColorRect] = []
var _inventario_cantidad: Array[Label] = []
var _comando_botones: Array[Button] = []
var _contador_atributos: Label
var _contador_talentos: Label
var _retrato: GladiatorPortrait
var _emblema: Label
var _emblema_icono: TextureRect
var _estado: Label
var _minimapa: ArenaMinimap
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
	_tienda.configurar(_jugador, _arena)
	if _oleadas != null:
		_oleadas.mensaje.connect(mostrar_mensaje)
	if _jugador != null and not _jugador.nivel_alcanzado.is_connected(_al_subir_nivel):
		_jugador.nivel_alcanzado.connect(_al_subir_nivel)


func _al_subir_nivel(nivel: int) -> void:
	var extra := "+1 atributo"
	if nivel >= 4 and nivel <= 14:
		extra += "  ·  +1 punto de habilidad"
	mostrar_mensaje("¡NIVEL %d!\n%s" % [nivel, extra], 2.2)
	Sfx.reproducir(&"victoria", -10.0)


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
	_crear_stats()
	_crear_inventario()
	_crear_habilidades()
	_crear_minimapa()
	_crear_barra_superior()
	_crear_overlay()
	_crear_mensajes()


func _crear_minimapa() -> void:
	_minimapa = ArenaMinimap.new()
	_minimapa.position = Vector2(12, 10)
	_minimapa.size = Vector2(146, 112)
	_minimapa.set_jugador(_jugador)
	_minimapa.set_bandera(_bandera)
	_hud_arriba.add_child(_minimapa)


func _crear_retrato() -> void:
	var fondo := _panel(Vector2(8, 543), Vector2(160, 167), HIERRO, Color(0.40, 0.33, 0.23))
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
	var fondo := _panel(Vector2(176, 545), Vector2(300, 164), HIERRO, Color(0.36, 0.30, 0.22))
	_raiz.add_child(fondo)

	_clase = _texto(fondo, "GLADIADOR ORCO", Vector2(10, 3), Vector2(280, 20), 16, ORO)
	_clase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skin = _texto(fondo, "Tierra Baldía", Vector2(10, 21), Vector2(280, 14), 10, Color(0.78, 0.74, 0.66))
	_skin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nivel_texto = _texto(fondo, "Nv 1   XP 0 / 126", Vector2(10, 35), Vector2(280, 14), 10, Color(0.82, 0.70, 1.0))
	_nivel_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_barra_xp = _barra(fondo, Vector2(10, 51), Vector2(280, 5), Color(0.62, 0.35, 0.92))

	_emblema_icono = _icono_estatico(
		fondo, _id_emblema(), Vector2(12, 56), Vector2(50, 50), IconStudio.CATEGORIA_HABILIDAD
	)
	_emblema = _texto(fondo, "", Vector2(68, 62), Vector2(224, 44), 28, ORO)
	_emblema.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_emblema.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_estado = _texto(fondo, "", Vector2(8, 107), Vector2(284, 17), 10, TEXTO)
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_escudo_texto = _texto(fondo, "", Vector2(8, 123), Vector2(284, 12), 9, Color(0.55, 0.78, 1.0))
	_escudo_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_economia = _texto(fondo, "", Vector2(8, 136), Vector2(284, 26), 9, TEXTO)
	_economia.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_economia.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _crear_stats() -> void:
	var fondo := _panel(Vector2(482, 545), Vector2(260, 164), HIERRO, Color(0.36, 0.30, 0.22))
	_raiz.add_child(fondo)
	var titulo := _texto(fondo, "ATRIBUTOS", Vector2(10, 5), Vector2(240, 18), 13, ORO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icono_dano = _icono_estatico(fondo, &"atacar", Vector2(6, 26), Vector2(30, 30))
	_icono_armadura = _icono_estatico(fondo, &"mantener", Vector2(6, 41), Vector2(28, 28))
	_stats = RichTextLabel.new()
	_stats.position = Vector2(40, 24)
	_stats.size = Vector2(212, 68)
	_stats.bbcode_enabled = true
	_stats.scroll_active = false
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.add_theme_font_size_override("normal_font_size", 11)
	_stats.add_theme_color_override("default_color", TEXTO)
	fondo.add_child(_stats)
	_atributos = _texto(fondo, "", Vector2(10, 94), Vector2(240, 64), 11, TEXTO)


func _crear_inventario() -> void:
	var titulo := _texto(_raiz, "INVENTARIO", Vector2(750, 543), Vector2(188, 15), 11, ORO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in InventoryComponent.RANURAS:
		var columna := i % 2
		var fila := i / 2
		var pos := Vector2(750 + columna * 96, 560 + fila * 48)
		var boton := _boton(pos, Vector2(92, 44), "")
		boton.pressed.connect(_usar_ranura.bind(i))
		_raiz.add_child(boton)
		_inventario_botones.append(boton)
		_inventario_velos.append(_velo(boton, Vector2(92, 44)))
		var tecla := _texto(boton, ["Z", "X", "C", "V", "B", "N"][i], Vector2(3, 0), Vector2(20, 14), 9, ORO)
		tecla.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cantidad := _texto(boton, "", Vector2(56, 27), Vector2(24, 15), 10, TEXTO)
		cantidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cantidad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inventario_cantidad.append(cantidad)


func _crear_habilidades() -> void:
	var titulo := _texto(_raiz, "COMANDOS", Vector2(966, 543), Vector2(296, 15), 11, ORO)
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
	for i in comandos.size():
		var columna := i % 4
		var fila := i / 4
		var datos: Array = comandos[i]
		var boton := _boton(Vector2(966 + columna * 76, 558 + fila * 54), Vector2(68, 50), "")
		boton.tooltip_text = datos[2]
		boton.pressed.connect(datos[3])
		_boton_icono(boton, datos[0], IconStudio.CATEGORIA_COMANDO)
		_raiz.add_child(boton)
		_comando_botones.append(boton)
		var tecla := _texto(boton, datos[1], Vector2(3, 32), Vector2(63, 14), 9, ORO)
		tecla.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tecla.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if datos[0] == "atributos":
			_contador_atributos = _texto(boton, "", Vector2(43, 2), Vector2(22, 13), 9, Color(0.55, 1.0, 0.55))
			_contador_atributos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		elif datos[0] == "talentos":
			_contador_talentos = _texto(boton, "", Vector2(43, 2), Vector2(22, 13), 9, Color(1.0, 0.45, 0.35))
			_contador_talentos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	for i in 4:
		var boton := _boton(Vector2(966 + i * 76, 666), Vector2(68, 50), "")
		boton.pressed.connect(_lanzar_habilidad.bind(i))
		boton.add_theme_font_size_override("font_size", 10)
		_raiz.add_child(boton)
		_habilidad_botones.append(boton)
		_habilidad_velos.append(_velo(boton, Vector2(68, 50)))
		var tecla := _texto(boton, ["Q", "W", "E", "R"][i], Vector2(3, 1), Vector2(18, 14), 10, ORO)
		tecla.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cd := _texto(boton, "", Vector2(0, 18), Vector2(68, 14), 10, Color(1.0, 0.86, 0.55))
		cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_habilidad_cd.append(cd)
		if _jugador != null and _jugador.arma_actual != null:
			var hab := _jugador.arma_actual.obtener_habilidad(i)
			if hab != null:
				_boton_icono(boton, hab.id, IconStudio.CATEGORIA_HABILIDAD)


func _crear_barra_superior() -> void:
	_oleada = _texto(_hud_arriba, "", Vector2(430, 12), Vector2(420, 26), 22, ORO)
	_oleada.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemigos = _texto(_hud_arriba, "", Vector2(430, 38), Vector2(420, 18), 13, TEXTO)
	_enemigos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_oro = _texto(_hud_arriba, "", Vector2(640, 12), Vector2(280, 22), 16, ORO)
	_oro.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var marco := _panel(Vector2(455, 62), Vector2(370, 24), Color(0.08, 0.07, 0.06, 0.9), Color(0.45, 0.32, 0.2))
	_hud_arriba.add_child(marco)
	_barra_bandera = _barra(marco, Vector2(2, 2), Vector2(366, 20), Color(0.72, 0.18, 0.14))
	_barra_bandera.show_percentage = false
	var etiqueta := _texto(marco, "ESTANDARTE", Vector2(0, 2), Vector2(370, 20), 11, TEXTO)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_aviso = _texto(_hud_arriba, "", Vector2(330, 96), Vector2(620, 26), 20, Color(1.0, 0.45, 0.25))
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
	if arma != null:
		_clase.text = "%s  ·  %s" % [
			NOMBRES_CLASE[arma.clase] if arma.clase < NOMBRES_CLASE.size() else "GLADIADOR",
			NOMBRES_ROL[arma.rol] if arma.rol < NOMBRES_ROL.size() else "—"
		]
	_skin.text = "Piel: %s" % _nombre_skin()
	var atributo := _atributo_principal()
	var nombres := {&"fuerza": "FUE", &"agilidad": "AGI", &"inteligencia": "INT"}
	var valores := {
		&"fuerza": _jugador.estadisticas.fuerza_total,
		&"agilidad": _jugador.estadisticas.agilidad_total,
		&"inteligencia": _jugador.estadisticas.inteligencia_total,
	}
	_emblema.text = "%s  %d" % [nombres.get(atributo, "FUE"), int(valores.get(atributo, 0))]
	_emblema.add_theme_color_override("font_color", IconStudio.color_para(IconStudio.CATEGORIA_HABILIDAD, String(atributo)))
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
	var requerida := _jugador.estadisticas.experiencia_requerida
	var nivel := _jugador.estadisticas.nivel
	var ola := _oleadas.oleada_actual if _oleadas != null else 0
	if requerida <= 0:
		_nivel_texto.text = "Nv %d  MÁX  ·  O%d/20" % [nivel, ola]
		_barra_xp.max_value = 1.0
		_barra_xp.value = 1.0
	else:
		_nivel_texto.text = "Nv %d  XP %d/%d  ·  O%d" % [
			nivel, _jugador.estadisticas.experiencia, requerida, ola
		]
		_barra_xp.max_value = float(requerida)
		_barra_xp.value = float(_jugador.estadisticas.experiencia)
	_economia.text = "Oro %d  ·  Atrib %d  ·  Hab %d\nRojos %d  ·  T talentos  ·  K piel" % [
		_oro_arena(), _puntos_atributo(), _jugador.estadisticas.puntos_habilidad, _jugador.puntos_rojos
	]
	if _contador_atributos != null:
		_contador_atributos.text = str(_puntos_atributo()) if _puntos_atributo() > 0 else ""
	if _contador_talentos != null:
		_contador_talentos.text = str(_jugador.puntos_rojos) if _jugador.puntos_rojos > 0 else ""


func _actualizar_habilidades() -> void:
	var arma := _jugador.arma_actual
	for i in 4:
		var boton := _habilidad_botones[i]
		var cd := _habilidad_cd[i]
		boton.text = ""
		if arma == null:
			boton.icon = null
			boton.tooltip_text = "Sin arma"
			cd.text = ""
			_actualizar_velo(_habilidad_velos[i], 0.0)
			continue
		var habilidad := arma.obtener_habilidad(i)
		if habilidad == null:
			boton.icon = null
			boton.tooltip_text = "Ranura vacía"
			cd.text = ""
			_actualizar_velo(_habilidad_velos[i], 0.0)
			continue
		if not _jugador.habilidad_desbloqueada(i):
			var nivel_libre := _jugador.nivel_desbloqueo_habilidad(i)
			_boton_icono(boton, habilidad.id, IconStudio.CATEGORIA_HABILIDAD)
			boton.modulate = Color(0.48, 0.46, 0.44, 1.0)
			boton.tooltip_text = "%s\nBLOQUEADA · Se desbloquea al nivel %d." % [habilidad.nombre, nivel_libre]
			boton.disabled = true
			cd.text = "Nv %d" % nivel_libre
			_actualizar_velo(_habilidad_velos[i], 0.55)
			continue
		boton.modulate = Color.WHITE
		_boton_icono(boton, habilidad.id, IconStudio.CATEGORIA_HABILIDAD)
		var restante := _jugador.cooldown_restante(i)
		var rango := _jugador.rango_habilidad(habilidad.id)
		cd.text = ("%ds" % int(ceil(restante))) if restante > 0.0 else ("%d/%d" % [rango, habilidad.rango_maximo])
		_actualizar_velo(_habilidad_velos[i], restante / maxf(0.01, _jugador.cooldown_habilidad(habilidad)))
		boton.disabled = restante > 0.0 or _jugador.mana_actual < habilidad.coste_mana
		boton.tooltip_text = "%s · Rango %d/%d\n%s" % [
			habilidad.nombre, rango, habilidad.rango_maximo, _tooltip_habilidad(habilidad, i)
		]


func _actualizar_inventario() -> void:
	var inventario := _jugador.inventario
	for i in _inventario_botones.size():
		var boton := _inventario_botones[i]
		var cantidad_texto := _inventario_cantidad[i]
		if inventario == null:
			boton.icon = null
			cantidad_texto.text = ""
			continue
		var ranura: Dictionary = inventario.ranuras[i]
		var item: ItemData = ranura["item"]
		if item == null:
			boton.icon = null
			boton.tooltip_text = "Ranura vacía · %s" % ["Z", "X", "C", "V", "B", "N"][i]
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
		boton.tooltip_text = _tooltip_item(item)
		boton.disabled = restante > 0.0


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
	_oro.text = "ORO %d   ·   PUNTOS %d" % [_oro_arena(), _puntos_atributo()]
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
	var dano := 0.0
	if arma != null:
		dano = e.escalar_dano(arma.dano_ataque_base, &"fisico")
	var dano_base := arma.dano_ataque_base if arma != null else 0.0
	var bono_dano := maxf(0.0, dano - dano_base)
	_stats.text = "Daño      %d [color=#7dff9a]+%d[/color]\nArmadura  0 [color=#7dff9a]+%d[/color]\nVel.      %.2f/s\nCrítico   %d %%" % [
		int(round(dano_base)), int(round(bono_dano)),
		int(round(e.armadura_total)), e.velocidad_ataque, int(round(e.probabilidad_critico * 100.0))
	]
	_atributos.text = "FUE  %d  (+%d)\nAGI  %d  (+%d)\nINT  %d  (+%d)" % [
		int(e.fuerza), int(e.fuerza_total - e.fuerza),
		int(e.agilidad), int(e.agilidad_total - e.agilidad),
		int(e.inteligencia), int(e.inteligencia_total - e.inteligencia),
	]


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
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.13, 0.11)
	normal.border_color = Color(0.45, 0.34, 0.2)
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3
	normal.corner_radius_bottom_right = 3
	boton.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.20, 0.15)
	hover.border_color = ORO
	boton.add_theme_stylebox_override("hover", hover)
	boton.add_theme_stylebox_override("pressed", hover)
	return boton


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


func _id_emblema() -> StringName:
	if _jugador == null or _jugador.arma_actual == null:
		return &"prisionero_grito"
	match _jugador.arma_actual.clase:
		WeaponItem.Clase.BASTION:
			return &"bastion_inquebrantable"
		WeaponItem.Clase.FILO:
			return &"filo_ejecucion"
		WeaponItem.Clase.CETRO:
			return &"cetro_espiritu_ancestral"
		_:
			return &"prisionero_grito"


func _actualizar_emblema() -> void:
	if _emblema_icono == null:
		return
	var id := _id_emblema()
	if _emblema_icono.get_meta("icono_id", &"") == id:
		return
	_emblema_icono.set_meta("icono_id", id)
	_emblema_icono.texture = IconStudio.obtener(id, IconStudio.CATEGORIA_HABILIDAD)
	IconStudio.escuchar(id, Callable(self, "_icono_listo").bind(id))


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
	for rect in [_icono_dano, _icono_armadura, _emblema_icono]:
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
	for i in mini(4, _habilidad_botones.size()):
		var habilidad := _jugador.arma_actual.obtener_habilidad(i)
		if habilidad != null:
			_boton_icono(_habilidad_botones[i], habilidad.id, IconStudio.CATEGORIA_HABILIDAD)


func _al_cambiar_arma_hud(_arma: WeaponItem = null) -> void:
	_actualizar_iconos_habilidades()
	_actualizar_emblema()


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
