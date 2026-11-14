class_name WeaponItem
extends Resource
## Arma como clase de combate: define el rol, los bonos de atributo y el kit de
## 4 habilidades que reemplaza al del jugador al equiparse.
##
## Regla de diseño: un arma solo es válida si trae exactamente 4 habilidades
## (Q, W, E, R). El catálogo base vive en `crear_catalogo_base()` para que el
## prototipo sea jugable sin crear recursos .tres a mano.

enum Clase {
	PRISIONERO,
	BASTION,    ## Gran Alabarda: tanque / iniciador.
	FILO,       ## Guadaña gemela / katana: verdugo / DPS.
	CETRO,      ## Bastón rúnico: convocador / soporte.
	LANZA,      ## Pica de hoplita: tanque de zona / control.
	SAETA,      ## Arco corto: tiradora a distancia.
}

enum Rol {
	NINGUNO,
	TANQUE,
	VERDUGO,
	CONVOCADOR,
	TIRADOR,
}

const MAX_HABILIDADES := 4

@export_group("Identidad")
@export var id: StringName = &""
@export var nombre: String = ""
@export_multiline var descripcion: String = ""
@export var icono: Texture2D
@export var escena_visual: PackedScene
## Ajuste fino del arma al hueso de la mano (grados y escala).
@export var rotacion_visual: Vector3 = Vector3.ZERO
@export var escala_visual: float = 1.0

@export_group("Clase y rol")
@export var clase: Clase = Clase.PRISIONERO
@export var rol: Rol = Rol.NINGUNO

@export_group("Economía")
@export_range(0, 100000, 1) var precio_oro: int = 0
@export var disponible_en_armeria: bool = true

@export_group("Combate básico")
## Daño del ataque automático (sin contar el bono del atributo).
@export var dano_ataque_base: float = 10.0
## Alcance del ataque automático en metros.
@export var alcance_ataque: float = 2.8

@export_group("Escalado")
## Atributo que potencia el ataque básico (1 punto de daño por punto).
@export var atributo_principal: StringName = &"fuerza"
## Bonos planos por atributo: {"fuerza": 8, "agilidad": 0, "inteligencia": 0}.
@export var bonificaciones_atributos: Dictionary = {
	"fuerza": 0,
	"agilidad": 0,
	"inteligencia": 0,
}

@export_group("Kit de habilidades (Q, W, E, R)")
@export var habilidades: Array[AbilityData] = []


## Devuelve la habilidad del slot o null si el slot no existe.
func obtener_habilidad(slot: int) -> AbilityData:
	if slot < 0 or slot >= habilidades.size():
		return null
	return habilidades[slot]


## Identificador canónico de la clase para la curva de crecimiento de GladiatorStats.
func id_clase() -> StringName:
	match clase:
		Clase.BASTION:
			return &"bastion"
		Clase.FILO:
			return &"filo"
		Clase.CETRO:
			return &"cetro"
		Clase.LANZA:
			return &"lanza"
		Clase.SAETA:
			return &"saeta"
		_:
			return &"prisionero"


func validar() -> PackedStringArray:
	var errores := PackedStringArray()
	if id == &"":
		errores.append("El arma no tiene id.")
	if nombre.is_empty():
		errores.append("El arma no tiene nombre.")
	if habilidades.size() != MAX_HABILIDADES:
		errores.append(
			"El arma '%s' tiene %d habilidades; se esperaban %d."
			% [nombre, habilidades.size(), MAX_HABILIDADES]
		)
	for i in habilidades.size():
		var habilidad := habilidades[i]
		if habilidad == null:
			errores.append("El slot %d del arma '%s' está vacío." % [i, nombre])
		elif habilidad.id == &"":
			errores.append("El slot %d del arma '%s' no tiene id de habilidad." % [i, nombre])
	return errores


func es_valida() -> bool:
	return validar().is_empty()


## Punto de entrada para la armería. No referencia GladiatorController
## directamente para evitar una dependencia circular entre clases.
func equipar_en(gladiador: Node) -> bool:
	if gladiador == null or not gladiador.has_method("equipar_arma"):
		return false
	return gladiador.equipar_arma(self)


# --- Catálogo base --------------------------------------------------------

## Kit inicial de la Ronda 0: desarmado, sin rol de combate.
static func crear_prisionero() -> WeaponItem:
	var arma := WeaponItem.new()
	arma.id = &"prisionero_punos"
	arma.nombre = "Puños de Prisionero"
	arma.descripcion = "Sin arma ni rol. Sobrevive hasta la armería."
	arma.clase = Clase.PRISIONERO
	arma.rol = Rol.NINGUNO
	arma.precio_oro = 0
	arma.dano_ataque_base = 6.0
	arma.alcance_ataque = 2.4
	arma.atributo_principal = &"fuerza"
	arma.habilidades = _kit_prisionero()
	_aplicar_iconos(arma)
	_configurar_rangos(arma)
	return arma


## Las cinco clases jugables con las que se compra el rol en la armería.
## El catálogo se construye una vez y se comparte: cada llamada creaba 5 armas,
## 20 habilidades, ~40 talentos y dos escenas procedurales (medido: 15 ms por
## llamada), y se pedía al abrir la forja, al elegir clase y desde los menús.
static var _catalogo_cache: Array[WeaponItem] = []

static func crear_catalogo_base() -> Array[WeaponItem]:
	if not _catalogo_cache.is_empty():
		return _catalogo_cache
	var catalogo: Array[WeaponItem] = []
	catalogo.append(_crear_bastion())
	catalogo.append(_crear_filo())
	catalogo.append(_crear_cetro())
	catalogo.append(_crear_lancero())
	catalogo.append(_crear_saetera())
	for arma in catalogo:
		_aplicar_iconos(arma)
		_configurar_rangos(arma)
	_catalogo_cache = catalogo
	return _catalogo_cache


