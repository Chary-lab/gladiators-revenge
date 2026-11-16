class_name ReceptorGolpes3D
extends Area3D
## Hurtbox en una capa de colisión propia. No aplica daño por sí sola: recibe
## empujes de los sistemas de daño y los traduce a velocidad del CharacterBody3D
## dueño, para que el golpe se sienta en 3D sin duplicar la lógica de combate.
##
## Capas separadas (no se han cambiado las capas existentes del juego):
##   bit 4 (valor 8)  -> hitboxes
##   bit 5 (valor 16) -> hurtboxes

const CAPA_HITBOX := 1 << 3
const CAPA_HURTBOX := 1 << 4


func _init() -> void:
	collision_layer = CAPA_HURTBOX
	collision_mask = CAPA_HITBOX
	monitoring = true
	monitorable = true


## Configura el volumen de la zona. Se llama una vez al crear el componente.
func configurar(radio: float, altura: float = 1.8) -> void:
	for hijo: Node in get_children():
		hijo.queue_free()
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = maxf(0.2, radio)
	capsula.height = maxf(radio * 2.0, altura)
	forma.shape = capsula
	add_child(forma)


## Empuje real: suma velocidad al cuerpo dueño. El character body la amortigua
## en su propio `_physics_process`, así no hace falta un Tween por golpe.
func empujar(origen: Vector3, fuerza: float) -> void:
	if fuerza <= 0.0:
		return
	var dueno := get_parent()
	if dueno == null or not is_instance_valid(dueno):
		return
	if dueno.has_method("aplicar_empuje"):
		dueno.call("aplicar_empuje", origen, fuerza)
		return
	if dueno is CharacterBody3D:
		var lejos: Vector3 = (dueno as Node3D).global_position - origen
		lejos.y = 0.0
		if lejos.length_squared() > 0.0004:
			(dueno as CharacterBody3D).velocity += lejos.normalized() * fuerza
