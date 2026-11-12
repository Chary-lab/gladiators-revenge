class_name GladiatorStats
extends Resource
## Atributos escalables de un gladiador (STR / AGI / INT).
##
## Fuente única de verdad del RPG: el controlador, las armas y las habilidades
## leen estos valores calculados. Ningún otro script debe replicar fórmulas.
##
## Escalado por punto (ajustable en las constantes):
## - Fuerza: vida máxima, regeneración, daño físico de impacto, mitigación.
## - Agilidad: velocidad de ataque, crítico y velocidad de movimiento.
## - Inteligencia: maná, regeneración, daño mágico y herencia de invocaciones.
##
## IMPORTANTE: asigna un recurso distinto (o un .duplicate()) a cada gladiador,
## porque los puntos y los bonos de equipo son estado propio de cada personaje.

signal atributos_cambiados
signal experiencia_cambiada(actual: int, requerida: int, nivel: int)
signal nivel_subido(nivel: int)

const TIPO_FISICO := &"fisico"
const TIPO_MAGICO := &"magico"
const TIPO_VERDADERO := &"verdadero"

## Daño de ataque básico que aporta cada punto del atributo principal de la
## clase equipada (Bastión: FUE, Filo: AGI, Cetro: INT, Prisionero: FUE).
## Es deliberadamente bajo: un gladiador sin experiencia pega poco y su daño
## crece sobre todo con el nivel y el equipo.
const DANO_ATAQUE_POR_ATRIBUTO := 0.45
## Crecimiento del daño por nivel (3,5 % por nivel sobre el daño base).
const DANO_ESCALA_POR_NIVEL := 0.090
## Variación aleatoria del golpe: el daño real cae en [min, max].
const DANO_VARIANZA := 0.20
## Multiplicador de daño según la clase equipada (identidad de combate).
const MULT_DANO_POR_CLASE := {
	&"prisionero": 0.80,
	&"bastion": 1.00,
	&"filo": 1.12,
	&"cetro": 0.92,
}

## Crecimiento automático por nivel según la clase (FUE, AGI, INT). Los
## decimales se acumulan para no perder fracciones entre niveles.
const CRECIMIENTO_POR_CLASE := {
	&"prisionero": Vector3(3, 1, 1),
	&"bastion": Vector3(3, 1, 1),
	&"filo": Vector3(1, 3, 1),
	&"cetro": Vector3(1, 1, 3),
}

# --- Fuerza ---------------------------------------------------------------
const VIDA_BASE := 100.0
const VIDA_POR_FUERZA := 11.0
const REGEN_VIDA_BASE := 0.8
const REGEN_VIDA_POR_FUERZA := 0.08
const DANO_FISICO_POR_FUERZA := 1.2
const MITIGACION_FISICA_POR_FUERZA := 0.0040
const ARMADURA_POR_PUNTO := 0.01
const AGILIDAD_POR_ARMADURA := 0.12
const MITIGACION_FISICA_MAXIMA := 0.60

# --- Agilidad -------------------------------------------------------------
## Ataques por segundo. La base es el suelo de un novato: casi todo el ritmo
## lo aportan la Agilidad y el nivel.
const VEL_ATAQUE_BASE := 0.15
const VEL_ATAQUE_POR_AGI := 0.050
const VEL_ATAQUE_POR_NIVEL := 0.025
const VEL_ATAQUE_MIN := 0.15
const VEL_ATAQUE_MAX := 2.20
const CRITICO_BASE := 0.05
const CRITICO_POR_AGI := 0.0035
const CRITICO_MAXIMO := 0.75
const CRITICO_DANO_BASE := 1.50
const CRITICO_DANO_POR_AGI := 0.004
const VEL_MOV_BASE := 4.2
const VEL_MOV_POR_AGI := 0.035
const VEL_MOV_MIN := 3.0
const VEL_MOV_MAX := 9.0

