class_name Sfx
extends RefCounted
## Efectos de sonido del juego. Usa grabaciones CC0 de Kenney cuando están
## disponibles y sintetiza el resto en tiempo de ejecución. Se usa como clase
## estática: Sfx.reproducir("golpe"). Los reproductores se reutilizan en pool.

const MAX_REPRODUCTORES := 10
const FRECUENCIA := 22050

const RUTAS := {
	&"golpe": "res://assets/audio/golpe.ogg",
	&"critico": "res://assets/audio/critico.ogg",
	&"habilidad": "res://assets/audio/habilidad.ogg",
	&"magia": "res://assets/audio/magia.ogg",
	&"compra": "res://assets/audio/compra.ogg",
	&"oleada": "res://assets/audio/oleada.ogg",
	&"dano": "res://assets/audio/dano.ogg",
	&"muerte": "res://assets/audio/muerte.ogg",
	&"enemigo": "res://assets/audio/enemigo.ogg",
	&"espiritu": "res://assets/audio/espiritu.ogg",
	&"victoria": "res://assets/audio/victoria.ogg",
	&"derrota": "res://assets/audio/derrota.ogg",
	&"click": "res://assets/audio/click.ogg",
}

static var _streams: Dictionary = {}
static var _reproductores: Array[AudioStreamPlayer] = []
static var _siguiente := 0
static var _conectado := false


