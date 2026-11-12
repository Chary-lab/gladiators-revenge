class_name AbilityEffect
extends Node3D
## Ejecutor genérico de habilidades y objetos activos.
##
## Lee AbilityData, los talentos del portador y sus sinergias de clase. No hay
## lógica duplicada de escalado: todo daño/curación pasa por GladiatorStats.
## Los indicadores son mallas geométricas temporales animadas con Tween.

var _datos: AbilityData
var _portador: GladiatorController
var _radio := 2.5
var _duracion := 0.0
var _dano := 0.0
var _cura := 0.0
var _restante := 0.0
var _tick := 0.0
var _color := Color(0.95, 0.65, 0.20)
var _golpe_provocado := false
var _ya_vinculo := false
## En clientes de red: dibuja el efecto pero no aplica daño ni curación.
var solo_visual := false


func configurar(datos: AbilityData, portador: GladiatorController) -> void:
	_datos = datos
	_portador = portador
	_radio = datos.radio
	_duracion = datos.duracion
	if portador.has_method("bono_rango"):
		_radio += portador.bono_rango(datos, "radio")
		_duracion += portador.bono_rango(datos, "duracion")

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
	if portador.has_method("bono_rango"):
		_dano += portador.bono_rango(datos, "dano")
		_cura += portador.bono_rango(datos, "curacion")
	_dano += _bono_fuego()
	for talento in datos.talentos:
		if talento == null:
			continue
		var rango := portador.rango_talento(talento.id)
		if rango > 0 and talento.modificadores.has(&"dano"):
			_dano += float(talento.modificadores[&"dano"]) * rango

	# Sinergia Filo: el Paso Sombrío potencia el siguiente Tajo Gemelo.
	_dano *= portador.consumir_potenciador(datos.id)

	# Sinergia Bastión: Golpe Sísmico contra objetivos provocados por E.
	if datos.id == &"bastion_golpe_sismico" and _hay_provocado_en_radio():
		_golpe_provocado = true
		_dano *= 1.35

	match datos.tipo_dano:
		GladiatorStats.TIPO_MAGICO:
			_color = Color(0.45, 0.55, 1.0)
		_:
			_color = Color(1.0, 0.55, 0.20)
	if _cura > 0.0:
		_color = Color(0.35, 1.0, 0.45)

	if not solo_visual:
		_aplicar_efectos_al_portador()
	_construir_visual()
	if solo_visual:
		_restante = _duracion if _duracion > 0.0 else 0.4
		_tick = 999.0
		return
	if datos.efecto_especial == &"descarga":
		_descarga_encadenada()
	else:
		_aplicar_pulso()
	_restante = _duracion if _duracion > 0.0 else 0.4
	_tick = 0.5 if _duracion > 0.0 else 999.0


func _aplicar_efectos_al_portador() -> void:
	if _portador == null or _datos == null:
		return
	if _datos.escudo_por_atributo > 0.0:
		var atributo := _portador.estadisticas.fuerza_total
		if _datos.atributo_escalado == &"inteligencia":
			atributo = _portador.estadisticas.inteligencia_total
		elif _datos.atributo_escalado == &"agilidad":
			atributo = _portador.estadisticas.agilidad_total
		_portador.otorgar_escudo(atributo * _datos.escudo_por_atributo, maxf(_datos.duracion, 3.0))
	if _datos.inmunidad_aturdimiento > 0.0:
		_portador.otorgar_inmunidad_aturdimiento(_datos.inmunidad_aturdimiento)
	if _datos.efecto_especial == &"grito":
		_portador.aplicar_grito_guerra(maxf(_datos.duracion, 6.0), 0.25, 0.12)


