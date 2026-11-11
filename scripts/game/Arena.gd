class_name Arena
extends Node3D
## Raíz del prototipo: construye la arena, conecta los sistemas y gestiona la
## economía (oro, puntos de atributo) y la condición de victoria/derrota.
##
## La escena se genera por código para poder iterar sin editor. Los sistemas
## (oleadas, público, HUD, armería) son nodos independientes y sustituibles.

const ANCHO := 44.0
const LARGO := 32.0
const ALTO_MURO := 1.4
const RADIO_PUBLICO := 25.0
const RADIO_INTERACCION := 3.5

var oro := 200
var puntos_atributo := 0
var terminado := false

var _jugador: GladiatorController
var _camara: ArenaCamera
var _bandera: RebellionBanner
var _oleadas: WaveManager
var _publico: AudienceFury
var _hud: ArenaHUD
var _pedestales: Array[ArmoryPedestal] = []
var _puntos_spawn: Array[Vector3] = []


func _ready() -> void:
	_crear_entorno()
	_crear_suelo()
	_crear_muros()
	_crear_bandera()
	_crear_jugador()
	_crear_camara()
	_crear_armeria()
	_crear_oleadas()
	_crear_publico()
	_crear_hud()
	_conectar()

	var args := OS.get_cmdline_user_args()
	if "--captura" in args or "--captura-combate" in args:
		_capturar()


func _process(_delta: float) -> void:
	_actualizar_pista()


func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey):
		return
	var tecla := evento as InputEventKey
	if not tecla.pressed or tecla.echo:
		return

	match tecla.physical_keycode:
		KEY_F:
			_comprar_cercana()
		KEY_1:
			_gastar_punto(&"fuerza")
		KEY_2:
			_gastar_punto(&"agilidad")
		KEY_3:
			_gastar_punto(&"inteligencia")
		KEY_ENTER:
			if terminado:
				get_tree().reload_current_scene()


# --- Construcción del mundo ----------------------------------------------

func _crear_entorno() -> void:
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color(0.07, 0.06, 0.10)
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(0.78, 0.72, 0.88)
	entorno.ambient_light_energy = 0.65
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var mundo := WorldEnvironment.new()
	mundo.environment = entorno
	add_child(mundo)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sol.light_energy = 1.15
	sol.light_color = Color(1.0, 0.93, 0.82)
	sol.shadow_enabled = false
	add_child(sol)

	var relleno := OmniLight3D.new()
	relleno.position = Vector3(0, 8, 0)
	relleno.omni_range = 40.0
	relleno.light_energy = 0.5
	relleno.light_color = Color(1.0, 0.55, 0.30)
	add_child(relleno)


