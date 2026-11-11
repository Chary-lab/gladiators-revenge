class_name CurvaNivel
extends RefCounted
## Fuente única de verdad para la progresión de nivel y la experiencia.
##
## La XP de cada oleada se calcula con una curva cuadrática y se reparte entre
## los enemigos según su peso. Así una oleada nunca concede tres niveles, aunque
## el jugador elimine a todos los enemigos seguidos.

const NIVEL_MAXIMO := 20
const PESO_NORMAL := 1.0
const PESO_ELITE := 2.5
const PESO_JEFE := 8.0


## Experiencia necesaria para pasar de `nivel` al siguiente.
static func xp_requerida(nivel: int) -> int:
	if nivel < 1 or nivel >= NIVEL_MAXIMO:
		return 0
	return 80 + 40 * nivel + 6 * nivel * nivel


## Presupuesto total de experiencia de una oleada.
static func xp_oleada(oleada: int) -> int:
	if oleada < 1:
		return 0
	return 80 + 55 * oleada + 4 * oleada * oleada


## XP individual de un enemigo dentro del presupuesto de la oleada.
## `peso_total` incluye a todos los enemigos generados en esa oleada.
static func xp_enemigo(presupuesto: int, peso: float, peso_total: float) -> int:
	if presupuesto <= 0 or peso <= 0.0 or peso_total <= 0.0:
		return 0
	return maxi(1, int(round(float(presupuesto) * peso / peso_total)))


## Nivel que se alcanza al acumular `experiencia` partiendo de nivel 1.
static func nivel_por_experiencia(experiencia: int) -> int:
	var nivel := 1
	var resto := maxi(0, experiencia)
	while nivel < NIVEL_MAXIMO:
		var necesaria := xp_requerida(nivel)
		if necesaria <= 0 or resto < necesaria:
			break
		resto -= necesaria
		nivel += 1
	return nivel


## Comprueba la sincronía de la curva: devuelve el nivel al terminar cada
## oleada. Se usa en pruebas y para validar ajustes de balance.
static func simular_niveles(hasta: int = NIVEL_MAXIMO) -> Array[int]:
	var niveles: Array[int] = []
	var nivel := 1
	var xp := 0
	for oleada in range(1, hasta + 1):
		xp += xp_oleada(oleada)
		while nivel < NIVEL_MAXIMO and xp >= xp_requerida(nivel):
			xp -= xp_requerida(nivel)
			nivel += 1
		niveles.append(nivel)
	return niveles
