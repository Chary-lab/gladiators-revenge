extends SceneTree
## Banco de pruebas de rendimiento (CPU, headless).
##
##   godot --headless --script res://tests/bench.gd
##
## Fase de catálogos + cuatro fases de oleada apagando sistemas uno a uno (HUD,
## barras de enemigo) para localizar quién se come el fotograma. Mide
## `TIME_PROCESS` y `TIME_PHYSICS_PROCESS` (media y pico) y los fps de pared.

const FRAMES := 120
const ENEMIGOS := 30


func _initialize() -> void:
	await process_frame

	var t0 := Time.get_ticks_usec()
	for i in 20:
		WeaponItem.crear_catalogo_base()
	var armas_ms := float(Time.get_ticks_usec() - t0) / 20000.0
	t0 = Time.get_ticks_usec()
	for i in 100:
		ItemCatalog.vendibles()
		ItemCatalog.recetas()
	var objetos_ms := float(Time.get_ticks_usec() - t0) / 200000.0
	print("CATALOGO armas_ms=%.3f objetos_ms=%.3f" % [armas_ms, objetos_ms])

	var escena: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(escena)
	await process_frame
	await process_frame
	escena.call("_al_elegir_campeon", &"bastion")
	await process_frame

	await _medir("A_sin_oleada")

	var oleadas = escena.get("_oleadas")
	oleadas.call("aplicar_estado_red", 9, ENEMIGOS, 2, 0.1)
	for i in ENEMIGOS:
		oleadas.call("_invocar_enemigo")
	await _medir("B_oleada")

	var hud = escena.get("_hud")
	if hud != null:
		(hud as CanvasLayer).visible = false
		hud.set_process(false)
		hud.set_process_unhandled_input(false)
	await _medir("C_sin_hud")

	for nodo in get_nodes_in_group("enemigos"):
		var enemigo := nodo as ArenaEnemy
		if enemigo != null:
			enemigo.set_process(false)
	await _medir("D_sin_barras")

	print("NODOS=%d OBJETOS=%d" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
	])
	quit(0)


func _medir(fase: String) -> void:
	var suma_p := 0.0
	var pico_p := 0.0
	var suma_f := 0.0
	var inicio := Time.get_ticks_usec()
	for i in FRAMES:
		await process_frame
		var proceso := float(Performance.get_monitor(Performance.TIME_PROCESS))
		var fisica := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
		suma_p += proceso
		suma_f += fisica
		pico_p = maxf(pico_p, proceso)
	var pared := float(Time.get_ticks_usec() - inicio) / 1000000.0
	print("%s proceso_ms=%.2f pico=%.2f fisica_ms=%.2f fps_pared=%.0f enemigos=%d" % [
		fase, suma_p / FRAMES * 1000.0, pico_p * 1000.0, suma_f / FRAMES * 1000.0,
		FRAMES / maxf(pared, 0.001), get_nodes_in_group("enemigos").size(),
	])
