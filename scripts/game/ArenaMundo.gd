class_name ArenaMundo
extends Node3D
## Construcción del mundo estático de la arena: entorno, suelo, muros,
## decoración y zona segura. Extraído de Arena.gd (god object, AGENTS.md:139).
## Cero señales, cero dependencias de sistemas vivos; sólo geometría y luces.
##
## Datos que Arena necesita de vuelta:
##  - `puntos_spawn`: posiciones de aparición de enemigos.
## Las posiciones de fuente/obelisco se pasan al construir (Arena las usa
## también para interacción, curación y pistas), así que no se duplican aquí.

const ANCHO := 60.0
const LARGO := 40.0
const ALTO_MURO := 1.4
const BORDE_ARENA := 10.0
const CENTRO_ARENA := Vector3(-8.0, 0, 0)

var puntos_spawn: Array[Vector3] = []

var _fuente := Vector3(26.0, 0, 0)
var _obelisco := Vector3(22.0, 0, -9.0)


## Construye el mundo bajo `padre` y devuelve el nodo. Llamar una vez en _ready.
static func construir(padre: Node, fuente: Vector3, obelisco: Vector3) -> ArenaMundo:
	var mundo := ArenaMundo.new()
	mundo.name = "Mundo"
	padre.add_child(mundo)
	mundo._fuente = fuente
	mundo._obelisco = obelisco
	mundo._crear_entorno()
	mundo._crear_suelo()
	mundo._crear_muros()
	mundo._crear_decoracion()
	mundo._crear_zona_segura()
	return mundo


# --- Entorno ---------------------------------------------------------------

func _crear_entorno() -> void:
	# Atmósfera de arena de brasas: fondo carbón y luz ambiental cálida, en la
	# misma familia que ForjaTema (FONDO/PANEL/ASCUA), sin arte de terceros.
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color(0.055, 0.042, 0.038)
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(0.82, 0.66, 0.52)
	entorno.ambient_light_energy = 0.62
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var mundo := WorldEnvironment.new()
	mundo.environment = entorno
	add_child(mundo)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sol.light_energy = 1.08
	sol.light_color = Color(1.0, 0.85, 0.70)
	sol.shadow_enabled = false
	add_child(sol)

	var relleno := OmniLight3D.new()
	relleno.position = Vector3(0, 8, 0)
	relleno.omni_range = 40.0
	relleno.light_energy = 0.5
	relleno.light_color = Color(1.0, 0.55, 0.30)
	add_child(relleno)


# --- Suelo -----------------------------------------------------------------

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

	# Suelo de la arena usando meshes de KayKit para que no se vea plano.
	var suelo_tierra := load("res://assets/kaykit/dungeon/floor_dirt_large.gltf.glb") as PackedScene
	var suelo_baldosa := load("res://assets/kaykit/dungeon/floor_tile_large.gltf.glb") as PackedScene

	# Tiles de tierra en el área de combate principal.
	if suelo_tierra != null:
		for x in range(-int(ANCHO * 0.5), int(ANCHO * 0.5), 6):
			for z in range(-int(LARGO * 0.5), int(LARGO * 0.5), 6):
				var tile := suelo_tierra.instantiate() as Node3D
				if tile != null:
					tile.position = Vector3(float(x) + 3.0, 0.0, float(z) + 3.0)
					tile.scale = Vector3.ONE * 1.05
					# Integramos el GLB en la paleta carbón/ascua sin tocar su textura.
					MaterialTinte.aplicar(tile, "floor_dirt", Color(0.42, 0.33, 0.28))
					# Va dentro del StaticBody del suelo: hereda su colisión.
					suelo.add_child(tile)

	# Baldosas en la zona segura (base).
	if suelo_baldosa != null:
		for x in range(int(BORDE_ARENA + 2), int(ANCHO * 0.5), 6):
			for z in range(-int(LARGO * 0.5), int(LARGO * 0.5), 6):
				var tile := suelo_baldosa.instantiate() as Node3D
				if tile != null:
					tile.position = Vector3(float(x) + 3.0, 0.015, float(z) + 3.0)
					tile.scale = Vector3.ONE * 1.05
					MaterialTinte.aplicar(tile, "floor_tile", Color(0.50, 0.42, 0.35))
					add_child(tile)

	add_child(suelo)

	# Terreno exterior: evita que la cámara enseñe el vacío en las esquinas.
	var exterior := MeshInstance3D.new()
	var plano_exterior := PlaneMesh.new()
	plano_exterior.size = Vector2(ANCHO * 2.4, LARGO * 2.4)
	exterior.mesh = plano_exterior
	exterior.position.y = -0.05
	exterior.material_override = _material(Color(0.11, 0.085, 0.07))
	add_child(exterior)

	# Anillo central bajo el estandarte: ascua apagada.
	var anillo := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 5.0
	cilindro.bottom_radius = 5.0
	cilindro.height = 0.04
	anillo.mesh = cilindro
	anillo.position = CENTRO_ARENA + Vector3(0, 0.02, 0)
	anillo.material_override = _material(Color(0.32, 0.16, 0.10))
	add_child(anillo)

	# Losa de la zona segura: carbón calcáreo, separada de la arena por tono.
	var base := MeshInstance3D.new()
	var plano_base := PlaneMesh.new()
	plano_base.size = Vector2(20.0, LARGO)
	base.mesh = plano_base
	base.position = Vector3(20.0, 0.015, 0)
	base.material_override = _material(Color(0.20, 0.165, 0.13))
	add_child(base)

	# Gradas de la arena: tres graderíos, la base queda abierta al este.
	_crear_prop(Vector3(0, 1.5, -LARGO * 0.5 - 4.0), Vector3(ANCHO, 3.0, 6.0), Color(0.085, 0.07, 0.09))
	_crear_prop(Vector3(0, 1.5, LARGO * 0.5 + 4.0), Vector3(ANCHO, 3.0, 6.0), Color(0.085, 0.07, 0.09))
	_crear_prop(Vector3(-ANCHO * 0.5 - 4.0, 1.5, 0), Vector3(6.0, 3.0, LARGO), Color(0.07, 0.06, 0.075))

	puntos_spawn = [
		Vector3(-ANCHO * 0.5 + 4.0, 0, -LARGO * 0.5 + 3.0),
		Vector3(-ANCHO * 0.5 + 4.0, 0, LARGO * 0.5 - 3.0),
		Vector3(-10.0, 0, -LARGO * 0.5 + 3.0),
		Vector3(-10.0, 0, -LARGO * 0.5 + 3.0),
	]


