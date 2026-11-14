extends SceneTree
## Mide cuánto cuesta reconstruir la tienda (lo que hoy paga cada compra y cada
## cambio de modo). Si sale caro, el siguiente paso es refrescar en sitio.

func _initialize() -> void:
	await process_frame
	var escena: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(escena)
	await process_frame
	await process_frame
	escena.call("_al_elegir_campeon", &"bastion")
	var hud = escena.get("_hud")
	hud.call("alternar_tienda")
	await process_frame
	await process_frame
	var panel = hud.get("_tienda")
	if panel == null:
		print("TIENDA sin panel")
		quit(1)
		return

	var t0 := Time.get_ticks_usec()
	for i in 20:
		panel.call("_reconstruir")
	var reconstruir_ms := float(Time.get_ticks_usec() - t0) / 20000.0

	var grids: Array = panel.get("_cuadriculas")
	var tarjetas := 0
	for grid in grids:
		tarjetas += (grid as GridContainer).get_child_count()

	t0 = Time.get_ticks_usec()
	for i in 1000:
		panel.call("_actualizar_ficha")
	var ficha_us := float(Time.get_ticks_usec() - t0) / 1000.0

	t0 = Time.get_ticks_usec()
	for i in 200:
		panel.call("_refrescar")
	var refrescar_ms := float(Time.get_ticks_usec() - t0) / 200000.0

	print("TIENDA tarjetas=%d reconstruir_ms=%.2f refrescar_ms=%.3f ficha_us=%.2f" % [
		tarjetas, reconstruir_ms, refrescar_ms, ficha_us
	])
	quit(0)