func _crear_suelo() -> void:
	var region := NavigationRegion3D.new()
	var malla_nav := NavigationMesh.new()
	var mitad := Vector3(ANCHO * 0.5, 0.0, LARGO * 0.5)
	malla_nav.vertices = PackedVector3Array([
		Vector3(-mitad.x, 0, -mitad.z),
		Vector3(mitad.x, 0, -mitad.z),
		Vector3(mitad.x, 0, mitad.z),
		Vector3(-mitad.x, 0, mitad.z),
	])
	malla_nav.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = malla_nav
	add_child(region)

	var suelo := StaticBody3D.new()
	suelo.collision_layer = 1
	suelo.collision_mask = 1

	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(ANCHO, 1.0, LARGO)
	forma.shape = caja
	forma.position.y = -0.5
	suelo.add_child(forma)

	var visual := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(ANCHO, LARGO)
	visual.mesh = plano
	visual.material_override = _material(Color(0.36, 0.29, 0.22))
	suelo.add_child(visual)
	add_child(suelo)

	# Terreno exterior: evita que la cámara enseñe el vacío en las esquinas.
	var exterior := MeshInstance3D.new()
	var plano_exterior := PlaneMesh.new()
	plano_exterior.size = Vector2(ANCHO * 2.4, LARGO * 2.4)
	exterior.mesh = plano_exterior
	exterior.position.y = -0.05
	exterior.material_override = _material(Color(0.14, 0.12, 0.13))
	add_child(exterior)

	# Anillo central bajo el estandarte.
	var anillo := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 5.0
	cilindro.bottom_radius = 5.0
	cilindro.height = 0.04
	anillo.mesh = cilindro
	anillo.position.y = 0.02
	anillo.material_override = _material(Color(0.45, 0.32, 0.20))
	add_child(anillo)

	# Gradas: cuatro volúmenes fuera de los muros (origen de los proyectiles).
	_crear_prop(Vector3(0, 1.5, -LARGO * 0.5 - 4.0), Vector3(ANCHO, 3.0, 6.0), Color(0.16, 0.14, 0.18))
	_crear_prop(Vector3(0, 1.5, LARGO * 0.5 + 4.0), Vector3(ANCHO, 3.0, 6.0), Color(0.16, 0.14, 0.18))
	_crear_prop(Vector3(-ANCHO * 0.5 - 4.0, 1.5, 0), Vector3(6.0, 3.0, LARGO), Color(0.13, 0.12, 0.16))
	_crear_prop(Vector3(ANCHO * 0.5 + 4.0, 1.5, 0), Vector3(6.0, 3.0, LARGO), Color(0.13, 0.12, 0.16))

	_puntos_spawn = [
		Vector3(-ANCHO * 0.5 + 4.0, 0, -LARGO * 0.5 + 3.0),
		Vector3(ANCHO * 0.5 - 4.0, 0, -LARGO * 0.5 + 3.0),
		Vector3(-ANCHO * 0.5 + 4.0, 0, LARGO * 0.5 - 3.0),
		Vector3(ANCHO * 0.5 - 4.0, 0, LARGO * 0.5 - 3.0),
	]


func _crear_muros() -> void:
	var piedra := Color(0.24, 0.22, 0.21)
	_crear_caja_estatica(Vector3(0, ALTO_MURO * 0.5, -LARGO * 0.5), Vector3(ANCHO, ALTO_MURO, 1.0), piedra)
	_crear_caja_estatica(Vector3(0, ALTO_MURO * 0.5, LARGO * 0.5), Vector3(ANCHO, ALTO_MURO, 1.0), piedra)
	_crear_caja_estatica(Vector3(-ANCHO * 0.5, ALTO_MURO * 0.5, 0), Vector3(1.0, ALTO_MURO, LARGO), piedra)
	_crear_caja_estatica(Vector3(ANCHO * 0.5, ALTO_MURO * 0.5, 0), Vector3(1.0, ALTO_MURO, LARGO), piedra)


func _crear_bandera() -> void:
	_bandera = RebellionBanner.crear()
	add_child(_bandera)
	_bandera.global_position = Vector3.ZERO


