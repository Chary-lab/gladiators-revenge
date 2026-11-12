class_name IconStudio
extends RefCounted
## Estudio de miniaturas 3D 64x64. Renderiza una vez por icono con SubViewport
## y cachea el resultado. En --headless (sin renderer) entrega un icono
## procedural equivalente para que tests y UI nunca reciban un texture nulo.

const TAMANO := 64
const CATEGORIA_OBJETO := &"objeto"
const CATEGORIA_HABILIDAD := &"habilidad"
const CATEGORIA_COMANDO := &"comando"

static var _cache: Dictionary = {}
static var _fallbacks: Dictionary = {}
static var _callbacks: Dictionary = {}
static var _cola: Array[Dictionary] = []
static var _procesando := false
static var _contenedor: Node = null

static var COLOR_FUERZA := Color(0.92, 0.22, 0.10)
static var COLOR_AGILIDAD := Color(0.12, 0.78, 0.42)
static var COLOR_INTELIGENCIA := Color(0.28, 0.38, 0.96)
static var COLOR_LEGENDARIO := Color(0.98, 0.72, 0.18)
static var COLOR_APOYO := Color(0.58, 0.28, 0.92)
static var COLOR_NEUTRO := Color(0.62, 0.56, 0.46)


static func color_para(categoria: StringName, id: StringName = &"") -> Color:
	var texto := String(id)
	if texto == "fuerza":
		return COLOR_FUERZA
	if texto == "agilidad":
		return COLOR_AGILIDAD
	if texto == "inteligencia":
		return COLOR_INTELIGENCIA
	if texto.contains("obsidiana") or texto.contains("eclipse") or texto.contains("cataclismo") or texto.contains("cuerno"):
		return COLOR_LEGENDARIO
	if texto == "armadura_brasas":
		return COLOR_FUERZA
	if texto == "anillo_vampiro":
		return Color(0.80, 0.16, 0.22)
	if texto == "corazon_fenix":
		return Color(1.0, 0.52, 0.12)
	if texto == "capa_comandante" or texto == "guadana_verdugo_ancestral":
		return COLOR_LEGENDARIO
	if categoria == CATEGORIA_COMANDO:
		return COLOR_NEUTRO
	if texto.contains("bastion") or texto.contains("muro") or texto.contains("sismico") or texto.contains("provoca") or texto.contains("brasa") or texto.contains("placa"):
		return COLOR_FUERZA
	if texto.contains("filo") or texto.contains("tajo") or texto.contains("paso") or texto.contains("marca") or texto.contains("ejecucion") or texto.contains("pluma") or texto.contains("engranaje"):
		return COLOR_AGILIDAD
	if texto.contains("cetro") or texto.contains("espiritu") or texto.contains("raices") or texto.contains("orbe") or texto.contains("cristal") or texto.contains("corona") or texto.contains("sello"):
		return COLOR_INTELIGENCIA
	if texto.contains("estandarte") or texto.contains("cuerno") or texto.contains("grito") or texto.contains("vinculo") or texto.contains("egida"):
		return COLOR_APOYO
	if texto.contains("pocion"):
		return COLOR_FUERZA if texto.contains("vida") else COLOR_INTELIGENCIA
	if texto.contains("pergamino"):
		return COLOR_APOYO
	return COLOR_NEUTRO


static func obtener(id: StringName, categoria: StringName = CATEGORIA_OBJETO, color := Color.TRANSPARENT) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var tono := color if color.a > 0.0 else color_para(categoria, id)
	if not _en_cola(id):
		_cola.append({"id": id, "categoria": categoria, "color": tono})
		_procesar_cola()
	return _fallback(id, tono)


static func escuchar(id: StringName, callback: Callable) -> void:
	if _cache.has(id):
		callback.call(_cache[id])
		return
	if not _callbacks.has(id):
		_callbacks[id] = []
	var lista: Array = _callbacks[id]
	if not lista.has(callback):
		lista.append(callback)
	_callbacks[id] = lista


static func limpiar() -> void:
	_cache.clear()
	_fallbacks.clear()
	_callbacks.clear()
	_cola.clear()
	if is_instance_valid(_contenedor):
		_contenedor.queue_free()
	_contenedor = null


static func _en_cola(id: StringName) -> bool:
	for tarea in _cola:
		if tarea.get("id", &"") == id:
			return true
	return false


static func _raiz() -> Window:
	var arbol := Engine.get_main_loop() as SceneTree
	return arbol.root if arbol != null else null


static func _procesar_cola() -> void:
	if _procesando or _cola.is_empty():
		return
	_procesando = true
	while not _cola.is_empty():
		var tarea: Dictionary = _cola.pop_front()
		var id: StringName = tarea["id"]
		if _cache.has(id):
			continue
		var textura: Texture2D = null
		if DisplayServer.get_name() != "headless":
			textura = await _renderizar(tarea["categoria"], tarea["color"], id)
		if textura == null:
			textura = _fallback(id, tarea["color"])
		_cache[id] = textura
		_avisar(id, textura)
	_procesando = false


