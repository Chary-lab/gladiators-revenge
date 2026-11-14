class_name NombreJugador
extends CanvasLayer
## Primera pantalla de la partida: el apodo del gladiador.
##
## Se muestra antes de la forja de campeones y sólo la primera vez (se recuerda
## en `user://perfil.cfg`). Es texto y poco más: la identidad del jugador en su
## ficha del HUD.

signal confirmado(apodo: String)

var _campo: LineEdit
var _aviso: Label
var _boton: Button


func configurar() -> void:
	layer = 62
	process_mode = Node.PROCESS_MODE_ALWAYS

	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme = ForjaTema.tema_global()
	add_child(raiz)

	var fondo := FondoForja.new()
	fondo.intensidad = 1.2
	fondo.velo = 0.55
	raiz.add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(centro)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", ForjaTema.estilo_ventana())
	ForjaTema.ornar(panel)
	centro.add_child(panel)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	panel.add_child(columna)

	var titulo := ForjaTema.titulo("¿CÓMO TE LLAMAN?", 30, ForjaTema.ORO_CLARO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(titulo)

	var sub := ForjaTema.etiqueta(
		"Tu apodo encabeza la ficha de la arena y te sigue en la partida.", 12, ForjaTema.TENUE, true
	)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(sub)

	var divisor := CenterContainer.new()
	columna.add_child(divisor)
	divisor.add_child(ForjaTema.regla(220))

	var rotulo_campo := ForjaTema.rotulo("TU APODO", 10, ForjaTema.TENUE)
	columna.add_child(rotulo_campo)

	_campo = LineEdit.new()
	_campo.max_length = Perfil.LARGO_MAXIMO
	_campo.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_campo.placeholder_text = "Escribí tu apodo…"
	_campo.custom_minimum_size = Vector2(0, 54)
	# Texto de campo con la sans del motor (no la de títulos): así se lee como
	# algo que se escribe y no como un rótulo grabado.
	_campo.add_theme_font_size_override("font_size", 22)
	_campo.add_theme_color_override("font_color", ForjaTema.TEXTO_FUERTE)
	_campo.add_theme_color_override("font_placeholder_color", Color(0.55, 0.48, 0.38, 0.8))
	_campo.add_theme_color_override("caret_color", ForjaTema.ORO_CLARO)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.048, 0.040, 0.98)
	normal.border_color = ForjaTema.ORO_OSCURO
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	_campo.add_theme_stylebox_override("normal", normal)
	var foco := normal.duplicate() as StyleBoxFlat
	foco.border_color = ForjaTema.ORO_CLARO
	foco.set_border_width_all(2)
	_campo.add_theme_stylebox_override("focus", foco)
	_campo.text_changed.connect(_al_escribir)
	_campo.text_submitted.connect(func(_t: String) -> void: _confirmar())
	columna.add_child(_campo)

	_aviso = ForjaTema.etiqueta("Entre 2 y %d letras." % Perfil.LARGO_MAXIMO, 10, ForjaTema.TENUE, true)
	columna.add_child(_aviso)

	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(0, 6)
	columna.add_child(hueco)

	_boton = ForjaTema.boton("ENTRAR A LA ARENA", 18, true)
	_boton.custom_minimum_size = Vector2(0, 52)
	_boton.pressed.connect(_confirmar)
	columna.add_child(_boton)

	var pista := ForjaTema.etiqueta("Enter también sirve · se guarda para la próxima vez", 10, ForjaTema.TENUE, true)
	columna.add_child(pista)

	_campo.text = Perfil.apodo()
	_campo.grab_focus()
	_campo.caret_column = _campo.text.length()
	# Pulso suave del borde: la única pieza que se puede tocar tiene que moverse.
	var brillo := create_tween().set_loops()
	brillo.tween_property(_campo, "modulate", Color(1.0, 0.97, 0.90, 1.0), 1.1)
	brillo.tween_property(_campo, "modulate", Color(1, 1, 1, 1), 1.1)


func _al_escribir(_texto: String) -> void:
	if _aviso != null:
		_aviso.text = "Entre 2 y %d letras." % Perfil.LARGO_MAXIMO
		_aviso.add_theme_color_override("font_color", ForjaTema.TENUE)


func _confirmar() -> void:
	var apodo := Perfil.normalizar(_campo.text)
	if apodo.length() < 2:
		_aviso.text = "Elegí un apodo de al menos 2 letras."
		_aviso.add_theme_color_override("font_color", Color(1.0, 0.55, 0.42))
		_campo.grab_focus()
		return
	Sfx.reproducir(&"click", -8.0)
	confirmado.emit(apodo)
	queue_free()
