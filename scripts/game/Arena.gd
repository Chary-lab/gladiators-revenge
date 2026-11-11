class_name Arena
extends Node3D
## Raíz del prototipo: construye la arena, conecta los sistemas y gestiona la
## economía (oro, puntos de atributo) y la condición de victoria/derrota.
##
## La escena se genera por código para poder iterar sin editor. Los sistemas
## (oleadas, público, HUD, armería) son nodos independientes y sustituibles.

const ANCHO := 60.0
const LARGO := 40.0
const ALTO_MURO := 1.4
const RADIO_PUBLICO := 32.0
const RADIO_INTERACCION := 3.5
const BORDE_ARENA := 10.0
const CENTRO_ARENA := Vector3(-8.0, 0, 0)

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
var _tienda: ShopPedestal
var _puerta: PuertaArena
var _texto_pista := ""
var _pedestales: Array[ArmoryPedestal] = []
var _puntos_spawn: Array[Vector3] = []
var _en_combate := false
var _fuente := Vector3(26.0, 0, 0)
var _obelisco := Vector3(22.0, 0, -9.0)
var _campeon_elegido := false
var _tiempo_entrada := 0.0


func _ready() -> void:
	get_tree().paused = false
	_crear_entorno()
	_crear_suelo()
	_crear_muros()
	_crear_decoracion()
	_crear_zona_segura()
	_crear_puerta()
	_crear_bandera()
	_crear_jugador()
	_crear_camara()
	_crear_armeria()
	_crear_tienda()
	_crear_oleadas()
	_crear_publico()
	_crear_hud()
	_conectar()

	var args := OS.get_cmdline_user_args()
	if "--captura" in args or "--captura-combate" in args or "--captura-cerca" in args or "--captura-talentos" in args or "--captura-habilidad" in args or "--captura-jefe" in args or "--captura-tienda" in args:
		_capturar()


func _process(delta: float) -> void:
	_actualizar_pista()
	_curar_en_zona_segura(delta)
	_tiempo_entrada = maxf(0.0, _tiempo_entrada - delta)


func _en_base() -> bool:
	return _jugador != null and _jugador.global_position.x > BORDE_ARENA + 1.0


func _curar_en_zona_segura(delta: float) -> void:
	if _jugador == null or terminado or _en_combate:
		return
	if not _en_base():
		return
	if _jugador.global_position.distance_to(_fuente) > 5.5:
		return
	_jugador.curar(_jugador.estadisticas.salud_maxima * 0.035 * delta)
	_jugador.restaurar_mana(_jugador.estadisticas.mana_maximo * 0.05 * delta)


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
			_interactuar_cercano()
		KEY_T:
			_hud.alternar_talentos()
		KEY_K:
			_ciclar_skin()
		KEY_G:
			_alternar_bandera()
		KEY_ESCAPE:
			_hud.cerrar_talentos()
			_hud.cerrar_tienda()
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
	anillo.position = CENTRO_ARENA + Vector3(0, 0.02, 0)
	anillo.material_override = _material(Color(0.45, 0.32, 0.20))
	add_child(anillo)

	# Losa de la zona segura: más clara para separar base y arena.
	var base := MeshInstance3D.new()
	var plano_base := PlaneMesh.new()
	plano_base.size = Vector2(20.0, LARGO)
	base.mesh = plano_base
	base.position = Vector3(20.0, 0.015, 0)
	base.material_override = _material(Color(0.43, 0.35, 0.27))
	add_child(base)

	# Gradas de la arena: tres graderíos, la base queda abierta al este.
	_crear_prop(Vector3(0, 1.5, -LARGO * 0.5 - 4.0), Vector3(ANCHO, 3.0, 6.0), Color(0.16, 0.14, 0.18))
	_crear_prop(Vector3(0, 1.5, LARGO * 0.5 + 4.0), Vector3(ANCHO, 3.0, 6.0), Color(0.16, 0.14, 0.18))
	_crear_prop(Vector3(-ANCHO * 0.5 - 4.0, 1.5, 0), Vector3(6.0, 3.0, LARGO), Color(0.13, 0.12, 0.16))

	_puntos_spawn = [
		Vector3(-ANCHO * 0.5 + 4.0, 0, -LARGO * 0.5 + 3.0),
		Vector3(-ANCHO * 0.5 + 4.0, 0, LARGO * 0.5 - 3.0),
		Vector3(-10.0, 0, -LARGO * 0.5 + 3.0),
		Vector3(-10.0, 0, LARGO * 0.5 - 3.0),
	]


