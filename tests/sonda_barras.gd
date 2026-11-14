extends SceneTree
## Sonda de la barra de vida: crea un enemigo de cada arquetipo nuevo, lo deja al
## 55 % y comprueba que la barra existe, está visible y queda por encima del
## modelo (no dentro de la cabeza del bruto).

func _initialize() -> void:
	await process_frame
	for tipo in [&"sabueso", &"bruto", &"nigromante", &"esqueleto", &"elite"]:
		var enemigo := ArenaEnemy.crear()
		root.add_child(enemigo)
		enemigo.global_position = Vector3.ZERO
		enemigo.preparar(12, tipo == &"elite", null, null, null, null, 0, tipo, 1.0, 1.0)
		enemigo.set_physics_process(false)
		enemigo.salud_actual = enemigo.salud_maxima * 0.55
		enemigo.call("_actualizar_barra_vida")
		enemigo.call("_sincronizar_barra")
		var barra: Node3D = enemigo.get("_barra_raiz")
		var alto := float(enemigo.get("_alto_barra"))
		var escala := float(enemigo.get("_escala_base"))
		if barra == null:
			print("%s: SIN BARRA" % tipo)
		else:
			print("%s: visible=%s alto_local=%.2f mundo=%.2f escala=%.2f" % [
				tipo, barra.visible, alto, alto * escala, escala
			])
		enemigo.queue_free()
	quit(0)