# --- Inteligencia ---------------------------------------------------------
const MANA_BASE := 60.0
const MANA_POR_INT := 7.0
const REGEN_MANA_BASE := 1.2
const REGEN_MANA_POR_INT := 0.09
const DANO_MAGICO_POR_INT := 1.4
const MITIGACION_MAGICA_POR_INT := 0.0015
const MITIGACION_MAGICA_MAXIMA := 0.40
const HERENCIA_INVOCACION_BASE := 0.05
const HERENCIA_INVOCACION_POR_INT := 0.004
const HERENCIA_INVOCACION_MAXIMA := 0.85

@export_group("Atributos primarios")
@export_range(1, 500, 1) var fuerza: int = 10
@export_range(1, 500, 1) var agilidad: int = 10
@export_range(1, 500, 1) var inteligencia: int = 10

@export_group("Progresión")
@export_range(0, 999, 1) var puntos_libres: int = 0
@export_range(1, 20, 1) var nivel: int = 1
@export_range(0, 999999, 1) var experiencia: int = 0
## XP sobrante al alcanzar el nivel máximo; Arena la convierte en oro.
var experiencia_excedente: int = 0

## Clase equipada: define la curva de crecimiento automático por nivel.
var clase: StringName = &"prisionero"
var _crecimiento: Vector3 = CRECIMIENTO_POR_CLASE[&"prisionero"]
var _resto_crecimiento := Vector3.ZERO

## Bonos temporales aportados por el arma equipada (no se serializan: el arma
## los vuelve a aplicar al equiparse).
var _bonos_equipo: Dictionary = {"fuerza": 0, "agilidad": 0, "inteligencia": 0}
## Bonos permanentes de los 6 objetos del inventario. Se recalculan al cambiar
## cualquier ranura; las fórmulas derivadas siguen viviendo solo aquí.
var _bonos_inventario: Dictionary = {}


# --- Totales (base + arma + inventario) -----------------------------------

func _bono(clave: String) -> float:
	return float(_bonos_equipo.get(clave, 0)) + float(_bonos_inventario.get(clave, 0))

var fuerza_total: int:
	get:
		return fuerza + int(_bono("fuerza"))

var agilidad_total: int:
	get:
		return agilidad + int(_bono("agilidad"))

var inteligencia_total: int:
	get:
		return inteligencia + int(_bono("inteligencia"))


# --- Derivados de Fuerza --------------------------------------------------

var salud_maxima: float:
	get:
		return VIDA_BASE + fuerza_total * VIDA_POR_FUERZA + _bono("vida")

var regeneracion_salud: float:
	get:
		return REGEN_VIDA_BASE + fuerza_total * REGEN_VIDA_POR_FUERZA + _bono("regeneracion")

var bono_dano_fisico: float:
	get:
		return fuerza_total * DANO_FISICO_POR_FUERZA + _bono("dano_fisico")

var armadura_total: float:
	get:
		return maxf(0.0, _bono("armadura") + agilidad_total * AGILIDAD_POR_ARMADURA)

var mitigacion_fisica: float:
	get:
		return clampf(
			fuerza_total * MITIGACION_FISICA_POR_FUERZA + armadura_total * ARMADURA_POR_PUNTO,
			0.0,
			MITIGACION_FISICA_MAXIMA
		)


# --- Derivados de Agilidad ------------------------------------------------

## Multiplicador de frecuencia de ataque (1.0 = ritmo base del arma).
var velocidad_ataque: float:
	get:
		return clampf(
			VEL_ATAQUE_BASE
			+ agilidad_total * VEL_ATAQUE_POR_AGI
			+ float(nivel - 1) * VEL_ATAQUE_POR_NIVEL
			+ _bono("velocidad_ataque"),
			VEL_ATAQUE_MIN,
			VEL_ATAQUE_MAX
		)

var probabilidad_critico: float:
	get:
		return clampf(
			CRITICO_BASE + agilidad_total * CRITICO_POR_AGI + _bono("critico"),
			0.0,
			CRITICO_MAXIMO
		)

