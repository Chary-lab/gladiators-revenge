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

const TIPO_FISICO := &"fisico"
const TIPO_MAGICO := &"magico"
const TIPO_VERDADERO := &"verdadero"

# --- Fuerza ---------------------------------------------------------------
const VIDA_BASE := 120.0
const VIDA_POR_FUERZA := 11.0
const REGEN_VIDA_BASE := 0.4
const REGEN_VIDA_POR_FUERZA := 0.06
const DANO_FISICO_POR_FUERZA := 1.6
const MITIGACION_FISICA_POR_FUERZA := 0.0035
const ARMADURA_POR_PUNTO := 0.004
const MITIGACION_FISICA_MAXIMA := 0.60

# --- Agilidad -------------------------------------------------------------
const VEL_ATAQUE_BASE := 0.85
const VEL_ATAQUE_POR_AGI := 0.012
const VEL_ATAQUE_MIN := 0.60
const VEL_ATAQUE_MAX := 2.50
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
const MANA_BASE := 80.0
const MANA_POR_INT := 9.0
const REGEN_MANA_BASE := 1.2
const REGEN_MANA_POR_INT := 0.09
const DANO_MAGICO_POR_INT := 1.8
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
@export_range(1, 100, 1) var nivel: int = 1

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
		return maxf(0.0, _bono("armadura"))

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
			VEL_ATAQUE_BASE + agilidad_total * VEL_ATAQUE_POR_AGI + _bono("velocidad_ataque"),
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