static func _avisar(id: StringName, textura: Texture2D) -> void:
	if not _callbacks.has(id):
		return
	var lista: Array = _callbacks[id]
	for callback in lista:
		if callback.is_valid():
			callback.call(textura)
	_callbacks.erase(id)


static func _renderizar(categoria: StringName, color: Color, id: StringName) -> Texture2D:
	var raiz := _raiz()
	if raiz == null:
		return null
	if not is_instance_valid(_contenedor):
		_contenedor = Node.new()
		_contenedor.name = "IconStudio"
		_contenedor.process_mode = Node.PROCESS_MODE_ALWAYS
		raiz.add_child.call_deferred(_contenedor)
		await (Engine.get_main_loop() as SceneTree).process_frame

	var vp := SubViewport.new()
	vp.size = Vector2i(TAMANO, TAMANO)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_4X
	_contenedor.add_child(vp)

	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.78, 0.72)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	entorno.environment = env
	vp.add_child(entorno)

	var camara := Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = 3.05
	camara.position = Vector3(2.7, 1.9, 2.7)
	vp.add_child(camara)
	camara.look_at(Vector3(0, 0.22, 0))

	# Fondo degradado detrás del modelo.
	var fondo := Sprite3D.new()
	fondo.texture = _degradado(color)
	fondo.pixel_size = 0.008
	fondo.scale = Vector3(13, 13, 1)
	fondo.position = Vector3(0, 0, -6)
	fondo.no_depth_test = false
	camara.add_child(fondo)

	var calida := DirectionalLight3D.new()
	calida.rotation_degrees = Vector3(-48, -32, 0)
	calida.light_color = Color(1.0, 0.86, 0.66)
	calida.light_energy = 2.2
	vp.add_child(calida)

	var borde := OmniLight3D.new()
	borde.position = Vector3(-1.5, 1.2, 1.4)
	borde.light_color = color.lightened(0.35)
	borde.light_energy = 4.5
	borde.omni_range = 6.0
	vp.add_child(borde)

	var relleno := OmniLight3D.new()
	relleno.position = Vector3(1.6, -0.8, 2.4)
	relleno.light_color = Color(0.55, 0.68, 1.0)
	relleno.light_energy = 1.8
	relleno.omni_range = 5.0
	vp.add_child(relleno)

	var modelo := ItemModelFactory.crear(id, categoria)
	modelo.scale = Vector3.ONE * _escala(categoria)
	modelo.position = Vector3(0, -0.12, 0) if categoria != CATEGORIA_OBJETO else Vector3(0, -0.04, 0)
	vp.add_child(modelo)

	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await (Engine.get_main_loop() as SceneTree).process_frame
	await RenderingServer.frame_post_draw
	var imagen: Image = null
	if is_instance_valid(vp):
		imagen = vp.get_texture().get_image()
	_contenedor.remove_child(vp)
	vp.queue_free()
	if imagen == null or imagen.is_empty():
		return null
	imagen.flip_y()
	return ImageTexture.create_from_image(imagen)


static func _escala(categoria: StringName) -> float:
	match categoria:
		CATEGORIA_HABILIDAD:
			return 1.22
		CATEGORIA_COMANDO:
			return 1.12
		_:
			return 1.18


static func _degradado(color: Color) -> GradientTexture2D:
	var gradiente := Gradient.new()
	gradiente.colors = PackedColorArray([
		Color(0.035, 0.03, 0.035, 0.96),
		color.darkened(0.42),
		color.lightened(0.18),
	])
	gradiente.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.width = 64
	textura.height = 64
	textura.fill = GradientTexture2D.FILL_LINEAR
	textura.fill_from = Vector2(0.5, 0.0)
	textura.fill_to = Vector2(0.5, 1.0)
	return textura


static func _fallback(id: StringName, color: Color) -> Texture2D:
	if _fallbacks.has(id):
		return _fallbacks[id]
	var img := Image.create(TAMANO, TAMANO, false, Image.FORMAT_RGBA8)
	var centro := Vector2(TAMANO * 0.5, TAMANO * 0.5)
	for y in TAMANO:
		for x in TAMANO:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(centro) / (TAMANO * 0.5)
			var base := color.darkened(0.55).lerp(color.lightened(0.10), clampf(1.0 - d, 0.0, 1.0))
			var borde := 1.0 if d > 0.84 else 0.0
			if borde > 0.0:
				base = Color(0.47, 0.38, 0.25, 1.0)
			# Rombo central claro para que la miniatura se lea incluso sin renderer.
			var rombo := absf(p.x - centro.x) / 17.0 + absf(p.y - centro.y) / 21.0
			if rombo < 1.0:
				base = base.lerp(Color(0.95, 0.93, 0.86, 1.0), 0.42)
			img.set_pixel(x, y, Color(base.r, base.g, base.b, 1.0))
	var textura := ImageTexture.create_from_image(img)
	_fallbacks[id] = textura
	return textura
