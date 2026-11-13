class_name SeleccionCampeon
extends CanvasLayer
## Pantalla de selección de campeón: rombos de clase a la izquierda, ficha del
## campeón en el centro y estadísticas/habilidades a la derecha.
##
## Es pura presentación: recibe una lista de diccionarios ya calculados por la
## arena (`clase`, `nombre`, `lema`, `vida`, `mana`, `dano_min`, `dano_max`,
## `defensa`, `habilidades` como Array de diccionarios con `nombre` y `tecla`).

signal elegido(clase: StringName)
signal cerrado

var _perfiles: Array = []
var _indice := 0
var _actual: StringName = &""
var _emblemas: Array = []
var _marca: ForjaTema.Emblema
var _nombre: Label
var _lema: Label
var _barras: Array = []
var _valores: Array = []
var _tiles: Array = []
var _btn_elegir: Button
var _armado := false


func configurar(perfiles: Array, actual: StringName = &"") -> void:
	_perfiles = perfiles
	_actual = actual
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in perfiles.size():
		if StringName(perfiles[i].get("clase", "")) == actual:
			_indice = i
	_construir()
	_actualizar()


func _construir() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.035, 0.030, 0.026)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	# Marco de pergamino: cuatro hairline doradas dentro del margen.
	var marco := ColorRect.new()
	marco.color = Color(0, 0, 0, 0)
	marco.set_anchors_preset(Control.PRESET_FULL_RECT)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(marco)
	_borde(raiz, Vector2(28, 28), Vector2(1224, 1))
	_borde(raiz, Vector2(28, 691), Vector2(1224, 1))
	_borde(raiz, Vector2(28, 28), Vector2(1, 664))
	_borde(raiz, Vector2(1251, 28), Vector2(1, 664))

	# Cabecera.
	var titulo := ForjaTema.etiqueta("FORJA DE CAMPEONES", 22, ForjaTema.ORO_CLARO)
	titulo.position = Vector2(56, 44)
	raiz.add_child(titulo)
	var sub := ForjaTema.etiqueta("El campeón que elijas es permanente en esta partida", 13, ForjaTema.TENUE)
	sub.position = Vector2(56, 74)
	raiz.add_child(sub)
	_borde(raiz, Vector2(56, 98), Vector2(320, 1), ForjaTema.ORO_OSCURO)

	# Emblemas de clase (izquierda).
	for i in _perfiles.size():
		var perfil: Dictionary = _perfiles[i]
		var clase := StringName(perfil.get("clase", ""))
		var boton := Button.new()
		boton.flat = true
		boton.focus_mode = Control.FOCUS_NONE
		boton.position = Vector2(52, 150 + i * 128)
		boton.size = Vector2(104, 104)
		var vacio := StyleBoxEmpty.new()
		for estado in ["normal", "hover", "pressed", "focus"]:
			boton.add_theme_stylebox_override(estado, vacio)
		var emblema := ForjaTema.Emblema.new(clase, 86.0)
		emblema.position = Vector2(9, 9)
		boton.add_child(emblema)
		var etiqueta := ForjaTema.etiqueta(
			String(ForjaTema.NOMBRE_EMBLEMA.get(clase, "?")), 11, ForjaTema.TENUE
		)
		etiqueta.position = Vector2(0, 92)
		etiqueta.size = Vector2(104, 0)
		etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boton.add_child(etiqueta)
		boton.pressed.connect(_seleccionar.bind(i))
		raiz.add_child(boton)
		_emblemas.append(emblema)

	# Marca grande de agua del campeón centrada.
	_marca = ForjaTema.Emblema.new(&"bastion", 250.0)
	_marca.position = Vector2(330, 168)
	raiz.add_child(_marca)

	_nombre = ForjaTema.etiqueta("", 54, ForjaTema.ORO_CLARO)
	_nombre.position = Vector2(320, 452)
	_nombre.size = Vector2(460, 0)
	raiz.add_child(_nombre)

	_lema = ForjaTema.etiqueta("", 14, ForjaTema.TENUE)
	_lema.position = Vector2(322, 522)
	_lema.size = Vector2(430, 0)
	_lema.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	raiz.add_child(_lema)

	# Ficha de la derecha.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ForjaTema.estilo_panel())
	panel.position = Vector2(800, 120)
	panel.size = Vector2(424, 470)
	raiz.add_child(panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 9)
	panel.add_child(columna)

	columna.add_child(ForjaTema.etiqueta("ESTADÍSTICAS", 13, ForjaTema.ORO))
	for _i in 4:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 10)
		var etiqueta := ForjaTema.etiqueta("", 12, ForjaTema.TEXTO)
		etiqueta.custom_minimum_size = Vector2(92, 0)
		fila.add_child(etiqueta)
		var barra := ForjaTema.BarraSegmentada.new(0.5)
		barra.custom_minimum_size = Vector2(210, 11)
		barra.alto = 11
		fila.add_child(barra)
		var valor := ForjaTema.etiqueta("", 12, ForjaTema.ORO_CLARO)
		valor.custom_minimum_size = Vector2(64, 0)
		valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fila.add_child(valor)
		columna.add_child(fila)
		_barras.append(barra)
		_valores.append(valor)

	var espacio := Control.new()
	espacio.custom_minimum_size = Vector2(0, 6)
	columna.add_child(espacio)
	columna.add_child(ForjaTema.etiqueta("HABILIDADES", 13, ForjaTema.ORO))

	var fila_tiles := HBoxContainer.new()
	fila_tiles.add_theme_constant_override("separation", 8)
	columna.add_child(fila_tiles)
	for i in 3:
		var tile := PanelContainer.new()
		var estilo := ForjaTema.estilo_panel(1.0, ForjaTema.ORO_OSCURO)
		estilo.content_margin_left = 8
		estilo.content_margin_right = 8
		estilo.content_margin_top = 6
		estilo.content_margin_bottom = 6
		tile.add_theme_stylebox_override("panel", estilo)
		tile.custom_minimum_size = Vector2(126, 62)
		var dentro := VBoxContainer.new()
		dentro.add_theme_constant_override("separation", 2)
		tile.add_child(dentro)
		var tecla := ForjaTema.etiqueta(["Q", "W", "E"][i], 17, ForjaTema.ORO_CLARO, true)
		dentro.add_child(tecla)
		var nombre_hab := ForjaTema.etiqueta("", 10, ForjaTema.TENUE, true)
		nombre_hab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dentro.add_child(nombre_hab)
		fila_tiles.add_child(tile)
		_tiles.append(nombre_hab)

	var relleno := Control.new()
	relleno.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(relleno)

	_btn_elegir = ForjaTema.boton("ELEGIR CAMPEÓN", 17, true)
	_btn_elegir.custom_minimum_size = Vector2(0, 50)
	_btn_elegir.pressed.connect(_confirmar)
	columna.add_child(_btn_elegir)

	var salir := ForjaTema.boton("VOLVER", 13)
	salir.position = Vector2(56, 630)
	salir.custom_minimum_size = Vector2(120, 40)
	salir.pressed.connect(_cerrar)
	raiz.add_child(salir)

	var ayuda := ForjaTema.etiqueta("1/2/3 para cambiar · Enter para confirmar", 11, ForjaTema.TENUE)
	ayuda.position = Vector2(196, 640)
	raiz.add_child(ayuda)


