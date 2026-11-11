extends SceneTree
## Segundo cliente de la prueba cooperativa: valida que dos personas no puedan
## repetir clase y que ambas aparezcan en la misma arena.
##
## Uso (con un cliente A conectado y esperando):
##   godot --headless --script res://tests/net_smoke_b.gd -- --cliente=ws://127.0.0.1:9080

var _pruebas := 0
var _fallos := 0


func _comprobar(condicion: bool, texto: String) -> void:
	_pruebas += 1
	if condicion:
		print("  OK    ", texto)
	else:
		_fallos += 1
		printerr("  FALLO ", texto)


func _esperar_hasta(condicion: Callable, maximo := 600) -> bool:
	for i in maximo:
		if bool(condicion.call()):
			return true
		await process_frame
	return bool(condicion.call())


func _init() -> void:
	print("== Net smoke B: segundo cliente ==")
	var escena: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(escena)
	await process_frame
	await process_frame

	var red = escena.get("red")
	var jugador = escena.get("_jugador")
	_comprobar(
		await _esperar_hasta(func() -> bool: return red.estado == NetCoop.Estado.CONECTADO),
		"el segundo cliente se conecta"
	)
	_comprobar(
		await _esperar_hasta(func() -> bool: return escena.get("_log_snapshot") != null),
		"el segundo cliente recibe estado"
	)
	_comprobar(
		await _esperar_hasta(func() -> bool: return red.clases_ocupadas.has(&"bastion")),
		"el lobby muestra la clase Bastión ocupada por el primer jugador"
	)

	red.enviar_clase(&"bastion")
	await create_timer(0.8).timeout
	_comprobar(
		jugador.arma_actual == null or jugador.arma_actual.id_clase() != &"bastion",
		"un segundo jugador no puede repetir el Bastión"
	)

	red.enviar_clase(&"filo")
	var clase_ok := false
	for i in 300:
		if jugador.arma_actual != null and jugador.arma_actual.id_clase() == &"filo":
			clase_ok = true
			break
		await process_frame
	_comprobar(clase_ok, "el segundo jugador recibe su clase Filo")

	_comprobar(
		await _esperar_hasta(func() -> bool: return escena.get("_jugadores_remotos").size() >= 2, 600),
		"los dos jugadores coexisten en la arena"
	)

	var clases := {}
	for id in escena.get("_jugadores_remotos").keys():
		var cuerpo = escena.get("_jugadores_remotos")[id]
		if cuerpo != null and cuerpo.arma_actual != null:
			clases[cuerpo.arma_actual.id_clase()] = true
	_comprobar(clases.has(&"bastion") and clases.has(&"filo"), "la partida tiene dos clases distintas")

	print("== %d pruebas, %d fallos ==" % [_pruebas, _fallos])
	Sfx.liberar()
	quit(1 if _fallos > 0 else 0)