var multiplicador_critico: float:
	get:
		return CRITICO_DANO_BASE + agilidad_total * CRITICO_DANO_POR_AGI + _bono("dano_critico")

var velocidad_movimiento: float:
	get:
		return clampf(
			VEL_MOV_BASE + agilidad_total * VEL_MOV_POR_AGI + _bono("velocidad_movimiento"),
			VEL_MOV_MIN,
			VEL_MOV_MAX
		)


# --- Derivados de Inteligencia -------------------------------------------

var mana_maximo: float:
	get:
		return MANA_BASE + inteligencia_total * MANA_POR_INT + _bono("mana")

var regeneracion_mana: float:
	get:
		return REGEN_MANA_BASE + inteligencia_total * REGEN_MANA_POR_INT + _bono("regeneracion_mana")

var bono_dano_magico: float:
	get:
		return inteligencia_total * DANO_MAGICO_POR_INT + _bono("dano_magico")

var mitigacion_magica: float:
	get:
		return clampf(inteligencia_total * MITIGACION_MAGICA_POR_INT, 0.0, MITIGACION_MAGICA_MAXIMA)

## Porcentaje (0..1) del poder del héroe que hereda una invocación.
var herencia_invocaciones: float:
	get:
		return clampf(
			HERENCIA_INVOCACION_BASE + inteligencia_total * HERENCIA_INVOCACION_POR_INT,
			0.0,
			HERENCIA_INVOCACION_MAXIMA
		)

## Fracción del daño físico infligido que vuelve como vida (ítems).
var robo_vida: float:
	get:
		return clampf(_bono("robo_vida"), 0.0, 0.35)


# --- API ------------------------------------------------------------------

## Total del atributo por su nombre canónico (&"fuerza", &"agilidad",
## &"inteligencia"). Cualquier valor desconocido cae en Fuerza.
func atributo_total(atributo: StringName) -> int:
	match atributo:
		&"agilidad":
			return agilidad_total
		&"inteligencia":
			return inteligencia_total
		_:
			return fuerza_total


## Daño medio del ataque automático: base del arma + atributo principal,
## escalado por nivel y por la clase equipada. Única fórmula del ataque básico.
func escalar_ataque_principal(dano_base: float, atributo: StringName) -> float:
	var base := dano_base + float(atributo_total(atributo)) * DANO_ATAQUE_POR_ATRIBUTO
	base *= 1.0 + float(nivel - 1) * DANO_ESCALA_POR_NIVEL
	base *= float(MULT_DANO_POR_CLASE.get(clase, 1.0))
	return base


## Rango de daño del golpe básico (mínimo y máximo) alrededor de la media.
## El controlador tira `randf_range(x, y)` en cada ataque.
func rango_dano_ataque(dano_base: float, atributo: StringName) -> Vector2:
	var medio := escalar_ataque_principal(dano_base, atributo)
	return Vector2(
		maxf(1.0, round(medio * (1.0 - DANO_VARIANZA))),
		maxf(2.0, round(medio * (1.0 + DANO_VARIANZA)))
	)


## Fija la curva de crecimiento de la clase equipada. Se llama al equipar.
func configurar_clase(nueva_clase: StringName) -> void:
	clase = nueva_clase
	_crecimiento = CRECIMIENTO_POR_CLASE.get(nueva_clase, CRECIMIENTO_POR_CLASE[&"prisionero"])
	_resto_crecimiento = Vector3.ZERO


## Aplica el crecimiento de un nivel, acumulando las fracciones pendientes.
func _aplicar_crecimiento_nivel() -> void:
	_resto_crecimiento += _crecimiento
	var ganancia_fuerza := int(floor(_resto_crecimiento.x))
	var ganancia_agilidad := int(floor(_resto_crecimiento.y))
	var ganancia_inteligencia := int(floor(_resto_crecimiento.z))
	fuerza += ganancia_fuerza
	agilidad += ganancia_agilidad
	inteligencia += ganancia_inteligencia
	_resto_crecimiento.x -= ganancia_fuerza
	_resto_crecimiento.y -= ganancia_agilidad
	_resto_crecimiento.z -= ganancia_inteligencia


