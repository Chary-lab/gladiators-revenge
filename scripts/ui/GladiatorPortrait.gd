class_name GladiatorPortrait
extends SubViewportContainer
## Busto 3D en vivo del gladiador. Usa un SubViewport propio para no mezclar
## la cámara del retrato con la cámara isométrica del combate.

var _jugador: GladiatorController
var _viewport: SubViewport
var _modelo: CharacterVisual
var _tiempo := 0.0


func configurar(jugador: GladiatorController) -> void:
	_jugador = jugador
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(150, 108)
	size = Vector2(150, 108)
	_construir()
	if _jugador != null:
		if not _jugador.arma_cambiada.is_connected(_al_cambiar_arma):
			_jugador.arma_cambiada.connect(_al_cambiar_arma)
		if not _jugador.aspecto_cambiado.is_connected(_reconstruir):
			_jugador.aspecto_cambiado.connect(_reconstruir)


func _construir() -> void:
	if _viewport != null and is_instance_valid(_viewport):
		remove_child(_viewport)
		_viewport.queue_free()

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(160, 116)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	var camara := Camera3D.new()
	camara.position = Vector3(0.80, 1.52, 1.85)
	camara.fov = 36.0
	camara.near = 0.05
	_viewport.add_child(camara)
	camara.look_at(Vector3(0, 1.18, 0))

	var fondo := Sprite3D.new()
	fondo.texture = _degradado()
	fondo.pixel_size = 0.006
	fondo.scale = Vector3(20, 20, 1)
	fondo.position = Vector3(0, 0, -5)
	camara.add_child(fondo)

	var clave := DirectionalLight3D.new()
	clave.rotation_degrees = Vector3(-35, -28, 0)
	clave.light_color = Color(1.0, 0.84, 0.62)
	clave.light_energy = 2.4
	_viewport.add_child(clave)

	var borde := OmniLight3D.new()
	borde.position = Vector3(-1.2, 1.6, 1.4)
	borde.light_color = Color(0.36, 0.82, 1.0)
	borde.light_energy = 4.0
	borde.omni_range = 5.0
	_viewport.add_child(borde)

	var relleno := OmniLight3D.new()
	relleno.position = Vector3(1.4, 0.8, 2.2)
	relleno.light_color = Color(1.0, 0.62, 0.30)
	relleno.light_energy = 2.0
	relleno.omni_range = 4.0
	_viewport.add_child(relleno)

	_modelo = CharacterVisual.new()
	_modelo.name = "RetratoGladiador"
	_viewport.add_child(_modelo)
	var ruta := "res://assets/kaykit/adventurers/Barbarian.glb"
	var tinte := Color.WHITE
	if _jugador != null:
		ruta = _jugador.ruta_modelo
		tinte = _jugador.tinte_skin
	_modelo.configurar(ruta, tinte, "barbaro")
	_modelo.anadir_colmillos()
	_modelo.scale = Vector3(0.98, 0.98, 0.98)
	_modelo.position = Vector3(0, -0.03, 0)
	if _jugador != null and _jugador.arma_actual != null:
		_modelo.usar_arma_pesada(_jugador.arma_actual.clase == WeaponItem.Clase.BASTION)
		_modelo.equipar_arma(
			_jugador.arma_actual.escena_visual,
			_jugador.arma_actual.rotacion_visual,
			_jugador.arma_actual.escala_visual
		)


func _process(delta: float) -> void:
	_tiempo += delta
	if _modelo != null and is_instance_valid(_modelo):
		_modelo.rotation.y = sin(_tiempo * 0.45) * 0.16


func _al_cambiar_arma(_arma: WeaponItem = null) -> void:
	if _jugador == null or _modelo == null:
		return
	if _jugador.arma_actual == null:
		return
	_modelo.usar_arma_pesada(_jugador.arma_actual.clase == WeaponItem.Clase.BASTION)
	_modelo.equipar_arma(
		_jugador.arma_actual.escena_visual,
		_jugador.arma_actual.rotacion_visual,
		_jugador.arma_actual.escala_visual
	)


func _reconstruir() -> void:
	_construir()


func _degradado() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([
		Color(0.035, 0.03, 0.04, 1.0),
		Color(0.18, 0.12, 0.09, 1.0),
		Color(0.52, 0.34, 0.18, 1.0),
	])
	g.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	return t
