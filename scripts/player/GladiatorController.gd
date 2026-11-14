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
signal objetivo_cambiado(objetivo: Node3D)
signal modo_cambiado(modo: StringName)
signal escudo_cambiado(actual: float, maximo: float)
signal estadisticas_combate_cambiadas
signal aspecto_cambiado
signal progreso_cambiado(nivel: int, experiencia: int, requerida: int)
signal habilidades_cambiadas
signal nivel_alcanzado(nivel: int)
signal habilidad_mejorada(slot: int, habilidad: AbilityData, rango: int)
signal recibio_dano(intensidad: float)

const SLOT_Q := 0
const SLOT_W := 1
const SLOT_E := 2
const SLOT_R := 3
const RANGO_AGGRO := 7.0
const RANGO_OBJETIVO := 12.0
const RADIO_ATAQUE_MOVIMIENTO := 6.0
## Radio en metros en el que las auras de objetos épicos/legendarios alcanzan
## a los gladiadores aliados.
const RADIO_AURA := 10.0

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

## Modo red: null en partida local, NetCoop en servidor/cliente.
var red: NetCoop
var es_espejo := false
var es_local_red := false
## Punto de lanzamiento enviado por un cliente (el servidor no tiene ratón).
var punto_red := Vector3.ZERO
var tiene_punto_red := false
var _pos_objetivo_red := Vector3.ZERO
## Segundos restantes para revivir en co-op; 0 si está vivo o sin rescate.
var revive_en := 0.0
## Dirección del joystick táctil (x, z); cero cuando no se usa.
var direccion_tactil := Vector2.ZERO
## Destino predicho en cliente (clic o toque para moverse): el avatar camina ya
## y el servidor corrige después. Sin esto el propio jugador esperaba el RTT.
var _destino_predicho := Vector3.INF

var salud_actual := 0.0
var mana_actual := 0.0
var arma_actual: WeaponItem
var esta_muerto := false
var visual: CharacterVisual
var inventario: InventoryComponent
var combat: CombatComponent
var objetivo_actual: Node3D
var mantener_posicion := false
var modo_ataque_movimiento := false
var dano_infligido := 0.0
var dano_recibido := 0.0
var escudo_actual := 0.0

var _cooldowns := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _tiene_orden_movimiento := false
var _acumulador_regeneracion := 0.0
var _temporizador_ataque := 0.0
var _talentos_activos: Dictionary = {}
var _reduccion_temporal := 0.0
var _tiempo_reduccion := 0.0
var _critico_asegurado := 0.0
var _autoataque_activo := true
var _modo_ataque_armado := false
var _destino_ataque := Vector3.ZERO
var _tiempo_recalculo := 0.0
var _tiempo_escudo := 0.0
var _escudo_maximo := 0.0
var _inmunidad_aturdimiento := 0.0
var _inmunidad_daño := 0.0
var _buff_ataque := 0.0
var _buff_robo := 0.0
var _buff_dano := 0.0
var _tiempo_buff := 0.0
var _multiplicador_velocidad := 1.0
var _tiempo_impulso := 0.0
var _potenciar_tajo := false
var _arma_progreso_id: StringName = &""
var _habilidades_desbloqueadas: Dictionary = {}
var _rangos_habilidad: Dictionary = {}
var _orden_desbloqueo: Array[StringName] = []
var _marcador_movimiento: MeshInstance3D
var _marcador_objetivo: MeshInstance3D
var _marcador_ataque: MeshInstance3D

@onready var agente := $NavigationAgent3D as NavigationAgent3D
@onready var modelo := get_node_or_null("Modelo") as Node3D


func _ready() -> void:
	add_to_group(GRUPO_GLADIADORES)
	if estadisticas == null:
		estadisticas = GladiatorStats.new()
	if not estadisticas.atributos_cambiados.is_connected(_al_cambiar_atributos):
		estadisticas.atributos_cambiados.connect(_al_cambiar_atributos)
	if not estadisticas.nivel_subido.is_connected(_al_subir_nivel):
		estadisticas.nivel_subido.connect(_al_subir_nivel)
	if not estadisticas.experiencia_cambiada.is_connected(_al_cambiar_experiencia):
		estadisticas.experiencia_cambiada.connect(_al_cambiar_experiencia)

	salud_actual = estadisticas.salud_maxima
	mana_actual = estadisticas.mana_maximo

	agente.path_desired_distance = 0.6
	agente.target_desired_distance = 0.4

	_preparar_visual()
	_crear_marcadores()

	_combat_setup()

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


## Anillos de suelo: verde = destino, rojo = objetivo, naranja = ataque-mover.
func _crear_marcadores() -> void:
	_marcador_movimiento = _crear_anillo(Color(0.35, 1.0, 0.5))
	_marcador_objetivo = _crear_anillo(Color(1.0, 0.22, 0.18))
	_marcador_ataque = _crear_anillo(Color(1.0, 0.62, 0.15))


func _crear_anillo(color: Color) -> MeshInstance3D:
	var anillo := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.86
	toro.outer_radius = 1.0
	toro.rings = 40
	toro.ring_segments = 6
	anillo.mesh = toro
	anillo.top_level = true
	anillo.visible = false
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.6
	anillo.material_override = material
	add_child(anillo)
	return anillo


func _mostrar_marcador(marcador: MeshInstance3D, posicion: Vector3, radio: float) -> void:
	if marcador == null:
		return
	marcador.global_position = Vector3(posicion.x, 0.08, posicion.z)
	marcador.scale = Vector3(radio, 1.0, radio)
	marcador.visible = true


func _ocultar_marcadores() -> void:
	for marcador in [_marcador_movimiento, _marcador_objetivo, _marcador_ataque]:
		if marcador != null:
			marcador.visible = false


func _combat_setup() -> void:
	combat = CombatComponent.new()
	combat.name = "CombatComponent"
	add_child(combat)
	combat.estadisticas = estadisticas
	combat.arma_actual = arma_actual
	combat.visual = visual
	combat.inventario = inventario
	combat.controlador = self

	# Conectar señales
	combat.salud_cambiada.connect(_cb_salud_cambiada)
	combat.mana_cambiada.connect(_cb_mana_cambiada)
	combat.escudo_cambiado.connect(_cb_escudo_cambiado)
	combat.ataque_basico.connect(_cb_ataque_basico)
	combat.murio.connect(murio.emit)
	combat.estadisticas_combate_cambiadas.connect(estadisticas_combate_cambiadas.emit)

	# Inicializar estado
	combat.inicializar_estado()

	salud_actual = combat.salud_actual
	mana_actual = combat.mana_actual
	escudo_actual = combat.escudo_actual


