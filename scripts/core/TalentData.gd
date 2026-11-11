class_name TalentData
extends Resource
## Mejora desbloqueable de una habilidad concreta.
##
## `modificadores` es un diccionario abierto que el efecto de la habilidad
## interpreta. Convención acordada:
##   &"radio"        -> float, suma metros al radio
##   &"duracion"     -> float, suma segundos
##   &"dano"         -> float, suma daño plano
##   &"dano_fuego"   -> float, añade daño de fuego a quien pise la zona
##   &"coste_mana"   -> float, reduce el coste (valor negativo)

@export var id: StringName = &""
@export var nombre: String = ""
@export_multiline var descripcion: String = ""
@export_range(1, 5, 1) var rango_maximo: int = 1
@export_range(1, 50, 1) var coste_puntos_rojos: int = 3
## Talento que debe estar desbloqueado antes que este (vacío = sin requisito).
@export var talento_requerido: StringName = &""
@export var modificadores: Dictionary = {}
