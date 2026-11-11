class_name ItemModelFactory
extends RefCounted
## Construye miniaturas 3D con primitivas propias (sin arte de terceros).
## Se usan tanto en la tienda como en la consola inferior y en IconStudio.

const ACERO := Color(0.72, 0.76, 0.80)
const ACERO_OSCURO := Color(0.28, 0.31, 0.35)
const ORO := Color(0.95, 0.72, 0.28)
const MADERA := Color(0.34, 0.20, 0.10)
const CUERO := Color(0.30, 0.16, 0.08)
const SANGRE := Color(0.72, 0.10, 0.10)
const ESMERALDA := Color(0.10, 0.72, 0.42)
const ZAFIRO := Color(0.18, 0.38, 0.92)
const AMATISTA := Color(0.58, 0.24, 0.86)


static func crear(identificador: StringName, categoria: StringName = &"objeto") -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Miniatura"
	match categoria:
		&"habilidad":
			_habilidad(raiz, identificador)
		&"comando":
			_comando(raiz, identificador)
		_:
			_objeto(raiz, identificador)
	return raiz


static func _objeto(raiz: Node3D, id: StringName) -> void:
	var texto := String(id)
	if texto.begins_with("pocion"):
		_pocion(raiz, ZAFIRO if texto.contains("mana") else SANGRE)
	elif texto.begins_with("pergamino"):
		_pergamino(raiz, ORO if texto.contains("furia") else (Color(0.30, 0.80, 1.0) if texto.contains("egida") else Color(0.60, 0.72, 0.95)))
	elif texto == "brasa_forja":
		_gema(raiz, Color(1.0, 0.34, 0.10), 0.42)
	elif texto == "pluma_espectral":
		_pluma(raiz, Color(0.55, 0.95, 1.0))
	elif texto == "cristal_ancestral":
		_cristal(raiz, ZAFIRO)
	elif texto == "placa_oxidada":
		_escudo(raiz, Color(0.48, 0.36, 0.24))
	elif texto == "engranaje_ritual":
		_engranaje(raiz, ORO)
	elif texto == "raiz_savia":
		_raiz(raiz, ESMERALDA)
	elif texto == "nucleo_ferreo":
		_corazon(raiz, Color(0.95, 0.30, 0.16))
	elif texto == "furia_tormenta":
		_gema(raiz, Color(1.0, 0.55, 0.10), 0.48)
	elif texto == "ojo_halcon":
		_ojo(raiz, Color(1.0, 0.86, 0.30))
	elif texto == "corona_runica":
		_corona(raiz, AMATISTA)
	elif texto == "piel_basalto":
		_escudo(raiz, Color(0.42, 0.24, 0.14))
	elif texto == "sello_arcano":
		_sello(raiz, AMATISTA)
	elif texto == "corazon_obsidiana":
		_corazon(raiz, Color(0.85, 0.08, 0.14), true)
	elif texto == "daga_eclipse":
		_daga(raiz, Color(0.55, 0.30, 0.95))
	elif texto == "orbe_cataclismo":
		_orbe(raiz, ZAFIRO, true)
	elif texto == "cuerno_rebelion":
		_cuerno(raiz, ORO)
	else:
		_gema(raiz, Color(0.78, 0.56, 0.24), 0.42)


static func _habilidad(raiz: Node3D, id: StringName) -> void:
	var texto := String(id)
	if texto.contains("bastion") or texto.contains("muro") or texto.contains("provoca"):
		_escudo(raiz, ACERO)
		if texto.contains("sismico"):
			_martillo(raiz, ACERO_OSCURO)
	elif texto.contains("filo") or texto.contains("tajo") or texto.contains("ejecucion") or texto.contains("marca"):
		_daga(raiz, SANGRE if texto.contains("marca") else ACERO)
	elif texto.contains("paso"):
		_botas(raiz, Color(0.22, 0.18, 0.28))
	elif texto.contains("cetro") or texto.contains("espiritu") or texto.contains("raices") or texto.contains("estandarte"):
		_orbe(raiz, ESMERALDA, texto.contains("espiritu"))
	elif texto.contains("prisionero"):
		_puno(raiz)
	else:
		_gema(raiz, AMATISTA, 0.40)