func _physics_process(delta: float) -> void:
	if es_espejo:
		return
	combat._physics_process(delta)
	if inventario != null:
		inventario.actualizar(delta)

	if combat.esta_muerto:
		velocity = Vector3.ZERO
		return

	_temporizador_ataque = combat._temporizador_ataque
	_actualizar_objetivo(delta)
	_actualizar_marcador_objetivo()

	if arma_actual != null and _temporizador_ataque <= 0.0:
		_atacar_basico()

	if puede_moverse:
		_mover(delta)
	else:
		velocity = Vector3.ZERO

	# Sincronizar estado desde combat component
	salud_actual = combat.salud_actual
	mana_actual = combat.mana_actual
	escudo_actual = combat.escudo_actual
	esta_muerto = combat.esta_muerto


## Espejos: el propio jugador se predice en local (responde al instante) y los
## demás se interpolan hacia la posición del servidor.
func _process(delta: float) -> void:
	if not es_espejo:
		return
	var antes := global_position
	if es_local_red:
		_predecir_local(delta)
	else:
		global_position = global_position.lerp(_pos_objetivo_red, clampf(18.0 * delta, 0.0, 1.0))
	if visual != null:
		visual.mover(antes.distance_to(global_position) / maxf(0.001, delta))


## Predicción: el cuerpo propio se mueve al momento con el joystick o el destino
## tocado; el snapshot sólo corrige cuando la diferencia es grande (paredes,
## empujones, revivir). Sin esto todo el input esperaba a la red.
func _predecir_local(delta: float) -> void:
	if esta_muerto:
		direccion_tactil = Vector2.ZERO
		_destino_predicho = Vector3.INF
		return
	var velocidad := estadisticas.velocidad_movimiento * _multiplicador_velocidad
	var paso := Vector3.ZERO
	if direccion_tactil.length_squared() > 0.04:
		paso = Vector3(direccion_tactil.x, 0.0, direccion_tactil.y).normalized() * velocidad * delta
	elif _destino_predicho != Vector3.INF:
		var hacia := _destino_predicho - global_position
		hacia.y = 0.0
		if hacia.length() > 0.2:
			paso = hacia.normalized() * minf(hacia.length(), velocidad * delta)
			rotation.y = lerp_angle(rotation.y, atan2(hacia.x, hacia.z), clampf(12.0 * delta, 0.0, 1.0))
		else:
			_destino_predicho = Vector3.INF
	if paso != Vector3.ZERO:
		global_position += paso
	var error := global_position.distance_to(_pos_objetivo_red)
	if error > 4.0:
		global_position = _pos_objetivo_red
	elif error > 0.8:
		global_position = global_position.lerp(_pos_objetivo_red, clampf(2.5 * delta, 0.0, 1.0))


# --- Entrada --------------------------------------------------------------

func _procesar_input_red(evento: InputEvent) -> bool:
	if red == null or not es_local_red or red.estado != NetCoop.Estado.CONECTADO:
		return false
	if evento is InputEventMouseButton:
		var clic := evento as InputEventMouseButton
		if not clic.pressed:
			return true
		if clic.button_index == MOUSE_BUTTON_RIGHT:
			var punto = _punto_bajo_raton(clic.position)
			if punto != null:
				red.enviar_accion(&"mover", {"punto": punto})
				_destino_predicho = punto
				_animar_destino(punto, _marcador_movimiento, 1.1)
			return true
		if clic.button_index == MOUSE_BUTTON_LEFT:
			var punto_izq = _punto_bajo_raton(clic.position)
			if punto_izq != null:
				red.enviar_accion(&"atacar_mover", {"punto": punto_izq})
				_destino_predicho = punto_izq
				_animar_destino(punto_izq, _marcador_ataque, 1.5)
			return true
		return true
	if evento is InputEventKey:
		var tecla := evento as InputEventKey
		if not tecla.pressed or tecla.echo:
			return true
		var codigo := tecla.physical_keycode if tecla.physical_keycode != 0 else tecla.keycode
		var slot: int = TECLAS_HABILIDAD.get(codigo, -1)
		if slot >= 0:
			var punto_habilidad = _punto_bajo_raton(get_viewport().get_mouse_position())
			red.enviar_accion(&"habilidad", {"slot": slot, "punto": punto_habilidad})
			return true
		match codigo:
			KEY_S:
				red.enviar_accion(&"detener", {})
				_destino_predicho = Vector3.INF
			KEY_H:
				red.enviar_accion(&"mantener", {})
			KEY_A:
				red.enviar_accion(&"atacar", {})
			KEY_Z:
				red.enviar_accion(&"objeto", {"indice": 0, "punto": _punto_bajo_raton(get_viewport().get_mouse_position())})
			KEY_X:
				red.enviar_accion(&"objeto", {"indice": 1, "punto": _punto_bajo_raton(get_viewport().get_mouse_position())})
			KEY_C:
				red.enviar_accion(&"objeto", {"indice": 2, "punto": _punto_bajo_raton(get_viewport().get_mouse_position())})
			KEY_V:
				red.enviar_accion(&"objeto", {"indice": 3, "punto": _punto_bajo_raton(get_viewport().get_mouse_position())})
			KEY_B:
				red.enviar_accion(&"objeto", {"indice": 4, "punto": _punto_bajo_raton(get_viewport().get_mouse_position())})
			KEY_N:
				red.enviar_accion(&"objeto", {"indice": 5, "punto": _punto_bajo_raton(get_viewport().get_mouse_position())})
			_:
				return false
		return true
	return false

func _unhandled_input(evento: InputEvent) -> void:
	if esta_muerto:
		return
	if es_espejo and not es_local_red:
		return
	if red != null and red.es_servidor:
		return
	if red != null and es_local_red and red.estado == NetCoop.Estado.CONECTADO:
		if _procesar_input_red(evento):
			get_viewport().set_input_as_handled()
		return

	if evento is InputEventMouseButton:
		var clic := evento as InputEventMouseButton
		if not clic.pressed:
			return
		if clic.button_index == MOUSE_BUTTON_RIGHT:
			var enemigo := _enemigo_bajo_raton(clic.position)
			if enemigo != null:
				_fijar_objetivo(enemigo)
				_tiene_orden_movimiento = false
				modo_ataque_movimiento = false
				mantener_posicion = false
				_autoataque_activo = true
				_marcador_movimiento.visible = false
				_marcador_ataque.visible = false
				modo_cambiado.emit(&"objetivo")
			else:
				var punto = _punto_bajo_raton(clic.position)
				if punto != null:
					ordenar_movimiento(punto)
			get_viewport().set_input_as_handled()
		elif clic.button_index == MOUSE_BUTTON_LEFT:
			if _modo_ataque_armado:
				var punto = _punto_bajo_raton(clic.position)
				if punto != null:
					ordenar_ataque_movimiento(punto)
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
			return

		match codigo:
			KEY_S:
				detener()
				get_viewport().set_input_as_handled()
			KEY_H:
				alternar_mantener_posicion()
				get_viewport().set_input_as_handled()
			KEY_A:
				alternar_modo_ataque()
				get_viewport().set_input_as_handled()
			KEY_Z:
				usar_objeto(0)
			KEY_X:
				usar_objeto(1)
			KEY_C:
				usar_objeto(2)
			KEY_V:
				usar_objeto(3)
			KEY_B:
				usar_objeto(4)
			KEY_N:
				usar_objeto(5)


