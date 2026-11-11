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

const SLOT_Q := 0
const SLOT_W := 1
const SLOT_E := 2
const SLOT_R := 3
const RANGO_AGGRO := 7.0
const RANGO_OBJETIVO := 12.0
const RADIO_ATAQUE_MOVIMIENTO := 6.0

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
var inventario: InventoryComponent
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
var _buff_ataque := 0.0
var _buff_robo := 0.0
var _buff_dano := 0.0
var _tiempo_buff := 0.0
var _potenciar_tajo := false
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

	salud_actual = estadisticas.salud_maxima
	mana_actual = estadisticas.mana_maximo

	agente.path_desired_distance = 0.6
	agente.target_desired_distance = 0.4

	_preparar_visual()
	_crear_marcadores()

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


func _physics_process(delta: float) -> void:
	_actualizar_cooldowns(delta)
	_actualizar_estados(delta)
	if inventario != null:
		inventario.actualizar(delta)

	if esta_muerto:
		velocity = Vector3.ZERO
		return

	_regenerar(delta)
	_temporizador_ataque = maxf(0.0, _temporizador_ataque - delta)
	_actualizar_objetivo(delta)
	_actualizar_marcador_objetivo()

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
	_modo_ataque_armado = not _modo_ataque_armado
	modo_cambiado.emit(&"armar_ataque" if _modo_ataque_armado else &"cancelar")


func _animar_destino(destino: Vector3, marcador: MeshInstance3D, radio: float) -> void:
	_mostrar_marcador(marcador, destino, radio * 1.35)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(marcador, "scale", Vector3(radio * 0.55, 1.0, radio * 0.55), 0.55)
	tween.chain().tween_callback(func() -> void:
		if marcador == _marcador_movimiento and not modo_ataque_movimiento:
			marcador.visible = false
	)


func _mover(delta: float) -> void:
	var deseada := Vector3.ZERO

	if objetivo_actual != null and not mantener_posicion:
		var distancia := global_position.distance_to(objetivo_actual.global_position)
		var alcance := arma_actual.alcance_ataque if arma_actual != null else 2.0
		if distancia > alcance * 0.9:
			var direccion := objetivo_actual.global_position - global_position
			direccion.y = 0.0
			if direccion.length_squared() > 0.0004:
				direccion = direccion.normalized()
				deseada = direccion * estadisticas.velocidad_movimiento
				_orientar(direccion, delta)
		elif _tiene_orden_movimiento:
			_tiene_orden_movimiento = false

	if deseada == Vector3.ZERO and _tiene_orden_movimiento and not agente.is_navigation_finished():
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


func _actualizar_estados(delta: float) -> void:
	_tiempo_reduccion = maxf(0.0, _tiempo_reduccion - delta)
	if _tiempo_reduccion <= 0.0:
		_reduccion_temporal = 0.0
	_critico_asegurado = maxf(0.0, _critico_asegurado - delta)
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
	if inventario == null or esta_muerto:
		return false
	return inventario.usar(indice, self)


func restaurar_mana(cantidad: float) -> void:
	if esta_muerto or cantidad <= 0.0:
		return
	mana_actual = minf(estadisticas.mana_maximo, mana_actual + cantidad)
	mana_cambiada.emit(mana_actual, estadisticas.mana_maximo)


func aplicar_furia_temporal(duracion: float, bonus_ataque: float, robo: float) -> void:
	_buff_ataque = maxf(_buff_ataque, bonus_ataque)
	_buff_robo = maxf(_buff_robo, robo)
	_buff_dano = maxf(_buff_dano, 0.15)
	_tiempo_buff = maxf(_tiempo_buff, duracion)
	estadisticas_combate_cambiadas.emit()


