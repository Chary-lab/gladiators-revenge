class_name SpiritBolt
extends Node3D
## Proyectil espectral reutilizable del Espíritu Ancestral. Persigue al
## objetivo y aplica daño mágico al impactar. Usa un pool estático para no
## crear basura en el navegador.

const VELOCIDAD := 17.0
const VIDA_MAXIMA := 2.2

static var _pool: Array[SpiritBolt] = []
static var _pool_creado := false

var _objetivo: Node3D
var _dano := 1.0
var _dueno: GladiatorController
var _vida := VIDA_MAXIMA
var _activo := false
var _luz: OmniLight3D
var _esfera: MeshInstance3D


static func disparar(
	origen: Vector3,
	objetivo: Node3D,
	dano: float,
	dueno: GladiatorController,
	color: Color = Color(0.35, 1.0, 0.82)
) -> SpiritBolt:
	if not _pool_creado:
		_pool_creado = true
		var arbol := Engine.get_main_loop() as SceneTree
		if arbol != null:
			arbol.root.tree_exiting.connect(_limpiar)

	var rayo: SpiritBolt = null
	while not _pool.is_empty():
		var candidato: SpiritBolt = _pool.pop_back()
		if is_instance_valid(candidato):
			rayo = candidato
			break
	if rayo == null:
		rayo = SpiritBolt.new()
		rayo.name = "DardoAncestral"
		rayo._construir()
		var arbol := Engine.get_main_loop() as SceneTree
		if arbol != null and arbol.current_scene != null:
			arbol.current_scene.add_child(rayo)

	rayo.global_position = origen
	rayo._objetivo = objetivo
	rayo._dano = maxf(1.0, dano)
	rayo._dueno = dueno
	rayo._vida = VIDA_MAXIMA
	rayo._activo = true
	rayo.visible = true
	rayo.set_process(true)
	rayo._aplicar_color(color)
	return rayo


func _construir() -> void:
	_esfera = MeshInstance3D.new()
	var malla := SphereMesh.new()
	malla.radius = 0.16
	malla.height = 0.32
	malla.radial_segments = 8
	malla.rings = 4
	_esfera.mesh = malla
	add_child(_esfera)

	_luz = OmniLight3D.new()
	_luz.light_color = Color(0.35, 1.0, 0.82)
	_luz.light_energy = 0.9
	_luz.omni_range = 2.4
	_luz.shadow_enabled = false
	add_child(_luz)
	_aplicar_color(Color(0.35, 1.0, 0.82))


func _aplicar_color(color: Color) -> void:
	if _esfera == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.4
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_esfera.material_override = material


func _process(delta: float) -> void:
	if not _activo:
		return
	_vida -= delta
	if _vida <= 0.0 or _objetivo == null or not is_instance_valid(_objetivo):
		_reciclar()
		return
	if _objetivo.get("esta_muerto") == true:
		_reciclar()
		return

	var destino := _objetivo.global_position + Vector3(0, 1.0, 0)
	var direccion := destino - global_position
	var distancia := direccion.length()
	if distancia <= 0.55:
		_impactar()
		return
	if distancia > 0.001:
		global_position += direccion.normalized() * VELOCIDAD * delta
	rotate_y(delta * 9.0)


func _impactar() -> void:
	if _objetivo != null and is_instance_valid(_objetivo) and _objetivo.has_method("recibir_dano"):
		_objetivo.recibir_dano(_dano, GladiatorStats.TIPO_MAGICO, _dueno)
		if _dueno != null and is_instance_valid(_dueno):
			_dueno.registrar_dano(_dano)
	_reciclar()


func _reciclar() -> void:
	_activo = false
	_objetivo = null
	visible = false
	set_process(false)
	_pool.append(self)


static func _limpiar() -> void:
	for rayo in _pool:
		if is_instance_valid(rayo):
			rayo.queue_free()
	_pool.clear()
	_pool_creado = false
