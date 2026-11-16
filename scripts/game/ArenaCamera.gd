class_name ArenaCamera
extends Camera3D
## Cámara isométrica fija (ortográfica, 45° de giro) que sigue al gladiador.
##
## El shake es visual: se aplica como offset sobre la posición base, nunca se
## acumula en ella. La intensidad es trauma², así un golpe leve casi no mueve y
## un crítico pega sin marear. El decaimiento usa tiempo real
## (delta / Engine.time_scale) para que no se congele durante un hit-stop.

@export var desplazamiento := Vector3(13.0, 15.0, 13.0)
@export var suavizado := 6.0
## Límites del centro de cámara para no enseñar el vacío fuera de la arena.
@export var limites := Vector2(16.0, 4.0)
## 0 = sin temblor (accesibilidad), 1 = intensidad completa.
@export var intensidad_shake := 1.0
@export var trauma_decaimiento := 1.8
@export var movimiento_maximo := 0.45
@export var giro_maximo := 0.012

var objetivo: Node3D

var trauma := 0.0
var _t := 0.0
var _base_position := Vector3.ZERO
var _shake_offset := Vector3.ZERO


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = 22.0
	rotation_degrees = Vector3(-42.0, 45.0, 0.0)
	near = 0.1
	far = 300.0
	_base_position = global_position


## Suma trauma en vez de reemplazarlo: dos impactos seguidos se acumulan y
## ninguno deja la cámara girada al terminar.
func agitar(cantidad := 0.35) -> void:
	trauma = clampf(trauma + maxf(0.0, cantidad), 0.0, 1.0)


func ajustar_intensidad(valor: float) -> void:
	intensidad_shake = clampf(valor, 0.0, 1.0)


func _process(delta: float) -> void:
	if trauma <= 0.0:
		_shake_offset = Vector3.ZERO
		rotation.z = 0.0
		return
	var real := delta / maxf(Engine.time_scale, 0.0001)
	trauma = maxf(trauma - trauma_decaimiento * real, 0.0)
	var fuerza := trauma * trauma * intensidad_shake
	_t += real * 26.0
	# Senos a frecuencias distintas: movimiento orgánico sin saltos por frame.
	_shake_offset = Vector3(
		movimiento_maximo * fuerza * sin(_t * 1.7),
		movimiento_maximo * 0.35 * fuerza * sin(_t * 2.9),
		movimiento_maximo * fuerza * sin(_t * 2.3)
	)
	rotation.z = giro_maximo * fuerza * sin(_t * 1.1)
	global_position = _base_position + _shake_offset
	if trauma <= 0.0:
		_shake_offset = Vector3.ZERO
		rotation.z = 0.0
		global_position = _base_position


func _physics_process(delta: float) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		return
	var centro := objetivo.global_position
	centro.x = clampf(centro.x, -limites.x, limites.x)
	centro.z = clampf(centro.z, -limites.y, limites.y)
	var destino := centro + desplazamiento
	_base_position = _base_position.lerp(destino, 1.0 - exp(-suavizado * delta))
	global_position = _base_position + _shake_offset