static func _comando(raiz: Node3D, id: StringName) -> void:
	match String(id):
		"atacar":
			_espada_cruzada(raiz)
		"detener":
			_mano(raiz)
		"mantener":
			_escudo(raiz, ACERO)
		"skin":
			_yelmo(raiz, ESMERALDA)
		"atributos":
			_flecha(raiz, Color(1.0, 0.82, 0.16))
		"talentos":
			_arbol_runico(raiz)
		"tienda":
			_moneda(raiz)
		"estadisticas":
			_barras(raiz)
		_:
			_gema(raiz, AMATISTA, 0.4)


# --- Piezas ---------------------------------------------------------------

static func _mat(color: Color, metal := 0.0, brillo := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.34 if metal > 0.0 else 0.62
	if brillo > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = brillo
	return m


static func _malla(raiz: Node3D, malla: Mesh, color: Color, pos := Vector3.ZERO, metal := 0.0, brillo := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = _mat(color, metal, brillo)
	mi.position = pos
	raiz.add_child(mi)
	return mi


static func _caja(raiz: Node3D, tam: Vector3, color: Color, pos := Vector3.ZERO, metal := 0.0, brillo := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = tam
	return _malla(raiz, mesh, color, pos, metal, brillo)


static func _cilindro(raiz: Node3D, radio: float, alto: float, color: Color, pos := Vector3.ZERO, metal := 0.0, brillo := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radio
	mesh.bottom_radius = radio
	mesh.height = alto
	return _malla(raiz, mesh, color, pos, metal, brillo)


static func _esfera(raiz: Node3D, radio: float, color: Color, pos := Vector3.ZERO, metal := 0.0, brillo := 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radio
	mesh.height = radio * 2.0
	return _malla(raiz, mesh, color, pos, metal, brillo)


static func _cono(raiz: Node3D, radio: float, alto: float, color: Color, pos := Vector3.ZERO, metal := 0.0, brillo := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radio
	mesh.height = alto
	return _malla(raiz, mesh, color, pos, metal, brillo)


static func _anillo(raiz: Node3D, interior: float, exterior: float, color: Color, pos := Vector3.ZERO, brillo := 1.0) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = interior
	mesh.outer_radius = exterior
	return _malla(raiz, mesh, color, pos, 0.0, brillo)


static func _espada(raiz: Node3D, color: Color) -> void:
	_caja(raiz, Vector3(0.14, 1.15, 0.06), color, Vector3(0, 0.40, 0), 1.0)
	_caja(raiz, Vector3(0.52, 0.08, 0.12), ORO, Vector3(0, -0.18, 0), 0.8)
	_cilindro(raiz, 0.055, 0.38, MADERA, Vector3(0, -0.42, 0))
	_esfera(raiz, 0.075, ORO, Vector3(0, -0.62, 0), 0.8)


static func _daga(raiz: Node3D, color: Color) -> void:
	_caja(raiz, Vector3(0.10, 0.86, 0.05), color, Vector3(0, 0.32, 0), 1.0)
	_caja(raiz, Vector3(0.34, 0.07, 0.10), ORO, Vector3(0, -0.12, 0), 0.8)
	_cilindro(raiz, 0.045, 0.30, CUERO, Vector3(0, -0.30, 0))
	_cono(raiz, 0.06, 0.16, color, Vector3(0, 0.93, 0), 1.0)


static func _espada_cruzada(raiz: Node3D) -> void:
	var a := Node3D.new()
	raiz.add_child(a)
	_espada(a, ACERO)
	a.rotation_degrees = Vector3(0, 0, -32)
	a.position = Vector3(-0.18, 0, 0)
	var b := Node3D.new()
	raiz.add_child(b)
	_espada(b, ACERO)
	b.rotation_degrees = Vector3(0, 0, 32)
	b.position = Vector3(0.18, 0, 0)


static func _escudo(raiz: Node3D, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.58
	mesh.bottom_radius = 0.50
	mesh.height = 0.14
	var escudo := _malla(raiz, mesh, color, Vector3(0, 0.1, 0), 0.5)
	escudo.rotation_degrees = Vector3(90, 0, 0)
	_esfera(raiz, 0.16, ORO, Vector3(0, 0.1, 0.12), 0.9)
	_caja(raiz, Vector3(0.08, 0.72, 0.05), ORO, Vector3(0, 0.1, 0.02), 0.8)


static func _yelmo(raiz: Node3D, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.46
	mesh.height = 0.62
	mesh.is_hemisphere = true
	var casco := _malla(raiz, mesh, color, Vector3(0, 0.12, 0), 0.7)
	casco.rotation_degrees = Vector3(0, 0, 0)
	_caja(raiz, Vector3(0.72, 0.10, 0.34), color, Vector3(0, -0.14, 0), 0.7)
	_caja(raiz, Vector3(0.06, 0.18, 0.46), ORO, Vector3(0, 0.28, 0), 0.8)
	_cono(raiz, 0.10, 0.34, ORO, Vector3(-0.40, 0.34, 0))
	_cono(raiz, 0.10, 0.34, ORO, Vector3(0.40, 0.34, 0))


static func _pocion(raiz: Node3D, color: Color) -> void:
	_esfera(raiz, 0.40, color, Vector3(0, -0.14, 0), 0.0, 1.1)
	_esfera(raiz, 0.13, Color(1, 1, 1, 0.55), Vector3(-0.13, 0.02, 0.28), 0.0, 1.4)
	_cilindro(raiz, 0.14, 0.32, Color(0.70, 0.82, 0.84), Vector3(0, 0.30, 0))
	_cilindro(raiz, 0.17, 0.12, CUERO, Vector3(0, 0.48, 0))
	_cilindro(raiz, 0.10, 0.06, ORO, Vector3(0, 0.40, 0))


static func _pergamino(raiz: Node3D, color: Color) -> void:
	_caja(raiz, Vector3(0.58, 0.72, 0.04), Color(0.92, 0.84, 0.64), Vector3(0, 0.08, 0), 0.0, 0.15)
	_cilindro(raiz, 0.09, 0.70, color, Vector3(-0.30, 0.08, 0))
	var der := _cilindro(raiz, 0.09, 0.70, color, Vector3(0.30, 0.08, 0))
	der.rotation_degrees = Vector3(0, 0, 0)
	_caja(raiz, Vector3(0.34, 0.05, 0.05), color, Vector3(0, 0.05, 0.05), 0.0, 0.9)


static func _gema(raiz: Node3D, color: Color, tam: float) -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(tam, tam * 1.25, tam)
	_malla(raiz, mesh, color, Vector3(0, 0.12, 0), 0.2, 0.8)
	_anillo(raiz, tam * 0.72, tam * 0.82, ORO, Vector3(0, -0.38, 0), 0.5)


static func _cristal(raiz: Node3D, color: Color) -> void:
	_cono(raiz, 0.30, 0.85, color, Vector3(0, 0.18, 0), 0.1, 0.9)
	_cono(raiz, 0.18, 0.52, color, Vector3(-0.26, 0.02, 0.10), 0.1, 0.7)
	_cono(raiz, 0.15, 0.40, color, Vector3(0.26, -0.06, -0.08), 0.1, 0.7)


static func _corazon(raiz: Node3D, color: Color, legendario := false) -> void:
	_esfera(raiz, 0.34, color, Vector3(-0.15, 0.10, 0), 0.2, 1.2)
	_esfera(raiz, 0.34, color, Vector3(0.15, 0.10, 0), 0.2, 1.2)
	_cono(raiz, 0.46, 0.55, color, Vector3(0, -0.30, 0), 0.1, 1.0).rotation_degrees = Vector3(180, 0, 0)
	if legendario:
		_anillo(raiz, 0.48, 0.56, ORO, Vector3(0, 0.02, 0), 1.5)


static func _orbe(raiz: Node3D, color: Color, brillante := false) -> void:
	_esfera(raiz, 0.34, color, Vector3(0, 0.08, 0), 0.1, 1.4 if brillante else 0.7)
	_anillo(raiz, 0.40, 0.47, ORO, Vector3(0, 0.08, 0), 0.9)
	var a := _cilindro(raiz, 0.035, 0.90, MADERA, Vector3(0, -0.46, 0))
	a.rotation_degrees = Vector3(0, 0, 0)
	_caja(raiz, Vector3(0.22, 0.10, 0.22), ORO, Vector3(0, 0.08, 0), 0.8)


static func _pluma(raiz: Node3D, color: Color) -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.42, 1.15, 0.06)
	var pluma := _malla(raiz, mesh, color, Vector3(0, 0.18, 0), 0.0, 0.9)
	pluma.rotation_degrees = Vector3(0, 0, 12)
	_cilindro(raiz, 0.025, 1.20, Color(0.85, 0.88, 0.92), Vector3(0, 0.12, 0))


static func _raiz(raiz: Node3D, color: Color) -> void:
	for i in 3:
		var c := _cilindro(raiz, 0.08, 0.82, color, Vector3(-0.24 + i * 0.24, 0.10, 0.0))
		c.rotation_degrees = Vector3(0, 0, -18 + i * 18)
	_esfera(raiz, 0.12, color, Vector3(0, 0.48, 0), 0.0, 0.4)


static func _engranaje(raiz: Node3D, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.44
	mesh.bottom_radius = 0.44
	mesh.height = 0.14
	var g := _malla(raiz, mesh, color, Vector3(0, 0.08, 0), 0.9)
	g.rotation_degrees = Vector3(90, 0, 0)
	_cilindro(raiz, 0.16, 0.16, Color(0.12, 0.10, 0.08), Vector3(0, 0.08, 0.03), 0.4).rotation_degrees = Vector3(90, 0, 0)
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var diente := _caja(raiz, Vector3(0.14, 0.16, 0.12), color, Vector3(cos(ang) * 0.46, sin(ang) * 0.46 + 0.08, 0), 0.9)
		diente.rotation_degrees = Vector3(0, 0, rad_to_deg(ang))


static func _ojo(raiz: Node3D, color: Color) -> void:
	_esfera(raiz, 0.40, Color(0.92, 0.90, 0.82), Vector3(0, 0.10, 0))
	_esfera(raiz, 0.18, color, Vector3(0, 0.10, 0.30), 0.1, 1.3)
	_esfera(raiz, 0.07, Color(0.06, 0.05, 0.04), Vector3(0, 0.10, 0.44))
	_anillo(raiz, 0.43, 0.49, ORO, Vector3(0, 0.10, 0.0), 0.8)


static func _corona(raiz: Node3D, color: Color) -> void:
	_cilindro(raiz, 0.40, 0.22, color, Vector3(0, -0.10, 0), 0.7, 0.6)
	for i in 5:
		var ang := TAU * float(i) / 5.0
		_cono(raiz, 0.10, 0.38, ORO, Vector3(cos(ang) * 0.32, 0.20, sin(ang) * 0.32), 0.8, 0.5)
	_esfera(raiz, 0.09, color, Vector3(0, 0.08, 0), 0.0, 1.2)


static func _sello(raiz: Node3D, color: Color) -> void:
	_cilindro(raiz, 0.42, 0.12, color, Vector3(0, 0.02, 0), 0.4, 0.6)
	_anillo(raiz, 0.36, 0.42, ORO, Vector3(0, 0.02, 0), 0.8)
	_esfera(raiz, 0.12, color, Vector3(0, 0.08, 0), 0.0, 1.5)
	for i in 4:
		var ang := TAU * float(i) / 4.0
		_caja(raiz, Vector3(0.08, 0.08, 0.28), ORO, Vector3(cos(ang) * 0.22, 0.02, sin(ang) * 0.22), 0.8).rotation_degrees = Vector3(0, rad_to_deg(ang), 0)


static func _daga_eclipse(raiz: Node3D) -> void:
	_daga(raiz, Color(0.55, 0.30, 0.95))


static func _martillo(raiz: Node3D, color: Color) -> void:
	_cilindro(raiz, 0.055, 1.25, MADERA, Vector3(0, 0.05, 0))
	_caja(raiz, Vector3(0.62, 0.28, 0.28), color, Vector3(0, 0.70, 0), 1.0)
	_caja(raiz, Vector3(0.72, 0.10, 0.34), ORO, Vector3(0, 0.70, 0), 0.8)


static func _botas(raiz: Node3D, color: Color) -> void:
	_caja(raiz, Vector3(0.24, 0.42, 0.26), color, Vector3(-0.18, 0.18, 0))
	_caja(raiz, Vector3(0.24, 0.42, 0.26), color, Vector3(0.18, 0.18, 0))
	_caja(raiz, Vector3(0.24, 0.16, 0.46), CUERO, Vector3(-0.18, -0.08, 0.10))
	_caja(raiz, Vector3(0.24, 0.16, 0.46), CUERO, Vector3(0.18, -0.08, 0.10))
	_caja(raiz, Vector3(0.28, 0.06, 0.28), ORO, Vector3(-0.18, 0.40, 0), 0.6)
	_caja(raiz, Vector3(0.28, 0.06, 0.28), ORO, Vector3(0.18, 0.40, 0), 0.6)


static func _puno(raiz: Node3D) -> void:
	_esfera(raiz, 0.30, Color(0.36, 0.52, 0.22), Vector3(0, 0.10, 0))
	for i in 3:
		_esfera(raiz, 0.11, Color(0.36, 0.52, 0.22), Vector3(-0.18 + i * 0.18, 0.34, 0.18))
	_cilindro(raiz, 0.18, 0.30, CUERO, Vector3(0, -0.22, 0))


static func _mano(raiz: Node3D) -> void:
	_esfera(raiz, 0.28, Color(0.70, 0.52, 0.36), Vector3(0, 0.0, 0))
	for i in 4:
		var dedo := _cilindro(raiz, 0.075, 0.42, Color(0.70, 0.52, 0.36), Vector3(-0.18 + i * 0.12, 0.34, 0))
		dedo.rotation_degrees = Vector3(0, 0, 0)
	_caja(raiz, Vector3(0.64, 0.12, 0.20), ORO, Vector3(0, -0.34, 0), 0.5)


static func _flecha(raiz: Node3D, color: Color) -> void:
	_cilindro(raiz, 0.055, 1.10, MADERA, Vector3(0, 0.0, 0))
	_cono(raiz, 0.18, 0.34, color, Vector3(0, 0.66, 0), 0.0, 1.1)
	_caja(raiz, Vector3(0.30, 0.18, 0.05), SANGRE, Vector3(0, -0.44, 0))


static func _arbol_runico(raiz: Node3D) -> void:
	_cilindro(raiz, 0.10, 0.95, MADERA, Vector3(0, -0.02, 0))
	for i in 4:
		var ang := TAU * float(i) / 4.0
		var rama := _cilindro(raiz, 0.055, 0.50, Color(0.22, 0.58, 0.32), Vector3(cos(ang) * 0.20, 0.34, sin(ang) * 0.20))
		rama.rotation_degrees = Vector3(rad_to_deg(ang) * 0.0, 0, 32 if i % 2 == 0 else -32)
		_esfera(raiz, 0.10, Color(0.48, 1.0, 0.62), Vector3(cos(ang) * 0.34, 0.54, sin(ang) * 0.34), 0.0, 1.2)
	_anillo(raiz, 0.30, 0.36, ORO, Vector3(0, 0.30, 0), 0.7)


static func _moneda(raiz: Node3D) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.42
	mesh.height = 0.10
	var moneda := _malla(raiz, mesh, ORO, Vector3(0, 0.05, 0), 1.0)
	moneda.rotation_degrees = Vector3(90, 0, 0)
	_anillo(raiz, 0.34, 0.40, Color(0.72, 0.50, 0.14), Vector3(0, 0.05, 0.02), 0.4)
	_caja(raiz, Vector3(0.12, 0.34, 0.05), Color(0.55, 0.36, 0.08), Vector3(0, 0.05, 0.08), 0.6)


static func _barras(raiz: Node3D) -> void:
	_caja(raiz, Vector3(0.16, 0.50, 0.16), Color(0.9, 0.35, 0.20), Vector3(-0.28, -0.02, 0), 0.0, 0.7)
	_caja(raiz, Vector3(0.16, 0.86, 0.16), Color(0.95, 0.75, 0.20), Vector3(0.0, 0.16, 0), 0.0, 0.7)
	_caja(raiz, Vector3(0.16, 1.10, 0.16), Color(0.25, 0.80, 0.45), Vector3(0.28, 0.28, 0), 0.0, 0.7)
	_caja(raiz, Vector3(0.90, 0.06, 0.24), Color(0.16, 0.14, 0.12), Vector3(0, -0.42, 0))


static func _cuerno(raiz: Node3D, color: Color) -> void:
	var cuerno := _cono(raiz, 0.22, 1.00, Color(0.88, 0.80, 0.62), Vector3(0, 0.18, 0))
	cuerno.rotation_degrees = Vector3(0, 0, 18)
	_anillo(raiz, 0.20, 0.27, color, Vector3(0, -0.28, 0), 1.0)
	_anillo(raiz, 0.16, 0.22, color, Vector3(0.10, -0.06, 0), 1.0)
	_caja(raiz, Vector3(0.42, 0.08, 0.08), color, Vector3(0.28, 0.58, 0), 0.6, 0.8)
