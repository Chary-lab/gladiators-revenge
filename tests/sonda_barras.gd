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
		var relleno := enemigo.get("_barra_relleno") as MeshInstance3D
		var ancho := relleno.scale.x if relleno != null else -1.0
		# Con la vida al 25 % el ancho debe ser una cuarta parte del total.
		enemigo.salud_actual = enemigo.salud_maxima * 0.25
		enemigo.call("_actualizar_barra_vida")
		var ancho_bajo := relleno.scale.x if relleno != null else -1.0
		if barra == null:
			print("%s: SIN BARRA" % tipo)
		else:
			print("%s: visible=%s alto_mundo=%.2f ancho_55%%=%.2f ancho_25%%=%.2f" % [
				tipo, barra.visible, alto * escala, ancho, ancho_bajo
			])
		enemigo.queue_free()
	quit(0)
