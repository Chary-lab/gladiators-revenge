extends SceneTree
## Prueba de integración de red: un cliente real contra un servidor cooperativo.
##
## Uso:
##   godot --headless -- --servidor --puerto=9080 --red-rapida
##   godot --headless --script res://tests/net_smoke.gd -- --cliente=ws://127.0.0.1:9080

var _pruebas := 0
var _fallos := 0


func _comprobar(condicion: bool, texto: String) -> void:
	_pruebas += 1
	if condicion:
		print("  OK    ", texto)
	else:
		_fallos += 1
		printerr("  FALLO ", texto)


func _mantenerse_vivo(red) -> void:
	while true:
		red.enviar_accion(&"debug_curar", {})
		await create_timer(0.5).timeout


func _esperar_hasta(condicion: Callable, maximo := 600) -> bool:
	# En headless los fotogramas corren a miles por segundo: se espera 10 ms por
	# vuelta para que "maximo" sean ~maximo/100 segundos y no milisegundos.
	for i in maximo:
		if bool(condicion.call()):
			return true
		await create_timer(0.01).timeout
	return bool(condicion.call())


func _init() -> void:
	print("== Net smoke: cliente cooperativo ==")
	var escena: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(escena)
	await process_frame
	await process_frame

	var red = escena.get("red")
	var jugador = escena.get("_jugador")
	_comprobar(red != null and bool(escena.get("es_cliente")), "la arena arranca en modo cliente")
	_comprobar(escena.get("_log_snapshot") != null, "el cliente prepara la recepción de snapshots")
	_comprobar(
		await _esperar_hasta(func() -> bool: return red.estado == NetCoop.Estado.CONECTADO),
		"el cliente se conecta al servidor"
	)
	_comprobar(
		await _esperar_hasta(func() -> bool: return bool(escena.get("_log_snapshot"))),
		"llega el primer snapshot del servidor"
	)
	_comprobar(jugador != null and escena.get("_jugadores_remotos").has(red.peer_local), "el jugador local está registrado")

	# El cliente A es el "compañero vivo" de esta prueba: si muere, la partida
	# termina y el cliente B ya no puede probar el revivir. Se cura solo.
	_mantenerse_vivo(red)

	# Con --red-rapida las oleadas se suceden cada segundo y el portón devuelve al
	# jugador a la arena, donde la tienda está cerrada: se vuelve a la base (acción
	# de pruebas) y se compra en el mismo envío.
	red.enviar_accion(&"debug_base", {})
	red.enviar_accion(&"comprar", {"id": &"brasa_forja"})
	_comprobar(
		await _esperar_hasta(func() -> bool: return jugador.inventario != null and jugador.inventario.tiene(&"brasa_forja")),
		"la compra del mercader se sincroniza desde el servidor"
	)

	var posicion_inicial: Vector3 = jugador.global_position
	red.enviar_accion(&"mover", {"punto": Vector3(18.0, 0.0, 0.0)})
	await create_timer(2.5).timeout
	_comprobar(jugador.global_position.distance_to(posicion_inicial) > 0.4, "el servidor mueve al gladiador")

	red.enviar_clase(&"bastion")
	_comprobar(
		await _esperar_hasta(func() -> bool: return jugador.arma_actual != null and jugador.arma_actual.id_clase() == &"bastion"),
		"la clase Bastión llega desde el servidor"
	)

	red.enviar_clase(&"filo")
	await create_timer(0.6).timeout
	_comprobar(
		jugador.arma_actual.id_clase() == &"bastion",
		"un jugador no puede escoger una segunda clase"
	)

	_comprobar(
		await _esperar_hasta(func() -> bool: return escena.get("_enemigos_remotos").size() > 0, 900),
		"el cliente recibe enemigos de la oleada"
	)
	var oleada: int = escena.get("_oleadas").oleada_actual
	_comprobar(oleada >= 1, "la oleada avanza en red")

	var espera := 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--esperar="):
			espera = float(arg.substr("--esperar=".length()))
	if espera > 0.0:
		for i in int(espera):
			red.enviar_accion(&"debug_curar", {})
			await create_timer(1.0).timeout

	print("== %d pruebas, %d fallos ==" % [_pruebas, _fallos])
	Sfx.liberar()
	quit(1 if _fallos > 0 else 0)