func _crear_jugador() -> void:
	_jugador = GladiatorController.new()
	_jugador.name = "Gladiador"
	_jugador.collision_layer = 1
	_jugador.collision_mask = 1

	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.45
	capsula.height = 1.8
	forma.shape = capsula
	forma.position.y = 0.9
	_jugador.add_child(forma)

	var agente := NavigationAgent3D.new()
	agente.name = "NavigationAgent3D"
	_jugador.add_child(agente)

	var modelo := Node3D.new()
	modelo.name = "Modelo"

	var cuerpo := MeshInstance3D.new()
	var malla_cuerpo := CapsuleMesh.new()
	malla_cuerpo.radius = 0.45
	malla_cuerpo.height = 1.6
	cuerpo.mesh = malla_cuerpo
	cuerpo.position.y = 0.8
	cuerpo.material_override = _material(Color(0.34, 0.52, 0.22))
	modelo.add_child(cuerpo)

	var cabeza := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.27
	esfera.height = 0.54
	cabeza.mesh = esfera
	cabeza.position = Vector3(0, 1.62, 0.08)
	cabeza.material_override = _material(Color(0.40, 0.58, 0.25))
	modelo.add_child(cabeza)

	var arma := MeshInstance3D.new()
	var caja_arma := BoxMesh.new()
	caja_arma.size = Vector3(0.10, 0.10, 1.3)
	arma.mesh = caja_arma
	arma.position = Vector3(0.5, 1.0, 0.45)
	var acero := StandardMaterial3D.new()
	acero.albedo_color = Color(0.72, 0.72, 0.78)
	acero.metallic = 0.8
	acero.roughness = 0.4
	arma.material_override = acero
	modelo.add_child(arma)

	_jugador.add_child(modelo)
	_jugador.estadisticas = GladiatorStats.new()
	_jugador.arma_inicial = WeaponItem.crear_prisionero()

	add_child(_jugador)
	_jugador.global_position = Vector3(0, 0, 6)


func _crear_camara() -> void:
	_camara = ArenaCamera.new()
	add_child(_camara)
	_camara.objetivo = _jugador
	_camara.global_position = _jugador.global_position + _camara.desplazamiento
	_camara.current = true


func _crear_armeria() -> void:
	var armas := WeaponItem.crear_catalogo_base()
	for i in armas.size():
		var pedestal := ArmoryPedestal.new()
		add_child(pedestal)
		pedestal.global_position = Vector3(-6.0 + i * 6.0, 0, 11.0)
		pedestal.configurar(armas[i])
		_pedestales.append(pedestal)


func _crear_oleadas() -> void:
	_oleadas = WaveManager.new()
	add_child(_oleadas)
	_oleadas.iniciar(_jugador, _bandera, _puntos_spawn, self)


func _crear_publico() -> void:
	_publico = AudienceFury.new()
	add_child(_publico)
	_publico.iniciar(_jugador, Vector3.ZERO, RADIO_PUBLICO)


func _crear_hud() -> void:
	_hud = ArenaHUD.new()
	add_child(_hud)
	_hud.configurar(_jugador, _oleadas, _bandera, self)


func _conectar() -> void:
	_oleadas.oleada_terminada.connect(_al_terminar_oleada)
	_oleadas.oro_ganado.connect(_al_ganar_oro)
	_oleadas.victoria.connect(_al_victoria)
	_bandera.destruida.connect(_al_destruir_bandera)
	_jugador.murio.connect(_al_morir_jugador)
	_jugador.arma_cambiada.connect(_al_cambiar_arma)
	_publico.furia_iniciada.connect(_al_furia_iniciada)


# --- Economía y armería ---------------------------------------------------

func _al_terminar_oleada(numero: int) -> void:
	if terminado:
		return
	oro += 60 + numero * 15
	puntos_atributo += 2
	_jugador.estadisticas.otorgar_puntos(2)
	_jugador.otorgar_puntos_rojos(1)
	_jugador.curar(_jugador.estadisticas.salud_maxima * 0.25)
	_hud.mostrar_mensaje("Oleada %d superada  ·  +2 puntos" % numero, 2.5)


func _al_ganar_oro(cantidad: int) -> void:
	if terminado:
		return
	if _publico != null and _publico.congelando:
		return
	oro += cantidad


func _gastar_punto(atributo: StringName) -> void:
	if terminado or puntos_atributo <= 0:
		return
	if _jugador.gastar_punto_atributo(atributo):
		puntos_atributo -= 1


func _comprar_cercana() -> void:
	if terminado:
		return
	var pedestal := _pedestal_cercano()
	if pedestal == null:
		return
	if oro < pedestal.precio():
		_hud.mostrar_mensaje("Necesitas %d de oro" % pedestal.precio(), 2.0)
		return
	if pedestal.comprar(_jugador):
		oro -= pedestal.precio()
		_hud.mostrar_mensaje("Has tomado %s" % pedestal.arma.nombre, 2.5)


