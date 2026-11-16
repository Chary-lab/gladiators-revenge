class_name SafeArea
extends RefCounted
## Convierte el rect de pantalla segura del dispositivo a coordenadas del
## viewport y coloca un Control diseñado en 1280×720 dentro de él.
##
## En escritorio `get_display_safe_area()` cubre toda la ventana, así que el
## marco queda exactamente igual que antes. En móvil (notch, esquinas curvas)
## el marco se escala de forma uniforme y se centra dentro del área segura.

const ANCHO_DISENO := 1280.0
const ALTO_DISENO := 720.0


## Rect segura en coordenadas del viewport. Si el sistema no reporta un área
## válida (headless, escritorio, ventana sin inicializar), devuelve el viewport
## completo para no mover nada.
static func area_en_viewport(viewport: Vector2) -> Rect2:
	var completo := Rect2(Vector2.ZERO, viewport)
	var area: Rect2i = DisplayServer.get_display_safe_area()
	var ventana: Vector2 = Vector2(DisplayServer.window_get_size())
	if area.size.x <= 0 or area.size.y <= 0 or ventana.x <= 0.0 or ventana.y <= 0.0:
		return completo

	var factor := viewport / ventana
	var inicio := Vector2(area.position) * factor
	var fin := (Vector2(area.position) + Vector2(area.size)) * factor
	inicio.x = clampf(inicio.x, 0.0, viewport.x)
	inicio.y = clampf(inicio.y, 0.0, viewport.y)
	fin.x = clampf(fin.x, inicio.x, viewport.x)
	fin.y = clampf(fin.y, inicio.y, viewport.y)
	if fin.x <= inicio.x or fin.y <= inicio.y:
		return completo
	return Rect2(inicio, fin - inicio)


## Rect final del marco en coordenadas del viewport.
static func marco(viewport: Vector2, ancho: float, alto: float) -> Rect2:
	var area := area_en_viewport(viewport)
	var escala := mini(area.size.x / ancho, area.size.y / alto)
	escala = maxf(escala, 0.1)
	var orig := area.position + (area.size - Vector2(ancho, alto) * escala) * 0.5
	return Rect2(orig, Vector2(ancho, alto) * escala)


## Coloca `control` (diseñado en `ancho`×`alto`) dentro del área segura.
static func aplicar(control: Control, ancho: float = ANCHO_DISENO, alto: float = ALTO_DISENO) -> void:
	if control == null or not control.is_inside_tree() or control.get_viewport() == null:
		return
	if ancho <= 0.0 or alto <= 0.0:
		return
	var viewport: Vector2 = control.get_viewport_rect().size
	var destino := marco(viewport, ancho, alto)

	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = ancho
	control.offset_bottom = alto
	control.position = destino.position
	control.scale = destino.size / Vector2(ancho, alto)
