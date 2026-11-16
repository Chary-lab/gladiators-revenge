class_name EnemyData
extends Resource
## Datos data-driven de un arquetipo de enemigo. No sustituye las tablas
## heredadas: las extiende. `arquetipo_base` elige la fila existente de
## `ArenaEnemy.ARQUETIPOS`/`VISUALES` para el modelo y las estadísticas base, y
## este recurso aplica multiplicadores y el rol de comportamiento.

enum Rol { MELEE, CHARGER, RANGED, TANK }

@export var id: StringName = &""
@export var nombre := ""
@export var rol: Rol = Rol.MELEE
## Uno de los nueve ids ya existentes: esqueleto, espectro, arquero, hechicero,
## tanque, elite, sabueso, bruto o nigromante.
@export var arquetipo_base: StringName = &"esqueleto"
@export var vida_mult := 1.0
@export var dano_mult := 1.0
@export var velocidad_mult := 1.0
@export var cadencia_mult := 1.0
@export var escala_mult := 1.0
@export var recompensa_mult := 1.0
## Cada cuántos segundos el cargador hace su embestida (0 desactiva el rol).
@export var periodo_carga := 0.0
@export var multiplicador_carga := 2.4
@export var duracion_carga := 0.35
