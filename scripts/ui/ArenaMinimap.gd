class_name ArenaMinimap
extends Control
## Radar 2D del patio: jugador, estandarte, enemigos, armería y mercader.
## Se dibuja con primitivas para no depender de texturas ni shaders.

const ANCHO_ARENA := 44.0
const LARGO_ARENA := 32.0

var _jugador: GladiatorController
var _bandera: RebellionBanner
var _tiempo := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func set_jugador(jugador: GladiatorController) -> void:
	_jugador = jugador


func set_bandera(bandera: RebellionBanner) -> void:
	_bandera = bandera


func _process(delta: float) -> void:
	_tiempo += delta
	if _tiempo >= 0.1:
		_tiempo = 0.0
		queue_redraw()


func _draw() -> void:
	var fuente := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.045, 0.04, 0.96), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.4, 0.22), false, 2.0)
	draw_string(fuente, Vector2(8, 15), "MAPA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.86, 0.68, 0.32))

	var margen := 8.0
	var area := Vector2(size.x - margen * 2.0, size.y - margen * 2.0 - 12.0)
	var escala := minf(area.x / ANCHO_ARENA, area.y / LARGO_ARENA)
	var centro := Vector2(size.x * 0.5, 12.0 + area.y * 0.5 + margen)
	var mitad := Vector2(ANCHO_ARENA * 0.5 * escala, LARGO_ARENA * 0.5 * escala)
	var patio := Rect2(centro - mitad, mitad * 2.0)
	draw_rect(patio, Color(0.22, 0.18, 0.14), true)
	draw_rect(patio, Color(0.5, 0.42, 0.3), false, 1.0)
	# Anillo del estandarte.
	draw_circle(centro, 5.0 * escala, Color(0.42, 0.33, 0.2, 0.55))

	if _bandera != null and is_instance_valid(_bandera):
		var p := _a_mapa(_bandera.global_position, centro, escala)
		draw_circle(p, 4.0, Color(0.85, 0.25, 0.18))

	for nodo in get_tree().get_nodes_in_group("enemigos"):
		var enemigo := nodo as Node3D
		if enemigo == null:
			continue
		var p := _a_mapa(enemigo.global_position, centro, escala)
		var jefe := enemigo.has_method("configurar_para_ronda")
		draw_circle(p, 3.2 if jefe else 2.2, Color(1.0, 0.35, 0.28) if jefe else Color(0.9, 0.22, 0.18))

	for nodo in get_tree().get_nodes_in_group("pedestales"):
		var pedestal := nodo as Node3D
		if pedestal == null:
			continue
		var p := _a_mapa(pedestal.global_position, centro, escala)
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0.85, 0.68, 0.32), true)

	for nodo in get_tree().get_nodes_in_group("tiendas"):
		var tienda := nodo as Node3D
		if tienda == null:
			continue
		var p := _a_mapa(tienda.global_position, centro, escala)
		draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0.4, 0.8, 0.9), true)

	if _jugador != null and is_instance_valid(_jugador):
		var p := _a_mapa(_jugador.global_position, centro, escala)
		draw_circle(p, 4.2, Color(0.4, 0.95, 0.5))
		draw_arc(p, 6.0, 0.0, TAU, 16, Color(0.85, 0.75, 0.4), 1.0)


func _a_mapa(posicion: Vector3, centro: Vector2, escala: float) -> Vector2:
	return centro + Vector2(posicion.x, posicion.z) * escala