## Raycast del cursor contra el plano del suelo. Devuelve Vector3 o null.
func _punto_bajo_raton(posicion_pantalla: Vector2) -> Variant:
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return null
	var origen := camara.project_ray_origin(posicion_pantalla)
	var direccion := camara.project_ray_normal(posicion_pantalla)
	return Plane(Vector3.UP, 0.0).intersects_ray(origen, direccion)


func _resolver_punto(habilidad: AbilityData, punto_objetivo = null) -> Vector3:
	var punto := global_position
	if habilidad == null or habilidad.objetivo == AbilityData.Objetivo.PROPIO:
		return punto
	var apuntado = punto_objetivo
	if apuntado == null and tiene_punto_red:
		apuntado = punto_red
	if apuntado == null:
		apuntado = _punto_bajo_raton(get_viewport().get_mouse_position())
	if apuntado != null:
		punto = apuntado
	return punto


func _enemigo_bajo_raton(posicion_pantalla: Vector2) -> Node3D:
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return null
	var origen := camara.project_ray_origin(posicion_pantalla)
	var destino := origen + camara.project_ray_normal(posicion_pantalla) * 100.0
	var consulta := PhysicsRayQueryParameters3D.create(origen, destino, 2)
	var resultado := get_world_3d().direct_space_state.intersect_ray(consulta)
	if resultado.is_empty():
		return null
	var nodo := resultado.get("collider") as Node
	while nodo != null:
		if nodo is Node3D and nodo.is_in_group(GRUPO_ENEMIGOS):
			return nodo as Node3D
		nodo = nodo.get_parent()
	return null


func _es_cliente_red() -> bool:
	return red != null and es_local_red and not red.es_servidor and red.estado == NetCoop.Estado.CONECTADO


# --- Movimiento -----------------------------------------------------------

## Ordena un desplazamiento al punto indicado, ajustado a la malla de navegación.
func ordenar_movimiento(punto: Vector3) -> void:
	if esta_muerto:
		return
	if _es_cliente_red():
		red.enviar_accion(&"mover", {"punto": punto})
		return
	var destino := NavigationServer3D.map_get_closest_point(
		get_world_3d().navigation_map, punto
	)
	destino.y = global_position.y
	agente.target_position = destino
	_tiene_orden_movimiento = true
	objetivo_actual = null
	objetivo_cambiado.emit(null)
	mantener_posicion = false
	modo_ataque_movimiento = false
	_modo_ataque_armado = false
	_autoataque_activo = true
	_marcador_ataque.visible = false
	_marcador_objetivo.visible = false
	_animar_destino(destino, _marcador_movimiento, 1.1)
	modo_cambiado.emit(&"mover")


func ordenar_ataque_movimiento(punto: Vector3) -> void:
	if esta_muerto:
		return
	if _es_cliente_red():
		red.enviar_accion(&"atacar_mover", {"punto": punto})
		return
	var destino := NavigationServer3D.map_get_closest_point(
		get_world_3d().navigation_map, punto
	)
	destino.y = global_position.y
	_destino_ataque = destino
	agente.target_position = destino
	_tiene_orden_movimiento = true
	modo_ataque_movimiento = true
	_modo_ataque_armado = false
	mantener_posicion = false
	_autoataque_activo = true
	objetivo_actual = null
	objetivo_cambiado.emit(null)
	_marcador_movimiento.visible = false
	_marcador_objetivo.visible = false
	_animar_destino(destino, _marcador_ataque, 1.5)
	modo_cambiado.emit(&"ataque_mover")


func detener() -> void:
	if _es_cliente_red():
		red.enviar_accion(&"detener", {})
		return
	_tiene_orden_movimiento = false
	modo_ataque_movimiento = false
	mantener_posicion = false
	_autoataque_activo = false
	objetivo_actual = null
	objetivo_cambiado.emit(null)
	agente.target_position = global_position
	velocity = Vector3.ZERO
	if visual != null:
		visual.mover(0.0)
	_ocultar_marcadores()
	modo_cambiado.emit(&"detenido")


func alternar_mantener_posicion() -> void:
	if _es_cliente_red():
		red.enviar_accion(&"mantener", {})
		return
	if mantener_posicion:
		mantener_posicion = false
		_autoataque_activo = true
		modo_cambiado.emit(&"libre")
		return
	_tiene_orden_movimiento = false
	modo_ataque_movimiento = false
	_autoataque_activo = false
	objetivo_actual = null
	objetivo_cambiado.emit(null)
	agente.target_position = global_position
	velocity = Vector3.ZERO
	mantener_posicion = true
	_ocultar_marcadores()
	modo_cambiado.emit(&"mantener")


func alternar_modo_ataque() -> void:
	if _es_cliente_red():
		red.enviar_accion(&"atacar", {})
		return
	_modo_ataque_armado = not _modo_ataque_armado
	modo_cambiado.emit(&"armar_ataque" if _modo_ataque_armado else &"cancelar")


func _animar_destino(destino: Vector3, marcador: MeshInstance3D, radio: float) -> void:
	_mostrar_marcador(marcador, destino, radio * 1.35)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(marcador, "scale", Vector3(radio * 0.55, 1.0, radio * 0.55), 0.55)
	var _tween_cb := Callable(self, "_on_tween_animar_destino_completo").bind(marcador)
	tween.chain().tween_callback(_tween_cb)


## Movimiento directo desde el joystick táctil (no pasa por navegación).
func mover_tactil(direccion: Vector2) -> void:
	direccion_tactil = direccion.limit_length(1.0)


