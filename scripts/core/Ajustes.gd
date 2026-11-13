class_name Ajustes
extends RefCounted
## Ajustes persistentes del jugador (user://ajustes.cfg).

const RUTA := "user://ajustes.cfg"

var volumen := 0.8         # 0..1, bus Master
var escala_tactil := 1.0   # tamaño de los botones táctiles


static func cargar() -> Ajustes:
	var a := Ajustes.new()
	var cfg := ConfigFile.new()
	if cfg.load(RUTA) == OK:
		a.volumen = float(cfg.get_value("audio", "volumen", a.volumen))
		a.escala_tactil = float(cfg.get_value("tactil", "escala", a.escala_tactil))
	return a


func guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volumen", volumen)
	cfg.set_value("tactil", "escala", escala_tactil)
	cfg.save(RUTA)


func aplicar() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(volumen, 0.0001, 1.0)))
		AudioServer.set_bus_mute(bus, volumen <= 0.001)
