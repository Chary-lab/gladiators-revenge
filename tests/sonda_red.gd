extends SceneTree
## Sonda temporal de latencia. Mide, contra un servidor real:
##   1. cadencia y tamaño de los snapshots,
##   2. retardo entrada -> servidor -> snapshot, con un giro de 180°: se ordena
##      caminar al punto opuesto y se cronometra hasta que el snapshot muestra
##      movimiento hacia el destino nuevo (no hay ambigüedad con el movimiento
##      anterior, que iba en sentido contrario).
##
## Uso:
##   godot --headless --script res://tests/sonda_red.gd -- --cliente=ws://127.0.0.1:9099 --segundos=30
##   godot --headless --script res://tests/sonda_red.gd -- --cliente=wss://…/sala/1 --segundos=30

const DESTINOS := [Vector3(6, 0, 6), Vector3(-6, 0, -6)]

var _url := ""
var _segundos := 30.0
var _red: NetCoop
var _intervalos: Array = []
var _tamanos: Array = []
var _ultimo_us := 0
var _pos := Vector3.ZERO
var _pos_prev := Vector3.ZERO
var _pos_valida := false
var _enemigos := 0
var _max_enemigos := 0
var _inicio := 0
var _latencias: Array = []
var _espera_hasta := 0
var _objetivo := 0
var _fase := "listo"      # listo | esperando | enfriando
var _t_envio := 0
var _dir_nueva := Vector3.ZERO
var _t_conexion := 0
var _ms_handshake := -1.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cliente="):
			_url = arg.substr("--cliente=".length())
		elif arg.begins_with("--segundos="):
			_segundos = float(arg.substr("--segundos=".length()))
	if _url.is_empty():
		printerr("falta --cliente=")
		quit(2)
		return

	_red = NetCoop.new()
	_red.name = "SondaNet"
	get_root().add_child(_red)
	_red.snapshot_recibido.connect(_al_snapshot)
	_red.bienvenida.connect(func(_id: int) -> void:
		_ms_handshake = float(Time.get_ticks_usec() - _t_conexion) / 1000.0
	)
	_t_conexion = Time.get_ticks_usec()
	_red.unirse(_url)
	_inicio = Time.get_ticks_msec()
	print("== Sonda de red: %s ==" % _url)
	_ciclo()


func _ciclo() -> void:
	var fin := _inicio + int(_segundos * 1000.0)
	while Time.get_ticks_msec() < fin:
		if _red.estado == NetCoop.Estado.CONECTADO and _fase == "listo" \
				and _pos_valida and Time.get_ticks_msec() >= _espera_hasta:
			_enviar_giro()
		await create_timer(0.02).timeout
	_informar()


func _enviar_giro() -> void:
	_objetivo = 1 - _objetivo
	var destino: Vector3 = DESTINOS[_objetivo]
	_dir_nueva = (destino - _pos)
	_dir_nueva.y = 0.0
	if _dir_nueva.length() < 2.0:
		# Ya está encima del destino: se manda el otro y se reintenta después.
		_objetivo = 1 - _objetivo
		destino = DESTINOS[_objetivo]
		_dir_nueva = (destino - _pos)
		_dir_nueva.y = 0.0
	_dir_nueva = _dir_nueva.normalized()
	_t_envio = Time.get_ticks_usec()
	_fase = "esperando"
	_red.enviar_accion(&"mover", {"punto": destino})


func _al_snapshot(datos: Dictionary) -> void:
	var ahora := Time.get_ticks_usec()
	if _ultimo_us > 0:
		_intervalos.append(float(ahora - _ultimo_us) / 1000.0)
	_ultimo_us = ahora
	_tamanos.append(var_to_bytes(datos).size())

	var filas: Array = datos.get("jugadores", [])
	_enemigos = datos.get("enemigos", []).size() + datos.get("jefes", []).size()
	_max_enemigos = maxi(_max_enemigos, _enemigos)
	if filas.is_empty():
		return

	_pos = filas[0].get("pos", _pos)
	if not _pos_valida:
		_pos_prev = _pos
		_pos_valida = true
		return

	var delta_pos: Vector3 = _pos - _pos_prev
	_pos_prev = _pos
	var pasos := delta_pos.length()
	if _fase == "esperando" and pasos > 0.12:
		# Se mueve de verdad: ¿hacia el destino nuevo?
		if delta_pos.normalized().dot(_dir_nueva) > 0.75:
			_latencias.append(float(ahora - _t_envio) / 1000.0)
			_fase = "enfriando"
			_espera_hasta = Time.get_ticks_msec() + 2500
	elif _fase == "enfriando" and Time.get_ticks_msec() >= _espera_hasta:
		_fase = "listo"


func _informar() -> void:
	var total := _tamanos.size()
	print("-- snapshots: %d en %.1f s --" % [total, _segundos])
	if total < 3:
		printerr("muy pocos snapshots; ¿la sala no arrancó?")
		quit(1)
		return
	var intervalos: Array = _intervalos.duplicate()
	intervalos.sort()
	var suma := 0.0
	for v in intervalos:
		suma += float(v)
	var medio: float = suma / maxf(1.0, float(intervalos.size()))
	var p50: float = intervalos[int(intervalos.size() * 0.5)]
	var p95: float = intervalos[mini(intervalos.size() - 1, int(intervalos.size() * 0.95))]
	print("  intervalo ms: medio %.1f · p50 %.1f · p95 %.1f · peor %.1f" % [
		medio, p50, p95, intervalos[intervalos.size() - 1]
	])
	print("  frecuencia efectiva: %.1f Hz" % (1000.0 / maxf(0.001, medio)))
	var tam_medio := 0.0
	for t in _tamanos:
		tam_medio += float(t)
	tam_medio /= float(total)
	print("  tamaño: medio %.0f B · máx %d B · ancho %.1f KB/s" % [
		tam_medio, _tamanos.max(), tam_medio * (1000.0 / maxf(0.001, medio)) / 1024.0
	])
	if not _latencias.is_empty():
		var lat: Array = _latencias.duplicate()
		lat.sort()
		var media_lat := 0.0
		for v in lat:
			media_lat += float(v)
		media_lat /= float(lat.size())
		print("  giro -> snapshot: n=%d medio %.0f ms · p50 %.0f · peor %.0f" % [
			lat.size(), media_lat, lat[int(lat.size() * 0.5)], lat[lat.size() - 1]
		])
	else:
		print("  giro -> snapshot: sin muestras (¿el jugador no se movió?)")
	print("  handshake (unirse -> bienvenida): %.0f ms" % _ms_handshake)
	print("  jugadores 1 · enemigos máx %d" % _max_enemigos)
	_red.cerrar()
	quit(0)
