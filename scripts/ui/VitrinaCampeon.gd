class_name VitrinaCampeon
extends SubViewportContainer
## Vitrina 3D del campeón: el gladiador de cuerpo entero con su arma, iluminado
## como una estatua de la forja. Es la pieza central del lobby y de la forja de
## campeones.
##
## Mantiene su propio SubViewport (con mundo 3D aparte) para no mezclar cámaras
## con la arena ni con el retrato del HUD. En headless no se construye nada: las
## pruebas no pagan el coste de instanciar modelos.

var _viewport: SubViewport
var _camara: Camera3D
var _modelo: CharacterVisual
var _soporte: Node3D
var _tiempo := 0.0
var _sway := 0.22
var _tinte := Color.WHITE
var _clase: StringName = &"bastion"
var _construido := false


func configurar(lado := Vector2(420, 520)) -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = lado
	size = lado
	if DisplayServer.get_name() == "headless":
		return
	_construir()


func _construir() -> void:
	if _construido:
		return
	_construido = true
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(maxi(2, int(size.x)), maxi(2, int(size.y)))
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	_camara = Camera3D.new()
	_camara.fov = 32.0
	_camara.near = 0.05
	_viewport.add_child(_camara)
	_camara.look_at_from_position(Vector3(-0.22, 1.00, 4.55), Vector3(-0.18, 0.86, 0), Vector3.UP)

	var gradiente := Sprite3D.new()
	gradiente.texture = _degradado()
	gradiente.pixel_size = 0.0055
	gradiente.scale = Vector3(34, 34, 1)
	gradiente.position = Vector3(0, 0, -7)
	_camara.add_child(gradiente)

	var luz_clave := DirectionalLight3D.new()
	luz_clave.rotation_degrees = Vector3(-36, -34, 0)
	luz_clave.light_color = Color(1.0, 0.86, 0.66)
	luz_clave.light_energy = 2.9
	_viewport.add_child(luz_clave)

	var contraluz := OmniLight3D.new()
	contraluz.position = Vector3(1.7, 1.9, -1.3)
	contraluz.light_color = Color(1.0, 0.46, 0.18)
	contraluz.light_energy = 7.0
	contraluz.omni_range = 7.0
	_viewport.add_child(contraluz)

	var relleno := OmniLight3D.new()
	relleno.position = Vector3(-1.9, 1.1, 1.7)
	relleno.light_color = Color(0.46, 0.62, 1.0)
	relleno.light_energy = 2.4
	relleno.omni_range = 6.0
	_viewport.add_child(relleno)

	_soporte = Node3D.new()
	_vp_add(_soporte)

	_modelo = CharacterVisual.new()
	_modelo.name = "Campeon"
	_soporte.add_child(_modelo)
	_modelo.configurar("res://assets/kaykit/adventurers/Barbarian.glb", _tinte, "barbaro")
	_modelo.anadir_colmillos()


func _vp_add(nodo: Node) -> void:
	if _viewport != null:
		_viewport.add_child(nodo)


func _process(delta: float) -> void:
	if not _construido or _modelo == null or not is_instance_valid(_modelo):
		return
	_tiempo += delta
	_soporte.rotation.y = sin(_tiempo * 0.42) * _sway + 0.16
	_soporte.position.y = sin(_tiempo * 0.9) * 0.012
	# Mantiene el lienzo 3D al tamaño real de la vitrina (responsive).
	var destino := Vector2i(maxi(2, int(size.x)), maxi(2, int(size.y)))
	if _viewport.size != destino:
		_viewport.size = destino


## Cambia el campeón exhibido: tinte (piel), arma y postura.
func mostrar(
	clase: StringName,
	tinte: Color,
	arma_escena: PackedScene = null,
	arma_rotacion: Vector3 = Vector3.ZERO,
	arma_escala: float = 1.0,
	pesada: bool = false
) -> void:
	_clase = clase
	_tinte = tinte
	if not _construido or _modelo == null or not is_instance_valid(_modelo):
		return
	_modelo.aplicar_skin(tinte)
	_modelo.usar_arma_pesada(pesada)
	if arma_escena != null:
		_modelo.equipar_arma(arma_escena, arma_rotacion, arma_escala)
	girar()


## Giro de presentación al cambiar de campeón: una vuelta rápida y vuelve.
func girar() -> void:
	if not _construido or _soporte == null:
		return
	var tween := create_tween()
	tween.tween_property(_soporte, "rotation:y", _soporte.rotation.y + PI * 2.0, 0.55) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _degradado() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([
		Color(0.02, 0.015, 0.012, 0.0),
		Color(0.14, 0.055, 0.030, 0.16),
		Color(0.42, 0.16, 0.06, 0.34),
		Color(0.05, 0.03, 0.02, 0.0),
	])
	g.offsets = PackedFloat32Array([0.0, 0.45, 0.62, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 96
	t.height = 96
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.72)
	t.fill_to = Vector2(0.5, 0.0)
	return t