func _pedestal_cercano() -> ArmoryPedestal:
	var mejor: ArmoryPedestal = null
	var mejor_distancia := RADIO_INTERACCION
	for pedestal in _pedestales:
		if pedestal.vendida:
			continue
		var distancia := _jugador.global_position.distance_to(pedestal.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = pedestal
	return mejor


func _actualizar_pista() -> void:
	if _hud == null or _jugador == null or terminado:
		return
	var pedestal := _pedestal_cercano()
	if pedestal == null:
		_hud.establecer_pista("")
		return
	var alcanza := " " if oro >= pedestal.precio() else "  ·  falta oro"
	_hud.establecer_pista("F — %s (%d oro)%s" % [pedestal.arma.nombre, pedestal.precio(), alcanza])


# --- Final de partida -----------------------------------------------------

func _al_cambiar_arma(arma: WeaponItem) -> void:
	if _hud != null and arma != null:
		_hud.mostrar_mensaje("Equipado: %s" % arma.nombre, 2.0)


func _al_furia_iniciada(duracion: float) -> void:
	_hud.mostrar_mensaje("¡El público se aburre! Muévete. (%.0f s)" % duracion, 2.0)


func _al_morir_jugador() -> void:
	_finalizar("DERROTA", "El gladiador ha caído.")


func _al_destruir_bandera() -> void:
	_finalizar("DERROTA", "El estandarte de la rebelión ha caído.")


func _al_victoria() -> void:
	_finalizar("VICTORIA", "Las 20 oleadas han sido superadas.")


func _finalizar(titulo: String, detalle: String) -> void:
	if terminado:
		return
	terminado = true
	_jugador.puede_moverse = false
	_oleadas.set_process(false)
	_publico.set_process(false)
	_hud.mostrar_final("%s\n%s" % [titulo, detalle])
	if _jugador.esta_muerto:
		_hud.mostrar_final("%s\n%s\n\nEnter para reintentar" % [titulo, detalle])
	else:
		_hud.mostrar_final("%s\n%s\n\nEnter para reintentar" % [titulo, detalle])


func esta_congelado() -> bool:
	return _publico != null and _publico.congelando


# --- Utilidades -----------------------------------------------------------

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


func _crear_prop(pos: Vector3, tam: Vector3, color: Color) -> void:
	var nodo := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	nodo.mesh = caja
	nodo.position = pos
	nodo.material_override = _material(color)
	add_child(nodo)


func _crear_caja_estatica(pos: Vector3, tam: Vector3, color: Color) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.position = pos
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 1

	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tam
	forma.shape = caja
	cuerpo.add_child(forma)

	var visual := MeshInstance3D.new()
	var malla := BoxMesh.new()
	malla.size = tam
	visual.mesh = malla
	visual.material_override = _material(color)
	cuerpo.add_child(visual)
	add_child(cuerpo)


## Captura una imagen para revisar la dirección visual sin abrir el editor.
func _capturar() -> void:
	var combate := "--captura-combate" in OS.get_cmdline_user_args()
	if combate:
		var sin_arma: bool = _jugador != null and _jugador.arma_actual != null and _jugador.arma_actual.clase == WeaponItem.Clase.PRISIONERO
		if sin_arma:
			_jugador.equipar_arma(WeaponItem.crear_catalogo_base()[0])
		await get_tree().create_timer(8.5).timeout
	else:
		await get_tree().create_timer(2.5).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	var imagen := get_viewport().get_texture().get_image()
	var ruta := "res://captura_combate.png" if combate else "res://captura.png"
	var error := imagen.save_png(ProjectSettings.globalize_path(ruta))
	print("CAPTURA: guardada en ", ruta, " error=", error, " tamaño=", imagen.get_size())
	get_tree().quit()
