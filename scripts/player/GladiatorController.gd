class_name GladiatorController
extends CharacterBody3D
## Controlador del gladiador: movimiento por click derecho, atributos
## escalables, maná, daño recibido y lanzamiento de habilidades Q/W/E/R.
##
## Escena esperada:
##   GladiatorController (CharacterBody3D, en el grupo "gladiadores")
##   ├── NavigationAgent3D
##   └── Modelo (Node3D opcional: solo se gira el modelo, no el cuerpo)
##
## La arena se asume plana (Y = 0) y el movimiento se resuelve en el plano XZ
## con NavigationAgent3D. La cámara isométrica es responsabilidad de la escena.

signal salud_cambiada(actual: float, maxima: float)
signal mana_cambiada(actual: float, maximo: float)
signal arma_cambiada(arma: WeaponItem)
signal habilidad_lanzada(slot: int, habilidad: AbilityData)
signal ataque_basico(objetivo: Node3D, dano: float, critico: bool)
signal talentos_cambiados
signal murio

const SLOT_Q := 0
const SLOT_W := 1
const SLOT_E := 2
const SLOT_R := 3

const TECLAS_HABILIDAD: Dictionary = {
	KEY_Q: SLOT_Q,
	KEY_W: SLOT_W,
	KEY_E: SLOT_E,
	KEY_R: SLOT_R,
}

const GRUPO_GLADIADORES := &"gladiadores"
const GRUPO_ENEMIGOS := &"enemigos"
const ACELERACION := 30.0
const VELOCIDAD_GIRO := 10.0
const INTERVALO_REGENERACION := 0.25

@export_group("Datos")
@export var estadisticas: GladiatorStats
@export var arma_inicial: WeaponItem

@export_group("Aspecto")
## Modelo GLB del gladiador; se oculta la cápsula de bloqueo.
@export_file("*.glb") var ruta_modelo := "res://assets/kaykit/adventurers/Barbarian.glb"
@export var tinte_skin: Color = Color.WHITE

@export_group("Control")
@export var puede_moverse := true

@export_group("Progresión de combate")
## Puntos rojos: se auto-invierten en los talentos del arma equipada.
@export var puntos_rojos := 0

var salud_actual := 0.0
var mana_actual := 0.0
var arma_actual: WeaponItem
var esta_muerto := false
var visual: CharacterVisual

var _cooldowns := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _tiene_orden_movimiento := false
var _acumulador_regeneracion := 0.0
var _temporizador_ataque := 0.0
var _talentos_activos: Dictionary = {}
var _reduccion_temporal := 0.0
var _tiempo_reduccion := 0.0
var _critico_asegurado := 0.0

@onready var agente := $NavigationAgent3D as NavigationAgent3D
@onready var modelo := get_node_or_null("Modelo") as Node3D


func _ready() -> void:
	add_to_group(GRUPO_GLADIADORES)
	if estadisticas == null:
		estadisticas = GladiatorStats.new()
	if not estadisticas.atributos_cambiados.is_connected(_al_cambiar_atributos):
		estadisticas.atributos_cambiados.connect(_al_cambiar_atributos)

	salud_actual = estadisticas.salud_maxima
	mana_actual = estadisticas.mana_maximo

	agente.path_desired_distance = 0.6
	agente.target_desired_distance = 0.4

	_preparar_visual()

	if arma_inicial != null:
		equipar_arma(arma_inicial)
	_emitir_estado()


## Sustituye la cápsula de bloqueo por el modelo animado del gladiador.
func _preparar_visual() -> void:
	if visual == null:
		visual = CharacterVisual.new()
		visual.name = "Visual"
		add_child(visual)
		visual.configurar(ruta_modelo, tinte_skin, "barbaro")
		visual.anadir_colmillos()
	if modelo != null:
		modelo.visible = false


func _physics_process(delta: float) -> void:
	_actualizar_cooldowns(delta)

	if esta_muerto:
		velocity = Vector3.ZERO
		return

	_regenerar(delta)
	_temporizador_ataque = maxf(0.0, _temporizador_ataque - delta)
	_tiempo_reduccion = maxf(0.0, _tiempo_reduccion - delta)
	if _tiempo_reduccion <= 0.0:
		_reduccion_temporal = 0.0
	_critico_asegurado = maxf(0.0, _critico_asegurado - delta)
	if arma_actual != null and _temporizador_ataque <= 0.0:
		_atacar_basico()

	if puede_moverse:
		_mover(delta)
	else:
		velocity = Vector3.ZERO


