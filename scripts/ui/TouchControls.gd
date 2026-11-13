class_name TouchControls
extends CanvasLayer
## Botones táctiles para jugar sin teclado: habilidades Q/W/E/R, interactuar (F)
## y detener (S). Se coloca por encima del HUD y solo aparece en pantallas
## táctiles (o con `--tactil`, para probarlo en escritorio).
##
## Se dibuja en las coordenadas de diseño del HUD (1280x720); el proyecto escala
## con `canvas_items`, así que los botones crecen con la pantalla.

signal habilidad(slot: int)
signal interactuar
signal detener

const CLAVES := ["Q", "W", "E", "R"]

var _raiz: Control
var _botones: Array = []
var _jugador: GladiatorController


func configurar(jugador: GladiatorController) -> void:
	_jugador = jugador
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS

	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	# 2x2 de habilidades, a la derecha y por encima de la consola.
	for i in CLAVES.size():
		var columna := i % 2
		var fila := i / 2
		var boton := _crear_boton(CLAVES[i], Vector2(1064 + columna * 96, 300 + fila * 96), Vector2(88, 88), 30)
		boton.pressed.connect(func() -> void: habilidad.emit(i))
		_botones.append(boton)

	var detener_btn := _crear_boton("DETENER", Vector2(950, 300), Vector2(100, 88), 15)
	detener_btn.pressed.connect(func() -> void: detener.emit())

	var interactuar_btn := _crear_boton("INTERACTUAR", Vector2(950, 396), Vector2(100, 88), 15)
	interactuar_btn.pressed.connect(func() -> void: interactuar.emit())


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
	estilo.set_corner_radius_all(44)
	boton.add_theme_stylebox_override("normal", estilo)
	var pulsado := estilo.duplicate() as StyleBoxFlat
	pulsado.bg_color = Color(0.24, 0.18, 0.10, 0.92)
	boton.add_theme_stylebox_override("pressed", pulsado)
	boton.add_theme_stylebox_override("hover", estilo)
	boton.add_theme_stylebox_override("disabled", estilo)
	_raiz.add_child(boton)
	return boton


func _process(_delta: float) -> void:
	if _jugador == null or _botones.is_empty():
		return
	# Atenuar las habilidades que no se pueden usar (sin maná o en recarga).
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
