extends SceneTree
## Sonda manual: comprueba que CrearSala descarga cloudflared, abre el túnel y
## lanza el servidor headless. Requiere red. Uso:
##   godot --headless --script res://tests/inspect_crear_sala.gd
## No forma parte de la suite automática (tarda ~1 min y abre un túnel real).

var _creador: CrearSala
var _reloj := 0.0
var _fin := false


func _initialize() -> void:
	print("== sonda crear sala ==")
	_creador = CrearSala.new()
	root.add_child(_creador)
	_creador.estado.connect(func(t: String) -> void: print("[estado] %s" % t))
	_creador.lista.connect(_al_lista)
	_creador.fallo.connect(_al_fallo)
	_creador.crear()


func _process(delta: float) -> bool:
	_reloj += delta
	if _fin:
		return true
	if _reloj > 120.0:
		print("FALLO: sin respuesta en 120 s")
		_creador.cerrar()
		return true
	return false


func _al_lista(url_local: String, url_publica: String) -> void:
	print("OK local=%s publica=%s" % [url_local, url_publica])
	print("manteniendo la sala 90 s para inspeccionar puerto y procesos…")
	await create_timer(90.0).timeout
	print("== fin ==")
	_fin = true
	_creador.cerrar()


func _al_fallo(motivo: String) -> void:
	print("FALLO: %s" % motivo)
	_fin = true
	_creador.cerrar()