# --- Entrada --------------------------------------------------------------

func _unhandled_input(evento: InputEvent) -> void:
	if esta_muerto:
		return

	if evento is InputEventMouseButton:
		var clic := evento as InputEventMouseButton
		if clic.pressed and clic.button_index == MOUSE_BUTTON_RIGHT:
			var punto = _punto_bajo_raton(clic.position)
			if punto != null:
				ordenar_movimiento(punto)
				get_viewport().set_input_as_handled()
		return

	if evento is InputEventKey:
		var tecla := evento as InputEventKey
		if not tecla.pressed or tecla.echo:
			return
		var codigo := tecla.physical_keycode if tecla.physical_keycode != 0 else tecla.keycode
		var slot: int = TECLAS_HABILIDAD.get(codigo, -1)
		if slot >= 0:
			intentar_habilidad(slot)
			get_viewport().set_input_as_handled()


## Raycast del cursor contra el plano del suelo. Devuelve Vector3 o null.
func _punto_bajo_raton(posicion_pantalla: Vector2) -> Variant:
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return null
	var origen := camara.project_ray_origin(posicion_pantalla)
	var direccion := camara.project_ray_normal(posicion_pantalla)
	return Plane(Vector3.UP, 0.0).intersects_ray(origen, direccion)


# --- Movimiento -----------------------------------------------------------

## Ordena un desplazamiento al punto indicado, ajustado a la malla de navegación.
func ordenar_movimiento(punto: Vector3) -> void:
	if esta_muerto:
		return
	var destino := NavigationServer3D.map_get_closest_point(
		get_world_3d().navigation_map, punto
	)
	destino.y = global_position.y
	agente.target_position = destino
	_tiene_orden_movimiento = true


func _mover(delta: float) -> void:
	var deseada := Vector3.ZERO

	if _tiene_orden_movimiento:
		if agente.is_navigation_finished():
			_tiene_orden_movimiento = false
		else:
			var siguiente := agente.get_next_path_position()
			var direccion := siguiente - global_position
			direccion.y = 0.0
			if direccion.length_squared() > 0.0004:
				direccion = direccion.normalized()
				deseada = direccion * estadisticas.velocidad_movimiento
				_orientar(direccion, delta)

	velocity = velocity.move_toward(deseada, ACELERACION * delta)
	velocity.y = 0.0
	move_and_slide()
	if visual != null:
		visual.mover(velocity.length())


func _orientar(direccion: Vector3, delta: float) -> void:
	var angulo := atan2(direccion.x, direccion.z)
	var nodo := modelo if modelo != null else self
	nodo.rotation.y = lerp_angle(nodo.rotation.y, angulo, VELOCIDAD_GIRO * delta)


# --- Regeneración y temporizadores ---------------------------------------

func _actualizar_cooldowns(delta: float) -> void:
	for i in _cooldowns.size():
		_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)


func _regenerar(delta: float) -> void:
	_acumulador_regeneracion += delta
	if _acumulador_regeneracion < INTERVALO_REGENERACION:
		return

	var paso := _acumulador_regeneracion
	_acumulador_regeneracion = 0.0

	if salud_actual < estadisticas.salud_maxima:
		salud_actual = minf(
			estadisticas.salud_maxima,
			salud_actual + estadisticas.regeneracion_salud * paso
		)
		salud_cambiada.emit(salud_actual, estadisticas.salud_maxima)

	if mana_actual < estadisticas.mana_maximo:
		mana_actual = minf(
			estadisticas.mana_maximo,
			mana_actual + estadisticas.regeneracion_mana * paso
		)
		mana_cambiada.emit(mana_actual, estadisticas.mana_maximo)


# --- Armas y habilidades --------------------------------------------------

## Equipa un arma y sustituye el kit completo. La armería debe llamar aquí.
func equipar_arma(nueva_arma: WeaponItem) -> bool:
	if nueva_arma == null or not nueva_arma.es_valida():
		push_warning("Se intentó equipar un arma inválida; revisa WeaponItem.validar().")
		return false

	arma_actual = nueva_arma
	estadisticas.aplicar_bonos_equipo(nueva_arma.bonificaciones_atributos)
	_cooldowns.fill(0.0)
	if visual != null:
		visual.usar_arma_pesada(nueva_arma.clase == WeaponItem.Clase.BASTION)
		visual.equipar_arma(
			nueva_arma.escena_visual,
			nueva_arma.rotacion_visual,
			nueva_arma.escala_visual
		)
	arma_cambiada.emit(arma_actual)
	return true