func _crear_muros() -> void:
	var piedra := Color(0.24, 0.22, 0.21)
	_crear_caja_estatica(Vector3(0, ALTO_MURO * 0.5, -LARGO * 0.5), Vector3(ANCHO, ALTO_MURO, 1.0), piedra)
	_crear_caja_estatica(Vector3(0, ALTO_MURO * 0.5, LARGO * 0.5), Vector3(ANCHO, ALTO_MURO, 1.0), piedra)
	_crear_caja_estatica(Vector3(-ANCHO * 0.5, ALTO_MURO * 0.5, 0), Vector3(1.0, ALTO_MURO, LARGO), piedra)
	_crear_caja_estatica(Vector3(ANCHO * 0.5, ALTO_MURO * 0.5, 0), Vector3(1.0, ALTO_MURO, LARGO), piedra)
	# Muro divisorio entre arena y base, con un portón central de 10 m.
	_crear_caja_estatica(Vector3(BORDE_ARENA, 1.8, -12.5), Vector3(1.0, 3.6, 15.0), piedra)
	_crear_caja_estatica(Vector3(BORDE_ARENA, 1.8, 12.5), Vector3(1.0, 3.6, 15.0), piedra)


## Props modulares de KayKit: columnas, antorchas, estandartes y cobertura.
func _crear_decoracion() -> void:
	var columna := load("res://assets/kaykit/dungeon/column.gltf.glb") as PackedScene
	var antorcha := load("res://assets/kaykit/dungeon/torch_lit.gltf.glb") as PackedScene
	var banderin := load("res://assets/kaykit/dungeon/banner_red.gltf.glb") as PackedScene
	var muro_roto := load("res://assets/kaykit/dungeon/wall_broken.gltf.glb") as PackedScene
	var escombro := load("res://assets/kaykit/dungeon/rubble_large.gltf.glb") as PackedScene

	# Cuatro columnas en las esquinas de la arena, con antorchas cálidas.
	var esquinas := [
		Vector3(-ANCHO * 0.5 + 3.0, 0, -LARGO * 0.5 + 3.0),
		Vector3(-ANCHO * 0.5 + 3.0, 0, LARGO * 0.5 - 3.0),
		Vector3(BORDE_ARENA - 3.0, 0, -LARGO * 0.5 + 3.0),
		Vector3(BORDE_ARENA - 3.0, 0, LARGO * 0.5 - 3.0),
	]
	for punto in esquinas:
		_instanciar_prop(columna, punto, 1.7)
		_instanciar_prop(antorcha, punto + Vector3(0, 2.8, 0), 1.4)
		var luz := OmniLight3D.new()
		luz.position = punto + Vector3(0, 3.1, 0)
		luz.omni_range = 10.0
		luz.light_energy = 1.25
		luz.light_color = Color(1.0, 0.58, 0.26)
		add_child(luz)

	# Ritmo visual en los muros norte y sur de la arena.
	for x in [-22.0, -8.0, 4.0]:
		_instanciar_prop(columna, Vector3(x, 0, -LARGO * 0.5 + 1.6), 1.5)
		_instanciar_prop(columna, Vector3(x, 0, LARGO * 0.5 - 1.6), 1.5)

	for x in [-18.0, 0.0]:
		_instanciar_prop(banderin, Vector3(x, 2.2, -LARGO * 0.5 + 1.1), 1.35)

	# Cobertura: muros derruidos y escombros, siempre fuera del carril central.
	_instanciar_prop(muro_roto, Vector3(-19.0, 0, -6.0), 1.2)
	_instanciar_prop(muro_roto, Vector3(-19.0, 0, 6.0), 1.2)
	_instanciar_prop(escombro, Vector3(-13.0, 0, 10.0), 1.0)
	_instanciar_prop(escombro, Vector3(-4.0, 0, -10.0), 0.9)
	_instanciar_prop(escombro, Vector3(-25.0, 0, 0.0), 1.1)
	_crear_caja_estatica(Vector3(-19.0, 1.0, -6.0), Vector3(2.6, 2.0, 2.0), Color(0.28, 0.25, 0.22))
	_crear_caja_estatica(Vector3(-19.0, 1.0, 6.0), Vector3(2.6, 2.0, 2.0), Color(0.28, 0.25, 0.22))


func _instanciar_prop(escena: PackedScene, pos: Vector3, escala: float) -> void:
	if escena == null:
		return
	var nodo := escena.instantiate() as Node3D
	if nodo == null:
		return
	nodo.position = pos
	nodo.scale = Vector3.ONE * escala
	add_child(nodo)


