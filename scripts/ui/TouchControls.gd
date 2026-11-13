class_name TouchControls
extends CanvasLayer
## HUD táctil: joystick con anillo de runas a la izquierda, abanico de
## habilidades a la derecha, vida/maná arriba y botón de pausa.
##
## Coordenadas de diseño 1280x720. El joystick emite una dirección normalizada
## que el gladiador usa para moverse de verdad, sin depender de la emulación de
## ratón (eso era lo que "no agarraba" en el teléfono).

signal mover(direccion: Vector2)
signal habilidad(slot: int)
signal interactuar
signal detener
signal pausa

const CLAVES := ["Q", "W", "E", "R"]
const CENTRO_JOY := Vector2(186, 470)
const RADIO_JOY := 104.0
const CENTRO_ABANICO := Vector2(1128, 600)
const RADIO_ABANICO := 190.0
## Ángulos del abanico de habilidades (grados: 180 = izquierda, 270 = arriba).
const ANGULOS := [190.0, 220.0, 250.0, 280.0]

var _raiz: Control
var _base: Panel
var _aro: ForjaTema.AroRunas
var _perilla: Panel
var _botones: Array = []
var _panel_vital: PanelContainer
var _barra_vida: ForjaTema.BarraSegmentada
var _barra_mana: ForjaTema.BarraSegmentada
var _texto_vida: Label
var _texto_mana: Label
var _boton_pausa: Button
var _jugador: GladiatorController
## Multiplicador de tamaño configurable desde Ajustes.
var escala := 1.0
var _arrastrando := false


func configurar(jugador: GladiatorController) -> void:
	_jugador = jugador
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS

	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_crear_vitales()
	_crear_joystick()

	for i in CLAVES.size():
		var boton := _crear_boton(CLAVES[i], _posicion_abanico(i), 104, 30, true)
		boton.pressed.connect(func() -> void: habilidad.emit(i))
		_botones.append(boton)

	var interactuar_btn := _crear_boton("INTERACTUAR", Vector2(1152, 302), 116, 14, false)
	interactuar_btn.pressed.connect(func() -> void: interactuar.emit())

	var detener_btn := _crear_boton("DETENER", Vector2(958, 330), 92, 13, false)
	detener_btn.pressed.connect(func() -> void: detener.emit())

	_boton_pausa = ForjaTema.boton("II", 18)
	_boton_pausa.position = Vector2(1198, 148)
	_boton_pausa.custom_minimum_size = Vector2(56, 44)
	_boton_pausa.size = Vector2(56, 44)
	_boton_pausa.pressed.connect(func() -> void: pausa.emit())
	_raiz.add_child(_boton_pausa)

	aplicar_escala(escala)


func _posicion_abanico(indice: int) -> Vector2:
	var grados: float = ANGULOS[clampi(indice, 0, ANGULOS.size() - 1)]
	var rad := deg_to_rad(grados)
	return CENTRO_ABANICO + Vector2(cos(rad), sin(rad)) * RADIO_ABANICO - Vector2(52, 52)


func _crear_vitales() -> void:
	_panel_vital = PanelContainer.new()
	var estilo := ForjaTema.estilo_panel(0.92)
	estilo.content_margin_left = 10
	estilo.content_margin_right = 12
	estilo.content_margin_top = 8
	estilo.content_margin_bottom = 8
	_panel_vital.add_theme_stylebox_override("panel", estilo)
	_panel_vital.position = Vector2(20, 86)
	_panel_vital.custom_minimum_size = Vector2(268, 0)
	_raiz.add_child(_panel_vital)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 5)
	_panel_vital.add_child(columna)

	for dato in [["VIDA", ForjaTema.VIDA], ["MANÁ", ForjaTema.MANA]]:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		var nombre := ForjaTema.etiqueta(String(dato[0]), 10, ForjaTema.TENUE)
		nombre.custom_minimum_size = Vector2(40, 0)
		fila.add_child(nombre)
		var barra := ForjaTema.BarraSegmentada.new(1.0, dato[1])
		barra.custom_minimum_size = Vector2(150, 12)
		fila.add_child(barra)
		var valor := ForjaTema.etiqueta("", 10, ForjaTema.ORO_CLARO)
		valor.custom_minimum_size = Vector2(58, 0)
		valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fila.add_child(valor)
		columna.add_child(fila)
		if String(dato[0]) == "VIDA":
			_barra_vida = barra
			_texto_vida = valor
		else:
			_barra_mana = barra
			_texto_mana = valor


func _crear_joystick() -> void:
	_base = Panel.new()
	_base.size = Vector2(RADIO_JOY, RADIO_JOY) * 2.0
	_base.position = CENTRO_JOY - Vector2(RADIO_JOY, RADIO_JOY)
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0, 0, 0, 0)
	estilo.border_color = Color(ForjaTema.ORO_OSCURO.r, ForjaTema.ORO_OSCURO.g, ForjaTema.ORO_OSCURO.b, 0.55)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(int(RADIO_JOY))
	_base.add_theme_stylebox_override("panel", estilo)
	_raiz.add_child(_base)

	_aro = ForjaTema.AroRunas.new(RADIO_JOY)
	_aro.position = CENTRO_JOY - Vector2(RADIO_JOY, RADIO_JOY)
	_raiz.add_child(_aro)

	_perilla = Panel.new()
	_perilla.size = Vector2(RADIO_JOY, RADIO_JOY)
	_perilla.position = CENTRO_JOY - _perilla.size * 0.5
	_perilla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo_perilla := StyleBoxFlat.new()
	estilo_perilla.bg_color = Color(0.72, 0.58, 0.30, 0.32)
	estilo_perilla.border_color = ForjaTema.ORO
	estilo_perilla.set_border_width_all(2)
	estilo_perilla.set_corner_radius_all(int(RADIO_JOY * 0.5))
	_perilla.add_theme_stylebox_override("panel", estilo_perilla)
	_raiz.add_child(_perilla)