func _process(delta: float) -> void:
	_restante -= delta
	if solo_visual:
		if _restante <= 0.0:
			queue_free()
		return
	if _datos != null and _datos.tipo == AbilityData.Tipo.ZONA and _hay_elite_en_radio():
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

	var enemigos := get_tree().get_nodes_in_group("enemigos")
	for nodo in enemigos:
		var enemigo := nodo as Node3D
		if enemigo == null:
			continue
		if enemigo.global_position.distance_to(global_position) > _radio:
			continue

		if _datos.efecto_especial == &"marca_verdugo" and enemigo.has_method("aplicar_marca"):
			enemigo.aplicar_marca(maxf(_duracion, 4.0))

		var dano := _dano
		if _datos.efecto_especial == &"ejecucion" and enemigo.has_method("esta_marcado") and enemigo.esta_marcado():
			dano *= 1.25
		if dano > 0.0 and enemigo.has_method("recibir_dano"):
			enemigo.recibir_dano(dano, _datos.tipo_dano, _portador)
			_portador.registrar_dano(dano)
			var vida_despues: float = enemigo.get("salud_actual") if enemigo.get("salud_actual") != null else 1.0
			if _datos.efecto_especial == &"ejecucion":
				if vida_despues <= 0.0 or (enemigo.has_method("esta_marcado") and enemigo.esta_marcado()):
					_portador.reducir_cooldown(GladiatorController.SLOT_R, 0.70)
					_ya_vinculo = true

		if _datos.provoca and enemigo.has_method("aplicar_provocacion"):
			enemigo.aplicar_provocacion(_portador, maxf(_duracion, 2.0))
		if _golpe_provocado and enemigo.has_method("aplicar_aturdimiento"):
			enemigo.aplicar_aturdimiento(2.6)
		if _datos.vulnerabilidad_magica and enemigo.has_method("aplicar_vulnerabilidad"):
			enemigo.aplicar_vulnerabilidad(maxf(_duracion, 3.0))
		if _datos.efecto_especial == &"raices" and enemigo.has_method("aplicar_aturdimiento"):
			enemigo.aplicar_aturdimiento(maxf(_duracion, 1.8))

	if _cura > 0.0 and _portador != null and is_instance_valid(_portador):
		if _portador.global_position.distance_to(global_position) <= _radio:
			_portador.curar(_cura)
			NumerosDano.mostrar(_portador.global_position + Vector3(0, 1.8, 0), _cura, GladiatorStats.TIPO_VERDADERO, false, true)

	# Sinergia Cetro Q: la espina salta y cura al espíritu o estandarte cercano.
	if _datos.efecto_especial == &"vinculo" and not _ya_vinculo:
		_curar_aliado_cercano()
		_ya_vinculo = true


func _curar_aliado_cercano() -> void:
	var mejor: Node3D = null
	var mejor_distancia := 10.0
	for grupo in [&"aliados", &"banderas"]:
		for nodo in get_tree().get_nodes_in_group(grupo):
			var aliado := nodo as Node3D
			if aliado == null or not aliado.has_method("curar"):
				continue
			var distancia := aliado.global_position.distance_to(global_position)
			if distancia < mejor_distancia:
				mejor_distancia = distancia
				mejor = aliado
	if mejor == null:
		return
	var cantidad := _portador.estadisticas.escalar_invocacion(18.0 + _portador.estadisticas.inteligencia_total * 0.4)
	mejor.curar(cantidad)
	NumerosDano.mostrar(mejor.global_position + Vector3(0, 1.6, 0), cantidad, GladiatorStats.TIPO_VERDADERO, false, true)


func _descarga_encadenada() -> void:
	var candidatos: Array[Node3D] = []
	var distancias: Array[float] = []
	for nodo in get_tree().get_nodes_in_group("enemigos"):
		var enemigo := nodo as Node3D
		if enemigo == null:
			continue
		var distancia := global_position.distance_to(enemigo.global_position)
		if distancia > 12.0:
			continue
		candidatos.append(enemigo)
		distancias.append(distancia)
	var golpeados := 0
	var maximo := 1 + _datos.rebotes
	while golpeados < maximo and not candidatos.is_empty():
		var indice := 0
		for i in candidatos.size():
			if distancias[i] < distancias[indice]:
				indice = i
		var objetivo := candidatos[indice]
		candidatos.remove_at(indice)
		distancias.remove_at(indice)
		_crear_rayo(objetivo.global_position)
		objetivo.recibir_dano(_dano, GladiatorStats.TIPO_MAGICO, _portador)
		_portador.registrar_dano(_dano)
		golpeados += 1


func _crear_rayo(destino: Vector3) -> void:
	var rayo := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.09, 0.09, global_position.distance_to(destino))
	rayo.mesh = caja
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.75, 1.0, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(0.35, 0.65, 1.0)
	material.emission_energy_multiplier = 2.5
	rayo.material_override = material
	add_child(rayo)
	var medio := global_position.lerp(destino, 0.5)
	rayo.global_position = Vector3(medio.x, 0.75, medio.z)
	rayo.look_at(destino, Vector3.UP)
	var tween := rayo.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.32)
	tween.tween_callback(rayo.queue_free)


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
	var tracker = get_tree().get_first_node_in_group("enemy_tracker")
	if tracker != null:
		return tracker.hay_alguno_en_radio(global_position, _radio, Callable(self, "_es_elite"))
	return false

func _es_elite(enemigo: Node3D) -> bool:
	return enemigo.get("es_elite") == true


func _hay_provocado_en_radio() -> bool:
	var tracker = get_tree().get_first_node_in_group("enemy_tracker")
	if tracker != null:
		return tracker.hay_alguno_en_radio(global_position, _radio, Callable(self, "_esta_provocado"))
	return false

