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

## Paletas de skin del gladiador: se multiplican sobre la textura base.
const SKIN_TIERRA_BALDIA := Color(0.72, 0.95, 0.55)
const SKIN_CENIZA := Color(0.78, 0.80, 0.78)
const SKIN_SANGRE := Color(1.00, 0.62, 0.55)
const SKIN_HIELO := Color(0.62, 0.82, 1.00)
const SKINS := [
	{"nombre": "Tierra Baldía", "tinte": SKIN_TIERRA_BALDIA},
	{"nombre": "Ceniza", "tinte": SKIN_CENIZA},
	{"nombre": "Sangre", "tinte": SKIN_SANGRE},
	{"nombre": "Hielo", "tinte": SKIN_HIELO},
]

var oro := 200
var puntos_atributo := 0
var terminado := false
var _skin_actual := 0

var _jugador: GladiatorController
var _camara: ArenaCamera
var _bandera: RebellionBanner
var _oleadas: WaveManager
var _publico: AudienceFury
var _hud: ArenaHUD
var _pedestales: Array[ArmoryPedestal] = []
var _puntos_spawn: Array[Vector3] = []


func _ready() -> void:
	get_tree().paused = false
	_crear_entorno()
	_crear_suelo()
	_crear_muros()
	_crear_decoracion()
	_crear_bandera()
	_crear_jugador()
	_crear_camara()
	_crear_armeria()
	_crear_oleadas()
	_crear_publico()
	_crear_hud()
	_conectar()

	var args := OS.get_cmdline_user_args()
	if "--captura" in args or "--captura-combate" in args or "--captura-cerca" in args or "--captura-talentos" in args or "--captura-habilidad" in args or "--captura-jefe" in args:
		_capturar()


func _process(_delta: float) -> void:
	_actualizar_pista()


func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey):
		return
	var tecla := evento as InputEventKey
	if not tecla.pressed or tecla.echo:
		return

	if terminado:
		if tecla.physical_keycode == KEY_ENTER:
			get_tree().reload_current_scene()
		return

	match tecla.physical_keycode:
		KEY_F:
			_comprar_cercana()
		KEY_T:
			_hud.alternar_talentos()
		KEY_K:
			_ciclar_skin()
		KEY_ESCAPE:
			_hud.cerrar_talentos()
		KEY_1:
			_gastar_punto(&"fuerza")
		KEY_2:
			_gastar_punto(&"agilidad")
		KEY_3:
			_gastar_punto(&"inteligencia")


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
	exterior.material_override = _material(Color(0.33, 0.27, 0.22))
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


## Props modulares de KayKit: columnas, antorchas y estandartes del Imperio.
func _crear_decoracion() -> void:
	var columna := load("res://assets/kaykit/dungeon/column.gltf.glb") as PackedScene
	var antorcha := load("res://assets/kaykit/dungeon/torch_lit.gltf.glb") as PackedScene
	var banderin := load("res://assets/kaykit/dungeon/banner_red.gltf.glb") as PackedScene

	var esquinas := [
		Vector3(-ANCHO * 0.5 + 2.0, 0, -LARGO * 0.5 + 2.0),
		Vector3(ANCHO * 0.5 - 2.0, 0, -LARGO * 0.5 + 2.0),
		Vector3(-ANCHO * 0.5 + 2.0, 0, LARGO * 0.5 - 2.0),
		Vector3(ANCHO * 0.5 - 2.0, 0, LARGO * 0.5 - 2.0),
	]
	for punto in esquinas:
		_instanciar_prop(columna, punto, 1.6)
		_instanciar_prop(antorcha, punto + Vector3(0, 2.7, 0), 1.4)
		var luz := OmniLight3D.new()
		luz.position = punto + Vector3(0, 3.0, 0)
		luz.omni_range = 9.0
		luz.light_energy = 1.2
		luz.light_color = Color(1.0, 0.58, 0.26)
		add_child(luz)

	# Columnas intermedias: ritmo visual sin coste de mallas animadas.
	for x in [-11.0, 0.0, 11.0]:
		_instanciar_prop(columna, Vector3(x, 0, -LARGO * 0.5 + 1.6), 1.5)
		_instanciar_prop(columna, Vector3(x, 0, LARGO * 0.5 - 1.6), 1.5)

	for x in [-8.0, 8.0]:
		_instanciar_prop(banderin, Vector3(x, 2.2, -LARGO * 0.5 + 1.1), 1.3)