func _mover(delta: float) -> void:
	var deseada := Vector3.ZERO

	# Joystick: manda sobre el destino de clic mientras se esté arrastrando.
	if direccion_tactil.length_squared() > 0.04:
		var dir := Vector3(direccion_tactil.x, 0.0, direccion_tactil.y)
		if dir.length_squared() > 0.0004:
			dir = dir.normalized()
			deseada = dir * estadisticas.velocidad_movimiento * _multiplicador_velocidad
			_orientar(dir, delta)
			_tiene_orden_movimiento = false
			velocity = velocity.move_toward(deseada, ACELERACION * delta)
			velocity.y = 0.0
			move_and_slide()
			if visual != null:
				visual.mover(velocity.length())
			return

	if objetivo_actual != null and not mantener_posicion:
		var distancia := global_position.distance_to(objetivo_actual.global_position)
		var alcance := arma_actual.alcance_ataque if arma_actual != null else 2.0
		if distancia > alcance * 0.9:
			var direccion := objetivo_actual.global_position - global_position
			direccion.y = 0.0
			if direccion.length_squared() > 0.0004:
				direccion = direccion.normalized()
				deseada = direccion * estadisticas.velocidad_movimiento * _multiplicador_velocidad
				_orientar(direccion, delta)
		elif _tiene_orden_movimiento:
			_tiene_orden_movimiento = false

	if deseada == Vector3.ZERO and _tiene_orden_movimiento and not agente.is_navigation_finished():
		var siguiente := agente.get_next_path_position()
		var direccion := siguiente - global_position
		direccion.y = 0.0
		if direccion.length_squared() > 0.0004:
			direccion = direccion.normalized()
			deseada = direccion * estadisticas.velocidad_movimiento * _multiplicador_velocidad
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


func _actualizar_estados(delta: float) -> void:
	_tiempo_reduccion = maxf(0.0, _tiempo_reduccion - delta)
	if _tiempo_reduccion <= 0.0:
		_reduccion_temporal = 0.0
	_inmunidad_daño = maxf(0.0, _inmunidad_daño - delta)
	_inmunidad_aturdimiento = maxf(0.0, _inmunidad_aturdimiento - delta)

	if _tiempo_escudo > 0.0:
		_tiempo_escudo -= delta
		if _tiempo_escudo <= 0.0 and escudo_actual > 0.0:
			escudo_actual = 0.0
			_escudo_maximo = 0.0
			escudo_cambiado.emit(0.0, 0.0)

	if _tiempo_buff > 0.0:
		_tiempo_buff -= delta
		if _tiempo_buff <= 0.0:
			_buff_ataque = 0.0
			_buff_robo = 0.0
			_buff_dano = 0.0

	if _tiempo_impulso > 0.0:
		_tiempo_impulso -= delta
		if _tiempo_impulso <= 0.0:
			_multiplicador_velocidad = 1.0


func _actualizar_objetivo(delta: float) -> void:
	_tiempo_recalculo = maxf(0.0, _tiempo_recalculo - delta)

	if objetivo_actual != null and not _objetivo_vivo(objetivo_actual):
		objetivo_actual = null
		objetivo_cambiado.emit(null)
		_marcador_objetivo.visible = false
		if modo_ataque_movimiento and _destino_ataque != Vector3.ZERO:
			_tiene_orden_movimiento = true
			agente.target_position = _destino_ataque
			_mostrar_marcador(_marcador_ataque, _destino_ataque, 1.3)

	if objetivo_actual != null:
		if global_position.distance_to(objetivo_actual.global_position) > RANGO_OBJETIVO:
			objetivo_actual = null
			objetivo_cambiado.emit(null)
			_marcador_objetivo.visible = false
		return

	if mantener_posicion:
		return

	if modo_ataque_movimiento and _tiempo_recalculo <= 0.0 and _tiene_orden_movimiento:
		_tiempo_recalculo = 0.25
		var cercano := _enemigo_mas_cercano(RADIO_ATAQUE_MOVIMIENTO)
		if cercano != null:
			_fijar_objetivo(cercano)
			_tiene_orden_movimiento = false
			velocity = Vector3.ZERO
			return

	if _autoataque_activo and not _tiene_orden_movimiento:
		var cercano := _enemigo_mas_cercano(RANGO_AGGRO)
		if cercano != null:
			_fijar_objetivo(cercano)


func _actualizar_marcador_objetivo() -> void:
	if _marcador_objetivo == null or objetivo_actual == null:
		return
	if is_instance_valid(objetivo_actual):
		_mostrar_marcador(_marcador_objetivo, objetivo_actual.global_position, 0.75)


func _objetivo_vivo(nodo: Node3D) -> bool:
	if nodo == null or not is_instance_valid(nodo):
		return false
	if nodo.has_method("esta_muerto") and nodo.esta_muerto():
		return false
	var vida = nodo.get("salud_actual")
	if vida != null and float(vida) <= 0.0:
		return false
	var activo = nodo.get("activo")
	if activo != null and activo == false:
		return false
	return true


