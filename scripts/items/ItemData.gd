class_name ItemData
extends Resource
## Objeto de inventario/tienda. Los bonus usan las mismas claves que
## GladiatorStats._bonos_inventario; ninguna fórmula vive aquí.

enum Tipo { POCION, PERGAMINO, COMPONENTE, INTERMEDIO, LEGENDARIO }

@export var id: StringName = &""
@export var nombre := ""
@export var descripcion := ""
## Icono textual (sin fuentes externas): ❤ ✦ ⚔ etc. La UI lo dibuja grande.
@export var icono := "◆"
@export var tipo: Tipo = Tipo.COMPONENTE
@export var nivel := 1
@export var precio := 100
@export var precio_forja := 0
@export var bonificaciones: Dictionary = {}
@export var receta: Array[StringName] = []
@export var habilidad: AbilityData
@export var pasiva := ""
@export var consumible := false
@export var maximo_pila := 1
@export var curacion_vida := 0.0
@export var curacion_mana := 0.0
@export var efecto_especial: StringName = &""


func es_equipo() -> bool:
	return tipo in [Tipo.COMPONENTE, Tipo.INTERMEDIO, Tipo.LEGENDARIO]


func es_pocion() -> bool:
	return tipo == Tipo.POCION


func descripcion_bonos() -> String:
	var lineas: PackedStringArray = []
	for clave in bonificaciones:
		var valor := float(bonificaciones[clave])
		var texto := _nombre_bono(clave)
		if clave in [&"velocidad_ataque", &"critico", &"robo_vida"]:
			lineas.append("+%d %% %s" % [int(round(valor * 100.0)), texto])
		elif clave in [&"regeneracion", &"regeneracion_mana", &"velocidad_movimiento"]:
			lineas.append("+%.1f %s" % [valor, texto])
		else:
			lineas.append("+%d %s" % [int(round(valor)), texto])
	if not pasiva.is_empty():
		lineas.append(pasiva)
	return "\n".join(lineas)


func _nombre_bono(clave: StringName) -> String:
	match clave:
		&"fuerza": return "Fuerza"
		&"agilidad": return "Agilidad"
		&"inteligencia": return "Inteligencia"
		&"vida": return "Vida máxima"
		&"armadura": return "Armadura"
		&"dano_fisico": return "Daño físico"
		&"dano_magico": return "Daño mágico"
		&"critico": return "crítico"
		&"velocidad_ataque": return "velocidad de ataque"
		&"velocidad_movimiento": return "velocidad de movimiento"
		&"regeneracion": return "regeneración de vida"
		&"regeneracion_mana": return "regeneración de maná"
		&"mana": return "maná máximo"
		&"robo_vida": return "robo de vida"
	return String(clave)
