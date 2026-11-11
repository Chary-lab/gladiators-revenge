class_name ArmoryPedestal
extends Node3D
## Pedestal de la armería. Muestra el arma y su precio; comprar reemplaza el kit.

var arma: WeaponItem
var vendida := false

var _icono: MeshInstance3D
var _etiqueta: Label3D
var _base: MeshInstance3D


func configurar(nueva_arma: WeaponItem) -> void:
	add_to_group("pedestales")
	arma = nueva_arma
	_construir()
	_actualizar_etiqueta()


func _construir() -> void:
	_base = MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 0.55
	cilindro.bottom_radius = 0.7
	cilindro.height = 0.9
	_base.mesh = cilindro
	_base.position.y = 0.45
	var piedra := StandardMaterial3D.new()
	piedra.albedo_color = Color(0.34, 0.31, 0.27)
	piedra.roughness = 1.0
	_base.material_override = piedra
	add_child(_base)

	_icono = MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.18, 1.4, 0.18)
	_icono.mesh = caja
	_icono.position.y = 1.85
	var material := StandardMaterial3D.new()
	material.albedo_color = _color_por_rol()
	material.emission_enabled = true
	material.emission = _color_por_rol()
	material.emission_energy_multiplier = 1.4
	_icono.material_override = material
	add_child(_icono)

	_etiqueta = Label3D.new()
	_etiqueta.font_size = 48
	_etiqueta.pixel_size = 0.006
	_etiqueta.position = Vector3(0, 2.9, 0)
	_etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_etiqueta.no_depth_test = true
	_etiqueta.outline_size = 10
	_etiqueta.modulate = Color(1, 0.93, 0.75)
	add_child(_etiqueta)


func _process(delta: float) -> void:
	if not vendida and _icono != null:
		_icono.rotate_y(delta * 1.6)
	if _etiqueta != null:
		var jugador := get_tree().get_first_node_in_group(GladiatorController.GRUPO_GLADIADORES) as Node3D
		_etiqueta.visible = jugador != null and _es_el_pedestal_mas_cercano(jugador)


func _actualizar_etiqueta() -> void:
	if arma == null or _etiqueta == null:
		return
	_etiqueta.text = "%s\n%d oro   F: comprar" % [arma.nombre, arma.precio_oro]


func precio() -> int:
	return arma.precio_oro if arma != null else 0


## El coste de oro lo descuenta Arena; aquí solo se valida y equipa.
func comprar(jugador: GladiatorController) -> bool:
	if vendida or arma == null or jugador == null:
		return false
	if not jugador.equipar_arma(arma):
		return false

	vendida = true
	_icono.visible = false
	_etiqueta.text = "VENDIDA"
	_etiqueta.modulate = Color(0.6, 0.6, 0.6)
	var gris := StandardMaterial3D.new()
	gris.albedo_color = Color(0.22, 0.22, 0.22)
	_base.material_override = gris
	return true


func _es_el_pedestal_mas_cercano(jugador: Node3D) -> bool:
	var distancia := jugador.global_position.distance_to(global_position)
	if distancia > 9.0:
		return false
	for nodo in get_tree().get_nodes_in_group("pedestales"):
		var otro := nodo as Node3D
		if otro != null and otro != self and jugador.global_position.distance_to(otro.global_position) < distancia:
			return false
	return true


func _color_por_rol() -> Color:
	if arma == null:
		return Color(0.7, 0.7, 0.7)
	match arma.clase:
		WeaponItem.Clase.BASTION:
			return Color(0.95, 0.65, 0.20)
		WeaponItem.Clase.FILO:
			return Color(0.35, 0.85, 0.95)
		WeaponItem.Clase.CETRO:
			return Color(0.70, 0.45, 0.95)
		_:
			return Color(0.7, 0.7, 0.7)
