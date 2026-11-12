class_name BalanceOlas
extends RefCounted
## Perfiles de oleada: qué arquetipos de enemigo salen en cada ronda, cuántos y
## con qué multiplicadores de vida y daño.
##
## Fuente única de verdad del ritmo de dificultad: `WaveManager` solo consume
## estos datos y `ArenaEnemy` aplica los multiplicadores. Ajustar aquí, no en el
## gestor de oleadas.

const ESQUELETO := &"esqueleto"
const ESPECTRO := &"espectro"
const ARQUERO := &"arquero"
const HECHICERO := &"hechicero"
const TANQUE := &"tanque"
const ELITE := &"elite"

const TIPOS_VALIDOS: Array[StringName] = [ESQUELETO, ESPECTRO, ARQUERO, HECHICERO, TANQUE, ELITE]

## Perfiles por número de oleada (1..20). `tipos` son pesos relativos de
## aparición; `vida` y `dano` multiplican las estadísticas base del enemigo.
## `jefe` elige el jefe de la ronda: &"", &"caballero" o &"liche".
const PERFILES := [
	{"titulo": "Esqueletos", "tipos": {ESQUELETO: 1.0}, "vida": 1.0, "dano": 1.0, "jefe": &""},
	{"titulo": "Espectros", "tipos": {ESPECTRO: 1.0}, "vida": 1.0, "dano": 1.0, "jefe": &""},
	{"titulo": "Lluvia de flechas", "tipos": {ARQUERO: 0.6, ESQUELETO: 0.4}, "vida": 1.0, "dano": 1.0, "jefe": &""},
	{"titulo": "Círculo de magos", "tipos": {HECHICERO: 0.7, ESQUELETO: 0.3}, "vida": 1.0, "dano": 1.0, "jefe": &""},
	{"titulo": "El Campeón del Imperio", "tipos": {ESQUELETO: 1.0}, "vida": 1.05, "dano": 1.0, "jefe": &"caballero"},
	{"titulo": "Muro de bárbaros", "tipos": {TANQUE: 0.6, ESQUELETO: 0.4}, "vida": 1.05, "dano": 1.0, "jefe": &""},
	{"titulo": "Hostigadores", "tipos": {ESPECTRO: 0.5, ARQUERO: 0.5}, "vida": 1.0, "dano": 1.05, "jefe": &""},
	{"titulo": "Magos y huesos", "tipos": {HECHICERO: 0.5, ESQUELETO: 0.5}, "vida": 1.05, "dano": 1.05, "jefe": &""},
	{"titulo": "Asedio mixto", "tipos": {TANQUE: 0.35, ARQUERO: 0.35, ESPECTRO: 0.3}, "vida": 1.1, "dano": 1.1, "jefe": &""},
	{"titulo": "El Liche de la Arena", "tipos": {HECHICERO: 0.6, ESQUELETO: 0.4}, "vida": 1.1, "dano": 1.1, "jefe": &"liche"},
	{"titulo": "Falange imperial", "tipos": {TANQUE: 0.5, ARQUERO: 0.3, ESQUELETO: 0.2}, "vida": 1.1, "dano": 1.1, "jefe": &""},
	{"titulo": "Vendaval de espectros", "tipos": {ESPECTRO: 0.7, ARQUERO: 0.3}, "vida": 1.1, "dano": 1.15, "jefe": &""},
	{"titulo": "Concilio oscuro", "tipos": {HECHICERO: 0.8, TANQUE: 0.2}, "vida": 1.15, "dano": 1.15, "jefe": &""},
	{"titulo": "Sangre y acero", "tipos": {TANQUE: 0.3, ESPECTRO: 0.3, ARQUERO: 0.2, HECHICERO: 0.2}, "vida": 1.15, "dano": 1.2, "jefe": &""},
	{"titulo": "La guardia pretoriana", "tipos": {ELITE: 0.25, ESQUELETO: 0.75}, "vida": 1.15, "dano": 1.15, "jefe": &"caballero"},
	{"titulo": "Bárbaros y magos", "tipos": {TANQUE: 0.5, HECHICERO: 0.5}, "vida": 1.2, "dano": 1.2, "jefe": &""},
	{"titulo": "Flechas sin fin", "tipos": {ARQUERO: 0.8, ESPECTRO: 0.2}, "vida": 1.2, "dano": 1.2, "jefe": &""},
	{"titulo": "El asedio final", "tipos": {TANQUE: 0.3, ARQUERO: 0.3, HECHICERO: 0.2, ESPECTRO: 0.2}, "vida": 1.25, "dano": 1.25, "jefe": &""},
	{"titulo": "Última muralla", "tipos": {TANQUE: 0.35, ELITE: 0.2, ARQUERO: 0.25, HECHICERO: 0.2}, "vida": 1.3, "dano": 1.3, "jefe": &""},
	{"titulo": "El Emperador de Hierro", "tipos": {TANQUE: 0.3, ESPECTRO: 0.3, ARQUERO: 0.2, HECHICERO: 0.2}, "vida": 1.35, "dano": 1.35, "jefe": &"liche"},
]


## Perfil de una oleada concreta. Siempre devuelve un diccionario válido: las
## oleadas fuera de rango reutilizan el último perfil.
static func perfil(oleada: int) -> Dictionary:
	var indice := clampi(oleada - 1, 0, PERFILES.size() - 1)
	var datos: Dictionary = PERFILES[indice]
	var copia := datos.duplicate(true)
	copia["numero"] = oleada
	copia["cantidad"] = cantidad(oleada)
	return copia


## Enemigos que salen en la oleada. Crece de 16 a 88 enemigos: con arquetipos
## más duros no hace falta inundar la arena.
static func cantidad(oleada: int) -> int:
	return 14 + int(round(float(oleada) * 3.0))


## Elige un arquetipo según los pesos del perfil.
static func elegir_tipo(datos: Dictionary, rng: RandomNumberGenerator = null) -> StringName:
	var tipos: Dictionary = datos.get("tipos", {ESQUELETO: 1.0})
	var total := 0.0
	for clave in tipos:
		total += float(tipos[clave])
	if total <= 0.0:
		return ESQUELETO
	var tirada := (rng.randf() if rng != null else randf()) * total
	for clave in tipos:
		tirada -= float(tipos[clave])
		if tirada <= 0.0:
			return clave
	return tipos.keys()[tipos.size() - 1]
