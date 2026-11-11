extends SceneTree
## Simulación acelerada: recorre las 20 oleadas matando enemigos al instante
## para comprobar el cierre de rondas, la aparición de jefes y la victoria.

var victoria := false
var oleadas_vistas := 0
var oleadas_con_jefe: Array[int] = []


func _init() -> void:
	Engine.time_scale = 8.0
	var escena: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(escena)
	await process_frame

	var oleadas := escena.get("_oleadas") as WaveManager
	oleadas.espera_inicial = 0.15
	oleadas.espera_entre_oleadas = 0.2
	oleadas.duracion_entrada = 0.05
	oleadas.intervalo_spawn = 0.01
	oleadas.oleada_iniciada.connect(func(numero: int, _total: int) -> void:
		oleadas_vistas = numero
	)
	oleadas.victoria.connect(func() -> void:
		victoria = true
	)

	var fotogramas := 0
	while not victoria and fotogramas < 40000:
		await process_frame
		fotogramas += 1
		for nodo in get_nodes_in_group("enemigos"):
			if nodo is ArenaBossAI:
				var numero := oleadas.oleada_actual
				if not oleadas_con_jefe.has(numero):
					oleadas_con_jefe.append(numero)
			if nodo.has_method("recibir_dano"):
				nodo.recibir_dano(999999.0, GladiatorStats.TIPO_VERDADERO, null)

	Engine.time_scale = 1.0
	var exitos := 0
	exitos += _comprobar(oleadas_vistas == 20, "se alcanza la oleada 20 (vista: %d)" % oleadas_vistas)
	exitos += _comprobar(victoria, "la partida termina en victoria")
	exitos += _comprobar(oleadas_con_jefe == [5, 10, 15, 20], "hay jefe en las oleadas 5, 10, 15 y 20: %s" % [oleadas_con_jefe])
	print("== %d comprobaciones, %d fallos ==" % [3, 3 - exitos])
	quit(0 if exitos == 3 else 1)


func _comprobar(condicion: bool, texto: String) -> int:
	print(("  OK    " if condicion else "  FALLO ") + texto)
	return 1 if condicion else 0
