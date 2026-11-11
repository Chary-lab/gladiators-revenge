class_name ArenaHUD
extends CanvasLayer
## HUD del prototipo, construido por código (sin .tscn) para poder iterar sin
## editor. Todos los controles ignoran el ratón para no bloquear el click-to-move.

const ANCHO := 1280.0
const ALTO := 720.0
const TECLAS := ["Q", "W", "E", "R"]

var _jugador: GladiatorController
var _oleadas: WaveManager
var _bandera: RebellionBanner
var _arena: Node

var _raiz: Control
var _barra_salud: ProgressBar
var _barra_mana: ProgressBar
var _barra_bandera: ProgressBar
var _texto_salud: Label
var _texto_mana: Label
var _texto_arma: Label
var _texto_talentos: Label
var _texto_oleada: Label
var _texto_enemigos: Label
var _texto_oro: Label
var _texto_puntos: Label
var _mensaje: Label
var _pista: Label
var _slots: Array[Label] = []
var _aviso: Label
var _talentos: TalentPanel

var _mensaje_tiempo := 0.0
var _final := false


func _ready() -> void:
	_raiz = Control.new()
	_raiz.position = Vector2.ZERO
	_raiz.size = Vector2(ANCHO, ALTO)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_barra_salud = _crear_barra(Vector2(24, 24), Vector2(300, 26), Color(0.20, 0.75, 0.32))
	_texto_salud = _crear_etiqueta("", Vector2(24, 24), 300, 15, HORIZONTAL_ALIGNMENT_CENTER)

	_barra_mana = _crear_barra(Vector2(24, 56), Vector2(300, 14), Color(0.25, 0.55, 0.95))
	_texto_mana = _crear_etiqueta("", Vector2(24, 56), 300, 11, HORIZONTAL_ALIGNMENT_CENTER)

	_texto_arma = _crear_etiqueta("", Vector2(24, 78), 460, 18)
	_texto_talentos = _crear_etiqueta("", Vector2(24, 102), 460, 13)

	_texto_oleada = _crear_etiqueta("", Vector2(440, 16), 400, 26, HORIZONTAL_ALIGNMENT_CENTER)
	_texto_enemigos = _crear_etiqueta("", Vector2(440, 46), 400, 14, HORIZONTAL_ALIGNMENT_CENTER)
	_texto_enemigos.modulate = Color(0.85, 0.82, 0.75)

	_barra_bandera = _crear_barra(Vector2(460, 82), Vector2(360, 14), Color(0.90, 0.42, 0.16))
	_crear_etiqueta("ESTANDARTE", Vector2(460, 64), 360, 11, HORIZONTAL_ALIGNMENT_CENTER)

	_texto_oro = _crear_etiqueta("", Vector2(980, 22), 280, 20, HORIZONTAL_ALIGNMENT_RIGHT)
	_texto_puntos = _crear_etiqueta("", Vector2(980, 50), 280, 14, HORIZONTAL_ALIGNMENT_RIGHT)

	_crear_etiqueta(
		"Click derecho: mover   ·   QWER: habilidades   ·   T: talentos   ·   K: skin   ·   1/2/3: FUE/AGI/INT   ·   F: armería",
		Vector2(0, 702),
		ANCHO,
		12,
		HORIZONTAL_ALIGNMENT_CENTER
	).modulate = Color(0.75, 0.72, 0.68)

	for i in 4:
		_slots.append(_crear_slot(i))

	_mensaje = _crear_etiqueta("", Vector2(0, 270), ANCHO, 42, HORIZONTAL_ALIGNMENT_CENTER)
	_mensaje.add_theme_constant_override("outline_size", 10)
	_mensaje.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))

	_pista = _crear_etiqueta("", Vector2(0, 596), ANCHO, 18, HORIZONTAL_ALIGNMENT_CENTER)
	_pista.modulate = Color(1.0, 0.85, 0.45)

	_aviso = _crear_etiqueta("", Vector2(0, 120), ANCHO, 18, HORIZONTAL_ALIGNMENT_CENTER)
	_aviso.modulate = Color(1.0, 0.45, 0.35)

	_mensaje.text = ""
	_aviso.text = ""


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

	_talentos = TalentPanel.new()
	_talentos.name = "Talentos"
	add_child(_talentos)
	_talentos.configurar(_jugador)

	if _bandera != null:
		_barra_bandera.max_value = _bandera.salud_maxima
		_barra_bandera.value = _bandera.salud_maxima
	if _oleadas != null:
		_oleadas.mensaje.connect(mostrar_mensaje)


func _process(delta: float) -> void:
	if _mensaje_tiempo > 0.0:
		_mensaje_tiempo -= delta
		if _mensaje_tiempo <= 0.0 and not _final:
			_mensaje.text = ""

	_actualizar_jugador()
	_actualizar_oleadas()
	_actualizar_bandera()
	_actualizar_economia()
	_actualizar_habilidades()
	_actualizar_aviso()


