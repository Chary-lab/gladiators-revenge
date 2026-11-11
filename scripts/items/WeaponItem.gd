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
	return arma


## Las tres clases jugables con las que se compra el rol en la armería.
static func crear_catalogo_base() -> Array[WeaponItem]:
	var catalogo: Array[WeaponItem] = []
	catalogo.append(_crear_bastion())
	catalogo.append(_crear_filo())
	catalogo.append(_crear_cetro())
	return catalogo


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
	bastion.atributo_escalado = &"fuerza"
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
	kit.append(tajo)

	var paso := AbilityData.new()
	paso.id = &"filo_paso_sombrio"
	paso.nombre = "Paso Sombrío"
	paso.descripcion = "Dash hacia el cursor que el siguiente golpe sea crítico."
	paso.tipo = AbilityData.Tipo.MOVILIDAD
	paso.objetivo = AbilityData.Objetivo.SUELO
	paso.coste_mana = 20.0
	paso.cooldown = 7.0
	paso.radio = 5.5
	paso.atributo_escalado = &"agilidad"
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
	marca.atributo_escalado = &"agilidad"
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
	ejecucion.atributo_escalado = &"agilidad"
	kit.append(ejecucion)

	return kit


static func _kit_cetro() -> Array[AbilityData]:
	var kit: Array[AbilityData] = []

	var espina := AbilityData.new()
	espina.id = &"cetro_espina_vital"
	espina.nombre = "Espina Vital"
	espina.descripcion = "Dardo de savia que daña y ralentiza."
	espina.tipo = AbilityData.Tipo.PROYECTIL
	espina.objetivo = AbilityData.Objetivo.ENEMIGO
	espina.coste_mana = 18.0
	espina.cooldown = 3.5
	espina.dano_base = 22.0
	espina.tipo_dano = &"magico"
	espina.radio = 1.5
	espina.atributo_escalado = &"inteligencia"
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
	estandarte.tipo_dano = &"magico"
	estandarte.radio = 4.0
	estandarte.duracion = 8.0
	estandarte.atributo_escalado = &"inteligencia"

	var talento_radio := TalentData.new()
	talento_radio.id = &"estandarte_radio"
	talento_radio.nombre = "Círculo Ampliado"
	talento_radio.descripcion = "+1.5 m de radio al estandarte."
	talento_radio.coste_puntos_rojos = 3
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
	raices.atributo_escalado = &"inteligencia"
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
	kit.append(ancestral)

	return kit