static func reproducir(nombre: StringName, volumen_db := 0.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol == null:
		return
	if not _conectado:
		_conectado = true
		arbol.root.tree_exiting.connect(_limpiar, CONNECT_ONE_SHOT)
	if not _streams.has(nombre):
		_streams[nombre] = _crear_por_nombre(nombre)
	var stream: AudioStream = _streams.get(nombre)
	if stream == null:
		return

	if _reproductores.is_empty():
		for i in MAX_REPRODUCTORES:
			var reproductor := AudioStreamPlayer.new()
			reproductor.bus = &"Master"
			arbol.root.add_child(reproductor)
			_reproductores.append(reproductor)

	var reproductor := _reproductores[_siguiente]
	_siguiente = (_siguiente + 1) % _reproductores.size()
	reproductor.stream = stream
	reproductor.volume_db = volumen_db
	reproductor.pitch_scale = randf_range(0.96, 1.04)
	reproductor.play()


static func _limpiar() -> void:
	for reproductor in _reproductores:
		if is_instance_valid(reproductor):
			reproductor.stop()
			reproductor.stream = null
	_reproductores.clear()
	_streams.clear()
	_siguiente = 0
	_conectado = false


static func liberar() -> void:
	## Libera los reproductores ahora mismo (tests y cierre ordenado).
	for reproductor in _reproductores:
		if is_instance_valid(reproductor):
			reproductor.stop()
			reproductor.stream = null
			reproductor.free()
	_reproductores.clear()
	_streams.clear()
	_siguiente = 0
	_conectado = false


# --- Generación de ondas --------------------------------------------------

static func _crear_por_nombre(nombre: StringName) -> AudioStream:
	var ruta: String = RUTAS.get(nombre, "")
	if ruta != "" and ResourceLoader.exists(ruta):
		var recurso := load(ruta)
		if recurso is AudioStream:
			return recurso
	match nombre:
		&"golpe":
			return _crear(0.10, Callable(Sfx, "_golpe"))
		&"critico":
			return _crear(0.16, Callable(Sfx, "_critico"))
		&"habilidad":
			return _crear(0.28, Callable(Sfx, "_habilidad"))
		&"magia":
			return _crear(0.22, Callable(Sfx, "_magia"))
		&"compra":
			return _crear(0.34, Callable(Sfx, "_compra"))
		&"oleada":
			return _crear(0.55, Callable(Sfx, "_oleada"))
		&"dano":
			return _crear(0.16, Callable(Sfx, "_dano"))
		&"muerte":
			return _crear(0.65, Callable(Sfx, "_muerte"))
		&"enemigo":
			return _crear(0.26, Callable(Sfx, "_enemigo"))
		&"espiritu":
			return _crear(0.40, Callable(Sfx, "_espiritu"))
		&"victoria":
			return _crear(0.85, Callable(Sfx, "_victoria"))
		&"derrota":
			return _crear(1.0, Callable(Sfx, "_derrota"))
		_:
			return null


static func _crear(duracion: float, generador: Callable) -> AudioStreamWAV:
	var muestras := int(FRECUENCIA * duracion)
	var datos := PackedByteArray()
	datos.resize(muestras * 2)
	for i in muestras:
		var t := float(i) / FRECUENCIA
		var valor: float = clampf(generador.call(t, duracion), -1.0, 1.0)
		datos.encode_s16(i * 2, int(valor * 32767.0))
	var onda := AudioStreamWAV.new()
	onda.format = AudioStreamWAV.FORMAT_16_BITS
	onda.mix_rate = FRECUENCIA
	onda.stereo = false
	onda.data = datos
	return onda


static func _envolvente(t: float, duracion: float) -> float:
	return pow(maxf(0.0, 1.0 - t / duracion), 2.0)


static func _golpe(t: float, duracion: float) -> float:
	var ruido := sin(t * 991.0) * sin(t * 557.0)
	return (sin(TAU * 120.0 * t) * 0.55 + ruido * 0.35) * _envolvente(t, duracion)


static func _critico(t: float, duracion: float) -> float:
	var frecuencia := lerpf(620.0, 240.0, t / duracion)
	var onda := 1.0 if sin(TAU * frecuencia * t) >= 0.0 else -1.0
	return onda * 0.35 * _envolvente(t, duracion)


static func _habilidad(t: float, duracion: float) -> float:
	var frecuencia := lerpf(260.0, 920.0, t / duracion)
	return sin(TAU * frecuencia * t) * 0.35 * _envolvente(t, duracion)


static func _magia(t: float, duracion: float) -> float:
	var frecuencia := lerpf(760.0, 1180.0, t / duracion)
	var vibrato := 1.0 + 0.3 * sin(TAU * 22.0 * t)
	return sin(TAU * frecuencia * t * vibrato) * 0.28 * _envolvente(t, duracion)


static func _compra(t: float, duracion: float) -> float:
	var frecuencia := 1046.0 if t > 0.16 else 784.0
	return sin(TAU * frecuencia * t) * 0.3 * _envolvente(t, duracion)


static func _oleada(t: float, duracion: float) -> float:
	var frecuencia := 164.0 + 8.0 * sin(TAU * 5.0 * t)
	return sin(TAU * frecuencia * t) * 0.32 * _envolvente(t, duracion)


static func _dano(t: float, duracion: float) -> float:
	return sin(TAU * 92.0 * t) * 0.45 * _envolvente(t, duracion)


static func _muerte(t: float, duracion: float) -> float:
	var frecuencia := lerpf(220.0, 45.0, t / duracion)
	return sin(TAU * frecuencia * t) * 0.38 * _envolvente(t, duracion)


static func _enemigo(t: float, duracion: float) -> float:
	var frecuencia := lerpf(150.0, 38.0, t / duracion)
	var ruido := sin(t * 733.0) * 0.15
	return (sin(TAU * frecuencia * t) * 0.3 + ruido) * _envolvente(t, duracion)


static func _espiritu(t: float, duracion: float) -> float:
	var frecuencia := lerpf(900.0, 420.0, t / duracion)
	return sin(TAU * frecuencia * t) * 0.26 * _envolvente(t, duracion)


static func _victoria(t: float, duracion: float) -> float:
	var notas := [523.25, 659.25, 783.99, 1046.5]
	var indice := mini(int(t / (duracion / notas.size())), notas.size() - 1)
	return sin(TAU * float(notas[indice]) * t) * 0.3 * _envolvente(t, duracion)


static func _derrota(t: float, duracion: float) -> float:
	var frecuencia := lerpf(320.0, 70.0, t / duracion)
	return sin(TAU * frecuencia * t) * 0.4 * _envolvente(t, duracion)
