class_name AbilityData
extends Resource
## Datos de una habilidad activa (Q, W, E o R).
##
## No contiene lógica de combate: el kit se define como datos y la escena
## `escena_efecto` (u otro sistema suscrito a `habilidad_lanzada`) ejecuta el
## comportamiento. Así el arma puede sustituir el kit completo sin tocar código.

enum Tipo {
	IMPACTO,     ## Golpe instantáneo cuerpo a cuerpo.
	ZONA,        ## Área persistente en el suelo (estandartes, fuego, veneno).
	PROYECTIL,   ## Disparo con colisión (usar con Object Pooling).
	INVOCACION,  ## Invoca una criatura aliada.
	MOVILIDAD,   ## Dash, salto o reposicionamiento.
	APOYO,       ## Curación, escudo, provocación.
}

enum Objetivo {
	PROPIO,      ## Se lanza sobre el portador (autobuff, curación propia).
	SUELO,       ## Se lanza en el punto del ratón.
	ENEMIGO,     ## Requiere un enemigo seleccionado; si no hay, usa el suelo.
}

@export_group("Identidad")
@export var id: StringName = &""
@export var nombre: String = ""
@export_multiline var descripcion: String = ""
@export var icono: Texture2D

@export_group("Combate")
@export var tipo: Tipo = Tipo.IMPACTO
@export var objetivo: Objetivo = Objetivo.SUELO
@export var coste_mana: float = 20.0
@export var cooldown: float = 6.0
@export var dano_base: float = 0.0
@export var curacion_base: float = 0.0
@export var tipo_dano: StringName = &"fisico"
## Si es true, al impactar arrastra a los enemigos hacia el portador (taunt).
@export var provoca: bool = false
## Atributo que escala el daño de la habilidad (se lee desde GladiatorStats).
@export var atributo_escalado: StringName = &"fuerza"
@export var radio: float = 2.5
@export var duracion: float = 0.0
@export var escena_efecto: PackedScene

@export_group("Talentos de combate")
## Ranuras de mejora que se desbloquean con puntos rojos.
@export var talentos: Array[TalentData] = []
