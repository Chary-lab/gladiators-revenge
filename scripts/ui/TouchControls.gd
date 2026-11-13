class_name TouchControls
extends CanvasLayer
## Controles táctiles: joystick de movimiento a la izquierda y botones grandes a
## la derecha (Q/W/E/R, INTERACTUAR, DETENER).
##
## Se dibuja en coordenadas de diseño 1280x720 y se muestra solo en pantallas
## táctiles (o con `--tactil`). El joystick emite una dirección normalizada que
## el gladiador usa para moverse de verdad, sin depender de la emulación de ratón.

signal mover(direccion: Vector2)
signal habilidad(slot: int)
signal interactuar
signal detener

const CLAVES := ["Q", "W", "E", "R"]
const CENTRO_JOY := Vector2(178, 418)
const RADIO_JOY := 96.0
const ZONA_BOTONES_Y := 268.0

var _raiz: Control
var _base: Panel
var _perilla: Panel
var _botones: Array = []
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

	_crear_joystick()
	for i in CLAVES.size():
		var columna := i % 2
		var fila := i / 2
		var boton := _crear_boton(
			CLAVES[i],
			Vector2(1040 + columna * 104, 268 + fila * 104),
			Vector2(96, 96),
			30
		)
		boton.pressed.connect(func() -> void: habilidad.emit(i))
		_botones.append(boton)

	var detener_btn := _crear_boton("DETENER", Vector2(924, 268), Vector2(104, 96), 15)
	detener_btn.pressed.connect(func() -> void: detener.emit())

	var interactuar_btn := _crear_boton("INTERACTUAR", Vector2(924, 372), Vector2(104, 96), 15)
	interactuar_btn.pressed.connect(func() -> void: interactuar.emit())

	aplicar_escala(escala)


func _crear_joystick() -> void:
	_base = Panel.new()
	_base.size = Vector2(RADIO_JOY * 2.0, RADIO_JOY * 2.0)
	_base.position = CENTRO_JOY - Vector2(RADIO_JOY, RADIO_JOY)
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.10, 0.08, 0.06, 0.45)
	estilo.border_color = Color(0.62, 0.45, 0.22, 0.75)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(int(RADIO_JOY))
	_base.add_theme_stylebox_override("panel", estilo)
	_raiz.add_child(_base)

	_perilla = Panel.new()
	_perilla.size = Vector2(RADIO_JOY, RADIO_JOY)
	_perilla.position = CENTRO_JOY - Vector2(RADIO_JOY, RADIO_JOY) * 0.5
	_perilla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo_perilla := StyleBoxFlat.new()
	estilo_perilla.bg_color = Color(0.78, 0.62, 0.34, 0.85)
	estilo_perilla.set_corner_radius_all(int(RADIO_JOY * 0.5))
	_perilla.add_theme_stylebox_override("panel", estilo_perilla)
	_raiz.add_child(_perilla)


func _crear_boton(texto: String, posicion: Vector2, tamano: Vector2, letra: int) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.position = posicion
	boton.custom_minimum_size = tamano
	boton.size = tamano
	boton.focus_mode = Control.FOCUS_NONE
	boton.add_theme_font_size_override("font_size", letra)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.10, 0.08, 0.06, 0.72)
	estilo.border_color = Color(0.62, 0.45, 0.22)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(48)
	boton.add_theme_stylebox_override("normal", estilo)
	var pulsado := estilo.duplicate() as StyleBoxFlat
	pulsado.bg_color = Color(0.24, 0.18, 0.10, 0.92)
	boton.add_theme_stylebox_override("pressed", pulsado)
	boton.add_theme_stylebox_override("hover", estilo)
	boton.add_theme_stylebox_override("disabled", estilo)
	_raiz.add_child(boton)
	return boton


## Reubica y escala todo el bloque táctil (Ajustes → tamaño de botones).
func aplicar_escala(nueva: float) -> void:
	escala = clampf(nueva, 0.75, 1.6)
	if _raiz == null:
		return
	var centro := CENTRO_JOY
	var escala_v := Vector2(escala, escala)
	if _base != null:
		_base.size = Vector2(RADIO_JOY, RADIO_JOY) * 2.0 * escala
		_base.position = centro - _base.size * 0.5
		_base.pivot_offset = _base.size * 0.5
	if _perilla != null:
		_perilla.size = Vector2(RADIO_JOY, RADIO_JOY) * escala
		_perilla.position = centro - _perilla.size * 0.5
	for i in _botones.size():
		var boton: Button = _botones[i]
		var columna := i % 2
		var fila := i / 2
		var base_pos := Vector2(1040 + columna * 104, ZONA_BOTONES_Y + fila * 104)
		boton.size = Vector2(96, 96) * escala
		boton.custom_minimum_size = boton.size
		boton.position = base_pos - (boton.size - Vector2(96, 96)) * 0.5
		boton.pivot_offset = boton.size * 0.5


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
		var arrastre := evento as InputEventScreenDrag
		posicion = arrastre.position
		if not _arrastrando:
			return
		_mover_perilla(posicion)
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
	# Solo se activa si el toque empieza dentro de la zona del joystick.
	if inicio.distance_to(CENTRO_JOY) <= RADIO_JOY * escala * 1.35:
		_arrastrando = true
		_mover_perilla(posicion)


func _mover_perilla(posicion: Vector2) -> void:
	var delta := posicion - CENTRO_JOY
	var limite := RADIO_JOY * escala
	if delta.length() > limite:
		delta = delta.normalized() * limite
	_perilla.position = CENTRO_JOY + delta - _perilla.size * 0.5
	var direccion := delta / limite
	if direccion.length() < 0.18:
		direccion = Vector2.ZERO
	mover.emit(direccion)


func _soltar_joystick() -> void:
	_arrastrando = false
	if _perilla != null:
		_perilla.position = CENTRO_JOY - _perilla.size * 0.5
	mover.emit(Vector2.ZERO)


func _process(_delta: float) -> void:
	if _jugador == null or _botones.is_empty():
		return
	for i in mini(_botones.size(), CLAVES.size()):
		var boton: Button = _botones[i]
		if boton == null:
			continue
		boton.modulate = Color(1, 1, 1, 1) if _disponible(i) else Color(0.55, 0.55, 0.55, 0.8)


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