func _enemigo_mas_cercano(radio: float) -> Node3D:
	var tracker = get_tree().get_first_node_in_group("enemy_tracker")
	if tracker != null:
		return tracker.buscar_mas_cercano(global_position, radio)
	var mejor: Node3D = null
	var mejor_distancia := radio
	for nodo in get_tree().get_nodes_in_group(GRUPO_ENEMIGOS):
		var enemigo := nodo as Node3D
		if enemigo == null or not _objetivo_vivo(enemigo):
			continue
		var distancia := global_position.distance_to(enemigo.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = enemigo
	return mejor


func _fijar_objetivo(enemigo: Node3D) -> void:
	objetivo_actual = enemigo
	objetivo_cambiado.emit(enemigo)
	if enemigo != null:
		_mostrar_marcador(_marcador_objetivo, enemigo.global_position, 0.75)
	else:
		_marcador_objetivo.visible = false


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
	estadisticas.configurar_clase(nueva_arma.id_clase())
	estadisticas.aplicar_bonos_equipo(nueva_arma.bonificaciones_atributos)
	# Un arma que otorga vida máxima también entrega esa vida al campeón.
	var vida_antes := estadisticas.salud_maxima - float(nueva_arma.bonificaciones_atributos.get("vida", 0))
	var vida_despues := estadisticas.salud_maxima
	var ganancia := vida_despues - vida_antes
	if ganancia > 0.0:
		curar(ganancia)
	_cooldowns.fill(0.0)
	_inicializar_habilidades()
	if visual != null:
		visual.usar_arma_pesada(nueva_arma.clase == WeaponItem.Clase.BASTION)
		visual.equipar_arma(
			nueva_arma.escena_visual,
			nueva_arma.rotacion_visual,
			nueva_arma.escala_visual
		)
	arma_cambiada.emit(arma_actual)
	return true


## Prepara el orden aleatorio de Q/W/E y sincroniza los desbloqueos según el
## nivel actual. El campeón empieza con una habilidad y desbloquea el resto en
## los niveles 2 y 3; la definitiva R llega al nivel 6.
func _inicializar_habilidades() -> void:
	if arma_actual == null:
		return
	if _arma_progreso_id == arma_actual.id and not _orden_desbloqueo.is_empty():
		_sincronizar_desbloqueos()
		return

	_arma_progreso_id = arma_actual.id
	_habilidades_desbloqueadas.clear()
	_rangos_habilidad.clear()
	_orden_desbloqueo.clear()

	var indices: Array[int] = [SLOT_Q, SLOT_W, SLOT_E]
	indices.shuffle()
	for indice in indices:
		_orden_desbloqueo.append(arma_actual.obtener_habilidad(indice).id)

	_sincronizar_desbloqueos()
	habilidades_cambiadas.emit()


func _sincronizar_desbloqueos() -> void:
	if arma_actual == null:
		return
	var cantidad_qwe := int(min(3, max(1, estadisticas.nivel)))
	for i in cantidad_qwe:
		if i >= _orden_desbloqueo.size():
			break
		var id := _orden_desbloqueo[i]
		if not _habilidades_desbloqueadas.has(id):
			_habilidades_desbloqueadas[id] = true
			_rangos_habilidad[id] = max(1, int(_rangos_habilidad.get(id, 1)))

	var definitiva := arma_actual.obtener_habilidad(SLOT_R)
	if definitiva != null and estadisticas.nivel >= 6:
		if not _habilidades_desbloqueadas.has(definitiva.id):
			_habilidades_desbloqueadas[definitiva.id] = true
			_rangos_habilidad[definitiva.id] = max(1, int(_rangos_habilidad.get(definitiva.id, 1)))


func habilidad_desbloqueada(slot: int) -> bool:
	if arma_actual == null:
		return false
	var habilidad := arma_actual.obtener_habilidad(slot)
	return habilidad != null and bool(_habilidades_desbloqueadas.get(habilidad.id, false))


func nivel_desbloqueo_habilidad(slot: int) -> int:
	if slot == SLOT_R:
		return 6
	if arma_actual == null or slot < 0 or slot >= 3:
		return 1
	var habilidad := arma_actual.obtener_habilidad(slot)
	if habilidad == null:
		return 1
	var indice := _orden_desbloqueo.find(habilidad.id)
	return max(1, indice + 1)


func rango_habilidad(habilidad_id: StringName) -> int:
	return max(1, int(_rangos_habilidad.get(habilidad_id, 1)))


## Sube al azar una habilidad desbloqueada que no esté en su rango máximo.
## Se invoca automáticamente en cada subida de nivel; el jugador no elige.
func _subir_habilidad_aleatoria(slot_forzado: int = -1) -> AbilityData:
	if arma_actual == null:
		return null

	# Si se fuerza un slot específico, intentar subir ese primero
	if slot_forzado >= 0:
		var habilidad := arma_actual.obtener_habilidad(slot_forzado)
		if habilidad != null and habilidad_desbloqueada(slot_forzado):
			if rango_habilidad(habilidad.id) < max(1, habilidad.rango_maximo):
				_rangos_habilidad[habilidad.id] = rango_habilidad(habilidad.id) + 1
				return habilidad
		return null

	# Caso normal: elegir al azar entre candidatos desbloqueados
	var candidatos: Array[int] = []
	for slot in 4:
		var habilidad := arma_actual.obtener_habilidad(slot)
		if habilidad == null or not habilidad_desbloqueada(slot):
			continue
		if rango_habilidad(habilidad.id) < max(1, habilidad.rango_maximo):
			candidatos.append(slot)
	if candidatos.is_empty():
		return null

	var elegido: int = candidatos[randi() % candidatos.size()]
	var habilidad := arma_actual.obtener_habilidad(elegido)
	_rangos_habilidad[habilidad.id] = rango_habilidad(habilidad.id) + 1
	return habilidad


## Suma plana de una clave de mejora hasta el rango actual.
func bono_rango(habilidad: AbilityData, clave: String) -> float:
	if habilidad == null:
		return 0.0
	var total := 0.0
	var rango := rango_habilidad(habilidad.id)
	for r in range(2, rango + 1):
		var mejora := habilidad.mejora_para_rango(r)
		total += float(mejora.get(clave, 0.0))
	return total


func bono_talento(habilidad: AbilityData, clave: String) -> float:
	if habilidad == null:
		return 0.0
	var total := 0.0
	for talento in habilidad.talentos:
		if talento == null:
			continue
		var rango := rango_talento(talento.id)
		if rango <= 0:
			continue
		total += float(talento.modificadores.get(clave, 0.0)) * float(rango)
	return total


func cooldown_habilidad(habilidad: AbilityData) -> float:
	return maxf(0.5, habilidad.cooldown + bono_rango(habilidad, "cooldown"))


func radio_habilidad(habilidad: AbilityData) -> float:
	return maxf(0.5, habilidad.radio + bono_rango(habilidad, "radio"))


func duracion_habilidad(habilidad: AbilityData) -> float:
	return maxf(0.0, habilidad.duracion + bono_rango(habilidad, "duracion"))


func otorgar_experiencia(cantidad: int) -> void:
	if cantidad > 0:
		estadisticas.otorgar_experiencia(cantidad)


func _al_subir_nivel(nivel: int) -> void:
	_sincronizar_desbloqueos()

	# En niveles 1, 2 y 3 solo se desbloquea una QWE nueva; no se sube de nivel
	# ninguna habilidad todavía. En el 6 solo se desbloquea R (la definitiva).
	# En los demas niveles se sube al azar una habilidad desbloqueada.
	var subir_habilidad := true
	if nivel <= 3 or nivel == 6:
		subir_habilidad = false

	var mejorada: AbilityData = null
	if subir_habilidad:
		mejorada = _subir_habilidad_aleatoria()

	curar(estadisticas.salud_maxima * 0.15)
	restaurar_mana(estadisticas.mana_maximo * 0.15)
	habilidades_cambiadas.emit()
	nivel_alcanzado.emit(nivel)
	if mejorada != null:
		habilidad_mejorada.emit(
			arma_actual.habilidades.find(mejorada),
			mejorada,
			rango_habilidad(mejorada.id)
		)
	progreso_cambiado.emit(nivel, estadisticas.experiencia, estadisticas.experiencia_requerida)


func _al_cambiar_experiencia(actual: int, requerida: int, nivel: int) -> void:
	progreso_cambiado.emit(nivel, actual, requerida)


## Intenta lanzar la habilidad del slot. Devuelve true si se ejecutó.
func intentar_habilidad(slot: int, punto_objetivo = null) -> bool:
	if red != null and es_local_red and not red.es_servidor and red.estado == NetCoop.Estado.CONECTADO:
		var punto_envio = punto_objetivo
		if punto_envio == null:
			punto_envio = _punto_bajo_raton(get_viewport().get_mouse_position())
		red.enviar_accion(&"habilidad", {"slot": slot, "punto": punto_envio})
		return true
	if esta_muerto or arma_actual == null:
		return false
	if slot < 0 or slot >= combat._cooldowns.size():
		return false
	if combat._cooldowns[slot] > 0.0:
		return false

	var habilidad := arma_actual.obtener_habilidad(slot)
	if habilidad == null or not habilidad_desbloqueada(slot):
		return false
	if mana_actual < habilidad.coste_mana:
		return false

	mana_actual -= habilidad.coste_mana
	combat.set_cooldown(slot, cooldown_habilidad(habilidad))
	_cooldowns[slot] = combat.cooldown_restante(slot)
	mana_cambiada.emit(mana_actual, estadisticas.mana_maximo)

	var punto := _resolver_punto(habilidad, punto_objetivo)

	if habilidad.reduccion_dano > 0.0:
		_reduccion_temporal = habilidad.reduccion_dano
		_tiempo_reduccion = duracion_habilidad(habilidad)
	if habilidad.tipo == AbilityData.Tipo.MOVILIDAD:
		_ejecutar_dash(habilidad, punto)
		if habilidad.id == &"filo_paso_sombrio":
			_potenciar_tajo = true
	elif habilidad.tipo == AbilityData.Tipo.INVOCACION:
		_invocar_espiritu(habilidad, punto)

	_instanciar_efecto(habilidad, punto)
	if visual != null:
		visual.lanzar()
	habilidad_lanzada.emit(slot, habilidad)
	var sonido := &"habilidad"
	if arma_actual != null and arma_actual.clase == WeaponItem.Clase.CETRO:
		sonido = &"magia"
	elif habilidad.dano_base >= 45.0:
		sonido = &"golpe"
	elif habilidad.tipo == AbilityData.Tipo.MOVILIDAD:
		sonido = &"critico"
	Sfx.reproducir(sonido, -7.0)
	return true


func consumir_potenciador(habilidad_id: StringName) -> float:
	## Sinergia Filo: Paso Sombrío potencia el siguiente Tajo Gemelo (+40 %).
	if _potenciar_tajo and habilidad_id == &"filo_tajo_gemelo":
		_potenciar_tajo = false
		return 1.4
	return 1.0


func reducir_cooldown(slot: int, fraccion: float) -> void:
	if slot < 0 or slot >= _cooldowns.size():
		return
	_cooldowns[slot] = maxf(0.0, _cooldowns[slot] * (1.0 - clampf(fraccion, 0.0, 1.0)))


func usar_objeto(indice: int) -> bool:
	if _es_cliente_red():
		red.enviar_accion(&"objeto", {
			"indice": indice,
			"punto": _punto_bajo_raton(get_viewport().get_mouse_position()),
		})
		return true
	if inventario == null or esta_muerto:
		return false
	return inventario.usar(indice, self)


func restaurar_mana(cantidad: float) -> void:
	combat.restaurar_mana(cantidad)
	salud_actual = combat.salud_actual
	mana_actual = combat.mana_actual
	escudo_actual = combat.escudo_actual


func aplicar_furia_temporal(duracion: float, bonus_ataque: float, robo: float) -> void:
	_buff_ataque = maxf(_buff_ataque, bonus_ataque)
	_buff_robo = maxf(_buff_robo, robo)
	_buff_dano = maxf(_buff_dano, 0.15)
	_tiempo_buff = maxf(_tiempo_buff, duracion)
	estadisticas_combate_cambiadas.emit()


## Lanza habilidades de objetos (pergaminos, legendarios) con el mismo pipeline
## de efectos que las habilidades de arma, pero sin tocar el cooldown del arma.
func lanzar_habilidad_item(habilidad: AbilityData, punto_objetivo = null) -> bool:
	if esta_muerto or habilidad == null:
		return false
	if mana_actual < habilidad.coste_mana:
		return false
	mana_actual -= habilidad.coste_mana
	mana_cambiada.emit(mana_actual, estadisticas.mana_maximo)
	var punto := _resolver_punto(habilidad, punto_objetivo)

	if habilidad.reduccion_dano > 0.0:
		_reduccion_temporal = habilidad.reduccion_dano
		_tiempo_reduccion = duracion_habilidad(habilidad)
	if habilidad.tipo == AbilityData.Tipo.MOVILIDAD:
		_ejecutar_dash(habilidad, punto)
	elif habilidad.tipo == AbilityData.Tipo.INVOCACION:
		_invocar_espiritu(habilidad, punto)
	_instanciar_efecto(habilidad, punto)
	if visual != null:
		visual.lanzar()
	habilidad_lanzada.emit(-1, habilidad)
	Sfx.reproducir("magia" if habilidad.tipo_dano == GladiatorStats.TIPO_MAGICO else "habilidad", -7.0)
	return true


## Desplaza al gladiador hacia el punto apuntado, sin atravesar el navmesh.
func _ejecutar_dash(habilidad: AbilityData, punto: Vector3) -> void:
	var direccion := punto - global_position
	direccion.y = 0.0
	var distancia := minf(radio_habilidad(habilidad), direccion.length())
	if distancia < 0.25:
		return
	var destino := global_position + direccion.normalized() * distancia
	var mapa := get_world_3d().navigation_map
	if mapa.is_valid():
		destino = NavigationServer3D.map_get_closest_point(mapa, destino)
	var inicio := global_position
	global_position = destino
	velocity = Vector3.ZERO
	_tiene_orden_movimiento = false
	if arma_actual != null and arma_actual.clase == WeaponItem.Clase.FILO:
		_critico_asegurado = 3.0
		_otorgar_inmunidad_daño(0.4)  # i-frames durante el parpadeo
	if habilidad.efecto_especial == &"parpadeo":
		_critico_asegurado = 3.0
	if arma_actual != null and arma_actual.clase == WeaponItem.Clase.FILO:
		_crear_rastro(inicio, destino)
	if visual != null:
		visual.mover(0.0)


## Rastro geométrico temporal del dash (sin partículas: barato en Web).
func _crear_rastro(inicio: Vector3, fin: Vector3) -> void:
	var contenedor: Node = get_tree().current_scene
	if contenedor == null:
		contenedor = get_parent()
	if contenedor == null:
		return
	var pasos := 5
	for i in pasos:
		var t := float(i) / float(pasos - 1)
		var posicion := inicio.lerp(fin, t)
		var rastro := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(0.55, 0.03, 0.9)
		rastro.mesh = caja
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.35, 0.12, 0.55, 0.55)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = Color(0.45, 0.15, 0.7)
		material.emission_energy_multiplier = 1.4
		rastro.material_override = material
		contenedor.add_child(rastro)
		rastro.global_position = Vector3(posicion.x, 0.06, posicion.z)
		rastro.rotation.y = atan2(fin.x - inicio.x, fin.z - inicio.z)
		var tween := rastro.create_tween()
		tween.set_parallel(true)
		tween.tween_property(material, "albedo_color:a", 0.0, 0.6)
		tween.chain().tween_callback(rastro.queue_free)


