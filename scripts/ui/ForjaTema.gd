class_name ForjaTema
extends RefCounted
## Sistema visual del juego: la Forja de la Rebelión. Carbón cálido, oro viejo,
## ascua y sangre. Todo el HUD, el menú, la forja de campeones, la tienda y el
## HUD táctil toman de aquí la paleta, la tipografía, los estilos y las piezas
## dibujadas para que la interfaz se vea de una sola pieza.
##
## Reglas de la dirección de arte:
## - El fondo es carbón (nunca gris azulado); el oro es el único acento fuerte.
## - El ascua y el rojo solo marcan peligro, daño y sangre.
## - La rareza manda sobre el tipo de objeto: común, raro, épico y legendario
##   tienen color propio y se usan igual en tienda, inventario y tooltips.
## - Los títulos van en Cinzel (SIL OFL, `assets/ui/`); el cuerpo sigue en la
##   sans del motor porque se lee mejor en pantallas pequeñas.

# --- Paleta -----------------------------------------------------------------

const FONDO := Color(0.055, 0.047, 0.040)
const PANEL := Color(0.086, 0.075, 0.063, 0.97)
const PANEL_CLARO := Color(0.125, 0.107, 0.086, 0.96)
const PANEL_ALTO := Color(0.168, 0.142, 0.108, 0.97)
const ORO := Color(0.788, 0.635, 0.294)
const ORO_CLARO := Color(0.910, 0.784, 0.478)
const ORO_OSCURO := Color(0.396, 0.302, 0.125)
const ASCUA := Color(0.549, 0.165, 0.110)
const SANGRE := Color(0.639, 0.180, 0.145)
const VIDA := Color(0.694, 0.208, 0.169)
const MANA := Color(0.318, 0.514, 0.694)
const XP := Color(0.620, 0.380, 0.900)
const VERDE := Color(0.400, 0.780, 0.470)
const TEXTO := Color(0.847, 0.804, 0.729)
const TEXTO_FUERTE := Color(0.945, 0.906, 0.827)
const TENUE := Color(0.624, 0.560, 0.470)
const TINTA := Color(0.070, 0.060, 0.048)

## Colores de rareza: marcos, acentos y etiquetas de todo el juego.
const COLOR_RAREZA := {
	&"comun": Color(0.706, 0.663, 0.588),
	&"raro": Color(0.380, 0.720, 1.000),
	&"epico": Color(0.725, 0.525, 1.000),
	&"legendario": Color(1.000, 0.780, 0.300),
}
const NOMBRE_RAREZA := {
	&"comun": "Común",
	&"raro": "Raro",
	&"epico": "Épico",
	&"legendario": "Legendario",
}

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

const ROL_CLASE := {
	&"bastion": "TANQUE",
	&"filo": "VERDUGO",
	&"cetro": "CONVOCADOR",
	&"prisionero": "SIN CLASE",
}

const DESCRIPCION_CLASE := {
	&"bastion": "Aguanta el centro de la arena con escudo, provocación y golpes sísmicos.",
	&"filo": "Entra y sale del combate: dash, sangrado y crítico alto.",
	&"cetro": "Controla la distancia con proyectiles, espíritus y quemadura arcana.",
}

# --- Tipografía -------------------------------------------------------------

const RUTA_TITULO := "res://assets/ui/Cinzel-variable.ttf"

static var _fuente_titulo: Font = null
static var _fuente_etiqueta: Font = null
static var _tema: Theme = null
static var _grabber: Texture2D = null


## Cinzel, la tipografía de títulos grabados. Cae a la del motor si el archivo
## no está importado (tests viejos, export parcial).
static func fuente_titulo() -> Font:
	if _fuente_titulo != null:
		return _fuente_titulo
	if ResourceLoader.exists(RUTA_TITULO):
		var recurso = load(RUTA_TITULO)
		if recurso is Font:
			_fuente_titulo = recurso as Font
	if _fuente_titulo == null:
		_fuente_titulo = ThemeDB.fallback_font
	return _fuente_titulo


## Cinzel con tracking abierto: rótulos pequeños en versalitas.
static func fuente_etiqueta() -> Font:
	if _fuente_etiqueta != null:
		return _fuente_etiqueta
	var variacion := FontVariation.new()
	variacion.base_font = fuente_titulo()
	variacion.spacing_glyph = 2
	_fuente_etiqueta = variacion
	return _fuente_etiqueta


