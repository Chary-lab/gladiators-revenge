class_name ArenaCamera
extends Camera3D
## Cámara isométrica fija (ortográfica, 45° de giro) que sigue al gladiador.

@export var desplazamiento := Vector3(13.0, 15.0, 13.0)
@export var suavizado := 6.0
## Límites del centro de cámara para no enseñar el vacío fuera de la arena.
@export var limites := Vector2(17.0, 11.0)

var objetivo: Node3D


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = 28.0
	rotation_degrees = Vector3(-42.0, 45.0, 0.0)
	near = 0.1
	far = 300.0


func _physics_process(delta: float) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		return
	var destino := objetivo.global_position + desplazamiento
	destino.x = clampf(destino.x, -limites.x, limites.x)
	destino.z = clampf(destino.z, -limites.y, limites.y)
	global_position = global_position.lerp(destino, 1.0 - exp(-suavizado * delta))
