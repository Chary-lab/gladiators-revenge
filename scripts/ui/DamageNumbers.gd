class_name NumerosDano
extends RefCounted
## Números de daño/curación flotantes con pool estático de Label3D.
## Se llaman desde cualquier sistema de combate sin acoplarse al HUD:
##   NumerosDano.mostrar(posicion, 42.0, GladiatorStats.TIPO_FISICO, true)
##
## El pool evita instanciar etiquetas durante la oleada (requisito Web) y la
## animación se resuelve en un solo `_tick` conectado a `process_frame`: antes
## cada número creaba dos Tween (y mataba el anterior) y en una oleada con área
## eso costaba decenas de milisegundos por fotograma.

const MAX_ETIQUETAS := 40
const DURACION := 0.85
const SUBIDA := 1.7

static var _etiquetas: Array[Label3D] = []
static var _restante: PackedFloat32Array = PackedFloat32Array()
static var _origen: Array[Vector3] = []
static var _pico: PackedFloat32Array = PackedFloat32Array()
static var _siguiente := 0
static var _conectado := false
static var _ultimo_usec := 0


static func mostrar(
	posicion: Vector3,
	cantidad: float,
	tipo: StringName = GladiatorStats.TIPO_FISICO,
	critico := false,
	curacion := false
) -> void:
	if cantidad < 0.5:
		return
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol == null or arbol.root == null:
		return
	if not _conectado:
		_conectado = true
		_ultimo_usec = 0
		arbol.root.tree_exiting.connect(_limpiar, CONNECT_ONE_SHOT)
		arbol.process_frame.connect(_tick)

	_preparar_pool(arbol)
	var indice := _siguiente
	_siguiente = (_siguiente + 1) % _etiquetas.size()
	var etiqueta := _etiquetas[indice]

	if curacion:
		etiqueta.modulate = Color(0.40, 1.0, 0.52)
		etiqueta.text = "+%d" % int(round(cantidad))
	elif critico:
		etiqueta.modulate = Color(1.0, 0.86, 0.28)
		etiqueta.text = "%d" % int(round(cantidad))
	elif tipo == GladiatorStats.TIPO_MAGICO:
		etiqueta.modulate = Color(0.48, 0.72, 1.0)
		etiqueta.text = "%d" % int(round(cantidad))
	elif tipo == GladiatorStats.TIPO_VERDADERO:
		etiqueta.modulate = Color(1.0, 0.55, 0.55)
		etiqueta.text = "%d" % int(round(cantidad))
	else:
		etiqueta.modulate = Color(1.0, 1.0, 1.0)
		etiqueta.text = "%d" % int(round(cantidad))

	etiqueta.font_size = 80 if critico else 60
	etiqueta.scale = Vector3.ONE * 0.5
	etiqueta.global_position = posicion + Vector3(randf_range(-0.25, 0.25), SUBIDA, 0.0)
	etiqueta.modulate.a = 1.0
	etiqueta.visible = true

	_origen[indice] = etiqueta.global_position
	_restante[indice] = DURACION
	_pico[indice] = 1.5 if critico else 1.2


## Un solo recorrido por fotograma para las etiquetas activas: sin tweens, sin
## objetos nuevos por golpe. `process_frame` no trae delta, así que se mide con
## el reloj (y se acota para que un tirón no teletransporte las etiquetas).
static func _tick() -> void:
	var ahora := Time.get_ticks_usec()
	var delta := 0.016
	if _ultimo_usec > 0:
		delta = clampf(float(ahora - _ultimo_usec) / 1000000.0, 0.001, 0.1)
	_ultimo_usec = ahora
	for i in _etiquetas.size():
		var restante := _restante[i]
		if restante <= 0.0:
			continue
		restante -= delta
		_restante[i] = restante
		var etiqueta := _etiquetas[i]
		if restante <= 0.0:
			etiqueta.visible = false
			continue
		var avance := 1.0 - restante / DURACION
		etiqueta.global_position = _origen[i] + Vector3(0.0, SUBIDA * avance, 0.0)
		etiqueta.modulate.a = 1.0 - avance
		# Rebote de entrada (primer 12 %) y luego encogido hasta 0,7.
		var pico := _pico[i]
		var escala := 0.5 + (pico - 0.5) * minf(avance / 0.12, 1.0)
		if avance > 0.12:
			escala = lerpf(pico, 0.7, (avance - 0.12) / 0.88)
		etiqueta.scale = Vector3.ONE * escala


static func _preparar_pool(arbol: SceneTree) -> void:
	if not _etiquetas.is_empty():
		return
	_restante.resize(MAX_ETIQUETAS)
	_pico.resize(MAX_ETIQUETAS)
	_origen.resize(MAX_ETIQUETAS)
	for i in MAX_ETIQUETAS:
		var etiqueta := Label3D.new()
		etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		etiqueta.no_depth_test = true
		etiqueta.fixed_size = false
		etiqueta.pixel_size = 0.008
		etiqueta.outline_size = 14
		etiqueta.outline_modulate = Color(0, 0, 0, 0.9)
		etiqueta.render_priority = 10
		etiqueta.visible = false
		arbol.root.add_child(etiqueta)
		_etiquetas.append(etiqueta)
		_restante[i] = 0.0
		_pico[i] = 1.2
		_origen[i] = Vector3.ZERO
	_siguiente = 0


static func _limpiar() -> void:
	_etiquetas.clear()
	_restante.clear()
	_pico.clear()
	_origen.clear()
	_siguiente = 0
	_conectado = false
