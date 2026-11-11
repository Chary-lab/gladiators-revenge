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
var _stats: Label
var _atributos: Label
var _economia: Label
var _habilidad_etiquetas: Array[Label] = []
var _habilidad_botones: Array[Button] = []
var _habilidad_velos: Array[ColorRect] = []
var _inventario_botones: Array[Button] = []
var _inventario_velos: Array[ColorRect] = []
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
	_talentos = TalentPanel.new()
	add_child(_talentos)
	_talentos.configurar(_jugador)
	_tienda = ShopPanel.new()
	add_child(_tienda)
	_tienda.configurar(_jugador, _arena)
	if _oleadas != null:
		_oleadas.mensaje.connect(mostrar_mensaje)


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

	_crear_minimapa()
	_crear_ficha()
	_crear_stats()
	_crear_inventario()
	_crear_habilidades()
	_crear_barra_superior()
	_crear_overlay()
	_crear_mensajes()


func _crear_minimapa() -> void:
	_minimapa = ArenaMinimap.new()
	_minimapa.position = Vector2(10, 545)
	_minimapa.size = Vector2(154, 164)
	_minimapa.set_jugador(_jugador)
	_minimapa.set_bandera(_bandera)
	_raiz.add_child(_minimapa)


func _crear_ficha() -> void:
	var fondo := _panel(Vector2(172, 545), Vector2(228, 164), HIERRO, Color(0.36, 0.30, 0.22))
	_raiz.add_child(fondo)

	_clase = _texto(fondo, "GLADIADOR ORCO", Vector2(10, 6), Vector2(208, 22), 17, ORO)
	_clase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skin = _texto(fondo, "Tierra Baldía", Vector2(10, 27), Vector2(208, 16), 11, Color(0.78, 0.74, 0.66))
	_skin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_barra_vida = _barra(fondo, Vector2(10, 48), Vector2(208, 20), ROJO)
	_barra_mana = _barra(fondo, Vector2(10, 82), Vector2(208, 16), AZUL)
	_vida_texto = _texto(fondo, "", Vector2(12, 50), Vector2(204, 18), 12, TEXTO)
	_mana_texto = _texto(fondo, "", Vector2(12, 83), Vector2(204, 14), 11, TEXTO)
	_escudo_texto = _texto(fondo, "", Vector2(10, 101), Vector2(208, 14), 11, Color(0.55, 0.78, 1.0))

	_economia = _texto(fondo, "", Vector2(10, 112), Vector2(208, 50), 11, TEXTO)
	_economia.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _crear_stats() -> void:
	var fondo := _panel(Vector2(406, 545), Vector2(214, 164), HIERRO, Color(0.36, 0.30, 0.22))
	_raiz.add_child(fondo)
	var titulo := _texto(fondo, "ATRIBUTOS", Vector2(10, 5), Vector2(194, 18), 13, ORO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats = _texto(fondo, "", Vector2(10, 24), Vector2(194, 68), 11, TEXTO)
	_atributos = _texto(fondo, "", Vector2(10, 94), Vector2(194, 64), 11, TEXTO)


func _crear_inventario() -> void:
	var titulo := _texto(_raiz, "MOCHILA  ·  Z X C V B N", Vector2(628, 543), Vector2(300, 16), 11, ORO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in InventoryComponent.RANURAS:
		var columna := i % 3
		var fila := i / 3
		var boton := _boton(
			Vector2(628 + columna * 98, 562 + fila * 72),
			Vector2(94, 66),
			""
		)
		boton.add_theme_font_size_override("font_size", 11)
		boton.pressed.connect(_usar_ranura.bind(i))
		_raiz.add_child(boton)
		_inventario_botones.append(boton)
		_inventario_velos.append(_velo(boton, Vector2(94, 66)))


func _crear_habilidades() -> void:
	var titulo := _texto(_raiz, "HABILIDADES  ·  Q W E R", Vector2(930, 543), Vector2(340, 16), 11, ORO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 4:
		var columna := i % 2
		var fila := i / 2
		var boton := _boton(
			Vector2(930 + columna * 172, 562 + fila * 72),
			Vector2(166, 66),
			""
		)
		boton.add_theme_font_size_override("font_size", 11)
		boton.pressed.connect(_lanzar_habilidad.bind(i))
		_raiz.add_child(boton)
		_habilidad_botones.append(boton)
		_habilidad_velos.append(_velo(boton, Vector2(166, 66)))


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
	_economia.text = "Oro %d   ·   Puntos %d   ·   Rojos %d\nT talentos   K piel\nS parar   H fijar   A atacar-mover" % [
		_oro_arena(), _puntos_atributo(), _jugador.puntos_rojos
	]


func _actualizar_habilidades() -> void:
	var arma := _jugador.arma_actual
	for i in 4:
		var boton := _habilidad_botones[i]
		var tecla: String = ["Q", "W", "E", "R"][i]
		if arma == null:
			boton.text = "%s\n—" % tecla
			boton.tooltip_text = "Sin arma"
			_actualizar_velo(_habilidad_velos[i], 0.0)
			continue
		var habilidad := arma.obtener_habilidad(i)
		if habilidad == null:
			boton.text = "%s\n—" % tecla
			boton.tooltip_text = "Ranura vacía"
			_actualizar_velo(_habilidad_velos[i], 0.0)
			continue
		var restante := _jugador.cooldown_restante(i)
		boton.text = "%s  %s\n%s" % [tecla, habilidad.nombre.left(20), _cd(restante)]
		_actualizar_velo(_habilidad_velos[i], restante / maxf(0.01, habilidad.cooldown))
		boton.disabled = restante > 0.0 or _jugador.mana_actual < habilidad.coste_mana
		boton.tooltip_text = _tooltip_habilidad(habilidad, i)


func _actualizar_inventario() -> void:
	var inventario := _jugador.inventario
	for i in _inventario_botones.size():
		var boton := _inventario_botones[i]
		var tecla: String = ["Z", "X", "C", "V", "B", "N"][i]
		if inventario == null:
			boton.text = "%s\n—" % tecla
			continue
		var ranura: Dictionary = inventario.ranuras[i]
		var item: ItemData = ranura["item"]
		if item == null:
			boton.text = "%s\n·" % tecla
			boton.tooltip_text = "Ranura vacía"
			boton.disabled = true
			_actualizar_velo(_inventario_velos[i], 0.0)
			continue
		var restante := inventario.energia_restante(i)
		var cantidad := int(ranura["cantidad"])
		var cd_max := 8.0
		if item.habilidad != null:
			cd_max = maxf(0.1, item.habilidad.cooldown)
		_actualizar_velo(_inventario_velos[i], restante / cd_max)
		boton.text = "%s %s\n%s" % [
			tecla,
			item.nombre.left(11),
			_cd(restante) if restante > 0.0 else ("x%d" % cantidad if cantidad > 1 else "listo")
		]
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
	_stats.text = "Daño físico   %d\nArmadura      %d\nVel. ataque   %.2f/s\nCrítico       %d %%" % [
		int(round(dano)), int(round(e.armadura_total)), e.velocidad_ataque, int(round(e.probabilidad_critico * 100.0))
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