## Intenta lanzar la habilidad del slot. Devuelve true si se ejecutó.
func intentar_habilidad(slot: int) -> bool:
	if esta_muerto or arma_actual == null:
		return false
	if slot < 0 or slot >= _cooldowns.size():
		return false
	if _cooldowns[slot] > 0.0:
		return false

	var habilidad := arma_actual.obtener_habilidad(slot)
	if habilidad == null or mana_actual < habilidad.coste_mana:
		return false

	mana_actual -= habilidad.coste_mana
	_cooldowns[slot] = habilidad.cooldown
	mana_cambiada.emit(mana_actual, estadisticas.mana_maximo)

	var punto := global_position
	if habilidad.objetivo != AbilityData.Objetivo.PROPIO:
		var apuntado = _punto_bajo_raton(get_viewport().get_mouse_position())
		if apuntado != null:
			punto = apuntado

	if habilidad.reduccion_dano > 0.0:
		_reduccion_temporal = habilidad.reduccion_dano
		_tiempo_reduccion = habilidad.duracion
	if habilidad.tipo == AbilityData.Tipo.MOVILIDAD:
		_ejecutar_dash(habilidad, punto)
	elif habilidad.tipo == AbilityData.Tipo.INVOCACION:
		_invocar_espiritu(habilidad, punto)

	_instanciar_efecto(habilidad, punto)
	if visual != null:
		visual.lanzar()
	habilidad_lanzada.emit(slot, habilidad)
	Sfx.reproducir("magia" if arma_actual != null and arma_actual.clase == WeaponItem.Clase.CETRO else "habilidad", -7.0)
	return true


## Desplaza al gladiador hacia el punto apuntado, sin atravesar el navmesh.
func _ejecutar_dash(habilidad: AbilityData, punto: Vector3) -> void:
	var direccion := punto - global_position
	direccion.y = 0.0
	var distancia := minf(habilidad.radio, direccion.length())
	if distancia < 0.25:
		return
	var destino := global_position + direccion.normalized() * distancia
	var mapa := get_world_3d().navigation_map
	if mapa.is_valid():
		destino = NavigationServer3D.map_get_closest_point(mapa, destino)
	global_position = destino
	velocity = Vector3.ZERO
	_tiene_orden_movimiento = false
	if arma_actual != null and arma_actual.clase == WeaponItem.Clase.FILO:
		_critico_asegurado = 3.0
	if visual != null:
		visual.mover(0.0)


func _invocar_espiritu(habilidad: AbilityData, punto: Vector3) -> void:
	var espiritu := SpiritSummon.crear()
	var contenedor: Node = get_tree().current_scene
	if contenedor == null:
		contenedor = get_parent()
	contenedor.add_child(espiritu)
	espiritu.global_position = punto
	espiritu.configurar(
		self,
		maxf(1.0, estadisticas.escalar_invocacion(habilidad.dano_base)),
		habilidad.duracion
	)
	Sfx.reproducir("espiritu", -8.0)


func _instanciar_efecto(habilidad: AbilityData, punto: Vector3) -> void:
	var efecto: Node
	if habilidad.escena_efecto != null:
		efecto = habilidad.escena_efecto.instantiate()
	else:
		efecto = AbilityEffect.new()
	var contenedor: Node = get_tree().current_scene
	if contenedor == null or contenedor == self:
		contenedor = get_parent()
	if contenedor == null:
		contenedor = self
	contenedor.add_child(efecto)

	if efecto is Node3D:
		(efecto as Node3D).global_position = punto
	if efecto.has_method("configurar"):
		efecto.configurar(habilidad, self)


# --- Ataque básico y talentos ---------------------------------------------

func _atacar_basico() -> void:
	if esta_muerto or arma_actual == null:
		return

	var alcance := arma_actual.alcance_ataque
	var mejor := alcance * alcance
	var objetivo: Node3D = null
	for nodo in get_tree().get_nodes_in_group(GRUPO_ENEMIGOS):
		var enemigo := nodo as Node3D
		if enemigo == null or not enemigo.is_inside_tree():
			continue
		var distancia := global_position.distance_squared_to(enemigo.global_position)
		if distancia < mejor:
			mejor = distancia
			objetivo = enemigo

	if objetivo == null:
		_temporizador_ataque = 0.15
		return

	_temporizador_ataque = 1.0 / maxf(0.2, estadisticas.velocidad_ataque)
	var dano := estadisticas.escalar_dano(arma_actual.dano_ataque_base, &"fisico")
	var critico := _critico_asegurado > 0.0 or randf() < estadisticas.probabilidad_critico
	if critico:
		dano *= estadisticas.multiplicador_critico

	var direccion := objetivo.global_position - global_position
	direccion.y = 0.0
	_orientar(direccion.normalized(), 1.0)
	if visual != null:
		visual.atacar()

	if objetivo.has_method("recibir_dano"):
		objetivo.recibir_dano(dano, &"fisico", self)
	ataque_basico.emit(objetivo, dano, critico)
	Sfx.reproducir("critico" if critico else "golpe", -8.0)