func _crear_zona_segura() -> void:
	# Fuente: cura durante preparación y descanso.
	var base := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 3.2
	cilindro.bottom_radius = 3.4
	cilindro.height = 0.5
	base.mesh = cilindro
	base.position = _fuente + Vector3(0, 0.25, 0)
	base.material_override = _material(Color(0.34, 0.29, 0.23))
	add_child(base)

	var agua := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 2.7
	disco.bottom_radius = 2.7
	disco.height = 0.08
	agua.mesh = disco
	agua.position = _fuente + Vector3(0, 0.53, 0)
	var material_agua := _material(Color(0.18, 0.62, 0.68))
	material_agua.emission_enabled = true
	material_agua.emission = Color(0.15, 0.75, 0.80)
	material_agua.emission_energy_multiplier = 0.8
	agua.material_override = material_agua
	add_child(agua)

	var pilar := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.5, 2.2, 0.5)
	pilar.mesh = caja
	pilar.position = _fuente + Vector3(0, 1.4, 0)
	pilar.material_override = _material(Color(0.45, 0.38, 0.28))
	add_child(pilar)
	_etiqueta_mundo("FUENTE", _fuente + Vector3(0, 2.9, 0), Color(0.55, 0.95, 0.95))
	var luz_agua := OmniLight3D.new()
	luz_agua.position = _fuente + Vector3(0, 2.0, 0)
	luz_agua.omni_range = 7.0
	luz_agua.light_energy = 0.8
	luz_agua.light_color = Color(0.35, 0.85, 0.95)
	add_child(luz_agua)

	# Obelisco de talentos.
	var obelisco := MeshInstance3D.new()
	var prisma := PrismMesh.new()
	prisma.size = Vector3(1.1, 3.2, 1.1)
	obelisco.mesh = prisma
	obelisco.position = _obelisco + Vector3(0, 1.6, 0)
	var material_obelisco := _material(Color(0.38, 0.22, 0.55))
	material_obelisco.emission_enabled = true
	material_obelisco.emission = Color(0.65, 0.30, 0.95)
	material_obelisco.emission_energy_multiplier = 1.2
	obelisco.material_override = material_obelisco
	add_child(obelisco)
	_etiqueta_mundo("TALENTOS", _obelisco + Vector3(0, 3.7, 0), Color(0.82, 0.62, 1.0))
	var luz_obelisco := OmniLight3D.new()
	luz_obelisco.position = _obelisco + Vector3(0, 2.0, 0)
	luz_obelisco.omni_range = 7.0
	luz_obelisco.light_energy = 0.9
	luz_obelisco.light_color = Color(0.65, 0.36, 1.0)
	add_child(luz_obelisco)

	# Círculo de campeones.
	var circulo := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 5.7
	toro.outer_radius = 6.0
	circulo.mesh = toro
	circulo.position = Vector3(18.0, 0.04, 0)
	circulo.material_override = _material(Color(0.64, 0.48, 0.22))
	add_child(circulo)
	_etiqueta_mundo("CAMPEONES", Vector3(18.0, 2.6, 0), Color(1.0, 0.84, 0.45))


func _etiqueta_mundo(texto: String, pos: Vector3, color: Color) -> void:
	var etiqueta := Label3D.new()
	etiqueta.text = texto
	etiqueta.font_size = 56
	etiqueta.pixel_size = 0.006
	etiqueta.outline_size = 10
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.modulate = color
	etiqueta.position = pos
	add_child(etiqueta)


func _crear_puerta() -> void:
	_puerta = PuertaArena.new()
	add_child(_puerta)
	_puerta.global_position = Vector3(BORDE_ARENA, 0, 0)
	_puerta.abrir()


func _crear_bandera() -> void:
	_bandera = RebellionBanner.crear()
	add_child(_bandera)
	_bandera.global_position = CENTRO_ARENA


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
	_jugador.global_position = Vector3(24.0, 0, 0)

	var inventario := InventoryComponent.new()
	inventario.name = "Inventario"
	_jugador.add_child(inventario)
	_jugador.inventario = inventario
	inventario.configurar(_jugador)
	inventario.agregar(ItemCatalog.obtener(&"pocion_vida"))


func _crear_tienda() -> void:
	_tienda = ShopPedestal.new()
	add_child(_tienda)
	_tienda.global_position = Vector3(27.0, 0, 8.0)


func _crear_camara() -> void:
	_camara = ArenaCamera.new()
	add_child(_camara)
	_camara.objetivo = _jugador
	_camara.limites = Vector2(ANCHO * 0.5 - 9.0, LARGO * 0.5 - 7.0)
	_camara.size = 26.0
	_camara.global_position = _jugador.global_position + _camara.desplazamiento
	_camara.current = true