func _invocar_espiritu(habilidad: AbilityData, punto: Vector3) -> void:
	var rango := rango_habilidad(habilidad.id)
	var duracion := duracion_habilidad(habilidad) + bono_talento(habilidad, "duracion")
	var dano := maxf(1.0, estadisticas.escalar_invocacion(habilidad.dano_base))
	dano += bono_rango(habilidad, "dano")
	dano += bono_talento(habilidad, "dano")
	# Aura de daño: objetos épicos/legendarios potencian a los espíritus.
	dano *= 1.0 + bono_aura(&"dano_aliados")

	var cantidad := 2 if rango >= 3 else 1
	for i in cantidad:
		var espiritu := SpiritSummon.crear()
		var contenedor: Node = get_tree().current_scene
		if contenedor == null:
			contenedor = get_parent()
		contenedor.add_child(espiritu)
		var desfase := Vector3(0.9, 0, 0.9) * float(i)
		espiritu.global_position = punto + desfase
		var factor := 1.0 if i == 0 else 0.5
		espiritu.configurar(self, dano * factor, duracion, factor < 1.0)
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
	if objetivo_actual == null and not _autoataque_activo and not mantener_posicion:
		return

	var alcance := arma_actual.alcance_ataque
	var objetivo := objetivo_actual
	if objetivo != null and not _objetivo_vivo(objetivo):
		objetivo = null
	if objetivo != null and global_position.distance_to(objetivo.global_position) > alcance:
		objetivo = null

	if objetivo == null:
		var mejor := alcance * alcance
		for nodo in get_tree().get_nodes_in_group(GRUPO_ENEMIGOS):
			var enemigo := nodo as Node3D
			if enemigo == null or not _objetivo_vivo(enemigo):
				continue
			var distancia := global_position.distance_squared_to(enemigo.global_position)
			if distancia < mejor:
				mejor = distancia
				objetivo = enemigo
		if objetivo != null and objetivo_actual == null:
			_fijar_objetivo(objetivo)

	if objetivo == null:
		_temporizador_ataque = 0.15
		return

	# Auras de objetos épicos/legendarios: se suman una vez por ataque.
	var auras := auras_cercanas()
	var vatq_aura := 1.0 + float(auras.get(&"velocidad_ataque_aliados", 0.0))
	# La recarga la descuenta CombatComponent: aquí solo se arma. Sin esto el
	# temporizador volvía a 0 cada frame y el campeón atacaba sin parar.
	_temporizador_ataque = 1.0 / maxf(0.2, estadisticas.velocidad_ataque * (1.0 + _buff_ataque) * vatq_aura)
	combat.iniciar_recarga_ataque(_temporizador_ataque)
	# Daño mín-máx: el golpe tira dentro de la banda del atributo y la clase.
	var rango := estadisticas.rango_dano_ataque(
		arma_actual.dano_ataque_base, arma_actual.atributo_principal
	)
	var dano := randf_range(rango.x, rango.y)
	dano *= 1.0 + _buff_dano
	# Aura de daño: bonos de objetos épicos/legendarios de ti y aliados cercanos.
	dano *= 1.0 + float(auras.get(&"dano_aliados", 0.0))
	var critico := _critico_asegurado > 0.0 or randf() < estadisticas.probabilidad_critico
	if critico:
		dano *= estadisticas.multiplicador_critico

	var direccion := objetivo.global_position - global_position
	direccion.y = 0.0
	_orientar(direccion.normalized(), 1.0)
	if visual != null:
		visual.atacar()

	if objetivo.has_method("recibir_dano"):
		objetivo.recibir_dano(dano, &"fisico", self, critico)
	ataque_basico.emit(objetivo, dano, critico)
	dano_infligido += dano
	estadisticas_combate_cambiadas.emit()
	# Aura de robo de vida: objetos épicos/legendarios de ti y aliados cercanos.
	var robo := estadisticas.robo_vida + _buff_robo + float(auras.get(&"robo_vida_aliados", 0.0))
	if robo > 0.0:
		curar(dano * robo)
	Sfx.reproducir("critico" if critico else "golpe", -8.0)

