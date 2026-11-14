class_name FondoForja
extends Control
## Fondo atmosférico de la forja: degradado de carbón, resplandor de ascua en el
## centro, arcos de arena grabados y brasas que suben. Todo se dibuja con
## `_draw()` y unas pocas formas: nada de shaders, para que la build Web no
## pierda fotogramas en el menú.
##
## Se usa en el lobby principal y en la forja de campeones. `intensidad` sube el
## brillo del ascua (selección de campeón) y `arcos` dibuja los aros de arena.

var intensidad := 1.0
var arcos := true
## Velo negro encima del degradado (0 = sin velo, 0.5 = oscurece a la mitad).
var velo := 0.0
var _tiempo := 0.0
var _brasas: Array = []
var _acumulado := 0.0

const BRASAS := 26
const BANDAS := 28


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Un Control hijo de CanvasLayer no recibe tamaño del viewport por sí solo:
	# se ancla a pantalla completa y, si el padre crece después, se sincroniza en
	# `_ajustar_tamano()` (antes se quedaba en 0x0 y no pintaba nada).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ajustar_tamano()
	_sembrar()


func _ajustar_tamano() -> void:
	var referencia := Vector2.ZERO
	var padre := get_parent()
	if padre is Control:
		referencia = (padre as Control).size
	else:
		referencia = get_viewport_rect().size
	if referencia.x > 1.0 and referencia.y > 1.0 and size != referencia:
		size = referencia


func _sembrar() -> void:
	_brasas.clear()
	for i in BRASAS:
		_brasas.append({
			"x": randf(),
			"y": randf(),
			"velocidad": randf_range(0.012, 0.045),
			"radio": randf_range(0.8, 2.4),
			"fase": randf() * TAU,
		})


func _process(delta: float) -> void:
	_tiempo += delta
	_ajustar_tamano()
	for brasa in _brasas:
		var datos: Dictionary = brasa
		datos["y"] = float(datos["y"]) - float(datos["velocidad"]) * delta
		if float(datos["y"]) < -0.04:
			datos["y"] = 1.04
			datos["x"] = randf()
	# 30 fps basta para brasas: el menú no necesita 60 redibujados completos.
	_acumulado += delta
	if _acumulado < 0.033:
		return
	_acumulado = 0.0
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return

	# Degradado vertical: carbón arriba, brasa apagada al pie de la arena.
	for i in BANDAS:
		var t := float(i) / float(BANDAS - 1)
		var color := Color(0.052, 0.045, 0.039, 1.0).lerp(Color(0.086, 0.052, 0.035, 1.0), t)
		var y := h * float(i) / float(BANDAS)
		draw_rect(Rect2(0, y, w, h / float(BANDAS) + 1.0), color)

	# Resplandor de ascua: círculos concéntricos desde el suelo.
	var centro := Vector2(w * 0.5, h * 0.92)
	var radio_max := maxf(w, h) * 0.75
	for i in 10:
		var t := float(i) / 10.0
		var radio := radio_max * (1.0 - t * 0.82)
		var alfa := (0.020 + 0.016 * float(i)) * intensidad
		draw_circle(centro, radio, Color(0.62, 0.24, 0.08, alfa))

	# Aros de arena grabados: el suelo del coliseo visto en perspectiva.
	if arcos:
		for i in 4:
			var t := float(i) / 4.0
			var radio_x := w * (0.30 + t * 0.34)
			var radio_y := radio_x * 0.22
			var alfa := 0.16 - t * 0.03
			_dibujar_elipse(Vector2(w * 0.5, h * 0.86), Vector2(radio_x, radio_y),
				Color(ForjaTema.ORO.r, ForjaTema.ORO.g, ForjaTema.ORO.b, alfa * intensidad))
		# Hairline del horizonte.
		draw_line(Vector2(0, h * 0.62), Vector2(w, h * 0.62),
			Color(ForjaTema.ORO_OSCURO.r, ForjaTema.ORO_OSCURO.g, ForjaTema.ORO_OSCURO.b, 0.18), 1.0)

	# Brasas: puntos cálidos que suben y parpadean.
	for brasa in _brasas:
		var datos: Dictionary = brasa
		var x := float(datos["x"]) * w
		var y := float(datos["y"]) * h
		var parpadeo := 0.55 + 0.45 * sin(_tiempo * 2.2 + float(datos["fase"]))
		var alfa := 0.55 * parpadeo * intensidad
		var radio := float(datos["radio"])
		draw_circle(Vector2(x, y), radio * 2.6, Color(1.0, 0.55, 0.22, alfa * 0.22))
		draw_circle(Vector2(x, y), radio, Color(1.0, 0.78, 0.42, alfa))

	if velo > 0.01:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.014, 0.010, velo), true)


func _dibujar_elipse(centro: Vector2, radios: Vector2, color: Color) -> void:
	var puntos := PackedVector2Array()
	var pasos := 48
	for i in pasos + 1:
		var angulo := TAU * float(i) / float(pasos)
		puntos.append(centro + Vector2(cos(angulo) * radios.x, sin(angulo) * radios.y))
	draw_polyline(puntos, color, 1.0, true)
