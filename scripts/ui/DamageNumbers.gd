class_name NumerosDano
extends RefCounted
## Números de daño/curación flotantes con pool estático de Label3D.
## Se llaman desde cualquier sistema de combate sin acoplarse al HUD:
##   NumerosDano.mostrar(posicion, 42.0, GladiatorStats.TIPO_FISICO, true)
## El pool evita instanciar etiquetas durante la oleada (requisito Web).

const MAX_ETIQUETAS := 40
const DURACION := 0.85

static var _etiquetas: Array[Label3D] = []
static var _siguiente := 0
static var _conectado := false


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
		arbol.root.tree_exiting.connect(_limpiar, CONNECT_ONE_SHOT)

	var etiqueta := _obtener(arbol)
	if etiqueta == null:
		return

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

	etiqueta.global_position = posicion + Vector3(randf_range(-0.25, 0.25), 1.7, 0.0)
	etiqueta.font_size = 72 if critico else 52
	etiqueta.scale = Vector3.ONE * (1.35 if critico else 1.0)
	etiqueta.visible = true
	etiqueta.modulate.a = 1.0

	if etiqueta.has_meta("tween"):
		var anterior: Tween = etiqueta.get_meta("tween")
		if anterior != null and anterior.is_valid():
			anterior.kill()

	var tween := etiqueta.create_tween()
	etiqueta.set_meta("tween", tween)
	tween.set_parallel(true)
	tween.tween_property(etiqueta, "global_position", etiqueta.global_position + Vector3(0, 1.7, 0), DURACION)
	tween.tween_property(etiqueta, "modulate:a", 0.0, DURACION)
	tween.tween_property(etiqueta, "scale", Vector3.ONE * 0.7, DURACION)
	var _cb_etiqueta := Callable(NumerosDano, "_on_etiqueta_tween_completo").bind(etiqueta)
	tween.chain().tween_callback(_cb_etiqueta)


static func _obtener(arbol: SceneTree) -> Label3D:
	if _etiquetas.is_empty():
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
	var etiqueta := _etiquetas[_siguiente]
	_siguiente = (_siguiente + 1) % _etiquetas.size()
	return etiqueta


static func _limpiar() -> void:
	_etiquetas.clear()
	_siguiente = 0
	_conectado = false

static func _on_etiqueta_tween_completo(etiqueta: Label3D) -> void:
	etiqueta.visible = false