## Glifos de texto para las ranuras de habilidad; no requieren texturas.
static func _aplicar_iconos(arma: WeaponItem) -> void:
	const ICONOS := {
		&"prisionero_punetazo": "◉",
		&"prisionero_patada": "↯",
		&"prisionero_rodar": "↻",
		&"prisionero_grito": "◈",
		&"bastion_muro_escudos": "◈",
		&"bastion_golpe_sismico": "✹",
		&"bastion_provocacion": "◉",
		&"bastion_inquebrantable": "◆",
		&"filo_tajo_gemelo": "╱",
		&"filo_paso_sombrio": "↯",
		&"filo_marca_verdugo": "☠",
		&"filo_ejecucion": "✖",
		&"cetro_espina_vital": "❖",
		&"cetro_estandarte_rebelion": "⚑",
		&"cetro_lazo_raices": "✸",
		&"cetro_espiritu_ancestral": "✦",
		&"lanza_estocada": "╱",
		&"lanza_muro_picas": "✹",
		&"lanza_embestida": "↯",
		&"lanza_formacion": "❖",
		&"saeta_disparo_doble": "✹",
		&"saeta_lluvia_puas": "✸",
		&"saeta_paso_cazador": "↯",
		&"saeta_ojo_tormenta": "✦",
	}
	for habilidad in arma.habilidades:
		if habilidad != null:
			habilidad.glifo = str(ICONOS.get(habilidad.id, "◆"))


static func _crear_bastion() -> WeaponItem:
	var arma := WeaponItem.new()
	arma.id = &"bastion_alabarda"
	arma.nombre = "Gran Alabarda de Bastión"
	arma.descripcion = "Acero de las minas de Hierro. Controla la arena y absorbe el castigo."
	arma.clase = Clase.BASTION
	arma.rol = Rol.TANQUE
	arma.precio_oro = 200
	arma.dano_ataque_base = 20.0
	arma.alcance_ataque = 3.0
	arma.atributo_principal = &"fuerza"
	arma.bonificaciones_atributos = {"fuerza": 8, "agilidad": 0, "inteligencia": 0}
	arma.escena_visual = load("res://assets/kaykit/weapons/axe_2handed.gltf")
	arma.rotacion_visual = Vector3(90.0, 0.0, 0.0)
	arma.escala_visual = 0.85
	arma.habilidades = _kit_bastion()
	return arma


static func _crear_filo() -> WeaponItem:
	var arma := WeaponItem.new()
	arma.id = &"filo_guadana"
	arma.nombre = "Guadaña Gemela del Verdugo"
	arma.descripcion = "Dos hojas, un solo destino. Castiga la espalda y desaparece."
	arma.clase = Clase.FILO
	arma.rol = Rol.VERDUGO
	arma.precio_oro = 200
	arma.dano_ataque_base = 15.0
	arma.alcance_ataque = 2.8
	arma.atributo_principal = &"agilidad"
	arma.bonificaciones_atributos = {"fuerza": 0, "agilidad": 8, "inteligencia": 0}
	arma.escena_visual = load("res://assets/kaykit/weapons/sword_1handed.gltf")
	arma.rotacion_visual = Vector3(90.0, 0.0, 0.0)
	arma.escala_visual = 0.90
	arma.habilidades = _kit_filo()
	return arma


static func _crear_cetro() -> WeaponItem:
	var arma := WeaponItem.new()
	arma.id = &"cetro_runico"
	arma.nombre = "Cetro Rúnico de las Tierras Baldías"
	arma.descripcion = "Canaliza a los espíritus que aun recuerdan el bosque quemado."
	arma.clase = Clase.CETRO
	arma.rol = Rol.CONVOCADOR
	arma.precio_oro = 200
	arma.dano_ataque_base = 11.0
	arma.alcance_ataque = 7.5
	arma.atributo_principal = &"inteligencia"
	arma.bonificaciones_atributos = {"fuerza": 0, "agilidad": 0, "inteligencia": 8}
	arma.escena_visual = load("res://assets/kaykit/weapons/staff.gltf")
	arma.rotacion_visual = Vector3(90.0, 0.0, 0.0)
	arma.escala_visual = 0.90
	arma.habilidades = _kit_cetro()
	return arma


static func _crear_lancero() -> WeaponItem:
	var arma := WeaponItem.new()
	arma.id = &"lanza_pica"
	arma.nombre = "Pica del Hoplita"
	arma.descripcion = "Fresno y bronce. Sostiene la línea mientras la marea rompe contra el escudo."
	arma.clase = Clase.LANZA
	arma.rol = Rol.TANQUE
	arma.precio_oro = 200
	arma.dano_ataque_base = 18.0
	arma.alcance_ataque = 3.6
	arma.atributo_principal = &"fuerza"
	arma.bonificaciones_atributos = {"fuerza": 7, "agilidad": 3, "inteligencia": 0}
	arma.escena_visual = _escena_pica()
	arma.rotacion_visual = Vector3(-72.0, 0.0, 0.0)
	arma.escala_visual = 0.95
	arma.habilidades = _kit_lancero()
	return arma


static func _crear_saetera() -> WeaponItem:
	var arma := WeaponItem.new()
	arma.id = &"saeta_arco"
	arma.nombre = "Arco Corto de Saeta"
	arma.descripcion = "Cuero, tendón y punta de pedernal. Mata desde donde el enemigo aún no te ve."
	arma.clase = Clase.SAETA
	arma.rol = Rol.TIRADOR
	arma.precio_oro = 200
	arma.dano_ataque_base = 12.0
	arma.alcance_ataque = 7.5
	arma.atributo_principal = &"agilidad"
	arma.bonificaciones_atributos = {"fuerza": 0, "agilidad": 8, "inteligencia": 0}
	arma.escena_visual = _escena_arco()
	# El plano del arco es XY; girarlo 30° en Y lo saca de canto respecto a la
	# cámara isométrica para que la curva se lea en partida.
	arma.rotacion_visual = Vector3(0.0, 30.0, 0.0)
	arma.escala_visual = 1.15
	arma.habilidades = _kit_saetera()
	return arma


# --- Armas procedurales ---------------------------------------------------
# El pack KayKit solo trae hacha, espada y bastón: la pica y el arco se
# construyen con primitivas para que las clases nuevas tengan silueta propia
# sin añadir arte externo (todo CC0/procedural).

