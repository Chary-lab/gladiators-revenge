class_name CharacterVisual
extends Node3D
## Envoltorio de los personajes KayKit (GLB con esqueleto y animaciones).
##
## Responsabilidades:
##  - Instanciar el modelo y localizar Skeleton3D / AnimationPlayer / slots de mano.
##  - Ocultar el equipo por defecto del pack (armas, escudos, sombreros).
##  - Aplicar la skin como tinte de material (el atlas es un gradiente único).
##  - Reproducir locomoción y acciones de una sola vez con crossfade.
##  - Anclar el arma del juego al hueso de la mano derecha.

const ANIM_IDLE := &"Idle"
const ANIM_RUN := &"Running_A"
const ANIM_ATTACK_2H := &"2H_Melee_Attack_Chop"
const ANIM_ATTACK_1H := &"1H_Melee_Attack_Slice_Diagonal"
const ANIM_CAST := &"Spellcast_Shoot"
const ANIM_SUMMON := &"Spellcast_Summon"
const ANIM_HIT := &"Hit_A"
const ANIM_DEATH := &"Death_A"

const ANIMACIONES_LOOP := [&"Idle", &"Idle_B", &"Idle_Combat", &"Running_A", &"Running_B", &"Walking_A", &"Walking_B", &"Unarmed_Idle", &"2H_Melee_Idle"]

var esqueleto: Skeleton3D
var animador: AnimationPlayer
var mano_derecha: BoneAttachment3D
var mano_izquierda: BoneAttachment3D

var _raiz: Node3D
var _anim_idle: StringName = ANIM_IDLE
var _anim_run: StringName = ANIM_RUN
var _anim_ataque: StringName = ANIM_ATTACK_2H
var _anim_lanzar: StringName = ANIM_CAST
var _anim_muerte: StringName = ANIM_DEATH
var _en_accion := false
var _muerto := false
var _anim_en_curso: StringName = &""
var _arma: Node3D
var _tinte := Color.WHITE


## Caché de escenas por ruta: `load()` de un GLB cuesta ~55 ms la primera
## vez (medido) y eso se notaba como tirón al invocar al espíritu.
static var _escenas: Dictionary = {}


## Carga en disco una o varias rutas para que el primer uso sea instantáneo.
static func precargar(rutas: Array) -> void:
	for ruta in rutas:
		_obtener_escena(str(ruta))


static func _obtener_escena(ruta: String) -> PackedScene:
	# Con el renderer dummy (headless) la caché estática no aporta velocidad y
	# deja una retahíla de "Parameter \"material\" is null" en el log de pruebas.
	if DisplayServer.get_name() == "headless":
		return load(ruta) as PackedScene
	if _escenas.has(ruta):
		return _escenas[ruta] as PackedScene
	var escena := load(ruta) as PackedScene
	_escenas[ruta] = escena
	return escena


## Crea el visual. `perfil` permite elegir animaciones según el tipo de modelo:
##   "barbaro", "esqueleto", "caballero" o "mago".
func configurar(ruta_modelo: String, tinte: Color = Color.WHITE, perfil: String = "barbaro") -> CharacterVisual:
	var escena := _obtener_escena(ruta_modelo)
	if escena == null:
		push_error("CharacterVisual: no se pudo cargar " + ruta_modelo)
		return self

	_raiz = escena.instantiate() as Node3D
	if _raiz == null:
		push_error("CharacterVisual: el modelo no es Node3D: " + ruta_modelo)
		return self
	add_child(_raiz)

	esqueleto = _raiz.find_child("Skeleton3D", true, false) as Skeleton3D
	animador = _raiz.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if esqueleto == null or animador == null:
		push_error("CharacterVisual: falta Skeleton3D o AnimationPlayer en " + ruta_modelo)
		return self

	mano_derecha = esqueleto.find_child("handslot_r", true, false) as BoneAttachment3D
	mano_izquierda = esqueleto.find_child("handslot_l", true, false) as BoneAttachment3D

	_ocultar_equipo_por_defecto()
	_aplicar_tinte(tinte)
	_configurar_perfil(perfil)
	_preparar_animaciones()

	animador.animation_finished.connect(_al_terminar_animacion)
	_reproducir(_anim_idle, 0.0, true)
	return self


func _configurar_perfil(perfil: String) -> void:
	match perfil:
		"esqueleto":
			_anim_ataque = ANIM_ATTACK_1H
			_anim_lanzar = &"Spellcast_Raise"
		"mago":
			_anim_ataque = &"Spellcast_Shoot"
			_anim_lanzar = ANIM_SUMMON
		"caballero":
			_anim_ataque = ANIM_ATTACK_2H
			_anim_lanzar = &"Spellcast_Raise"
		_:
			_anim_ataque = ANIM_ATTACK_2H
			_anim_lanzar = ANIM_CAST

	if not animador.has_animation(_anim_muerte):
		_anim_muerte = &"Death_B"
	if not animador.has_animation(_anim_idle):
		_anim_idle = &"Unarmed_Idle"


func _preparar_animaciones() -> void:
	for nombre in ANIMACIONES_LOOP:
		if animador.has_animation(nombre):
			animador.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
	for nombre in [ANIM_ATTACK_2H, ANIM_ATTACK_1H, ANIM_CAST, ANIM_SUMMON, ANIM_HIT, ANIM_DEATH, &"Death_B", &"Spellcast_Raise", &"2H_Melee_Attack_Spin"]:
		if animador.has_animation(nombre):
			animador.get_animation(nombre).loop_mode = Animation.LOOP_NONE
	animador.playback_default_blend_time = 0.15


