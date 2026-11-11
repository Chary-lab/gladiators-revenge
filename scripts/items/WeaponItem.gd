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
}

enum Rol {
	NINGUNO,
	TANQUE,
	VERDUGO,
	CONVOCADOR,
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
	arma.habilidades = _kit_prisionero()
	_aplicar_iconos(arma)
	_configurar_rangos(arma)
	return arma


## Las tres clases jugables con las que se compra el rol en la armería.
static func crear_catalogo_base() -> Array[WeaponItem]:
	var catalogo: Array[WeaponItem] = []
	catalogo.append(_crear_bastion())
	catalogo.append(_crear_filo())
	catalogo.append(_crear_cetro())
	for arma in catalogo:
		_aplicar_iconos(arma)
		_configurar_rangos(arma)
	return catalogo


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
	arma.bonificaciones_atributos = {"fuerza": 0, "agilidad": 0, "inteligencia": 8}
	arma.escena_visual = load("res://assets/kaykit/weapons/staff.gltf")
	arma.rotacion_visual = Vector3(90.0, 0.0, 0.0)
	arma.escala_visual = 0.90
	arma.habilidades = _kit_cetro()
	return arma


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
	grito.descripcion = "Recupera el aliento. Sin efecto de combate todavía."
	grito.tipo = AbilityData.Tipo.APOYO
	grito.objetivo = AbilityData.Objetivo.PROPIO
	grito.coste_mana = 0.0
	grito.cooldown = 20.0
	grito.duracion = 3.0
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


## Define los rangos de habilidad. Q/W/E llegan a 4; R a 3. Los valores son
## mejoras planas que el controlador y AbilityEffect suman al rango actual.
static func _configurar_rangos(arma: WeaponItem) -> void:
	var definitivas := [
		"prisionero_grito", "bastion_inquebrantable",
		"filo_ejecucion", "cetro_espiritu_ancestral",
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