func _instanciar_prop(escena: PackedScene, pos: Vector3, escala: float) -> void:
	if escena == null:
		return
	var nodo := escena.instantiate() as Node3D
	if nodo == null:
		return
	nodo.position = pos
	nodo.scale = Vector3.ONE * escala
	add_child(nodo)


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

	_jugador.tinte_skin = SKIN_TIERRA_BALDIA
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
	_oleadas.oleada_iniciada.connect(_al_iniciar_oleada)
	_oleadas.oleada_terminada.connect(_al_terminar_oleada)
	_oleadas.oro_ganado.connect(_al_ganar_oro)
	_oleadas.victoria.connect(_al_victoria)
	_bandera.destruida.connect(_al_destruir_bandera)
	_jugador.murio.connect(_al_morir_jugador)
	_jugador.arma_cambiada.connect(_al_cambiar_arma)
	_publico.furia_iniciada.connect(_al_furia_iniciada)


# --- Economía y armería ---------------------------------------------------

func _al_iniciar_oleada(_numero: int, _total: int) -> void:
	Sfx.reproducir("oleada", -5.0)


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


## Rota entre las skins cosméticas del orco (K).
func _ciclar_skin() -> void:
	if _jugador == null:
		return
	_skin_actual = (_skin_actual + 1) % SKINS.size()
	var skin: Dictionary = SKINS[_skin_actual]
	_jugador.aplicar_skin(skin["tinte"])
	_hud.mostrar_mensaje("Skin: %s" % skin["nombre"], 2.0)


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
		Sfx.reproducir("compra", -3.0)


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
	_hud.cerrar_talentos()
	Sfx.reproducir("victoria" if titulo == "VICTORIA" else "derrota")
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
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	var cerca := "--captura-cerca" in args
	var talentos := "--captura-talentos" in args
	var habilidad := "--captura-habilidad" in args
	var capturar_jefe := "--captura-jefe" in args
	var combate := "--captura-combate" in args or cerca or talentos or habilidad or capturar_jefe
	if combate:
		var sin_arma: bool = _jugador != null and _jugador.arma_actual != null and _jugador.arma_actual.clase == WeaponItem.Clase.PRISIONERO
		if sin_arma:
			var catalogo := WeaponItem.crear_catalogo_base()
			_jugador.equipar_arma(catalogo[2] if habilidad else catalogo[0])
		if talentos:
			_jugador.otorgar_puntos_rojos(8)
			_hud.alternar_talentos()
		if habilidad:
			_jugador.mana_actual = _jugador.estadisticas.mana_maximo
			var hab := _jugador.arma_actual.obtener_habilidad(3)
			if hab != null:
				_jugador._invocar_espiritu(hab, _jugador.global_position + Vector3(1.8, 0, 1.2))
			if _camara != null:
				_camara.size = 14.0
		elif capturar_jefe:
			var jefe := ArenaBossAI.crear(
				"res://assets/kaykit/skeletons/Skeleton_Mage.glb",
				Color(0.55, 0.95, 0.72), 1.5, "mago"
			)
			jefe.configurar_para_ronda(10)
			add_child(jefe)
			jefe.global_position = _jugador.global_position + Vector3(2.0, 0, -1.5)
			jefe.objetivo = _jugador
			if _camara != null:
				_camara.size = 14.0
		elif cerca and _camara != null:
			_camara.size = 7.0
		await get_tree().create_timer(3.0 if (cerca or talentos or habilidad or capturar_jefe) else 8.5).timeout
	else:
		await get_tree().create_timer(2.5).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	var imagen := get_viewport().get_texture().get_image()
	var ruta := "res://captura.png"
	if cerca:
		ruta = "res://captura_cerca.png"
	elif talentos:
		ruta = "res://captura_talentos.png"
	elif habilidad:
		ruta = "res://captura_habilidad.png"
	elif capturar_jefe:
		ruta = "res://captura_jefe.png"
	elif combate:
		ruta = "res://captura_combate.png"
	var error := imagen.save_png(ProjectSettings.globalize_path(ruta))
	print("CAPTURA: guardada en ", ruta, " error=", error, " tamaño=", imagen.get_size())
	get_tree().quit()