static func titulo(texto: String, tamano := 26, color := ORO_CLARO) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", fuente_titulo())
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.72))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Rótulo de sección: versalitas doradas con tracking.
static func rotulo(texto: String, tamano := 12, color := ORO) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", fuente_etiqueta())
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func etiqueta(texto: String, tamano := 14, color := TEXTO, centrado := false) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centrado:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# --- Estilos ----------------------------------------------------------------

static func estilo_panel(opacidad := 1.0, borde := ORO_OSCURO) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(PANEL.r, PANEL.g, PANEL.b, PANEL.a * opacidad)
	estilo.border_color = borde
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(3)
	estilo.content_margin_left = 18
	estilo.content_margin_right = 18
	estilo.content_margin_top = 14
	estilo.content_margin_bottom = 14
	return estilo


## Ventana principal: cuerpo oscuro, filo dorado y sombra profunda para
## despegar el panel de la arena.
static func estilo_ventana(acento := ORO_OSCURO, opacidad := 0.985) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.070, 0.061, 0.051, opacidad)
	estilo.border_color = acento
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(4)
	estilo.content_margin_left = 22
	estilo.content_margin_right = 22
	estilo.content_margin_top = 16
	estilo.content_margin_bottom = 16
	estilo.shadow_color = Color(0, 0, 0, 0.62)
	estilo.shadow_size = 14
	estilo.shadow_offset = Vector2(0, 6)
	return estilo


## Tarjeta de objeto: el filo toma el color de la rareza y, si está
## seleccionada, se enciende en oro con brillo.
static func estilo_tarjeta(acento := Color(0.706, 0.663, 0.588), seleccionada := false, elevada := false) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.145, 0.108, 0.058) if seleccionada else Color(0.098, 0.086, 0.074)
	if elevada and not seleccionada:
		estilo.bg_color = Color(0.135, 0.115, 0.092)
	estilo.border_color = ORO_CLARO if seleccionada else acento
	estilo.set_border_width_all(2 if seleccionada else 1)
	estilo.set_corner_radius_all(4)
	if seleccionada:
		estilo.shadow_color = Color(0, 0, 0, 0.5)
		estilo.shadow_size = 7
	else:
		estilo.shadow_color = Color(acento.r, acento.g, acento.b, 0.16)
		estilo.shadow_size = 4
	estilo.shadow_offset = Vector2(0, 2)
	return estilo