func _borde(padre: Node, posicion: Vector2, tamano: Vector2, color := ForjaTema.ORO_OSCURO) -> void:
	var linea := ColorRect.new()
	linea.color = color
	linea.position = posicion
	linea.size = tamano
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(linea)


func _seleccionar(indice: int) -> void:
	_indice = clampi(indice, 0, _perfiles.size() - 1)
	_actualizar()
	Sfx.reproducir("click", -6.0)


func _actualizar() -> void:
	if _perfiles.is_empty():
		return
	var perfil: Dictionary = _perfiles[_indice]
	var clase := StringName(perfil.get("clase", ""))
	for i in _emblemas.size():
		_emblemas[i].seleccionado = i == _indice
		_emblemas[i].queue_redraw()
	_marca.clase = clase
	_marca.seleccionado = true
	_marca.queue_redraw()
	_nombre.text = String(perfil.get("nombre", "")).to_upper()
	_lema.text = String(perfil.get("lema", ""))

	var vida := float(perfil.get("vida", 100.0))
	var mana := float(perfil.get("mana", 60.0))
	var dano := Vector2(float(perfil.get("dano_min", 4.0)), float(perfil.get("dano_max", 6.0)))
	var defensa := float(perfil.get("defensa", 0.0))
	var filas := [
		["VIDA", clampf(vida / 260.0, 0.0, 1.0), "%d" % int(vida), ForjaTema.VIDA],
		["MANÁ", clampf(mana / 180.0, 0.0, 1.0), "%d" % int(mana), ForjaTema.MANA],
		["DAÑO", clampf(dano.y / 40.0, 0.0, 1.0), "%d-%d" % [int(dano.x), int(dano.y)], ForjaTema.ORO],
		["DEFENSA", clampf(defensa / 0.6, 0.0, 1.0), "%d %%" % int(round(defensa * 100.0)), ForjaTema.TEXTO],
	]
	for i in _barras.size():
		var fila: Array = filas[i]
		_barras[i].valor = float(fila[1])
		_barras[i].color = fila[3]
		_barras[i].queue_redraw()
		_valores[i].text = String(fila[2])
		# La etiqueta de cada fila vive como primer hijo del HBox.
		var contenedor: HBoxContainer = _barras[i].get_parent()
		(contenedor.get_child(0) as Label).text = String(fila[0])

	var habilidades: Array = perfil.get("habilidades", [])
	for i in _tiles.size():
		var texto := "—"
		if i < habilidades.size():
			texto = String((habilidades[i] as Dictionary).get("nombre", "—"))
		(_tiles[i] as Label).text = texto

	# Si ya tenía campeón, el botón lo dice y no se puede repetir.
	if _actual != &"" and clase == _actual:
		_btn_elegir.text = "CAMPEÓN ACTUAL"
		_btn_elegir.disabled = true
	else:
		_btn_elegir.text = "ELEGIR CAMPEÓN"
		_btn_elegir.disabled = false


func _confirmar() -> void:
	if _perfiles.is_empty() or _btn_elegir.disabled:
		return
	var clase := StringName(_perfiles[_indice].get("clase", ""))
	_armado = true
	elegido.emit(clase)
	queue_free()


func _cerrar() -> void:
	cerrado.emit()
	queue_free()


func _input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	match (evento as InputEventKey).keycode:
		KEY_1, KEY_2, KEY_3:
			_seleccionar((evento as InputEventKey).keycode - KEY_1)
		KEY_ENTER, KEY_KP_ENTER:
			_confirmar()
		KEY_ESCAPE:
			_cerrar()