## Oculta armas y equipo que el pack trae visibles por defecto.
func _ocultar_equipo_por_defecto() -> void:
	for nodo in esqueleto.get_children():
		if nodo is BoneAttachment3D:
			for hijo in nodo.get_children():
				if hijo is MeshInstance3D:
					(hijo as MeshInstance3D).visible = false


## El atlas de KayKit es un gradiente: multiplicar el albedo da skins coherentes
## sin duplicar texturas ni mallas.
func _aplicar_tinte(tinte: Color) -> void:
	_tinte = tinte
	for nodo in _raiz.find_children("*", "MeshInstance3D", true, false):
		var malla := nodo as MeshInstance3D
		var material := _material_de(malla)
		if material == null:
			continue
		var copia := material.duplicate() as BaseMaterial3D
		var es_cabeza := "head" in malla.name.to_lower()
		copia.albedo_color = tinte if es_cabeza else tinte.lerp(Color.WHITE, 0.65)
		malla.material_override = copia


func _material_de(malla: MeshInstance3D) -> BaseMaterial3D:
	if malla.material_override is BaseMaterial3D:
		return malla.material_override as BaseMaterial3D
	if malla.mesh == null:
		return null
	for i in malla.mesh.get_surface_count():
		var material := malla.get_active_material(i)
		if material is BaseMaterial3D:
			return material as BaseMaterial3D
	return null


## Cambia la skin en caliente.
func aplicar_skin(tinte: Color) -> void:
	_aplicar_tinte(tinte)


# --- Locomoción y acciones -------------------------------------------------

## Actualiza idle/run sin interrumpir una acción de una sola vez.
func mover(velocidad: float) -> void:
	if _muerto or _en_accion:
		return
	var objetivo := _anim_run if velocidad > 0.2 else _anim_idle
	if not animador.has_animation(objetivo):
		objetivo = _anim_idle
	if animador.current_animation != objetivo:
		_reproducir(objetivo, 0.15, true)


## Elige el clip de ataque según el arma equipada (pesada o ligera).
func usar_arma_pesada(pesada: bool) -> void:
	_anim_ataque = ANIM_ATTACK_2H if pesada else ANIM_ATTACK_1H


func atacar() -> void:
	_una_vez(_anim_ataque)


func lanzar() -> void:
	_una_vez(_anim_lanzar)


func recibir_golpe() -> void:
	if _muerto:
		return
	_una_vez(ANIM_HIT)


func morir() -> void:
	if _muerto:
		return
	_muerto = true
	_en_accion = true
	_reproducir(_anim_muerte, 0.1, false)
	animador.speed_scale = 1.0


func esta_muerto() -> bool:
	return _muerto


## Devuelve el modelo a la vida al reutilizarlo desde el pool.
func revivir() -> void:
	_muerto = false
	_en_accion = false
	_anim_en_curso = &""
	if animador != null:
		animador.speed_scale = 1.0
		_reproducir(_anim_idle, 0.0, true)


func _una_vez(nombre: StringName) -> void:
	if _muerto:
		return
	if not animador.has_animation(nombre):
		return
	_en_accion = true
	_anim_en_curso = nombre
	_reproducir(nombre, 0.08, false)


func _al_terminar_animacion(nombre: StringName) -> void:
	if nombre == _anim_muerte:
		return
	if nombre == _anim_en_curso:
		_en_accion = false
		_anim_en_curso = &""
		_reproducir(_anim_idle, 0.15, true)


func _reproducir(nombre: StringName, mezcla: float, bucle: bool) -> void:
	if not animador.has_animation(nombre):
		return
	var animacion := animador.get_animation(nombre)
	if animacion != null:
		animacion.loop_mode = Animation.LOOP_LINEAR if bucle else Animation.LOOP_NONE
	animador.play(nombre, mezcla)


# --- Arma ------------------------------------------------------------------

## Ancla un arma al hueso de la mano derecha. `rotacion` y `escala` compensan
## la orientación concreta de cada GLB de arma.
func equipar_arma(escena: PackedScene, rotacion: Vector3 = Vector3.ZERO, escala: float = 1.0) -> void:
	if _arma != null and is_instance_valid(_arma):
		_arma.queue_free()
		_arma = null
	if escena == null or mano_derecha == null:
		return

	var arma := escena.instantiate() as Node3D
	if arma == null:
		return
	mano_derecha.add_child(arma)
	arma.position = Vector3.ZERO
	arma.rotation_degrees = rotacion
	arma.scale = Vector3.ONE * escala
	_arma = arma


func arma_actual() -> Node3D:
	return _arma


## Añade colmillos al hueso de la cabeza para convertir al bárbaro en orco.
func anadir_colmillos() -> void:
	var cabeza := esqueleto.find_child("head", true, false) as BoneAttachment3D
	if cabeza == null:
		return

	for lado in [-1.0, 1.0]:
		var colmillo := MeshInstance3D.new()
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = 0.032
		cono.height = 0.16
		cono.radial_segments = 6
		colmillo.mesh = cono
		var marfil := StandardMaterial3D.new()
		marfil.albedo_color = Color(0.93, 0.88, 0.72)
		marfil.roughness = 0.6
		colmillo.material_override = marfil
		colmillo.position = Vector3(0.10 * lado, 0.02, 0.12)
		colmillo.rotation_degrees = Vector3(-18.0, 0.0, -12.0 * lado)
		cabeza.add_child(colmillo)