static func estilo_barra(valor: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = valor
	estilo.set_corner_radius_all(2)
	return estilo


## Botón con marco de oro: relleno oscuro y, al pulsar, oro lleno con tinta
## oscura. `destacado` lo pinta como acción principal.
static func boton(texto: String, tamano := 16, destacado := false) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", tamano)
	b.add_theme_color_override("font_color", TINTA if destacado else ORO_CLARO)
	b.add_theme_color_override("font_hover_color", TINTA if destacado else Color(1, 0.93, 0.78))
	b.add_theme_color_override("font_pressed_color", TINTA)
	b.add_theme_color_override("font_disabled_color", Color(0.42, 0.38, 0.32))

	var normal := StyleBoxFlat.new()
	normal.bg_color = ORO if destacado else Color(0.10, 0.09, 0.075, 0.9)
	normal.border_color = ORO if destacado else ORO_OSCURO
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_top = 9
	normal.content_margin_bottom = 9
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 3
	b.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ORO_CLARO if destacado else Color(0.17, 0.14, 0.10, 0.95)
	hover.border_color = ORO_CLARO
	hover.shadow_size = 6
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


## Esquinas grabadas: cuatro filigranas doradas dibujadas sobre un panel.
static func ornar(padre: Control, acento := ORO_OSCURO) -> void:
	if padre == null:
		return
	padre.add_child(EsquinasOrnadas.new(acento))


# --- Tema global ------------------------------------------------------------

## Tema compartido por todas las pantallas: la versión web y el APK usan el
## mismo. Se aplica en la raíz del árbol y cada CanvasLayer lo hereda.
static func tema_global() -> Theme:
	if _tema != null:
		return _tema
	var t := Theme.new()
	t.default_font_size = 14

	t.set_stylebox("normal", "Button", _estilo_boton(Color(0.115, 0.100, 0.084), ORO_OSCURO))
	t.set_stylebox("hover", "Button", _estilo_boton(Color(0.200, 0.160, 0.105), ORO))
	t.set_stylebox("pressed", "Button", _estilo_boton(Color(0.085, 0.072, 0.058), ORO_CLARO))
	t.set_stylebox("disabled", "Button", _estilo_boton(Color(0.085, 0.080, 0.074), Color(0.28, 0.25, 0.21)))
	t.set_stylebox("focus", "Button", _estilo_boton(Color(0, 0, 0, 0), ORO_CLARO))
	t.set_color("font_color", "Button", ORO_CLARO)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.94, 0.80))
	t.set_color("font_pressed_color", "Button", ORO)
	t.set_color("font_disabled_color", "Button", Color(0.44, 0.41, 0.36))
	t.set_font("font", "Button", fuente_etiqueta())
	t.set_font_size("font_size", "Button", 15)

	t.set_stylebox("panel", "Panel", estilo_panel())
	t.set_stylebox("panel", "PanelContainer", estilo_ventana())
	t.set_stylebox("panel", "TooltipPanel", estilo_ventana(ORO, 0.99))

	t.set_color("font_color", "Label", TEXTO)
	t.set_color("font_color", "RichTextLabel", TEXTO)
	t.set_color("default_color", "RichTextLabel", TEXTO)
	t.set_font_size("normal_font_size", "RichTextLabel", 12)
	t.set_color("font_color", "TooltipLabel", TEXTO)

	t.set_stylebox("background", "ProgressBar", _estilo_barra_fondo(18.0))
	t.set_stylebox("fill", "ProgressBar", estilo_barra(VIDA))
	t.set_color("font_color", "ProgressBar", TEXTO)

	t.set_stylebox("slider", "HSlider", _estilo_barra_fondo(26.0))
	t.set_stylebox("grabber_area", "HSlider", estilo_barra(Color(0.42, 0.32, 0.14)))
	t.set_stylebox("grabber_area_highlight", "HSlider", estilo_barra(ORO_OSCURO))
	t.set_icon("grabber", "HSlider", _icono_grabber(ORO))
	t.set_icon("grabber_highlight", "HSlider", _icono_grabber(ORO_CLARO))

	t.set_stylebox("separator", "HSeparator", _estilo_regla())
	t.set_constant("separation", "HSeparator", 8)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("scroll", "VScrollBar", _estilo_barra_fondo(8.0))
	t.set_stylebox("grabber", "VScrollBar", estilo_barra(Color(0.34, 0.27, 0.16)))
	t.set_stylebox("grabber_highlight", "VScrollBar", estilo_barra(ORO_OSCURO))
	t.set_stylebox("grabber_pressed", "VScrollBar", estilo_barra(ORO))

	_tema = t
	return t


## Aplica el tema compartido a un Control o Window (CanvasLayer no lo admite).
static func aplicar_tema(nodo: Node) -> void:
	if nodo is Control or nodo is Window:
		(nodo as Node).set("theme", tema_global())


static func _estilo_boton(fondo: Color, borde: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(3)
	estilo.content_margin_left = 14
	estilo.content_margin_right = 14
	estilo.content_margin_top = 8
	estilo.content_margin_bottom = 8
	return estilo


static func _estilo_barra_fondo(alto := 18.0) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.035, 0.030, 0.026, 0.95)
	estilo.border_color = Color(0.24, 0.20, 0.15)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(2)
	estilo.content_margin_top = maxf(0.0, (alto - 6.0) * 0.5)
	estilo.content_margin_bottom = estilo.content_margin_top
	return estilo


static func _estilo_regla() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(ORO_OSCURO.r, ORO_OSCURO.g, ORO_OSCURO.b, 0.55)
	estilo.content_margin_top = 1
	estilo.content_margin_bottom = 0
	return estilo


## Bola dorada del deslizador dibujada en una imagen mínima (sin assets).
static func _icono_grabber(color: Color) -> Texture2D:
	if _grabber != null:
		return _grabber
	var lado := 14
	var imagen := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	imagen.fill(Color(0, 0, 0, 0))
	var centro := Vector2(lado * 0.5 - 0.5, lado * 0.5 - 0.5)
	var radio := lado * 0.46
	for y in lado:
		for x in lado:
			var distancia := Vector2(x, y).distance_to(centro)
			if distancia > radio:
				continue
			var borde := distancia > radio - 2.0
			imagen.set_pixel(x, y, TINTA if borde else color)
	_grabber = ImageTexture.create_from_image(imagen)
	return _grabber


