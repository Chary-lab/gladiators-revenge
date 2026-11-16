class_name SpawnPlan
extends Resource
## Parámetros del spawner de oleadas. Separarlos de `WaveManager` permite
## ajustar ritmo y mezcla de roles sin tocar código ni alterar `BalanceOlas`.

@export var intervalo_spawn := 0.80
@export var tamano_lote := 1
@export var probabilidad_elite_base := 0.06
@export var probabilidad_elite_por_oleada := 0.06
@export var probabilidad_elite_maxima := 0.35
## Probabilidad de que un enemigo use un `EnemyData` de los cuatro roles en
## vez de un arquetipo clásico. 0 deja la curva original intacta.
@export var probabilidad_data := 0.20