func _actualizar_jugador() -> void:
	if _jugador == null or _jugador.estadisticas == null:
		return
	var stats := _jugador.estadisticas
	var vida_max := maxf(1.0, stats.salud_maxima)
	_barra_salud.value = 100.0 * _jugador.salud_actual / vida_max
	_texto_salud.text = "%d / %d" % [int(_jugador.salud_actual), int(stats.salud_maxima)]

	var mana_max := maxf(1.0, stats.mana_maximo)
	_barra_mana.value = 100.0 * _jugador.mana_actual / mana_max
	_texto_mana.text = "%d / %d" % [int(_jugador.mana_actual), int(stats.mana_maximo)]

	if _jugador.arma_actual != null:
		_texto_arma.text = _jugador.arma_actual.nombre
	else:
		_texto_arma.text = "Sin arma"

	_texto_talentos.text = "Puntos rojos: %d" % _jugador.puntos_rojos


func _actualizar_oleadas() -> void:
	if _oleadas == null:
		return
	if _oleadas.oleada_actual <= 0:
		_texto_oleada.text = "PREPARACIÓN"
	else:
		_texto_oleada.text = "OLEADA %d / %d" % [_oleadas.oleada_actual, _oleadas.total_oleadas]
	_texto_enemigos.text = "Enemigos: %d" % _oleadas.enemigos_restantes()


func _actualizar_bandera() -> void:
	if _bandera == null:
		return
	_barra_bandera.value = _bandera.salud_actual
	_barra_bandera.max_value = _bandera.salud_maxima


func _actualizar_economia() -> void:
	if _arena == null:
		return
	var oro := int(_arena.get("oro"))
	var congelado: bool = _arena.has_method("esta_congelado") and _arena.esta_congelado()
	_texto_oro.text = "Oro: %d%s" % [oro, "  (congelado)" if congelado else ""]
	_texto_puntos.text = "Puntos: %d   1 FUE · 2 AGI · 3 INT" % int(_arena.get("puntos_atributo"))


func _actualizar_habilidades() -> void:
	if _jugador == null:
		return
	for i in _slots.size():
		var texto := "%s   —" % TECLAS[i]
		if _jugador.arma_actual != null:
			var habilidad := _jugador.arma_actual.obtener_habilidad(i)
			if habilidad != null:
				var cd := _jugador.cooldown_restante(i)
				texto = "%s  %s" % [TECLAS[i], habilidad.nombre]
				if cd > 0.05:
					texto += "\n%.1f s" % cd
				else:
					texto += "\n%d maná" % int(habilidad.coste_mana)
		_slots[i].text = texto


func _actualizar_aviso() -> void:
	if _jugador == null or _jugador.estadisticas == null or _arena == null:
		return
	var congelado: bool = _arena.has_method("esta_congelado") and _arena.esta_congelado()
	_aviso.text = "¡EL PÚBLICO ABUCHEA!" if congelado else ""


func mostrar_mensaje(texto: String, duracion: float) -> void:
	_mensaje.text = texto
	_mensaje_tiempo = duracion


func mostrar_final(texto: String) -> void:
	_final = true
	_mensaje.text = texto
	_mensaje_tiempo = 9999.0
	_mensaje.add_theme_font_size_override("font_size", 54)


func alternar_talentos() -> void:
	if _talentos != null:
		_talentos.alternar()


func cerrar_talentos() -> void:
	if _talentos != null:
		_talentos.cerrar_panel()


func establecer_pista(texto: String) -> void:
	_pista.text = texto


func _crear_barra(pos: Vector2, tam: Vector2, color: Color) -> ProgressBar:
	var barra := ProgressBar.new()
	barra.position = pos
	barra.size = tam
	barra.show_percentage = false
	barra.max_value = 100.0
	barra.value = 100.0
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.03, 0.03, 0.05, 0.78)
	fondo.set_corner_radius_all(4)
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = color
	relleno.set_corner_radius_all(4)

	barra.add_theme_stylebox_override("background", fondo)
	barra.add_theme_stylebox_override("fill", relleno)
	_raiz.add_child(barra)
	return barra


func _crear_etiqueta(
	texto: String,
	pos: Vector2,
	ancho: float,
	fuente: int,
	alineacion: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.position = pos
	etiqueta.size = Vector2(ancho, fuente * 1.5)
	etiqueta.horizontal_alignment = alineacion
	etiqueta.add_theme_font_size_override("font_size", fuente)
	etiqueta.add_theme_constant_override("outline_size", 4)
	etiqueta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(etiqueta)
	return etiqueta


func _crear_slot(indice: int) -> Label:
	var panel := Panel.new()
	panel.position = Vector2(400 + indice * 120, 628)
	panel.size = Vector2(112, 62)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.04, 0.04, 0.07, 0.82)
	estilo.set_corner_radius_all(6)
	estilo.set_border_width_all(2)
	estilo.border_color = Color(0.72, 0.55, 0.22, 0.9)
	panel.add_theme_stylebox_override("panel", estilo)
	_raiz.add_child(panel)

	var etiqueta := Label.new()
	etiqueta.position = Vector2(6, 4)
	etiqueta.size = Vector2(100, 54)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.add_theme_font_size_override("font_size", 12)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(etiqueta)
	return etiqueta
