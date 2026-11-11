class_name ShopPedestal
extends Node3D
## Puesto del mercader en la zona segura. La lógica de compra vive en Arena y
## ShopPanel; este nodo solo aporta presencia física y el rótulo de interacción.

var _etiqueta: Label3D
var _icono: Node3D


func _ready() -> void:
	add_to_group("tiendas")
	_construir()


func _construir() -> void:
	var base := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 1.5
	cilindro.bottom_radius = 1.7
	cilindro.height = 0.35
	base.mesh = cilindro
	base.position.y = 0.175
	base.material_override = _material(Color(0.3, 0.26, 0.22))
	add_child(base)

	var mostrador := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(2.1, 0.8, 1.0)
	mostrador.mesh = caja
	mostrador.position.y = 0.75
	mostrador.material_override = _material(Color(0.34, 0.21, 0.12))
	add_child(mostrador)

	for x in [-0.95, 0.95]:
		var poste := MeshInstance3D.new()
		var palo := CylinderMesh.new()
		palo.top_radius = 0.07
		palo.bottom_radius = 0.08
		palo.height = 2.9
		poste.mesh = palo
		poste.position = Vector3(x, 1.75, 0)
		poste.material_override = _material(Color(0.24, 0.15, 0.09))
		add_child(poste)

	var toldo := MeshInstance3D.new()
	var lona := BoxMesh.new()
	lona.size = Vector3(2.3, 0.08, 1.25)
	toldo.mesh = lona
	toldo.position = Vector3(0, 3.15, 0)
	toldo.material_override = _material(Color(0.55, 0.12, 0.1))
	add_child(toldo)

	_icono = Node3D.new()
	_icono.position = Vector3(0, 1.55, 0)
	add_child(_icono)
	var moneda := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.3
	disco.bottom_radius = 0.3
	disco.height = 0.07
	moneda.mesh = disco
	moneda.rotation_degrees.x = 90.0
	var oro := StandardMaterial3D.new()
	oro.albedo_color = Color(0.95, 0.75, 0.25)
	oro.emission_enabled = true
	oro.emission = Color(0.9, 0.6, 0.15)
	oro.emission_energy_multiplier = 1.8
	moneda.material_override = oro
	_icono.add_child(moneda)

	_etiqueta = Label3D.new()
	_etiqueta.text = "MERCADER\nF: abrir tienda"
	_etiqueta.font_size = 48
	_etiqueta.pixel_size = 0.006
	_etiqueta.outline_size = 10
	_etiqueta.modulate = Color(0.95, 0.85, 0.6)
	_etiqueta.position = Vector3(0, 3.7, 0)
	_etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_etiqueta.no_depth_test = true
	_etiqueta.visible = false
	add_child(_etiqueta)


func _process(delta: float) -> void:
	if _icono != null:
		_icono.rotate_y(delta * 1.8)
	if _etiqueta == null:
		return
	var jugador := get_tree().get_first_node_in_group("gladiadores") as Node3D
	if jugador == null:
		_etiqueta.visible = false
		return
	var distancia := global_position.distance_to(jugador.global_position)
	_etiqueta.visible = distancia <= 9.0 and _es_el_mas_cercano(jugador)


func _es_el_mas_cercano(jugador: Node3D) -> bool:
	var propia := global_position.distance_to(jugador.global_position)
	for nodo in get_tree().get_nodes_in_group("tiendas"):
		var otra := nodo as Node3D
		if otra != null and otra != self and otra.global_position.distance_to(jugador.global_position) < propia:
			return false
	return true


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
