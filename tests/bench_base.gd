extends SceneTree
## Coste base del bucle vacío: sirve de referencia para saber cuánto de los
## milisegundos por fotograma es motor y cuánto es del juego.

const FRAMES := 240


func _initialize() -> void:
	await process_frame
	var inicio := Time.get_ticks_usec()
	for i in FRAMES:
		await process_frame
	var segundos := float(Time.get_ticks_usec() - inicio) / 1000000.0
	print("BASE frames=%d fps=%.0f ms_por_frame=%.2f" % [
		FRAMES, FRAMES / maxf(segundos, 0.001), segundos / FRAMES * 1000.0
	])
	quit(0)
