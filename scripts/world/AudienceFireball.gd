class_name AudienceFireball
extends Node3D
## Proyectil de fuego lanzado por el público cuando abuchea (anti-camping).
## Pooled: nunca se libera, se devuelve al ObjectPool.

var _velocidad := 13.0
var _destino := Vector3.ZERO
var _direccion := Vector3.ZERO
var _jugador: GladiatorController
var _dano := 14.0
var _pool: ObjectPool
var _vida := 5.0


static func crear() -> AudienceFireball:
	var bola := AudienceFireball.new()
	bola._construir()
	return bola


func _construir() -> void:
	var malla := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.35
	esfera.height = 0.7
	malla.mesh = esfera
	malla.position.y = 0.0
	var fuego := StandardMaterial3D.new()
	fuego.albedo_color = Color(1.0, 0.45, 0.10)
	fuego.emission_enabled = true
	fuego.emission = Color(1.0, 0.35, 0.05)
	fuego.emission_energy_multiplier = 4.0
	malla.material_override = fuego
	add_child(malla)


func lanzar(
	origen: Vector3,
	destino: Vector3,
	jugador: GladiatorController,
	dano: float,
	pool: ObjectPool
) -> void:
	global_position = origen
	_destino = destino
	_direccion = (destino - origen).normalized()
	_jugador = jugador
	_dano = dano
	_pool = pool
	_vida = 5.0


func al_obtener() -> void:
	_vida = 5.0


func _physics_process(delta: float) -> void:
	global_position += _direccion * _velocidad * delta
	rotate_y(delta * 8.0)
	_vida -= delta

	if _vida <= 0.0 or global_position.distance_to(_destino) < 0.7:
		_explotar()


func _explotar() -> void:
	if _jugador != null and is_instance_valid(_jugador) and not _jugador.esta_muerto:
		if _jugador.global_position.distance_to(global_position) <= 2.2:
			_jugador.recibir_dano(_dano, GladiatorStats.TIPO_FISICO, null)

	if _pool != null:
		_pool.devolver(self)
