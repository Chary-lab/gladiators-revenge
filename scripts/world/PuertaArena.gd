class_name PuertaArena
extends Node3D
## Portón de hierro entre la zona segura y la arena. Se abre durante la
## preparación/entrada y se cierra cuando empieza el combate.

var _cuerpo: StaticBody3D
var _rejas: Node3D
var _abierta := true


func _ready() -> void:
	_construir()
	abrir()


func _construir() -> void:
	var piedra := Color(0.23, 0.21, 0.20)
	for lado in [-1.0, 1.0]:
		var pilar := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(1.0, 4.2, 1.0)
		pilar.mesh = caja
		pilar.position = Vector3(0, 2.1, lado * 5.0)
		pilar.material_override = _material(piedra)
		add_child(pilar)

	_cuerpo = StaticBody3D.new()
	_cuerpo.name = "ColisionPorton"
	_cuerpo.collision_layer = 1
	_cuerpo.collision_mask = 0
	var forma := CollisionShape3D.new()
	var caja_col := BoxShape3D.new()
	caja_col.size = Vector3(0.8, 4.0, 10.0)
	forma.shape = caja_col
	forma.position.y = 2.0
	_cuerpo.add_child(forma)
	add_child(_cuerpo)

	_rejas = Node3D.new()
	_rejas.name = "Rejas"
	add_child(_rejas)
	var hierro := Color(0.16, 0.15, 0.14)
	for z in range(-4, 5):
		var barra := MeshInstance3D.new()
		var cilindro := CylinderMesh.new()
		cilindro.top_radius = 0.09
		cilindro.bottom_radius = 0.09
		cilindro.height = 4.0
		barra.mesh = cilindro
		barra.position = Vector3(0, 2.0, float(z))
		barra.material_override = _material(hierro)
		_rejas.add_child(barra)
	for y in [0.7, 2.0, 3.3]:
		var travesano := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(0.18, 0.18, 9.0)
		travesano.mesh = caja
		travesano.position = Vector3(0, y, 0)
		travesano.material_override = _material(hierro)
		_rejas.add_child(travesano)


func abrir() -> void:
	_abierta = true
	if _cuerpo != null:
		_cuerpo.process_mode = Node.PROCESS_MODE_DISABLED
		_cuerpo.collision_layer = 0
	if _rejas != null:
		_rejas.visible = false


func cerrar() -> void:
	_abierta = false
	if _cuerpo != null:
		_cuerpo.process_mode = Node.PROCESS_MODE_INHERIT
		_cuerpo.collision_layer = 1
	if _rejas != null:
		_rejas.visible = true


func esta_abierta() -> bool:
	return _abierta


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
