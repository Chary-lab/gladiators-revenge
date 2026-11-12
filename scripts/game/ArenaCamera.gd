class_name ArenaCamera
extends Camera3D
## Cámara isométrica fija (ortográfica, 45° de giro) que sigue al gladiador.

@export var desplazamiento := Vector3(13.0, 15.0, 13.0)
@export var suavizado := 6.0
## Límites del centro de cámara para no enseñar el vacío fuera de la arena.
@export var limites := Vector2(16.0, 4.0)

var objetivo: Node3D

## Screen shake: sacude la cámara al recibir daño o activar furia del jefe.
var _shake_timer := 0.0
var _shake_intensity := 0.0
var _shake_decay := 8.0
var _shake_offset := Vector3.ZERO


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = 22.0
	rotation_degrees = Vector3(-42.0, 45.0, 0.0)
	near = 0.1
	far = 300.0


func _physics_process(delta: float) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		return
	var centro := objetivo.global_position
	centro.x = clampf(centro.x, -limites.x, limites.x)
	centro.z = clampf(centro.z, -limites.y, limites.y)
	var destino := centro + desplazamiento

	# Aplicar screen shake si está activo
	if _shake_timer > 0.0:
		_shake_timer = maxf(0.0, _shake_timer - delta)
		var shake_x = randf_range(-_shake_intensity, _shake_intensity)
		var shake_z = randf_range(-_shake_intensity, _shake_intensity)
		_shake_offset = Vector3(shake_x, 0.0, shake_z)
		_shake_intensity = maxf(0.0, _shake_intensity - delta * _shake_decay)
	else:
		_shake_offset = Vector3.ZERO

	destino += _shake_offset
	global_position = global_position.lerp(destino, 1.0 - exp(-suavizado * delta))
