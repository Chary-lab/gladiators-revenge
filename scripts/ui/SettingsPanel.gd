class_name SettingsPanel
extends CanvasLayer
## Panel de ajustes: volumen y tamaño de los botones táctiles. Guarda en
## user://ajustes.cfg y aplica al instante.

signal cerrado

var _ajustes: Ajustes
var _escala: HSlider


func configurar() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ajustes = Ajustes.cargar()

	var fondo := ColorRect.new()
	fondo.color = Color(0.03, 0.03, 0.03, 0.82)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var panel := PanelContainer.new()
	panel.theme = ForjaTema.tema_global()
	panel.add_theme_stylebox_override("panel", ForjaTema.estilo_ventana())
	ForjaTema.ornar(panel)
	centro.add_child(panel)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	columna.custom_minimum_size = Vector2(420, 0)
	panel.add_child(columna)

	var titulo := ForjaTema.titulo("AJUSTES", 26, ForjaTema.ORO_CLARO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(titulo)

	columna.add_child(_etiqueta("Volumen general"))
	var volumen := HSlider.new()
	volumen.min_value = 0
	volumen.max_value = 100
	volumen.step = 5
	volumen.value = _ajustes.volumen * 100.0
	volumen.custom_minimum_size = Vector2(420, 26)
	volumen.value_changed.connect(_al_cambiar_volumen)
	columna.add_child(volumen)

	columna.add_child(_etiqueta("Tamaño de los botones táctiles"))
	_escala = HSlider.new()
	_escala.min_value = 75
	_escala.max_value = 150
	_escala.step = 5
	_escala.value = _ajustes.escala_tactil * 100.0
	_escala.custom_minimum_size = Vector2(420, 26)
	_escala.value_changed.connect(_al_cambiar_escala)
	columna.add_child(_escala)

	var cerrar := ForjaTema.boton("CERRAR", 17, true)
	cerrar.custom_minimum_size = Vector2(0, 46)
	cerrar.pressed.connect(_al_cerrar)
	columna.add_child(cerrar)


func _etiqueta(texto: String) -> Label:
	return ForjaTema.rotulo(texto, 12, ForjaTema.TENUE)


func _al_cambiar_volumen(valor: float) -> void:
	_ajustes.volumen = valor / 100.0
	_ajustes.aplicar()
	_ajustes.guardar()


func _al_cambiar_escala(valor: float) -> void:
	_ajustes.escala_tactil = valor / 100.0
	_ajustes.guardar()


func _al_cerrar() -> void:
	cerrado.emit()
	queue_free()