## Lanza habilidades de objetos (pergaminos, legendarios) con el mismo pipeline
## de efectos que las habilidades de arma, pero sin tocar el cooldown del arma.
func lanzar_habilidad_item(habilidad: AbilityData) -> bool:
	if esta_muerto or habilidad == null:
		return false
	if mana_actual < habilidad.coste_mana:
		return false
	mana_actual -= habilidad.coste_mana
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
	habilidad_lanzada.emit(-1, habilidad)
	Sfx.reproducir("magia" if habilidad.tipo_dano == GladiatorStats.TIPO_MAGICO else "habilidad", -7.0)
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
	var inicio := global_position
	global_position = destino
	velocity = Vector3.ZERO
	_tiene_orden_movimiento = false
	if arma_actual != null and arma_actual.clase == WeaponItem.Clase.FILO:
		_critico_asegurado = 3.0
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

	_temporizador_ataque = 1.0 / maxf(0.2, estadisticas.velocidad_ataque * (1.0 + _buff_ataque))
	var dano := estadisticas.escalar_dano(arma_actual.dano_ataque_base, &"fisico")
	dano *= 1.0 + _buff_dano
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
	var robo := estadisticas.robo_vida + _buff_robo
	if robo > 0.0:
		curar(dano * robo)
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
func otorgar_escudo(cantidad: float, duracion: float) -> void:
	if cantidad <= 0.0:
		return
	escudo_actual = maxf(escudo_actual, cantidad)
	_escudo_maximo = maxf(_escudo_maximo, escudo_actual)
	_tiempo_escudo = maxf(_tiempo_escudo, duracion)
	escudo_cambiado.emit(escudo_actual, _escudo_maximo)


func otorgar_inmunidad_aturdimiento(duracion: float) -> void:
	_inmunidad_aturdimiento = maxf(_inmunidad_aturdimiento, duracion)


func aplicar_grito_guerra(duracion: float, bonus_ataque: float, robo: float) -> void:
	_buff_ataque = maxf(_buff_ataque, bonus_ataque)
	_buff_robo = maxf(_buff_robo, robo)
	_tiempo_buff = maxf(_tiempo_buff, duracion)
	# El grito también cura al estandarte y a las invocaciones cercanas.
	var cantidad := estadisticas.escalar_invocacion(60.0 + estadisticas.inteligencia_total * 1.2)
	for grupo in [&"banderas", &"aliados"]:
		for nodo in get_tree().get_nodes_in_group(grupo):
			var aliado := nodo as Node3D
			if aliado == null or not aliado.has_method("curar"):
				continue
			if aliado.global_position.distance_to(global_position) <= 10.0:
				aliado.curar(cantidad)
				if aliado.has_method("aplicar_buff"):
					aliado.aplicar_buff(duracion, bonus_ataque, robo)
	estadisticas_combate_cambiadas.emit()


func registrar_dano(cantidad: float) -> void:
	dano_infligido += cantidad
	estadisticas_combate_cambiadas.emit()


func recibir_dano(
	cantidad: float,
	tipo: StringName = GladiatorStats.TIPO_FISICO,
	fuente: Node = null
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

	if escudo_actual > 0.0:
		var absorbido := minf(escudo_actual, recibido)
		escudo_actual -= absorbido
		recibido -= absorbido
		escudo_cambiado.emit(escudo_actual, _escudo_maximo)
		NumerosDano.mostrar(global_position + Vector3(0, 1.9, 0), absorbido, GladiatorStats.TIPO_VERDADERO)

	# Bastión R: la Égida devuelve daño físico proporcional a la Fuerza.
	if _tiempo_escudo > 0.0 and tipo == GladiatorStats.TIPO_FISICO and fuente != null:
		if is_instance_valid(fuente) and fuente.has_method("recibir_dano"):
			var reflejo := estadisticas.fuerza_total * 0.8
			fuente.recibir_dano(reflejo, GladiatorStats.TIPO_VERDADERO, self)
			estadisticas_combate_cambiadas.emit()

	if recibido <= 0.0:
		return

	salud_actual = maxf(0.0, salud_actual - recibido)
	dano_recibido += recibido
	if salud_actual > 0.0:
		NumerosDano.mostrar(global_position + Vector3(0, 1.8, 0), recibido, tipo)
	salud_cambiada.emit(salud_actual, estadisticas.salud_maxima)
	estadisticas_combate_cambiadas.emit()
	if visual != null:
		visual.recibir_golpe()
	Sfx.reproducir("dano", -6.0)

	if salud_actual <= 0.0:
		_morir()


func curar(cantidad: float) -> void:
	if esta_muerto or cantidad <= 0.0:
		return
	var antes := salud_actual
	salud_actual = minf(estadisticas.salud_maxima, salud_actual + cantidad)
	var curado := salud_actual - antes
	if curado > 0.5:
		NumerosDano.mostrar(global_position + Vector3(0, 1.9, 0), curado, GladiatorStats.TIPO_VERDADERO, false, true)
	salud_cambiada.emit(salud_actual, estadisticas.salud_maxima)


func _morir() -> void:
	if esta_muerto:
		return
	esta_muerto = true
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