func _crear_muros() -> void:
	var piedra := Color(0.13, 0.115, 0.105)
	_crear_caja_estatica(Vector3(0, ALTO_MURO * 0.5, -LARGO * 0.5), Vector3(ANCHO, ALTO_MURO, 1.0), piedra)
	_crear_caja_estatica(Vector3(0, ALTO_MURO * 0.5, LARGO * 0.5), Vector3(ANCHO, ALTO_MURO, 1.0), piedra)
	_crear_caja_estatica(Vector3(-ANCHO * 0.5, ALTO_MURO * 0.5, 0), Vector3(1.0, ALTO_MURO, LARGO), piedra)
	_crear_caja_estatica(Vector3(ANCHO * 0.5, ALTO_MURO * 0.5, 0), Vector3(1.0, ALTO_MURO, LARGO), piedra)
	# Muro divisorio entre arena y base, con un portón central de 10 m.
	_crear_caja_estatica(Vector3(BORDE_ARENA, 1.8, -12.5), Vector3(1.0, 3.6, 15.0), piedra)
	_crear_caja_estatica(Vector3(BORDE_ARENA, 1.8, 12.5), Vector3(1.0, 3.6, 15.0), piedra)


# --- Decoración ------------------------------------------------------------

## Props modulares de KayKit: columnas, antorchas, estandartes y cobertura.
## La arena se llena con elementos visuales para que no se vea vacía.
func _crear_decoracion() -> void:
	var columna := load("res://assets/kaykit/dungeon/column.gltf.glb") as PackedScene
	var antorcha := load("res://assets/kaykit/dungeon/torch_lit.gltf.glb") as PackedScene
	var banderin := load("res://assets/kaykit/dungeon/banner_red.gltf.glb") as PackedScene
	var banderin_patron := load("res://assets/kaykit/dungeon/banner_patternA_red.gltf.glb") as PackedScene
	var muro_roto := load("res://assets/kaykit/dungeon/wall_broken.gltf.glb") as PackedScene
	var escombro := load("res://assets/kaykit/dungeon/rubble_large.gltf.glb") as PackedScene
	var barrera := load("res://assets/kaykit/dungeon/barrier.gltf.glb") as PackedScene

	# Columnas y antorchas en las cuatro esquinas de la arena.
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

	# Columnas adicionales a lo largo de los muros norte y sur.
	for x in [-26.0, -16.0, -6.0, 4.0, 14.0]:
		_instanciar_prop(columna, Vector3(x, 0, -LARGO * 0.5 + 1.6), 1.5)
		_instanciar_prop(columna, Vector3(x, 0, LARGO * 0.5 - 1.6), 1.5)
		_instanciar_prop(antorcha, Vector3(x, 2.8, -LARGO * 0.5 + 1.6), 1.2)
		_instanciar_prop(antorcha, Vector3(x, 2.8, LARGO * 0.5 - 1.6), 1.2)
		var luz_n := OmniLight3D.new()
		luz_n.position = Vector3(x, 3.1, -LARGO * 0.5 + 1.6)
		luz_n.omni_range = 8.0
		luz_n.light_energy = 1.0
		luz_n.light_color = Color(1.0, 0.55, 0.25)
		add_child(luz_n)
		var luz_s := OmniLight3D.new()
		luz_s.position = Vector3(x, 3.1, LARGO * 0.5 - 1.6)
		luz_s.omni_range = 8.0
		luz_s.light_energy = 1.0
		luz_s.light_color = Color(1.0, 0.55, 0.25)
		add_child(luz_s)

	# Banderas y estandartes en los muros.
	for x in [-22.0, -8.0, 6.0, 20.0]:
		_instanciar_prop(banderin, Vector3(x, 2.2, -LARGO * 0.5 + 1.1), 1.35)
		_instanciar_prop(banderin_patron, Vector3(x, 2.2, LARGO * 0.5 - 1.1), 1.35)

	# Cobertura: muros derruidos y escombros distribuidos por la arena.
	_instanciar_prop(muro_roto, Vector3(-24.0, 0, -10.0), 1.3)
	_instanciar_prop(muro_roto, Vector3(-24.0, 0, 10.0), 1.3)
	_instanciar_prop(muro_roto, Vector3(-19.0, 0, -6.0), 1.2)
	_instanciar_prop(muro_roto, Vector3(-19.0, 0, 6.0), 1.2)
	_instanciar_prop(muro_roto, Vector3(BORDE_ARENA - 2.0, 0, -14.0), 1.1)
	_instanciar_prop(muro_roto, Vector3(BORDE_ARENA - 2.0, 0, 14.0), 1.1)

	_instanciar_prop(escombro, Vector3(-17.0, 0, -14.0), 1.1)
	_instanciar_prop(escombro, Vector3(-13.0, 0, 10.0), 1.0)
	_instanciar_prop(escombro, Vector3(-4.0, 0, -10.0), 0.9)
	_instanciar_prop(escombro, Vector3(4.0, 0, 14.0), 1.0)
	_instanciar_prop(escombro, Vector3(14.0, 0, -14.0), 1.1)
	_instanciar_prop(escombro, Vector3(-25.0, 0, 0.0), 1.1)
	# Barreras bajas en los bordes laterales de la arena.
	_instanciar_prop(barrera, Vector3(-29.0, 0, -8.0), 1.0)
	_instanciar_prop(barrera, Vector3(-29.0, 0, 8.0), 1.0)
	_instanciar_prop(barrera, Vector3(BORDE_ARENA + 2.0, 0, -8.0), 1.0)
	_instanciar_prop(barrera, Vector3(BORDE_ARENA + 2.0, 0, 8.0), 1.0)

	_crear_caja_estatica(Vector3(-19.0, 1.0, -6.0), Vector3(2.6, 2.0, 2.0), Color(0.28, 0.25, 0.22))
	_crear_caja_estatica(Vector3(-19.0, 1.0, 6.0), Vector3(2.6, 2.0, 2.0), Color(0.28, 0.25, 0.22))
	_crear_caja_estatica(Vector3(20.0, 1.0, -12.0), Vector3(2.6, 2.0, 2.0), Color(0.28, 0.25, 0.22))
	_crear_caja_estatica(Vector3(20.0, 1.0, 12.0), Vector3(2.6, 2.0, 2.0), Color(0.28, 0.25, 0.22))