func _esta_provocado(enemigo: Node3D) -> bool:
	return enemigo.has_method("esta_provocado") and enemigo.esta_provocado()


func _construir_visual() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(_color.r, _color.g, _color.b, 0.32)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = _color
	material.emission_energy_multiplier = 2.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var disco := MeshInstance3D.new()
	var malla := CylinderMesh.new()
	malla.top_radius = _radio
	malla.bottom_radius = _radio
	malla.height = 0.05
	malla.radial_segments = 32
	disco.mesh = malla
	disco.position.y = 0.05
	disco.material_override = material
	add_child(disco)

	# Anillo nítido que marca el radio exacto.
	var anillo := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = maxf(0.05, _radio - 0.12)
	toro.outer_radius = _radio
	toro.rings = 40
	toro.ring_segments = 8
	anillo.mesh = toro
	anillo.position.y = 0.09
	anillo.material_override = material
	add_child(anillo)

	# Onda de expansión al lanzar.
	var onda := MeshInstance3D.new()
	var toro_onda := TorusMesh.new()
	toro_onda.inner_radius = 0.82
	toro_onda.outer_radius = 1.0
	toro_onda.rings = 32
	toro_onda.ring_segments = 6
	onda.mesh = toro_onda
	onda.position.y = 0.12
	onda.scale = Vector3.ONE * 0.25
	var material_onda := material.duplicate() as StandardMaterial3D
	material_onda.albedo_color = Color(_color.r, _color.g, _color.b, 0.75)
	onda.material_override = material_onda
	add_child(onda)
	var tween := onda.create_tween()
	tween.set_parallel(true)
	tween.tween_property(onda, "scale", Vector3.ONE * _radio, 0.55).set_ease(Tween.EASE_OUT)
	tween.tween_property(material_onda, "albedo_color:a", 0.0, 0.55)
	tween.chain().tween_callback(onda.queue_free)

	# Domo translúcido para zonas persistentes (estandarte, raíces).
	if _duracion > 0.0:
		var domo := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = _radio
		esfera.height = _radio
		esfera.is_hemisphere = true
		esfera.radial_segments = 32
		esfera.rings = 12
		domo.mesh = esfera
		domo.position.y = 0.02
		var material_domo := material.duplicate() as StandardMaterial3D
		material_domo.albedo_color = Color(_color.r, _color.g, _color.b, 0.10)
		material_domo.emission_energy_multiplier = 1.0
		domo.material_override = material_domo
		add_child(domo)

	# Destello central al lanzar la habilidad.
	var destello := MeshInstance3D.new()
	var esfera_destello := SphereMesh.new()
	esfera_destello.radius = _radio * 0.15
	esfera_destello.radial_segments = 16
	esfera_destello.rings = 8
	destello.mesh = esfera_destello
	destello.position.y = 0.08
	var material_destello := StandardMaterial3D.new()
	material_destello.albedo_color = _color
	material_destello.emission_enabled = true
	material_destello.emission = _color
	material_destello.emission_energy_multiplier = 4.0
	material_destello.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_destello.cull_mode = BaseMaterial3D.CULL_DISABLED
	destello.material_override = material_destello
	add_child(destello)
	var tween_d := destello.create_tween()
	tween_d.set_parallel(true)
	tween_d.tween_property(destello, "scale", Vector3.ONE * 3.0, 0.25).set_ease(Tween.EASE_OUT)
	tween_d.tween_property(material_destello, "emission_energy_multiplier", 0.0, 0.25)
	tween_d.chain().tween_callback(destello.queue_free)

	# Partículas de impacto: cubos pequeños que salen disparados desde el centro.
	if _duracion <= 0.0:
		for i in range(6):
			var particula := MeshInstance3D.new()
			var cubo := BoxMesh.new()
			cubo.size = Vector3(0.12, 0.12, 0.12)
			particula.mesh = cubo
			var angulo := float(i) * TAU / 6.0
			var dir := Vector3(cos(angulo), 0.4, sin(angulo))
			var material_p := StandardMaterial3D.new()
			material_p.albedo_color = _color
			material_p.emission_enabled = true
			material_p.emission = _color
			material_p.emission_energy_multiplier = 3.0
			material_p.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			particula.material_override = material_p
			add_child(particula)
			var tween_p := particula.create_tween()
			var destino_p := global_position + dir * _radio
			tween_p.tween_property(particula, "global_position", destino_p, 0.4).set_ease(Tween.EASE_OUT)
			tween_p.tween_property(material_p, "emission_energy_multiplier", 0.0, 0.4)
			tween_p.chain().tween_callback(particula.queue_free)