# --- Piezas dibujadas -------------------------------------------------------

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
		# Filo claro arriba: da volumen sin texturas.
		if valor > 0.0:
			draw_line(Vector2(1, 1), Vector2(maxf(1.0, ancho * valor - 1.0), 1), Color(1, 1, 1, 0.18), 1.0)
		draw_rect(
			Rect2(Vector2.ZERO, size),
			Color(ForjaTema.ORO_OSCURO.r, ForjaTema.ORO_OSCURO.g, ForjaTema.ORO_OSCURO.b, 0.8),
			false, 1.0
		)


## Velo de enfriamiento radial: dibuja el sector pendiente sobre el botón.
class VeloRadial:
	extends Control
	var fraccion := 0.0
	var color := Color(0.02, 0.02, 0.02, 0.62)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func fijar(f: float) -> void:
		var nuevo := clampf(f, 0.0, 1.0)
		visible = nuevo > 0.01
		if is_equal_approx(nuevo, fraccion):
			return
		fraccion = nuevo
		queue_redraw()

	func _draw() -> void:
		if fraccion <= 0.01:
			return
		var centro := size * 0.5
		var radio := minf(size.x, size.y) * 0.5
		var pasos := maxi(3, int(ceil(36.0 * fraccion)))
		var puntos := PackedVector2Array([centro])
		for i in pasos + 1:
			var angulo := -PI * 0.5 + TAU * fraccion * float(i) / float(pasos)
			puntos.append(centro + Vector2(cos(angulo), sin(angulo)) * radio)
		draw_colored_polygon(puntos, color)


## Emblema de clase: rombo de oro con la marca de la clase dibujada dentro.
class Emblema:
	extends Control
	var clase: StringName = &"bastion"
	var seleccionado := false
	var tamano := 78.0
	var atenuado := false

	func _init(c: StringName, t := 78.0) -> void:
		clase = c
		tamano = t
		custom_minimum_size = Vector2(tamano, tamano)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.46
		var puntos := PackedVector2Array([
			c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0),
		])
		var relleno := Color(0.16, 0.05, 0.04, 0.95) if seleccionado else Color(0.09, 0.08, 0.07, 0.95)
		if atenuado:
			relleno = Color(0.085, 0.075, 0.065, 0.95)
		if seleccionado:
			draw_circle(c, r * 1.22, Color(ForjaTema.ORO.r, ForjaTema.ORO.g, ForjaTema.ORO.b, 0.10))
			draw_circle(c, r * 1.02, Color(ForjaTema.ORO.r, ForjaTema.ORO.g, ForjaTema.ORO.b, 0.08))
		draw_colored_polygon(puntos, relleno)
		var borde := ForjaTema.ORO_CLARO if seleccionado else ForjaTema.ORO_OSCURO
		if atenuado:
			borde = Color(0.70, 0.58, 0.36, 0.95)
		var trazo := 2.4 if seleccionado else 1.4
		for i in 4:
			draw_line(puntos[i], puntos[(i + 1) % 4], borde, trazo)
		if seleccionado:
			var interior := r * 0.72
			var dentro := PackedVector2Array([
				c + Vector2(0, -interior), c + Vector2(interior, 0),
				c + Vector2(0, interior), c + Vector2(-interior, 0),
			])
			for i in 4:
				draw_line(dentro[i], dentro[(i + 1) % 4], Color(1, 0.95, 0.8, 0.55), 1.0)
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


## Cuatro esquinas grabadas: dos trazos y un remache por vértice.
class EsquinasOrnadas:
	extends Control
	var acento := ForjaTema.ORO_OSCURO
	var largo := 26.0

	func _init(color := ForjaTema.ORO_OSCURO, tamano := 26.0) -> void:
		acento = color
		largo = tamano
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var l := minf(largo, minf(w, h) * 0.25)
		if l <= 1.0:
			return
		var tenue := Color(acento.r, acento.g, acento.b, 0.45)
		var esquinas: Array[Vector2] = [Vector2(0, 0), Vector2(w - l, 0), Vector2(0, h - l), Vector2(w - l, h - l)]
		for esquina in esquinas:
			var x: float = esquina.x
			var y: float = esquina.y
			var sx: float = 1.0 if x <= 0.5 else -1.0
			var sy: float = 1.0 if y <= 0.5 else -1.0
			var hx: float = x if sx > 0.0 else x + l
			var hy: float = y if sy > 0.0 else y + l
			draw_line(Vector2(hx, hy), Vector2(hx + l * sx, hy), acento, 1.0)
			draw_line(Vector2(hx, hy), Vector2(hx, hy + l * sy), acento, 1.0)
			draw_line(Vector2(hx + 3.0 * sx, hy + 3.0 * sy), Vector2(hx + l * 0.7 * sx, hy + 3.0 * sy), tenue, 1.0)
			draw_circle(Vector2(hx + 5.0 * sx, hy + 5.0 * sy), 1.6, acento)


