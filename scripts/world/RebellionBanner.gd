class_name RebellionBanner
extends StaticBody3D
## Objetivo central que el jugador debe defender. Si cae, se pierde la partida.

signal salud_cambiada(actual: float, maxima: float)
signal destruida

var salud_maxima := 900.0
var salud_actual := 0.0


static func crear() -> RebellionBanner:
	var bandera := RebellionBanner.new()
	bandera._construir()
	return bandera


func _construir() -> void:
	collision_layer = 1
	collision_mask = 1

	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(1.2, 4.0, 1.2)
	forma.shape = caja
	forma.position.y = 2.0
	add_child(forma)

	var base := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 0.9
	cilindro.bottom_radius = 1.0
	cilindro.height = 0.25
	base.mesh = cilindro
	base.position.y = 0.12
	var piedra := StandardMaterial3D.new()
	piedra.albedo_color = Color(0.30, 0.28, 0.26)
	piedra.roughness = 1.0
	base.material_override = piedra
	add_child(base)

	var mastil := MeshInstance3D.new()
	var palo := CylinderMesh.new()
	palo.top_radius = 0.07
	palo.bottom_radius = 0.09
	palo.height = 4.0
	mastil.mesh = palo
	mastil.position.y = 2.0
	var madera := StandardMaterial3D.new()
	madera.albedo_color = Color(0.28, 0.18, 0.10)
	mastil.material_override = madera
	add_child(mastil)

	var tela := MeshInstance3D.new()
	var tela_malla := BoxMesh.new()
	tela_malla.size = Vector3(1.5, 0.9, 0.05)
	tela.mesh = tela_malla
	tela.position = Vector3(0.78, 3.25, 0.0)
	var seda := StandardMaterial3D.new()
	seda.albedo_color = Color(0.65, 0.12, 0.08)
	seda.emission_enabled = true
	seda.emission = Color(0.45, 0.06, 0.03)
	seda.emission_energy_multiplier = 1.8
	tela.material_override = seda
	add_child(tela)


func _ready() -> void:
	add_to_group("banderas")
	salud_actual = salud_maxima


func recibir_dano(cantidad: float, _tipo: StringName = &"fisico", _fuente: Node = null) -> void:
	if salud_actual <= 0.0 or cantidad <= 0.0:
		return
	salud_actual = maxf(0.0, salud_actual - cantidad)
	salud_cambiada.emit(salud_actual, salud_maxima)
	if salud_actual <= 0.0:
		destruida.emit()