static func _material_arma(color: Color, metalico := 0.0, rugosidad := 0.6) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metalico
	material.roughness = rugosidad
	return material


static func _pieza(raiz: Node3D, malla: Mesh, material: StandardMaterial3D, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var pieza := MeshInstance3D.new()
	pieza.mesh = malla
	pieza.material_override = material
	pieza.position = pos
	pieza.rotation_degrees = rot_deg
	raiz.add_child(pieza)
	# `PackedScene.pack()` solo serializa los hijos cuyo `owner` es la raíz: sin
	# esta línea el arma se empaquetaba vacía y el gladiador iba con las manos
	# libres aunque su clase fuese la correcta.
	pieza.owner = raiz


static func _escena_pica() -> PackedScene:
	var raiz := Node3D.new()
	raiz.name = "PicaVisual"
	var madera := _material_arma(Color(0.40, 0.26, 0.15), 0.0, 0.85)
	var bronce := _material_arma(Color(0.80, 0.64, 0.30), 0.75, 0.32)

	var asta := CylinderMesh.new()
	asta.top_radius = 0.026
	asta.bottom_radius = 0.032
	asta.height = 2.30
	asta.radial_segments = 8
	_pieza(raiz, asta, madera, Vector3(0, 0.10, 0))

	var regaton := CylinderMesh.new()
	regaton.top_radius = 0.038
	regaton.bottom_radius = 0.030
	regaton.height = 0.14
	regaton.radial_segments = 8
	_pieza(raiz, regaton, bronce, Vector3(0, -1.02, 0))

	var hoja := CylinderMesh.new()
	hoja.top_radius = 0.0
	hoja.bottom_radius = 0.055
	hoja.height = 0.42
	hoja.radial_segments = 6
	_pieza(raiz, hoja, bronce, Vector3(0, 1.44, 0))

	var collar := CylinderMesh.new()
	collar.top_radius = 0.05
	collar.bottom_radius = 0.05
	collar.height = 0.06
	collar.radial_segments = 8
	_pieza(raiz, collar, bronce, Vector3(0, 1.21, 0))

	return _empaquetar(raiz)


static func _escena_arco() -> PackedScene:
	var raiz := Node3D.new()
	raiz.name = "ArcoVisual"
	var madera := _material_arma(Color(0.34, 0.21, 0.12), 0.0, 0.8)
	var tendón := _material_arma(Color(0.88, 0.84, 0.70), 0.0, 0.9)

	# Arco de verdad: arco de circunferencia con la empuñadura en el origen y las
	# puntas volviendo hacia -X, donde se tensa la cuerda. Con dos palos rectos a
	# tamaño de juego se leía como una vara, no como un arco.
	var radio := 0.90
	var apertura := deg_to_rad(72.0)
	var puntos: Array[Vector3] = []
	for i in 7:
		var angulo := -apertura + (2.0 * apertura) * float(i) / 6.0
		puntos.append(Vector3(radio * cos(angulo) - radio, radio * sin(angulo), 0.0))

	for i in puntos.size() - 1:
		var a := puntos[i]
		var b := puntos[i + 1]
		var medio := (a + b) * 0.5
		var largo := a.distance_to(b)
		var brazo := CylinderMesh.new()
		brazo.top_radius = 0.024
		brazo.bottom_radius = 0.030
		brazo.height = largo * 1.08
		brazo.radial_segments = 6
		var giro := atan2(b.y - a.y, b.x - a.x) - PI * 0.5
		_pieza(raiz, brazo, madera, medio, Vector3(0.0, 0.0, rad_to_deg(giro)))

	var empunadura := BoxMesh.new()
	empunadura.size = Vector3(0.06, 0.26, 0.06)
	_pieza(raiz, empunadura, madera, Vector3.ZERO)

	var punta_a := puntos[0]
	var punta_b := puntos[puntos.size() - 1]
	var cuerda := BoxMesh.new()
	cuerda.size = Vector3(0.010, punta_a.distance_to(punta_b), 0.010)
	_pieza(raiz, cuerda, tendón, (punta_a + punta_b) * 0.5)

	var flecha := CylinderMesh.new()
	flecha.top_radius = 0.0
	flecha.bottom_radius = 0.014
	flecha.height = 0.20
	flecha.radial_segments = 5
	_pieza(raiz, flecha, tendón, Vector3(0.03, 0.0, 0), Vector3(0, 0, -90.0))

	return _empaquetar(raiz)


## `PackedScene.pack()` devuelve un Error, no la escena: empaquetar en dos
## pasos evita el error de tipos al devolver la escena ya cerrada.
static func _empaquetar(raiz: Node3D) -> PackedScene:
	var escena := PackedScene.new()
	var error := escena.pack(raiz)
	if error != OK:
		push_error("WeaponItem: no se pudo empaquetar el arma procedural (error %d)" % error)
	raiz.queue_free()
	return escena


# --- Kits ----------------------------------------------------------------

static func _kit_prisionero() -> Array[AbilityData]:
	var kit: Array[AbilityData] = []

	var punetazo := AbilityData.new()
	punetazo.id = &"prisionero_punetazo"
	punetazo.nombre = "Puñetazo"
	punetazo.descripcion = "Golpe seco con el puño libre."
	punetazo.tipo = AbilityData.Tipo.IMPACTO
	punetazo.objetivo = AbilityData.Objetivo.ENEMIGO
	punetazo.coste_mana = 0.0
	punetazo.cooldown = 1.0
	punetazo.dano_base = 8.0
	punetazo.radio = 2.0
	kit.append(punetazo)

	var patada := AbilityData.new()
	patada.id = &"prisionero_patada"
	patada.nombre = "Patada de Barro"
	patada.descripcion = "Empuja al enemigo para abrir distancia."
	patada.tipo = AbilityData.Tipo.APOYO
	patada.objetivo = AbilityData.Objetivo.ENEMIGO
	patada.coste_mana = 0.0
	patada.cooldown = 8.0
	patada.dano_base = 12.0
	patada.radio = 2.2
	kit.append(patada)

	var rodar := AbilityData.new()
	rodar.id = &"prisionero_rodar"
	rodar.nombre = "Rodar"
	rodar.descripcion = "Esquiva hacia la posición del cursor."
	rodar.tipo = AbilityData.Tipo.MOVILIDAD
	rodar.objetivo = AbilityData.Objetivo.SUELO
	rodar.coste_mana = 0.0
	rodar.cooldown = 6.0
	rodar.radio = 4.0
	kit.append(rodar)

	var grito := AbilityData.new()
	grito.id = &"prisionero_grito"
	grito.nombre = "Grito de Libertad"
	grito.descripcion = "Grito de guerra: cura al gladiador, otorga +25 % velocidad de ataque y +12 % robo de vida durante 3 s, y cura al estandarte y a los aliados cercanos."
	grito.tipo = AbilityData.Tipo.APOYO
	grito.objetivo = AbilityData.Objetivo.PROPIO
	grito.coste_mana = 0.0
	grito.cooldown = 20.0
	grito.duracion = 3.0
	grito.curacion_base = 40.0
	grito.efecto_especial = &"grito"
	grito.atributo_escalado = &"fuerza"
	grito.talentos.append(_talento(&"grito_cura", "Grito curativo", "Aumenta la curación en 15 por rango.", 2, &"", {&"curacion": 15.0}, 2))
	grito.talentos.append(_talento(&"grito_duracion", "Eco del grito", "La duración aumenta 1 s por rango.", 3, &"grito_cura", {&"duracion": 1.0}, 2))
	kit.append(grito)

	return kit


static func _kit_bastion() -> Array[AbilityData]:
	var kit: Array[AbilityData] = []

	var muro := AbilityData.new()
	muro.id = &"bastion_muro_escudos"
	muro.nombre = "Muro de Escudos"
	muro.descripcion = "Provoca a los enemigos en un radio de 5 m durante 3 s."
	muro.tipo = AbilityData.Tipo.APOYO
	muro.objetivo = AbilityData.Objetivo.PROPIO
	muro.coste_mana = 25.0
	muro.cooldown = 12.0
	muro.radio = 5.0
	muro.duracion = 3.0
	muro.provoca = true
	muro.talentos.append(_talento(&"muro_radio", "Muro reforzado", "Amplía el radio de provocación en 1,5 m por rango.", 2, &"", {&"radio": 1.5}, 2))
	muro.talentos.append(_talento(&"muro_duracion", "Provocación prolongada", "La provocación dura 1,5 s más por rango.", 3, &"muro_radio", {&"duracion": 1.5}, 2))
	kit.append(muro)

	var sismico := AbilityData.new()
	sismico.id = &"bastion_golpe_sismico"
	sismico.nombre = "Golpe Sísmico"
	sismico.descripcion = "Onda de impacto frontal que aturde a los enemigos."
	sismico.tipo = AbilityData.Tipo.IMPACTO
	sismico.objetivo = AbilityData.Objetivo.SUELO
	sismico.coste_mana = 30.0
	sismico.cooldown = 9.0
	sismico.dano_base = 35.0
	sismico.radio = 3.5
	sismico.talentos.append(_talento(&"sismico_onda", "Onda expansiva", "Aumenta el radio en 1,2 m por rango.", 2, &"", {&"radio": 1.2}, 2))
	sismico.talentos.append(_talento(&"sismico_fractura", "Fractura", "Añade 15 de daño por rango.", 3, &"sismico_onda", {&"dano": 15.0}, 2))
	kit.append(sismico)

	var provocacion := AbilityData.new()
	provocacion.id = &"bastion_provocacion"
	provocacion.nombre = "Provocación de Arena"
	provocacion.descripcion = "Arrastra a los enemigos cercanos hacia el gladiador."
	provocacion.tipo = AbilityData.Tipo.APOYO
	provocacion.objetivo = AbilityData.Objetivo.PROPIO
	provocacion.coste_mana = 20.0
	provocacion.cooldown = 14.0
	provocacion.radio = 6.0
	provocacion.duracion = 1.5
	provocacion.provoca = true
	provocacion.talentos.append(_talento(&"provocacion_autoridad", "Autoridad de arena", "Amplía el radio en 2 m por rango.", 3, &"", {&"radio": 2.0}, 2))
	kit.append(provocacion)

	var bastion := AbilityData.new()
	bastion.id = &"bastion_inquebrantable"
	bastion.nombre = "Bastión Inquebrantable"
	bastion.descripcion = "Ultimate: reduce el daño recibido y provoca sin descanso."
	bastion.tipo = AbilityData.Tipo.APOYO
	bastion.objetivo = AbilityData.Objetivo.PROPIO
	bastion.coste_mana = 60.0
	bastion.cooldown = 45.0
	bastion.radio = 8.0
	bastion.duracion = 6.0
	bastion.reduccion_dano = 0.4
	bastion.escudo_por_atributo = 0.55
	bastion.inmunidad_aturdimiento = 3.5
	bastion.efecto_especial = &"egida"
	bastion.atributo_escalado = &"fuerza"
	bastion.talentos.append(_talento(&"bastion_ira", "Ira de la horda", "La ultimate dura 2 s más por rango.", 4, &"", {&"duracion": 2.0}, 2))
	kit.append(bastion)

	return kit


static func _kit_filo() -> Array[AbilityData]:
	var kit: Array[AbilityData] = []

	var tajo := AbilityData.new()
	tajo.id = &"filo_tajo_gemelo"
	tajo.nombre = "Tajo Gemelo"
	tajo.descripcion = "Dos cortes rápidos en cono frontal."
	tajo.tipo = AbilityData.Tipo.IMPACTO
	tajo.objetivo = AbilityData.Objetivo.ENEMIGO
	tajo.coste_mana = 15.0
	tajo.cooldown = 4.0
	tajo.dano_base = 26.0
	tajo.radio = 2.6
	tajo.atributo_escalado = &"agilidad"
	tajo.talentos.append(_talento(&"tajo_alcance", "Alcance gemelo", "Amplía el cono en 0,6 m por rango.", 2, &"", {&"radio": 0.6}, 2))
	tajo.talentos.append(_talento(&"tajo_sangrado", "Sangrado", "Añade 10 de daño por rango.", 3, &"tajo_alcance", {&"dano": 10.0}, 2))
	kit.append(tajo)

	var paso := AbilityData.new()
	paso.id = &"filo_paso_sombrio"
	paso.nombre = "Paso Sombrío"
	paso.descripcion = "Dash hacia el cursor que deja un rastro y potencia el siguiente Tajo Gemelo (+40 %)."
	paso.tipo = AbilityData.Tipo.MOVILIDAD
	paso.objetivo = AbilityData.Objetivo.SUELO
	paso.coste_mana = 20.0
	paso.cooldown = 7.0
	paso.radio = 5.5
	paso.dano_base = 18.0
	paso.tipo_dano = GladiatorStats.TIPO_FISICO
	paso.atributo_escalado = &"agilidad"
	paso.talentos.append(_talento(&"paso_alcance", "Paso largo", "Aumenta la distancia del dash en 1,5 m por rango.", 2, &"", {&"radio": 1.5}, 2))
	paso.talentos.append(_talento(&"paso_filo", "Filo sombrío", "El impacto del dash añade 12 de daño por rango.", 3, &"paso_alcance", {&"dano": 12.0}, 2))
	kit.append(paso)

	var marca := AbilityData.new()
	marca.id = &"filo_marca_verdugo"
	marca.nombre = "Marca del Verdugo"
	marca.descripcion = "Marca al objetivo: recibe más daño crítico durante 5 s."
	marca.tipo = AbilityData.Tipo.APOYO
	marca.objetivo = AbilityData.Objetivo.ENEMIGO
	marca.coste_mana = 18.0
	marca.cooldown = 12.0
	marca.radio = 2.2
	marca.duracion = 5.0
	marca.efecto_especial = &"marca_verdugo"
	marca.atributo_escalado = &"agilidad"
	marca.talentos.append(_talento(&"marca_duradera", "Sentencia duradera", "La marca dura 1 s más por rango.", 2, &"", {&"duracion": 1.0}, 2))
	marca.talentos.append(_talento(&"marca_alcance", "Señal amplia", "Amplía el radio de la marca en 1 m por rango.", 3, &"marca_duradera", {&"radio": 1.0}, 2))
	kit.append(marca)

	var ejecucion := AbilityData.new()
	ejecucion.id = &"filo_ejecucion"
	ejecucion.nombre = "Ejecución"
	ejecucion.descripcion = "Ultimate: salto mortal con daño masivo y crítico garantizado."
	ejecucion.tipo = AbilityData.Tipo.MOVILIDAD
	ejecucion.objetivo = AbilityData.Objetivo.ENEMIGO
	ejecucion.coste_mana = 55.0
	ejecucion.cooldown = 40.0
	ejecucion.dano_base = 120.0
	ejecucion.radio = 3.0
	ejecucion.efecto_especial = &"ejecucion"
	ejecucion.atributo_escalado = &"agilidad"
	ejecucion.talentos.append(_talento(&"ejecucion_verdugo", "Sentencia del verdugo", "Añade 25 de daño por rango.", 4, &"", {&"dano": 25.0}, 2))
	kit.append(ejecucion)

	return kit


static func _kit_cetro() -> Array[AbilityData]:
	var kit: Array[AbilityData] = []

	var espina := AbilityData.new()
	espina.id = &"cetro_espina_vital"
	espina.nombre = "Espina Vital"
	espina.descripcion = "Dardo de savia que daña y sana a un aliado o estandarte cercano."
	espina.tipo = AbilityData.Tipo.PROYECTIL
	espina.objetivo = AbilityData.Objetivo.ENEMIGO
	espina.coste_mana = 18.0
	espina.cooldown = 3.5
	espina.dano_base = 22.0
	espina.tipo_dano = &"magico"
	espina.radio = 1.5
	espina.efecto_especial = &"vinculo"
	espina.atributo_escalado = &"inteligencia"
	espina.talentos.append(_talento(&"espina_veneno", "Savia corrosiva", "Añade 8 de daño por rango.", 2, &"", {&"dano": 8.0}, 2))
	espina.talentos.append(_talento(&"espina_radio", "Zarcillo largo", "Amplía el radio de la espina en 0,8 m por rango.", 3, &"espina_veneno", {&"radio": 0.8}, 2))
	kit.append(espina)

	var estandarte := AbilityData.new()
	estandarte.id = &"cetro_estandarte_rebelion"
	estandarte.nombre = "Estandarte de Rebelión"
	estandarte.descripcion = "Zona circular temporal que cura a los aliados. Un élite dentro del radio acorta su duración."
	estandarte.tipo = AbilityData.Tipo.ZONA
	estandarte.objetivo = AbilityData.Objetivo.SUELO
	estandarte.coste_mana = 35.0
	estandarte.cooldown = 16.0
	estandarte.dano_base = 6.0
	estandarte.curacion_base = 6.0
	estandarte.tipo_dano = &"magico"
	estandarte.radio = 4.0
	estandarte.duracion = 8.0
	estandarte.atributo_escalado = &"inteligencia"

	var talento_radio := TalentData.new()
	talento_radio.id = &"estandarte_radio"
	talento_radio.nombre = "Círculo Ampliado"
	talento_radio.descripcion = "+1.5 m de radio al estandarte."
	talento_radio.coste_puntos_rojos = 3
	talento_radio.rango_maximo = 2
	talento_radio.modificadores = {&"radio": 1.5}
	estandarte.talentos.append(talento_radio)

	var talento_fuego := TalentData.new()
	talento_fuego.id = &"estandarte_fuego"
	talento_fuego.nombre = "Brasas de Rebelión"
	talento_fuego.descripcion = "Los enemigos que pisen el estandarte reciben daño de fuego."
	talento_fuego.coste_puntos_rojos = 4
	talento_fuego.talento_requerido = &"estandarte_radio"
	talento_fuego.modificadores = {&"dano_fuego": 12.0}
	estandarte.talentos.append(talento_fuego)
	kit.append(estandarte)

	var raices := AbilityData.new()
	raices.id = &"cetro_lazo_raices"
	raices.nombre = "Lazo de Raíces"
	raices.descripcion = "Enraíza al enemigo en el suelo durante 2 s."
	raices.tipo = AbilityData.Tipo.APOYO
	raices.objetivo = AbilityData.Objetivo.ENEMIGO
	raices.coste_mana = 25.0
	raices.cooldown = 13.0
	raices.radio = 2.0
	raices.duracion = 2.0
	raices.vulnerabilidad_magica = true
	raices.efecto_especial = &"raices"
	raices.atributo_escalado = &"inteligencia"
	raices.talentos.append(_talento(&"raices_profundas", "Raíces profundas", "Enraíza 1 s más por rango.", 3, &"", {&"duracion": 1.0}, 2))
	raices.talentos.append(_talento(&"raices_radio", "Raíz expansiva", "Amplía el radio 1,2 m por rango.", 3, &"raices_profundas", {&"radio": 1.2}, 2))
	kit.append(raices)

	var ancestral := AbilityData.new()
	ancestral.id = &"cetro_espiritu_ancestral"
	ancestral.nombre = "Espíritu Ancestral"
	ancestral.descripcion = "Ultimate: invoca un espíritu cuyos atributos heredan un porcentaje de la INT del héroe."
	ancestral.tipo = AbilityData.Tipo.INVOCACION
	ancestral.objetivo = AbilityData.Objetivo.SUELO
	ancestral.coste_mana = 70.0
	ancestral.cooldown = 50.0
	ancestral.dano_base = 40.0
	ancestral.tipo_dano = &"magico"
	ancestral.duracion = 18.0
	ancestral.atributo_escalado = &"inteligencia"
	ancestral.talentos.append(_talento(&"ancestral_vinculo", "Vínculo ancestral", "El espíritu dura 2 s más por rango.", 4, &"", {&"duracion": 2.0}, 2))
	kit.append(ancestral)

	return kit


static func _kit_lancero() -> Array[AbilityData]:
	var kit: Array[AbilityData] = []

	var estocada := AbilityData.new()
	estocada.id = &"lanza_estocada"
	estocada.nombre = "Estocada Perforante"
	estocada.descripcion = "Golpe de pica que atraviesa la primera fila enemiga."
	estocada.tipo = AbilityData.Tipo.IMPACTO
	estocada.objetivo = AbilityData.Objetivo.ENEMIGO
	estocada.coste_mana = 18.0
	estocada.cooldown = 5.0
	estocada.dano_base = 30.0
	estocada.radio = 3.0
	estocada.atributo_escalado = &"fuerza"
	estocada.talentos.append(_talento(&"estocada_alcance", "Pica larga", "Amplía el alcance en 0,6 m por rango.", 2, &"", {&"radio": 0.6}, 2))
	estocada.talentos.append(_talento(&"estocada_perforar", "Punta de bronce", "Añade 12 de daño por rango.", 3, &"estocada_alcance", {&"dano": 12.0}, 2))
	kit.append(estocada)

	var muro_picas := AbilityData.new()
	muro_picas.id = &"lanza_muro_picas"
	muro_picas.nombre = "Muro de Picas"
	muro_picas.descripcion = "Zona de picas durante 6 s que corta el paso y desangra a quien la cruza."
	muro_picas.tipo = AbilityData.Tipo.ZONA
	muro_picas.objetivo = AbilityData.Objetivo.SUELO
	muro_picas.coste_mana = 30.0
	muro_picas.cooldown = 14.0
	muro_picas.dano_base = 12.0
	muro_picas.radio = 3.2
	muro_picas.duracion = 6.0
	muro_picas.atributo_escalado = &"fuerza"
	muro_picas.talentos.append(_talento(&"muro_picas_ancho", "Formación abierta", "Aumenta el radio en 1 m por rango.", 2, &"", {&"radio": 1.0}, 2))
	muro_picas.talentos.append(_talento(&"muro_picas_largo", "Empalizada", "La zona dura 2 s más por rango.", 3, &"muro_picas_ancho", {&"duracion": 2.0}, 2))
	kit.append(muro_picas)

	var embestida := AbilityData.new()
	embestida.id = &"lanza_embestida"
	embestida.nombre = "Embestida del Hoplita"
	embestida.descripcion = "Carga con el escudo por delante y aparta a los enemigos del camino."
	embestida.tipo = AbilityData.Tipo.MOVILIDAD
	embestida.objetivo = AbilityData.Objetivo.SUELO
	embestida.coste_mana = 22.0
	embestida.cooldown = 9.0
	embestida.dano_base = 22.0
	embestida.radio = 5.0
	embestida.atributo_escalado = &"fuerza"
	embestida.talentos.append(_talento(&"embestida_larga", "Carga profunda", "Aumenta la distancia 1,5 m por rango.", 2, &"", {&"radio": 1.5}, 2))
	embestida.talentos.append(_talento(&"embestida_golpe", "Choque de escudos", "Añade 14 de daño por rango.", 3, &"embestida_larga", {&"dano": 14.0}, 2))
	kit.append(embestida)

	var formacion := AbilityData.new()
	formacion.id = &"lanza_formacion"
	formacion.nombre = "Formación Inquebrantable"
	formacion.descripcion = "Ultimate: la falange cierra filas. Reduce el daño recibido, otorga escudo y lanza el grito de guerra."
	formacion.tipo = AbilityData.Tipo.APOYO
	formacion.objetivo = AbilityData.Objetivo.PROPIO
	formacion.coste_mana = 60.0
	formacion.cooldown = 42.0
	formacion.radio = 7.0
	formacion.duracion = 6.0
	formacion.reduccion_dano = 0.30
	formacion.escudo_por_atributo = 0.50
	formacion.inmunidad_aturdimiento = 2.0
	formacion.efecto_especial = &"grito"
	formacion.atributo_escalado = &"fuerza"
	formacion.talentos.append(_talento(&"formacion_duracion", "Filas cerradas", "La formación dura 2 s más por rango.", 4, &"", {&"duracion": 2.0}, 2))
	kit.append(formacion)

	return kit


static func _kit_saetera() -> Array[AbilityData]:
	var kit: Array[AbilityData] = []

	var doble := AbilityData.new()
	doble.id = &"saeta_disparo_doble"
	doble.nombre = "Disparo Doble"
	doble.descripcion = "Dos flechas seguidas al objetivo más cercano."
	doble.tipo = AbilityData.Tipo.PROYECTIL
	doble.objetivo = AbilityData.Objetivo.ENEMIGO
	doble.coste_mana = 16.0
	doble.cooldown = 4.0
	doble.dano_base = 26.0
	doble.radio = 1.8
	doble.atributo_escalado = &"agilidad"
	doble.talentos.append(_talento(&"doble_punta", "Punta de pedernal", "Añade 9 de daño por rango.", 2, &"", {&"dano": 9.0}, 2))
	doble.talentos.append(_talento(&"doble_alcance", "Tensión extra", "Aumenta el radio de impacto 0,6 m por rango.", 3, &"doble_punta", {&"radio": 0.6}, 2))
	kit.append(doble)

	var lluvia := AbilityData.new()
	lluvia.id = &"saeta_lluvia_puas"
	lluvia.nombre = "Lluvia de Púas"
	lluvia.descripcion = "Siembra de púas durante 5 s que castiga a todo el que se quede dentro."
	lluvia.tipo = AbilityData.Tipo.ZONA
	lluvia.objetivo = AbilityData.Objetivo.SUELO
	lluvia.coste_mana = 30.0
	lluvia.cooldown = 12.0
	lluvia.dano_base = 14.0
	lluvia.radio = 3.8
	lluvia.duracion = 5.0
	lluvia.atributo_escalado = &"agilidad"
	lluvia.talentos.append(_talento(&"lluvia_radio", "Lluvia amplia", "Aumenta el radio 1,2 m por rango.", 2, &"", {&"radio": 1.2}, 2))
	lluvia.talentos.append(_talento(&"lluvia_duracion", "Púas persistentes", "La zona dura 2 s más por rango.", 3, &"lluvia_radio", {&"duracion": 2.0}, 2))
	kit.append(lluvia)

	var paso := AbilityData.new()
	paso.id = &"saeta_paso_cazador"
	paso.nombre = "Paso del Cazador"
	paso.descripcion = "Salto corto que reposiciona a la saetera fuera del alcance cuerpo a cuerpo."
	paso.tipo = AbilityData.Tipo.MOVILIDAD
	paso.objetivo = AbilityData.Objetivo.SUELO
	paso.coste_mana = 18.0
	paso.cooldown = 8.0
	paso.dano_base = 12.0
	paso.radio = 5.5
	paso.atributo_escalado = &"agilidad"
	paso.talentos.append(_talento(&"paso_largo", "Zancada larga", "Aumenta la distancia 1,5 m por rango.", 2, &"", {&"radio": 1.5}, 2))
	paso.talentos.append(_talento(&"paso_puas", "Rastro de púas", "Añade 10 de daño por rango.", 3, &"paso_largo", {&"dano": 10.0}, 2))
	kit.append(paso)

	var ojo := AbilityData.new()
	ojo.id = &"saeta_ojo_tormenta"
	ojo.nombre = "Ojo de la Tormenta"
	ojo.descripcion = "Ultimate: descarga de flechas que marca a todos los enemigos del área."
	ojo.tipo = AbilityData.Tipo.ZONA
	ojo.objetivo = AbilityData.Objetivo.SUELO
	ojo.coste_mana = 65.0
	ojo.cooldown = 45.0
	ojo.dano_base = 40.0
	ojo.radio = 6.0
	ojo.duracion = 6.0
	ojo.efecto_especial = &"marca_verdugo"
	ojo.atributo_escalado = &"agilidad"
	ojo.talentos.append(_talento(&"ojo_duracion", "Tormenta larga", "La tormenta dura 2 s más por rango.", 4, &"", {&"duracion": 2.0}, 2))
	kit.append(ojo)

	return kit


## Define los rangos de habilidad. Q/W/E llegan a 4; R a 3. Los valores son
## mejoras planas que el controlador y AbilityEffect suman al rango actual.
static func _configurar_rangos(arma: WeaponItem) -> void:
	var definitivas := [
		"prisionero_grito", "bastion_inquebrantable",
		"filo_ejecucion", "cetro_espiritu_ancestral",
		"lanza_formacion", "saeta_ojo_tormenta",
	]
	for habilidad in arma.habilidades:
		if habilidad == null:
			continue
		habilidad.rango_maximo = 3 if String(habilidad.id) in definitivas else 4
		match String(habilidad.id):
			"prisionero_punetazo":
				habilidad.mejoras_rango = [
					{"descripcion": "+4 de daño", "dano": 4.0},
					{"descripcion": "+0.4 m de radio", "radio": 0.4},
					{"descripcion": "+6 de daño", "dano": 6.0},
				]
			"prisionero_patada":
				habilidad.mejoras_rango = [
					{"descripcion": "+5 de daño", "dano": 5.0},
					{"descripcion": "+0.5 m de radio", "radio": 0.5},
					{"descripcion": "+7 de daño", "dano": 7.0},
				]
			"prisionero_rodar":
				habilidad.mejoras_rango = [
					{"descripcion": "+1 m de impulso", "radio": 1.0},
					{"descripcion": "+0.5 s de duración", "duracion": 0.5},
					{"descripcion": "+1 m de impulso", "radio": 1.0},
				]
			"prisionero_grito":
				habilidad.mejoras_rango = [
					{"descripcion": "+2 s de duración", "duracion": 2.0},
					{"descripcion": "+1 m de radio", "radio": 1.0},
				]
			"bastion_muro_escudos":
				habilidad.mejoras_rango = [
					{"descripcion": "+1 s de duración", "duracion": 1.0},
					{"descripcion": "+0.8 m de radio", "radio": 0.8},
					{"descripcion": "+8 de daño", "dano": 8.0},
				]
			"bastion_golpe_sismico":
				habilidad.mejoras_rango = [
					{"descripcion": "+10 de daño", "dano": 10.0},
					{"descripcion": "+0.8 m de radio", "radio": 0.8},
					{"descripcion": "+1 s de aturdimiento", "duracion": 1.0},
				]
			"bastion_provocacion":
				habilidad.mejoras_rango = [
					{"descripcion": "+0.8 m de radio", "radio": 0.8},
					{"descripcion": "+1 s de provocación", "duracion": 1.0},
					{"descripcion": "+1 m de radio", "radio": 1.0},
				]
			"bastion_inquebrantable":
				habilidad.mejoras_rango = [
					{"descripcion": "+1.5 s de Égida", "duracion": 1.5},
					{"descripcion": "+20 de escudo", "dano": 20.0},
				]
			"filo_tajo_gemelo":
				habilidad.mejoras_rango = [
					{"descripcion": "+8 de daño", "dano": 8.0},
					{"descripcion": "+0.6 m de radio", "radio": 0.6},
					{"descripcion": "+12 de daño", "dano": 12.0},
				]
			"filo_paso_sombrio":
				habilidad.mejoras_rango = [
					{"descripcion": "+1 m de parpadeo", "radio": 1.0},
					{"descripcion": "+8 de daño", "dano": 8.0},
					{"descripcion": "+1.5 m de parpadeo", "radio": 1.5},
				]
			"filo_marca_verdugo":
				habilidad.mejoras_rango = [
					{"descripcion": "+1 s de marca", "duracion": 1.0},
					{"descripcion": "+1 m de radio", "radio": 1.0},
					{"descripcion": "+0.5 s de marca", "duracion": 0.5},
				]
			"filo_ejecucion":
				habilidad.mejoras_rango = [
					{"descripcion": "+25 de daño", "dano": 25.0},
					{"descripcion": "+30 de daño y -5 s de recarga", "dano": 30.0, "cooldown": -5.0},
				]
			"cetro_espina_vital":
				habilidad.mejoras_rango = [
					{"descripcion": "+7 de daño", "dano": 7.0},
					{"descripcion": "+0.8 m de radio", "radio": 0.8},
					{"descripcion": "+10 de daño", "dano": 10.0},
				]
			"cetro_estandarte_rebelion":
				habilidad.mejoras_rango = [
					{"descripcion": "+1 s de duración", "duracion": 1.0},
					{"descripcion": "+1 m de radio", "radio": 1.0},
					{"descripcion": "+12 de curación", "curacion": 12.0},
				]
			"cetro_lazo_raices":
				habilidad.mejoras_rango = [
					{"descripcion": "+0.8 m de radio", "radio": 0.8},
					{"descripcion": "+1 s de raíces", "duracion": 1.0},
					{"descripcion": "+8 de daño", "dano": 8.0},
				]
			"cetro_espiritu_ancestral":
				habilidad.mejoras_rango = [
					{"descripcion": "+4 s de invocación", "duracion": 4.0},
					{"descripcion": "+12 de daño y un segundo espíritu al 50 %", "dano": 12.0, "efecto_especial": &"espiritu_doble"},
				]
			"lanza_estocada":
				habilidad.mejoras_rango = [
					{"descripcion": "+9 de daño", "dano": 9.0},
					{"descripcion": "+0.6 m de alcance", "radio": 0.6},
					{"descripcion": "+13 de daño", "dano": 13.0},
				]
			"lanza_muro_picas":
				habilidad.mejoras_rango = [
					{"descripcion": "+1 m de radio", "radio": 1.0},
					{"descripcion": "+2 s de duración", "duracion": 2.0},
					{"descripcion": "+6 de daño por pulso", "dano": 6.0},
				]
			"lanza_embestida":
				habilidad.mejoras_rango = [
					{"descripcion": "+1.5 m de carga", "radio": 1.5},
					{"descripcion": "+10 de daño", "dano": 10.0},
					{"descripcion": "+2 m de carga", "radio": 2.0},
				]
			"lanza_formacion":
				habilidad.mejoras_rango = [
					{"descripcion": "+2 s de formación", "duracion": 2.0},
					{"descripcion": "+15 de escudo y 5 % más de reducción", "dano": 15.0, "reduccion_dano": 0.05},
				]
			"saeta_disparo_doble":
				habilidad.mejoras_rango = [
					{"descripcion": "+9 de daño", "dano": 9.0},
					{"descripcion": "+0.6 m de radio", "radio": 0.6},
					{"descripcion": "+12 de daño", "dano": 12.0},
				]
			"saeta_lluvia_puas":
				habilidad.mejoras_rango = [
					{"descripcion": "+1.2 m de radio", "radio": 1.2},
					{"descripcion": "+2 s de duración", "duracion": 2.0},
					{"descripcion": "+5 de daño por pulso", "dano": 5.0},
				]
			"saeta_paso_cazador":
				habilidad.mejoras_rango = [
					{"descripcion": "+1.5 m de salto", "radio": 1.5},
					{"descripcion": "+8 de daño", "dano": 8.0},
					{"descripcion": "+1.5 m de salto", "radio": 1.5},
				]
			"saeta_ojo_tormenta":
				habilidad.mejoras_rango = [
					{"descripcion": "+2 s de tormenta", "duracion": 2.0},
					{"descripcion": "+1.5 m de radio y +12 de daño", "radio": 1.5, "dano": 12.0},
				]
			_:
				pass


## Constructor abreviado de talentos para mantener legibles los kits.
static func _talento(
	id: StringName,
	nombre: String,
	descripcion: String,
	coste: int,
	requerido: StringName,
	modificadores: Dictionary,
	rango_maximo: int = 1
) -> TalentData:
	var talento := TalentData.new()
	talento.id = id
	talento.nombre = nombre
	talento.descripcion = descripcion
	talento.coste_puntos_rojos = coste
	talento.talento_requerido = requerido
	talento.modificadores = modificadores
	talento.rango_maximo = rango_maximo
	return talento