## Aplica daño plano a una habilidad según su tipo. El crítico lo resuelve
## quien ataca, no este recurso.
func escalar_dano(dano_base: float, tipo_dano: StringName = TIPO_FISICO) -> float:
	match tipo_dano:
		TIPO_FISICO:
			return dano_base + bono_dano_fisico
		TIPO_MAGICO:
			return dano_base + bono_dano_magico
		_:
			return dano_base


## Escala una estadística de una invocación (vida, daño, radio...) en función
## de la INT del héroe. Ej.: un espíritu con 100 de vida base y INT 50 hereda
## 100 * (1 + 0.25) = 125.
func escalar_invocacion(valor_base: float) -> float:
	return valor_base * (1.0 + inteligencia_total * herencia_invocaciones)


## Gasta un punto libre. Devuelve false si no quedan puntos o el atributo no
## existe.
func gastar_punto(atributo: StringName) -> bool:
	if puntos_libres <= 0:
		return false
	match atributo:
		&"fuerza":
			fuerza += 1
		&"agilidad":
			agilidad += 1
		&"inteligencia":
			inteligencia += 1
		_:
			return false
	puntos_libres -= 1
	atributos_cambiados.emit()
	return true


func otorgar_puntos(cantidad: int) -> void:
	if cantidad <= 0:
		return
	puntos_libres += cantidad
	atributos_cambiados.emit()


# --- Experiencia y niveles ------------------------------------------------

var experiencia_requerida: int:
	get:
		return CurvaNivel.xp_requerida(nivel)

var experiencia_faltante: int:
	get:
		if nivel >= CurvaNivel.NIVEL_MAXIMO:
			return 0
		return max(0, experiencia_requerida - experiencia)


## Añade XP y devuelve cuántos niveles se ganaron. El controlador se encarga
## de desbloquear habilidades y de avisar a la UI mediante `nivel_subido`.
func otorgar_experiencia(cantidad: int) -> int:
	if cantidad <= 0:
		return 0
	if nivel >= CurvaNivel.NIVEL_MAXIMO:
		experiencia_excedente += cantidad
		experiencia_cambiada.emit(0, 0, nivel)
		return 0

	var subidas := 0
	experiencia += cantidad
	while nivel < CurvaNivel.NIVEL_MAXIMO and experiencia >= experiencia_requerida:
		experiencia -= experiencia_requerida
		nivel += 1
		subidas += 1
		puntos_libres += 1
		_aplicar_crecimiento_nivel()
		nivel_subido.emit(nivel)

	# Al llegar al máximo, lo que sobre pasa al fondo de oro.
	if nivel >= CurvaNivel.NIVEL_MAXIMO and experiencia > 0:
		experiencia_excedente += experiencia
		experiencia = 0

	atributos_cambiados.emit()
	experiencia_cambiada.emit(experiencia, experiencia_requerida, nivel)
	return subidas


func reclamar_excedente() -> int:
	var cantidad := experiencia_excedente
	experiencia_excedente = 0
	return cantidad


## Sustituye los bonos del arma equipada. Se llama al equipar y al desequipar.
func aplicar_bonos_equipo(bonos: Dictionary) -> void:
	_bonos_equipo = bonos.duplicate(true)
	atributos_cambiados.emit()


## Sustituye los bonos agregados del inventario (6 ranuras).
func aplicar_bonos_inventario(bonos: Dictionary) -> void:
	_bonos_inventario = bonos.duplicate(true)
	atributos_cambiados.emit()


func quitar_bonos_equipo() -> void:
	aplicar_bonos_equipo({})
