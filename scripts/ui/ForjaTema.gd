class_name ForjaTema
extends RefCounted
## Sistema visual del juego: carbón, oro viejo y ascua. Todo el HUD, el menú y la
## selección de campeón toman de aquí los colores y las piezas para que la
## interfaz se vea de una sola pieza.
##
## Paleta pensada para la arena: fondo casi negro cálido (no gris azulado), oro
## como único acento fuerte y rojo ascua solo para peligro y sangre.

const FONDO := Color(0.055, 0.047, 0.040)
const PANEL := Color(0.086, 0.075, 0.063, 0.97)
const PANEL_CLARO := Color(0.125, 0.107, 0.086, 0.96)
const ORO := Color(0.788, 0.635, 0.294)
const ORO_CLARO := Color(0.910, 0.784, 0.478)
const ORO_OSCURO := Color(0.396, 0.302, 0.125)
const ASCUA := Color(0.549, 0.165, 0.110)
const SANGRE := Color(0.639, 0.180, 0.145)
const VIDA := Color(0.694, 0.208, 0.169)
const MANA := Color(0.318, 0.514, 0.694)
const TEXTO := Color(0.847, 0.804, 0.729)
const TENUE := Color(0.541, 0.482, 0.396)

const NOMBRE_EMBLEMA := {
	&"bastion": "BASTION",
	&"filo": "FILO",
	&"cetro": "CETRO",
	&"prisionero": "PRISIONERO",
}

const LEMA_CLASE := {
	&"bastion": "Muro de la arena. Aguanta y devuelve el golpe.",
	&"filo": "Filo veloz. Mata antes de que te toquen.",
	&"cetro": "Voluntad arcana. Quema desde la distancia.",
	&"prisionero": "Sin gloria. Sin armas. Solo furia.",
}


static func estilo_panel(opacidad := 1.0, borde := ORO_OSCURO) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(PANEL.r, PANEL.g, PANEL.b, PANEL.a * opacidad)
	estilo.border_color = borde
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(2)
	estilo.content_margin_left = 18
	estilo.content_margin_right = 18
	estilo.content_margin_top = 14
	estilo.content_margin_bottom = 14
	return estilo


static func etiqueta(texto: String, tamano := 14, color := TEXTO, centrado := false) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centrado:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Botón con marco de oro: relleno oscuro y, al pulsar, oro lleno con tinta
## oscura. `destacado` lo pinta como acción principal.
static func boton(texto: String, tamano := 16, destacado := false) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", tamano)
	b.add_theme_color_override("font_color", Color(0.09, 0.08, 0.06) if destacado else ORO_CLARO)
	b.add_theme_color_override("font_hover_color", Color(0.09, 0.08, 0.06) if destacado else Color(1, 0.93, 0.78))
	b.add_theme_color_override("font_pressed_color", Color(0.09, 0.08, 0.06))
	b.add_theme_color_override("font_disabled_color", Color(0.42, 0.38, 0.32))

	var normal := StyleBoxFlat.new()
	normal.bg_color = ORO if destacado else Color(0.10, 0.09, 0.075, 0.9)
	normal.border_color = ORO if destacado else ORO_OSCURO
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_top = 9
	normal.content_margin_bottom = 9
	b.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ORO_CLARO if destacado else Color(0.17, 0.14, 0.10, 0.95)
	hover.border_color = ORO_CLARO
	b.add_theme_stylebox_override("hover", hover)

	var pulsado := normal.duplicate() as StyleBoxFlat
	pulsado.bg_color = ORO_OSCURO if destacado else Color(0.06, 0.05, 0.04, 0.95)
	b.add_theme_stylebox_override("pressed", pulsado)
	b.add_theme_stylebox_override("disabled", normal)
	return b


## Línea fina dorada, como las reglas de los pergaminos.
static func regla(ancho: float, color := ORO_OSCURO) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(ancho, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Barra segmentada estilo RPG: valor sobre máximo en tramos con muescas.
class BarraSegmentada:
	extends Control
	var valor := 0.75
	var color := ForjaTema.VIDA
	var tramos := 14
	var alto := 10

	func _init(v := 0.75, c := ForjaTema.VIDA) -> void:
		valor = clampf(v, 0.0, 1.0)
		color = c

	func _draw() -> void:
		var ancho := size.x
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.035, 0.03), true)
		var paso := ancho / float(tramos)
		var llenos := valor * float(tramos)
		for i in tramos:
			var x := paso * float(i) + 1.0
			var w := maxf(1.0, paso - 2.0)
			var intensidad := color if float(i) < llenos else Color(color.r, color.g, color.b, 0.16)
			draw_rect(Rect2(Vector2(x, 0), Vector2(w, size.y)), intensidad, true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(ForjaTema.ORO_OSCURO.r, ForjaTema.ORO_OSCURO.g, ForjaTema.ORO_OSCURO.b, 0.8), false, 1.0)