## Suma las auras de uno mismo y de los aliados cercanos en un solo barrido.
## Los espíritus no llevan inventario, así que no aportan.
func auras_cercanas() -> Dictionary:
	var totales: Dictionary = {}
	if inventario != null:
		var propias := inventario.auras()
		for clave in propias:
			totales[clave] = float(totales.get(clave, 0.0)) + float(propias[clave])
	for nodo in get_tree().get_nodes_in_group(GRUPO_GLADIADORES):
		var aliado := nodo as GladiatorController
		if aliado == null or aliado == self or not is_instance_valid(aliado):
			continue
		if global_position.distance_to(aliado.global_position) > RADIO_AURA:
			continue
		if aliado.inventario == null:
			continue
		var suyas := aliado.inventario.auras()
		for clave in suyas:
			totales[clave] = float(totales.get(clave, 0.0)) + float(suyas[clave])
	return totales


## Bono de un tipo de aura concreto (ej. "dano_aliados").
func bono_aura(tipo: StringName) -> float:
	return float(auras_cercanas().get(tipo, 0.0))


func cooldown_restante(slot: int) -> float:
	if slot < 0 or slot >= 4:
		return 0.0
	if combat != null:
		return combat.cooldown_restante(slot)
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
	if _es_cliente_red():
		if talento != null:
			red.enviar_accion(&"talento", {"id": talento.id})
		return false
	if talento == null or arma_actual == null:
		return false
	var rango := rango_talento(talento.id)
	if rango >= max(1, talento.rango_maximo):
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
func otorgar_escudo(cantidad: float, duracion: float) -> void:
	combat.otorgar_escudo(cantidad, duracion)
	salud_actual = combat.salud_actual
	mana_actual = combat.mana_actual
	escudo_actual = combat.escudo_actual


func otorgar_inmunidad_aturdimiento(duracion: float) -> void:
	combat.otorgar_inmunidad_aturdimiento(duracion)

func _otorgar_inmunidad_daño(duracion: float) -> void:
	combat.otorgar_inmunidad_daño(duracion)


func aplicar_grito_guerra(duracion: float, bonus_ataque: float, robo: float) -> void:
	combat.aplicar_grito_guerra(duracion, bonus_ataque, robo)
	_buff_ataque = combat._buff_ataque
	_buff_robo = combat._buff_robo
	_buff_dano = combat._buff_dano
	_tiempo_buff = combat._tiempo_buff


func registrar_dano(cantidad: float) -> void:
	combat.registrar_dano(cantidad)


func recibir_dano(
	cantidad: float,
	tipo: StringName = GladiatorStats.TIPO_FISICO,
	fuente: Node = null
) -> void:
	combat.recibir_dano(cantidad, tipo, fuente)
	salud_actual = combat.salud_actual
	mana_actual = combat.mana_actual
	escudo_actual = combat.escudo_actual
	esta_muerto = combat.esta_muerto
	recibio_dano.emit(1.0)


func curar(cantidad: float) -> void:
	combat.curar(cantidad)
	salud_actual = combat.salud_actual
	mana_actual = combat.mana_actual
	escudo_actual = combat.escudo_actual