func _crear_armeria() -> void:
	var armas := WeaponItem.crear_catalogo_base()
	var posiciones := [Vector3(18.0, 0, 7.0), Vector3(18.0, 0, 0.0), Vector3(18.0, 0, -7.0)]
	for i in armas.size():
		var pedestal := ArmoryPedestal.new()
		add_child(pedestal)
		pedestal.global_position = posiciones[i]
		pedestal.configurar(armas[i])
		pedestal.es_campeon = true
		_pedestales.append(pedestal)


func _crear_oleadas() -> void:
	_oleadas = WaveManager.new()
	add_child(_oleadas)
	_oleadas.iniciar(_jugador, _bandera, _puntos_spawn, self)


func _crear_publico() -> void:
	_publico = AudienceFury.new()
	add_child(_publico)
	_publico.iniciar(_jugador, CENTRO_ARENA, RADIO_PUBLICO)


func _crear_hud() -> void:
	_hud = ArenaHUD.new()
	add_child(_hud)
	_hud.configurar(_jugador, _oleadas, _bandera, self)


func _conectar() -> void:
	_oleadas.entrada_iniciada.connect(_al_entrada_iniciada)
	_oleadas.oleada_iniciada.connect(_al_iniciar_oleada)
	_oleadas.oleada_terminada.connect(_al_terminar_oleada)
	_oleadas.oro_ganado.connect(_al_ganar_oro)
	_oleadas.victoria.connect(_al_victoria)
	_bandera.destruida.connect(_al_destruir_bandera)
	_jugador.murio.connect(_al_morir_jugador)
	_jugador.arma_cambiada.connect(_al_cambiar_arma)
	_publico.furia_iniciada.connect(_al_furia_iniciada)


# --- Economía y armería ---------------------------------------------------

func _al_entrada_iniciada(duracion: float) -> void:
	_en_combate = false
	_tiempo_entrada = duracion
	if _puerta != null:
		_puerta.abrir()
	if _jugador != null:
		_jugador.aplicar_impulso_velocidad(1.35, duracion)
	if _hud != null:
		_hud.mostrar_mensaje("¡Corre a la arena! +35 % velocidad", 2.6)


func _al_iniciar_oleada(_numero: int, _total: int) -> void:
	_en_combate = true
	if _puerta != null:
		_puerta.cerrar()
	if _jugador != null and _jugador.global_position.x > BORDE_ARENA:
		_jugador.global_position = Vector3(BORDE_ARENA - 4.0, 0, 0)
		if _hud != null:
			_hud.mostrar_mensaje("El portón se cerró: dentro de la arena", 2.2)
	if _bandera != null:
		_bandera.configurar_inmune(5.0)
	Sfx.reproducir("oleada", -5.0)
	if _publico != null:
		_publico.establecer_combate(true)


func _al_terminar_oleada(numero: int) -> void:
	_en_combate = false
	if _puerta != null:
		_puerta.abrir()
	if _publico != null:
		_publico.establecer_combate(false)
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


func _alternar_bandera() -> void:
	if terminado or _bandera == null or _jugador == null:
		return
	if _bandera.esta_cargada():
		if _jugador.global_position.x > BORDE_ARENA - 1.0:
			_hud.mostrar_mensaje("El estandarte solo se coloca dentro de la arena.", 2.4)
			return
		_bandera.colocar(_jugador.global_position)
		_hud.mostrar_mensaje("Estandarte colocado. Defiéndelo.", 2.4)
		Sfx.reproducir("compra", -5.0)
		return
	if _jugador.global_position.distance_to(_bandera.global_position) > 4.0:
		_hud.mostrar_mensaje("Acércate al estandarte para cargarlo (G).", 2.0)
		return
	if _bandera.recoger(_jugador):
		_hud.mostrar_mensaje("Estandarte en mano: G para colocarlo.", 2.5)
		Sfx.reproducir("click", -8.0)


func _interactuar_cercano() -> void:
	if terminado:
		return
	var pedestal := _pedestal_cercano()
	if pedestal != null:
		if _campeon_elegido:
			_hud.mostrar_mensaje("Tu campeón ya está elegido. La clase es permanente.", 2.5)
			return
		if pedestal.comprar(_jugador):
			_campeon_elegido = true
			_hud.mostrar_mensaje("Campeón: %s" % pedestal.arma.nombre, 2.8)
			Sfx.reproducir("compra", -3.0)
		return
	if _tienda_cercana():
		_hud.alternar_tienda()
		return
	if _jugador.global_position.distance_to(_obelisco) <= 4.5:
		_hud.alternar_talentos()
		return
	if _jugador.global_position.distance_to(_fuente) <= 5.5:
		_hud.mostrar_mensaje("La fuente restaura vida y maná fuera de combate.", 2.5)