func cooldown_restante(slot: int) -> float:
	if slot < 0 or slot >= _cooldowns.size():
		return 0.0
	return _cooldowns[slot]


func tiene_talento(id: StringName) -> bool:
	return rango_talento(id) > 0


func rango_talento(id: StringName) -> int:
	return int(_talentos_activos.get(id, 0))


func otorgar_puntos_rojos(cantidad: int) -> void:
	if cantidad <= 0:
		return
	puntos_rojos += cantidad
	talentos_cambiados.emit()


## Compra un rango de talento. La UI de talentos es la única que debe llamar.
func desbloquear_talento(talento: TalentData) -> bool:
	if talento == null or arma_actual == null:
		return false
	var rango := rango_talento(talento.id)
	if rango >= maxi(1, talento.rango_maximo):
		return false
	if talento.coste_puntos_rojos > puntos_rojos:
		return false
	if talento.talento_requerido != &"" and not tiene_talento(talento.talento_requerido):
		return false

	puntos_rojos -= talento.coste_puntos_rojos
	_talentos_activos[talento.id] = rango + 1
	talentos_cambiados.emit()
	return true


# --- Daño, curación y muerte ----------------------------------------------

## Punto único de entrada del daño. `fuente` permite atribuir muertes y aggro.
func recibir_dano(
	cantidad: float,
	tipo: StringName = GladiatorStats.TIPO_FISICO,
	_fuente: Node = null
) -> void:
	if esta_muerto or cantidad <= 0.0:
		return

	var mitigacion := 0.0
	match tipo:
		GladiatorStats.TIPO_FISICO:
			mitigacion = estadisticas.mitigacion_fisica
		GladiatorStats.TIPO_MAGICO:
			mitigacion = estadisticas.mitigacion_magica
		_:
			mitigacion = 0.0

	var recibido := cantidad * (1.0 - clampf(mitigacion, 0.0, 0.9))
	recibido *= 1.0 - clampf(_reduccion_temporal, 0.0, 0.9)
	salud_actual = maxf(0.0, salud_actual - recibido)
	salud_cambiada.emit(salud_actual, estadisticas.salud_maxima)
	if visual != null:
		visual.recibir_golpe()
	Sfx.reproducir("dano", -6.0)

	if salud_actual <= 0.0:
		_morir()


func curar(cantidad: float) -> void:
	if esta_muerto or cantidad <= 0.0:
		return
	salud_actual = minf(estadisticas.salud_maxima, salud_actual + cantidad)
	salud_cambiada.emit(salud_actual, estadisticas.salud_maxima)


func _morir() -> void:
	if esta_muerto:
		return
	esta_muerto = true
	velocity = Vector3.ZERO
	_tiene_orden_movimiento = false
	agente.set_physics_process(false)
	remove_from_group(GRUPO_GLADIADORES)
	if visual != null:
		visual.morir()
	Sfx.reproducir("muerte", -3.0)
	murio.emit()


# --- Progresión -----------------------------------------------------------

## Gasta un punto de atributo. GladiatorStats emite y el controlador ajusta
## salud/maná a los nuevos máximos.
func gastar_punto_atributo(atributo: StringName) -> bool:
	return estadisticas.gastar_punto(atributo)


## Cambia la skin cosmética del orco sin alterar atributos.
func aplicar_skin(tinte: Color) -> void:
	tinte_skin = tinte
	if visual != null:
		visual.aplicar_skin(tinte)


func _al_cambiar_atributos() -> void:
	salud_actual = minf(salud_actual, estadisticas.salud_maxima)
	mana_actual = minf(mana_actual, estadisticas.mana_maximo)
	_emitir_estado()


func _emitir_estado() -> void:
	salud_cambiada.emit(salud_actual, estadisticas.salud_maxima)
	mana_cambiada.emit(mana_actual, estadisticas.mana_maximo)