func _morir() -> void:
	combat._morir()
	velocity = Vector3.ZERO
	_tiene_orden_movimiento = false
	objetivo_actual = null
	_ocultar_marcadores()
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
	if _es_cliente_red():
		red.enviar_accion(&"punto", {"atributo": atributo})
		return true
	return estadisticas.gastar_punto(atributo)


## Cambia la skin cosmética del orco sin alterar atributos.
func aplicar_impulso_velocidad(multiplicador: float, duracion: float) -> void:
	_multiplicador_velocidad = maxf(1.0, multiplicador)
	_tiempo_impulso = maxf(0.1, duracion)


func aplicar_skin(tinte: Color) -> void:
	tinte_skin = tinte
	if visual != null:
		visual.aplicar_skin(tinte)
	aspecto_cambiado.emit()


## Aplica el estado autoritativo que llega del servidor a un espejo local.
func aplicar_estado_red(datos: Dictionary) -> void:
	_pos_objetivo_red = datos.get("pos", global_position)
	rotation.y = float(datos.get("rot", rotation.y))

	var e := estadisticas
	var base: Dictionary = datos.get("base", {})
	e.fuerza = int(base.get("fuerza", e.fuerza))
	e.agilidad = int(base.get("agilidad", e.agilidad))
	e.inteligencia = int(base.get("inteligencia", e.inteligencia))
	e.nivel = int(datos.get("nivel", e.nivel))
	e.experiencia = int(datos.get("xp", e.experiencia))
	e.puntos_libres = int(datos.get("puntos_libres", e.puntos_libres))
	puntos_rojos = int(datos.get("puntos_rojos", puntos_rojos))

	var totales: Dictionary = datos.get("totales", {})
	e._bonos_equipo = {
		"fuerza": float(totales.get("fuerza", e.fuerza)) - float(e.fuerza),
		"agilidad": float(totales.get("agilidad", e.agilidad)) - float(e.agilidad),
		"inteligencia": float(totales.get("inteligencia", e.inteligencia)) - float(e.inteligencia),
	}
	var salud_max := float(datos.get("salud_max", e.salud_maxima))
	var mana_max := float(datos.get("mana_max", e.mana_maximo))
	e._bonos_equipo["vida"] = salud_max - (GladiatorStats.VIDA_BASE + e.fuerza_total * GladiatorStats.VIDA_POR_FUERZA)
	e._bonos_equipo["mana"] = mana_max - (GladiatorStats.MANA_BASE + e.inteligencia_total * GladiatorStats.MANA_POR_INT)
	e.atributos_cambiados.emit()

	salud_actual = float(datos.get("salud", salud_actual))
	mana_actual = float(datos.get("mana", mana_actual))
	escudo_actual = float(datos.get("escudo", 0.0))
	revive_en = float(datos.get("revive_en", 0.0))
	dano_infligido = float(datos.get("dano", dano_infligido))
	dano_recibido = float(datos.get("recibido", dano_recibido))

	var cds: Array = datos.get("cooldowns", [])
	for i in min(4, cds.size()):
		_cooldowns[i] = float(cds[i])
		if combat != null:
			combat.set_cooldown(i, float(cds[i]))

	var rangos_antes := _rangos_habilidad.duplicate()
	_rangos_habilidad.clear()
	var rangos: Dictionary = datos.get("rangos", {})
	for id in rangos:
		_rangos_habilidad[StringName(id)] = int(rangos[id])

	var desbloqueadas_antes := _habilidades_desbloqueadas.duplicate()
	_habilidades_desbloqueadas.clear()
	var desbloqueadas: Dictionary = datos.get("desbloqueadas", {})
	for id in desbloqueadas:
		_habilidades_desbloqueadas[StringName(id)] = bool(desbloqueadas[id])

	var talentos_antes := _talentos_activos.duplicate()
	_talentos_activos.clear()
	var talentos: Dictionary = datos.get("talentos", {})
	for id in talentos:
		_talentos_activos[StringName(id)] = int(talentos[id])

	if rangos_antes != _rangos_habilidad or desbloqueadas_antes != _habilidades_desbloqueadas:
		habilidades_cambiadas.emit()
	if talentos_antes != _talentos_activos:
		talentos_cambiados.emit()

	_aplicar_muerte_espejo(bool(datos.get("muerto", false)))


func _aplicar_muerte_espejo(muerto: bool) -> void:
	if muerto == esta_muerto:
		return
	esta_muerto = muerto
	if muerto:
		velocity = Vector3.ZERO
		_ocultar_marcadores()
		if visual != null:
			visual.morir()
	elif visual != null:
		visual.revivir()


## Revive al gladiador conservando stats, talentos, nivel e inventario.
## Solo el servidor lo llama; los clientes reciben el estado por snapshot.
func revivir_red(posicion: Vector3, fraccion_salud := 0.6) -> void:
	esta_muerto = false
	revive_en = 0.0
	global_position = posicion
	salud_actual = maxf(1.0, estadisticas.salud_maxima * clampf(fraccion_salud, 0.1, 1.0))
	mana_actual = estadisticas.mana_maximo * 0.5
	escudo_actual = 0.0
	velocity = Vector3.ZERO
	_tiene_orden_movimiento = false
	mantener_posicion = false
	modo_ataque_movimiento = false
	_autoataque_activo = true
	objetivo_actual = null
	_temporizador_ataque = 0.0
	_tiempo_reduccion = 0.0
	_reduccion_temporal = 0.0
	_buff_ataque = 0.0
	_buff_robo = 0.0
	_buff_dano = 0.0
	_tiempo_buff = 0.0
	_tiempo_escudo = 0.0
	_escudo_maximo = 0.0
	puede_moverse = true
	add_to_group(GRUPO_GLADIADORES)
	if agente != null:
		agente.set_physics_process(true)
	if visual != null:
		visual.revivir()
	_emitir_estado()
	Sfx.reproducir(&"victoria", -10.0)


func _al_cambiar_atributos() -> void:
	salud_actual = minf(salud_actual, estadisticas.salud_maxima)
	mana_actual = minf(mana_actual, estadisticas.mana_maximo)
	_emitir_estado()


func _emitir_estado() -> void:
	salud_cambiada.emit(salud_actual, estadisticas.salud_maxima)
	mana_cambiada.emit(mana_actual, estadisticas.mana_maximo)

func _cb_salud_cambiada(actual: float, maxima: float) -> void:
	salud_cambiada.emit(actual, maxima)

func _cb_mana_cambiada(actual: float, maximo: float) -> void:
	mana_cambiada.emit(actual, maximo)

func _cb_escudo_cambiado(actual: float, maximo: float) -> void:
	escudo_cambiado.emit(actual, maximo)

func _cb_ataque_basico(objetivo: Node3D, dano: float, critico: bool) -> void:
	ataque_basico.emit(objetivo, dano, critico)