func _instanciar_prop(escena: PackedScene, pos: Vector3, escala: float) -> void:
	if escena == null:
		return
	var nodo := escena.instantiate() as Node3D
	if nodo == null:
		return
	nodo.position = pos
	nodo.scale = Vector3.ONE * escala
	add_child(nodo)


# --- Zona segura -----------------------------------------------------------

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
	var material_agua := _material(Color(0.55, 0.22, 0.10))
	material_agua.emission_enabled = true
	material_agua.emission = Color(0.90, 0.30, 0.10)
	material_agua.emission_energy_multiplier = 0.7
	agua.material_override = material_agua
	add_child(agua)

	var pilar := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.5, 2.2, 0.5)
	pilar.mesh = caja
	pilar.position = _fuente + Vector3(0, 1.4, 0)
	pilar.material_override = _material(Color(0.45, 0.38, 0.28))
	add_child(pilar)
	_etiqueta_mundo("FUENTE", _fuente + Vector3(0, 2.9, 0), Color(1.0, 0.72, 0.40))
	var luz_agua := OmniLight3D.new()
	luz_agua.position = _fuente + Vector3(0, 2.0, 0)
	luz_agua.omni_range = 7.0
	luz_agua.light_energy = 0.9
	luz_agua.light_color = Color(1.0, 0.52, 0.22)
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


# --- Utilitarios -----------------------------------------------------------

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


func _crear_prop(pos: Vector3, tam: Vector3, color: Color) -> void:
	var nodo := MeshInstance3D.new()
	var malla := BoxMesh.new()
	malla.size = tam
	nodo.mesh = malla
	nodo.position = pos
	nodo.material_override = _material(color)
	add_child(nodo)


func _crear_caja_estatica(pos: Vector3, tam: Vector3, color: Color) -> void:
	var cuerpo := StaticBody3D.new()
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
	cuerpo.position = pos
	add_child(cuerpo)