## Iconos de estadística dibujados con vectores: la fuente del motor no trae
## glifos de corazón, gota, espada ni escudo, y depender de emojis sale como
## cajas. `tipo` elige la forma; `tamano` el lado del cuadrado.
class IconoStat:
	extends Control
	var tipo: StringName = &"vida"
	var color := ForjaTema.VIDA
	var tamano := 18.0

	func _init(t: StringName = &"vida", lado := 18.0, tono := Color(0, 0, 0, 0)) -> void:
		tipo = t
		tamano = lado
		if tono.a > 0.0:
			color = tono
		custom_minimum_size = Vector2(tamano, tamano)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func fijar_color(tono: Color) -> void:
		color = tono
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		match tipo:
			&"vida":
				# Corazón: dos lóbulos y una punta.
				draw_circle(c + Vector2(-r * 0.40, -r * 0.28), r * 0.42, color)
				draw_circle(c + Vector2(r * 0.40, -r * 0.28), r * 0.42, color)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(-r * 0.82, -r * 0.14),
					c + Vector2(r * 0.82, -r * 0.14),
					c + Vector2(0, r * 0.92),
				]), color)
			&"mana":
				# Gota: punta arriba y cuerpo redondo.
				draw_circle(c + Vector2(0, r * 0.28), r * 0.58, color)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, -r * 0.95),
					c + Vector2(r * 0.56, r * 0.20),
					c + Vector2(-r * 0.56, r * 0.20),
				]), color)
			&"dano":
				# Espada vertical con guarda.
				draw_line(c + Vector2(0, -r * 0.95), c + Vector2(0, r * 0.55), color, maxf(1.5, r * 0.20))
				draw_line(c + Vector2(-r * 0.55, r * 0.20), c + Vector2(r * 0.55, r * 0.20), color, maxf(1.2, r * 0.16))
				draw_line(c + Vector2(0, r * 0.55), c + Vector2(0, r * 0.92), color, maxf(1.5, r * 0.20))
			&"defensa":
				# Escudo con punta.
				var ancho := r * 0.62
				var alto := r * 0.74
				var arriba := c - Vector2(0, alto * 0.66)
				var puntos := PackedVector2Array([
					arriba + Vector2(-ancho, 0),
					arriba + Vector2(ancho, 0),
					c + Vector2(ancho, alto * 0.28),
					c + Vector2(0, alto * 1.02),
					c + Vector2(-ancho, alto * 0.28),
				])
				for i in puntos.size():
					draw_line(puntos[i], puntos[(i + 1) % puntos.size()], color, maxf(1.2, r * 0.16))
			&"critico":
				# Estrella de cuatro puntas.
				var puntos := PackedVector2Array([
					c + Vector2(0, -r * 0.95), c + Vector2(r * 0.26, -r * 0.26),
					c + Vector2(r * 0.95, 0), c + Vector2(r * 0.26, r * 0.26),
					c + Vector2(0, r * 0.95), c + Vector2(-r * 0.26, r * 0.26),
					c + Vector2(-r * 0.95, 0), c + Vector2(-r * 0.26, -r * 0.26),
				])
				draw_colored_polygon(puntos, color)
			&"velocidad":
				# Dos galones de avance.
				for i in 2:
					var x := c.x - r * 0.5 + float(i) * r * 0.62
					draw_line(Vector2(x, c.y - r * 0.62), Vector2(x + r * 0.52, c.y), color, maxf(1.2, r * 0.18))
					draw_line(Vector2(x + r * 0.52, c.y), Vector2(x, c.y + r * 0.62), color, maxf(1.2, r * 0.18))
			&"oro":
				draw_arc(c, r * 0.78, 0.0, TAU, 24, color, maxf(1.2, r * 0.16))
				draw_arc(c, r * 0.42, 0.0, TAU, 18, Color(color.r, color.g, color.b, 0.55), 1.0)
			_:
				# Rombo de nivel.
				var puntos := PackedVector2Array([
					c + Vector2(0, -r * 0.9), c + Vector2(r * 0.9, 0),
					c + Vector2(0, r * 0.9), c + Vector2(-r * 0.9, 0),
				])
				draw_colored_polygon(puntos, color)
