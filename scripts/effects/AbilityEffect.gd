class_name AbilityEffect
extends Node3D
## Ejecutor genérico de habilidades: daño, curación, provocación y zonas
## persistentes (estandartes). Lee AbilityData y los talentos activos del
## portador; no hay lógica por habilidad hardcodeada.
##
## El controlador instancia la escena, la posiciona y llama a configurar().

var _datos: AbilityData
var _portador: GladiatorController
var _radio := 2.5
var _duracion := 0.0
var _dano := 0.0
var _cura := 0.0
var _restante := 0.0
var _tick := 0.0
var _color := Color(0.95, 0.65, 0.20)


func configurar(datos: AbilityData, portador: GladiatorController) -> void:
	_datos = datos
	_portador = portador
	_radio = datos.radio
	_duracion = datos.duracion

	for talento in datos.talentos:
		if talento == null:
			continue
		var rango := portador.rango_talento(talento.id)
		if rango <= 0:
			continue
		if talento.modificadores.has(&"radio"):
			_radio += float(talento.modificadores[&"radio"]) * rango
		if talento.modificadores.has(&"duracion"):
			_duracion += float(talento.modificadores[&"duracion"]) * rango

	_dano = portador.estadisticas.escalar_dano(datos.dano_base, datos.tipo_dano)
	_cura = datos.curacion_base
	_dano += _bono_fuego()
	for talento in datos.talentos:
		if talento == null:
			continue
		var rango := portador.rango_talento(talento.id)
		if rango > 0 and talento.modificadores.has(&"dano"):
			_dano += float(talento.modificadores[&"dano"]) * rango

	match datos.tipo_dano:
		GladiatorStats.TIPO_MAGICO:
			_color = Color(0.45, 0.55, 1.0)
		_:
			_color = Color(1.0, 0.55, 0.20)
	if _cura > 0.0:
		_color = Color(0.35, 1.0, 0.45)

	_construir_visual()
	_aplicar_pulso()
	_restante = _duracion if _duracion > 0.0 else 0.4
	_tick = 0.5 if _duracion > 0.0 else 999.0


func _process(delta: float) -> void:
	_restante -= delta
	if _datos != null and _datos.tipo == AbilityData.Tipo.ZONA and _hay_elite_en_radio():
		# Regla del estandarte: un élite dentro acorta la duración.
		_restante -= delta * 1.5

	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		_aplicar_pulso()

	if _restante <= 0.0:
		queue_free()


func _aplicar_pulso() -> void:
	if _datos == null:
		return

	for nodo in get_tree().get_nodes_in_group("enemigos"):
		var enemigo := nodo as Node3D
		if enemigo == null:
			continue
		if enemigo.global_position.distance_to(global_position) > _radio:
			continue
		if _dano > 0.0 and enemigo.has_method("recibir_dano"):
			enemigo.recibir_dano(_dano, _datos.tipo_dano, _portador)
		if _datos.provoca and enemigo.has_method("aplicar_provocacion"):
			enemigo.aplicar_provocacion(_portador, maxf(_duracion, 2.0))

	if _cura > 0.0 and _portador != null and is_instance_valid(_portador):
		if _portador.global_position.distance_to(global_position) <= _radio:
			_portador.curar(_cura)


func _bono_fuego() -> float:
	if _portador == null or _datos == null:
		return 0.0
	var total := 0.0
	for talento in _datos.talentos:
		if talento != null:
			var rango := _portador.rango_talento(talento.id)
			if rango > 0 and talento.modificadores.has(&"dano_fuego"):
				total += float(talento.modificadores[&"dano_fuego"]) * rango
	return total


func _hay_elite_en_radio() -> bool:
	for nodo in get_tree().get_nodes_in_group("enemigos"):
		var enemigo := nodo as Node3D
		if enemigo == null:
			continue
		if enemigo.get("es_elite") != true:
			continue
		if enemigo.global_position.distance_to(global_position) <= _radio:
			return true
	return false


func _construir_visual() -> void:
	var disco := MeshInstance3D.new()
	var malla := CylinderMesh.new()
	malla.top_radius = _radio
	malla.bottom_radius = _radio
	malla.height = 0.06
	malla.radial_segments = 28
	disco.mesh = malla
	disco.position.y = 0.05
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(_color.r, _color.g, _color.b, 0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = _color
	material.emission_energy_multiplier = 2.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	disco.material_override = material
	add_child(disco)
