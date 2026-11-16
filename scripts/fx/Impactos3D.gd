class_name Impactos3D
extends Node3D
## Ráfagas de impacto con CPUParticles3D (sin shaders que compilar en Web).
##
## Se crean 12 emisores una vez y se reciclan: instanciar partículas por golpe
## era un pico en móvil. El color y el tamaño se ajustan por impacto, pero la
## malla, el material y la textura Kenney se comparten entre todas las ráfagas.

const CANTIDAD_POOL := 12
const DURACION := 0.7

var _pool: ObjectPool
var _malla: QuadMesh
var _material_particula: StandardMaterial3D
var _textura: Texture2D


func _ready() -> void:
	_textura = load("res://assets/kenney/particles/flare_01.png") as Texture2D
	_malla = QuadMesh.new()
	_malla.size = Vector2(0.16, 0.16)
	_material_particula = StandardMaterial3D.new()
	_material_particula.albedo_texture = _textura
	_material_particula.albedo_color = Color(1, 1, 1, 1)
	_material_particula.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_particula.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_particula.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_material_particula.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_malla.material = _material_particula

	_pool = ObjectPool.new(Callable(self, "_crear_emisor"))
	add_child(_pool)
	_pool.precalentar(CANTIDAD_POOL)


func reproducir(posicion: Vector3, color: Color, escala := 1.0, cantidad := 12) -> void:
	if _pool == null:
		return
	var emisor := _pool.obtener() as CPUParticles3D
	if emisor == null:
		return
	emisor.emitting = false
	emisor.global_position = posicion
	emisor.scale = Vector3.ONE * escala
	emisor.amount = clampi(cantidad, 4, 28)
	emisor.color = color
	emisor.restart()
	emisor.emitting = true
	# `finished` llega una vez por ráfaga (one_shot) y devuelve el emisor al pool.
	if emisor.has_signal("finished"):
		if not emisor.is_connected("finished", Callable(self, "_al_terminar").bind(emisor)):
			emisor.connect("finished", Callable(self, "_al_terminar").bind(emisor))
	else:
		var temporizador := get_tree().create_timer(DURACION, true, false, true)
		temporizador.timeout.connect(func() -> void: _al_terminar(emisor))


func _crear_emisor() -> Node:
	var emisor := CPUParticles3D.new()
	emisor.one_shot = true
	emisor.emitting = false
	emisor.local_coords = false
	emisor.mesh = _malla
	# CPUParticles3D no usa ParticleProcessMaterial: todo son propiedades
	# directas, así no hay shaders que precompilar en Web.
	emisor.direction = Vector3(0.0, 1.0, 0.0)
	emisor.spread = 180.0
	emisor.initial_velocity_min = 1.8
	emisor.initial_velocity_max = 4.6
	emisor.gravity = Vector3(0.0, -7.0, 0.0)
	emisor.lifetime = DURACION * 0.7
	emisor.scale_amount_min = 0.5
	emisor.scale_amount_max = 1.4
	emisor.color = Color(1, 1, 1, 1)
	emisor.amount = 12
	return emisor


func _al_terminar(emisor = null) -> void:
	if emisor != null and _pool != null:
		_pool.devolver(emisor as Node)