## Emblema de clase: rombo de oro con la marca de la clase dibujada dentro.
class Emblema:
	extends Control
	var clase: StringName = &"bastion"
	var seleccionado := false
	var tamano := 78.0

	func _init(c: StringName, t := 78.0) -> void:
		clase = c
		tamano = t
		custom_minimum_size = Vector2(tamano, tamano)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := tamano * 0.46
		var puntos := PackedVector2Array([
			c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0),
		])
		var relleno := Color(0.16, 0.05, 0.04, 0.95) if seleccionado else Color(0.09, 0.08, 0.07, 0.95)
		draw_colored_polygon(puntos, relleno)
		var borde := ForjaTema.ORO_CLARO if seleccionado else ForjaTema.ORO_OSCURO
		var trazo := 2.4 if seleccionado else 1.4
		for i in 4:
			draw_line(puntos[i], puntos[(i + 1) % 4], borde, trazo)
		if seleccionado:
			draw_line(puntos[0], puntos[(0 + 1) % 4], Color(1, 0.95, 0.8), 1.0)
			draw_line(puntos[2], puntos[(2 + 1) % 4], Color(1, 0.95, 0.8), 1.0)
		_marca(c, r * 0.62, borde)

	func _marca(c: Vector2, r: float, color: Color) -> void:
		match clase:
			&"bastion":
				# Escudo: rectángulo con punta inferior.
				var ancho := r * 0.62
				var alto := r * 0.78
				var arriba := c - Vector2(0, alto * 0.62)
				draw_line(arriba + Vector2(-ancho, 0), arriba + Vector2(ancho, 0), color, 2.0)
				draw_line(arriba + Vector2(-ancho, 0), c + Vector2(-ancho, alto * 0.30), color, 2.0)
				draw_line(arriba + Vector2(ancho, 0), c + Vector2(ancho, alto * 0.30), color, 2.0)
				draw_line(c + Vector2(-ancho, alto * 0.30), c + Vector2(0, alto * 0.95), color, 2.0)
				draw_line(c + Vector2(ancho, alto * 0.30), c + Vector2(0, alto * 0.95), color, 2.0)
			&"filo":
				# Espada: hoja, guarda y empuñadura.
				draw_line(c + Vector2(0, -r * 0.92), c + Vector2(0, r * 0.44), color, 2.2)
				draw_line(c + Vector2(-r * 0.42, r * 0.20), c + Vector2(r * 0.42, r * 0.20), color, 2.0)
				draw_line(c + Vector2(0, r * 0.44), c + Vector2(0, r * 0.86), color, 2.2)
				draw_line(c + Vector2(-0.14 * r, -r * 0.78), c + Vector2(0.14 * r, -r * 0.78), color, 1.6)
			&"cetro":
				# Orbe con aura y asta.
				draw_arc(c - Vector2(0, r * 0.22), r * 0.40, 0.0, TAU, 28, color, 2.0)
				draw_line(c + Vector2(0, r * 0.18), c + Vector2(0, r * 0.9), color, 2.0)
				for i in 6:
					var a := TAU * float(i) / 6.0 - 0.4
					draw_line(
						c - Vector2(0, r * 0.22) + Vector2(cos(a), sin(a)) * r * 0.62,
						c - Vector2(0, r * 0.22) + Vector2(cos(a), sin(a)) * r * 0.86,
						Color(color.r, color.g, color.b, 0.75), 1.4
					)
			_:
				draw_arc(c, r * 0.5, 0.0, TAU, 24, color, 2.0)


## Aro de runas del joystick: círculo grabado con muescas y una aguja que marca
## la dirección que se está empujando. Sustituye a un círculo liso: en pantalla
## pequeña el jugador necesita ver hacia dónde va sin mirarse el pulgar.
class AroRunas:
	extends Control
	var radio := 104.0
	var direccion := Vector2.ZERO
	var escala := 1.0

	func _init(r := 104.0) -> void:
		radio = r
		custom_minimum_size = Vector2(radio, radio) * 2.0
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := radio * escala
		draw_circle(c, r, Color(0.055, 0.047, 0.040, 0.62))
		draw_arc(c, r, 0.0, TAU, 64, Color(ForjaTema.ORO_OSCURO.r, ForjaTema.ORO_OSCURO.g, ForjaTema.ORO_OSCURO.b, 0.9), 2.0)
		draw_arc(c, r * 0.78, 0.0, TAU, 48, Color(ForjaTema.ORO.r, ForjaTema.ORO.g, ForjaTema.ORO.b, 0.28), 1.0)
		for i in 12:
			var a := TAU * float(i) / 12.0
			var largo := r * (0.16 if i % 3 == 0 else 0.08)
			var desde := c + Vector2(cos(a), sin(a)) * (r - largo)
			var hasta := c + Vector2(cos(a), sin(a)) * (r - 2.0)
			draw_line(desde, hasta, Color(ForjaTema.ORO.r, ForjaTema.ORO.g, ForjaTema.ORO.b, 0.55), 2.0 if i % 3 == 0 else 1.0)
		# Cruz tenue del centro.
		draw_line(c - Vector2(r * 0.18, 0), c + Vector2(r * 0.18, 0), Color(1, 0.95, 0.85, 0.12), 1.0)
		draw_line(c - Vector2(0, r * 0.18), c + Vector2(0, r * 0.18), Color(1, 0.95, 0.85, 0.12), 1.0)
		if direccion.length_squared() > 0.001:
			var punta := c + direccion * r * 0.92
			draw_line(c, punta, Color(ForjaTema.ORO_CLARO.r, ForjaTema.ORO_CLARO.g, ForjaTema.ORO_CLARO.b, 0.75), 3.0)
			draw_circle(punta, 5.0, ForjaTema.ORO_CLARO)