func _tienda_cercana() -> bool:
	if _tienda == null or _jugador == null:
		return false
	return _jugador.global_position.distance_to(_tienda.global_position) <= RADIO_INTERACCION


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


func puede_comprar_objeto(item: ItemData) -> bool:
	if item == null or terminado or _jugador == null or _jugador.inventario == null:
		return false
	if not _en_base():
		return false
	var inventario := _jugador.inventario
	var receta := inventario.receta_completada_por(item)
	var coste := item.precio + (receta.precio_forja if receta != null else 0)
	if oro < coste:
		return false
	if receta != null:
		return true
	return inventario.espacio_para(item)


## Compra un objeto y ejecuta la forja automática en cadena.
func comprar_objeto(item: ItemData) -> bool:
	if not puede_comprar_objeto(item):
		if oro < item.precio:
			_hud.mostrar_mensaje("Necesitas %d de oro" % item.precio, 2.0)
		else:
			_hud.mostrar_mensaje("La mochila está llena y no completa ninguna receta", 2.5)
		return false
	var inventario := _jugador.inventario
	var receta := inventario.receta_completada_por(item)
	var forjados: PackedStringArray = []

	if receta != null:
		oro -= item.precio + receta.precio_forja
		var creado := inventario.forjar_con(item, receta)
		if creado == null:
			oro += item.precio + receta.precio_forja
			_hud.mostrar_mensaje("No se pudo completar la forja", 2.0)
			return false
		forjados.append(creado.nombre)
		var actual := creado
		for i in 4:
			var siguiente := inventario.receta_completada_por(actual)
			if siguiente == null or oro < siguiente.precio_forja:
				break
			oro -= siguiente.precio_forja
			var encadenado := inventario.forjar_con(actual, siguiente)
			if encadenado == null:
				oro += siguiente.precio_forja
				break
			forjados.append(encadenado.nombre)
			actual = encadenado
		_hud.mostrar_mensaje("Forjado: %s" % " > ".join(forjados), 3.0)
	else:
		if not inventario.agregar(item):
			_hud.mostrar_mensaje("La mochila está llena", 2.0)
			return false
		oro -= item.precio
		_hud.mostrar_mensaje("Comprado: %s" % item.nombre, 2.0)

	Sfx.reproducir("compra", -3.0)
	return true


func _actualizar_pista() -> void:
	if _hud == null or _jugador == null or terminado:
		return
	var pedestal := _pedestal_cercano()
	if pedestal != null:
		if _campeon_elegido:
			_texto_pista = "Campeón elegido  ·  la clase es permanente"
		else:
			_texto_pista = "F — Elegir campeón: %s (gratis)" % pedestal.arma.nombre
		_hud.establecer_pista(_texto_pista)
		return
	if _tienda_cercana():
		_texto_pista = "F — Mercader de la Rebelión: objetos y forja"
	elif _jugador.global_position.distance_to(_obelisco) <= 4.5:
		_texto_pista = "F — Obelisco de talentos (T)"
	elif _jugador.global_position.distance_to(_fuente) <= 5.5:
		_texto_pista = "Fuente: restaura vida y maná fuera de combate"
	else:
		_texto_pista = ""
	_hud.establecer_pista(_texto_pista)


func pista_actual() -> String:
	return _texto_pista


func nombre_skin() -> String:
	if _skin_actual >= 0 and _skin_actual < SKINS.size():
		return str(SKINS[_skin_actual]["nombre"])
	return "Tierra Baldía"


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
	_hud.cerrar_tienda()
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
	var tienda := "--captura-tienda" in args
	var combate := "--captura-combate" in args or cerca or talentos or habilidad or capturar_jefe or tienda
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
		elif tienda:
			oro = 1600
			_jugador.inventario.agregar(ItemCatalog.obtener(&"brasa_forja"))
			_hud.alternar_tienda()
		elif cerca and _camara != null:
			_camara.size = 7.0
		await get_tree().create_timer(3.0 if (cerca or talentos or habilidad or capturar_jefe or tienda) else 8.5).timeout
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
	elif tienda:
		ruta = "res://captura_tienda.png"
	elif combate:
		ruta = "res://captura_combate.png"
	var error := imagen.save_png(ProjectSettings.globalize_path(ruta))
	print("CAPTURA: guardada en ", ruta, " error=", error, " tamaño=", imagen.get_size())
	get_tree().quit()