func _crear_boton(texto: String, posicion: Vector2, tamano: float, letra: int, circular: bool) -> Button:
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
	estilo.bg_color = Color(0.07, 0.06, 0.05, 0.82)
	estilo.border_color = ForjaTema.ORO_OSCURO
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(int(tamano * 0.5) if circular else 4)
	boton.add_theme_stylebox_override("normal", estilo)

	var pulsado := estilo.duplicate() as StyleBoxFlat
	pulsado.bg_color = Color(0.30, 0.22, 0.10, 0.95)
	pulsado.border_color = ForjaTema.ORO_CLARO
	boton.add_theme_stylebox_override("pressed", pulsado)
	boton.add_theme_stylebox_override("hover", estilo)
	boton.add_theme_stylebox_override("disabled", estilo)
	_raiz.add_child(boton)
	return boton


## Reubica y escala todo el bloque táctil (Ajustes → tamaño de botones).
func aplicar_escala(nueva: float) -> void:
	escala = clampf(nueva, 0.75, 1.6)
	if _raiz == null or _aro == null:
		return
	_aro.escala = escala
	_aro.queue_redraw()
	if _base != null:
		_base.size = Vector2(RADIO_JOY, RADIO_JOY) * 2.0 * escala
		_base.position = CENTRO_JOY - _base.size * 0.5
	if _perilla != null:
		_perilla.size = Vector2(RADIO_JOY, RADIO_JOY) * escala
		_perilla.position = CENTRO_JOY - _perilla.size * 0.5
	for i in _botones.size():
		var boton: Button = _botones[i]
		var centro := _posicion_abanico(i) + Vector2(52, 52)
		boton.size = Vector2(104, 104) * escala
		boton.custom_minimum_size = boton.size
		boton.position = centro - boton.size * 0.5


func _input(evento: InputEvent) -> void:
	# Joystick: acepta toque y ratón (para probar en escritorio).
	var inicio := Vector2.ZERO
	var posicion := Vector2.ZERO
	var activo := false
	if evento is InputEventScreenTouch:
		var toque := evento as InputEventScreenTouch
		inicio = toque.position
		posicion = toque.position
		activo = toque.pressed
		if not toque.pressed:
			_soltar_joystick()
			return
	elif evento is InputEventScreenDrag:
		if not _arrastrando:
			return
		_mover_perilla((evento as InputEventScreenDrag).position)
		return
	elif evento is InputEventMouseButton:
		var clic := evento as InputEventMouseButton
		if clic.button_index != MOUSE_BUTTON_LEFT:
			return
		inicio = clic.position
		posicion = clic.position
		activo = clic.pressed
		if not clic.pressed:
			_soltar_joystick()
			return
	elif evento is InputEventMouseMotion and _arrastrando:
		_mover_perilla((evento as InputEventMouseMotion).position)
		return
	else:
		return

	if not activo:
		return
	# Zona generosa: el pulgar no siempre acierta el centro del aro.
	if inicio.distance_to(CENTRO_JOY) <= RADIO_JOY * escala * 1.45:
		_arrastrando = true
		_mover_perilla(posicion)


func _mover_perilla(posicion: Vector2) -> void:
	var delta := posicion - CENTRO_JOY
	var limite := RADIO_JOY * escala
	if delta.length() > limite:
		delta = delta.normalized() * limite
	_perilla.position = CENTRO_JOY + delta - _perilla.size * 0.5
	var direccion := delta / limite
	if direccion.length() < 0.16:
		direccion = Vector2.ZERO
	_aro.direccion = direccion
	_aro.queue_redraw()
	mover.emit(direccion)


func _soltar_joystick() -> void:
	_arrastrando = false
	if _perilla != null:
		_perilla.position = CENTRO_JOY - _perilla.size * 0.5
	if _aro != null:
		_aro.direccion = Vector2.ZERO
		_aro.queue_redraw()
	mover.emit(Vector2.ZERO)


func _process(_delta: float) -> void:
	if _jugador == null:
		return
	var vida_max := maxf(1.0, _jugador.estadisticas.salud_maxima)
	_barra_vida.valor = clampf(_jugador.salud_actual / vida_max, 0.0, 1.0)
	_barra_vida.queue_redraw()
	_texto_vida.text = "%d" % int(ceil(_jugador.salud_actual))
	var mana_max := maxf(1.0, _jugador.estadisticas.mana_maximo)
	_barra_mana.valor = clampf(_jugador.mana_actual / mana_max, 0.0, 1.0)
	_barra_mana.queue_redraw()
	_texto_mana.text = "%d" % int(ceil(_jugador.mana_actual))

	for i in mini(_botones.size(), CLAVES.size()):
		var boton: Button = _botones[i]
		if boton == null:
			continue
		boton.modulate = Color(1, 1, 1, 1) if _disponible(i) else Color(0.55, 0.52, 0.46, 0.75)


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
