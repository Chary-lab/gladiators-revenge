class_name Legado
extends RefCounted
## Legado de Renegados: renombre acumulado durante una partida que otorga
## grados narrativos. Sistema original y puramente cosmético/narrativo: se
## alimenta de estado YA sincronizado (oleada terminada, bajas), así que cada
## cliente calcula lo mismo sin claves nuevas en el snapshot ni autoridad de
## red. No modifica daño, curación ni recompensas (AGENTS.md:56, 64).

## Renombre por oleada terminada y por baja. Números separados del balance
## de oro/XP para no tocar BalanceOlas ni GladiatorStats.
const RENOMBRE_OLEADA := 12
const RENOMBRE_BAJA := 1

## Umbrales y títulos, de menor a mayor. Nombres propios en español, sin
## caracteres tofu (AGENTS.md:145).
const GRADOS := [
	{"umbral": 0, "id": &"aspirante", "titulo": "Aspirante de la arena"},
	{"umbral": 40, "id": &"renegado", "titulo": "Renegado del foso"},
	{"umbral": 100, "id": "veterano", "titulo": "Veterano de la rebelión"},
	{"umbral": 200, "id": &"campeon", "titulo": "Campeón de ceniza"},
	{"umbral": 340, "id": &"inmortal", "titulo": "Inmortal del Legado"},
]

var renombre := 0
var grado: StringName = &"aspirante"


## Renombre que producen `oleada` oleadas terminadas y `bajas` abatidos.
## Estática y determinista: la usan los tests y el propio registro.
static func renombre_por(oleada: int, bajas: int) -> int:
	return maxi(0, oleada) * RENOMBRE_OLEADA + maxi(0, bajas) * RENOMBRE_BAJA


## Grado correspondiente a un renombre dado (el mayor umbral alcanzado).
static func grado_por(cantidad: int) -> StringName:
	var resultado: StringName = &"aspirante"
	for g in GRADOS:
		if cantidad >= int(g["umbral"]):
			resultado = StringName(g["id"])
	return resultado


static func titulo_de(grado_id: StringName) -> String:
	for g in GRADOS:
		if StringName(g["id"]) == grado_id:
			return str(g["titulo"])
	return ""


func registrar_oleada(numero: int) -> void:
	_sumar(renombre_por(numero, 0))


func registrar_bajas(cantidad: int) -> void:
	_sumar(renombre_por(0, cantidad))


func _sumar(cantidad: int) -> void:
	renombre += maxi(0, cantidad)
	grado = grado_por(renombre)


## Recalcula el renombre desde totales ya sincronizados. En co-op el cliente
## no corre WaveManager, así que deriva el Legado de `oleada`/`bajas` del
## snapshot; el resultado es idéntico al del servidor (AGENTS.md:64).
func sincronizar(oleada: int, bajas: int) -> void:
	renombre = renombre_por(oleada, bajas)
	grado = grado_por(renombre)


## Renombre y título actuales, para el HUD.
func estado() -> Dictionary:
	return {"renombre": renombre, "grado": grado, "titulo": titulo_de(grado)}
