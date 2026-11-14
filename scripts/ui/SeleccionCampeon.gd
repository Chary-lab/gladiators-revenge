class_name SeleccionCampeon
extends CanvasLayer
## Forja de Campeones: la pantalla de selección de clase, con el gladiador en
## tamaño héroe como pieza central.
##
## Tres zonas, como una ficha de personaje de RPG: el riel de clases a la
## izquierda, la vitrina 3D en el centro y la ficha a la derecha (nombre, rol,
## nivel, atributos, estadísticas con barras, habilidades y equipo). Es pura
## presentación: recibe los perfiles ya calculados por la arena y devuelve la
## clase elegida.

signal elegido(clase: StringName)
signal cerrado
## El jugador pidió cambiar el aspecto (piel) del gladiador sin salir del modal.
signal piel_siguiente

var _perfiles: Array = []
var _indice := 0
var _actual: StringName = &""
var _emblemas: Array = []
var _marca: ForjaTema.Emblema
var _vitrina: VitrinaCampeon
var _nombre: Label
var _lema: Label
var _descripcion: Label
var _rol: Label
var _barras: Array = []
var _valores: Array = []
var _tiles: Array = []
var _detalle_habilidad: Label
var _derivados: Array = []
var _atributos: Array = []
var _btn_elegir: Button
var _piel: Label
var _ranuras: Array = []
var _xp_texto: Label
var _volver: Button
var _xp_barra: ProgressBar
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


# --- Construcción -----------------------------------------------------------

func _construir() -> void:
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme = ForjaTema.tema_global()
	add_child(raiz)

	var fondo := FondoForja.new()
	fondo.intensidad = 1.55
	fondo.velo = 0.42
	raiz.add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 34)
	margen.add_theme_constant_override("margin_right", 34)
	margen.add_theme_constant_override("margin_top", 22)
	margen.add_theme_constant_override("margin_bottom", 18)
	raiz.add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	margen.add_child(columna)

	columna.add_child(_crear_cabecera())

	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 18)
	columna.add_child(cuerpo)

	cuerpo.add_child(_crear_riel())
	cuerpo.add_child(_crear_vitrina())
	cuerpo.add_child(_crear_ficha())

	columna.add_child(_crear_pie())


func _crear_cabecera() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	fila.add_child(ForjaTema.titulo("FORJA DE CAMPEONES", 28, ForjaTema.ORO_CLARO))
	var relleno := Control.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(relleno)
	var permanente := ForjaTema.rotulo("ELECCIÓN PERMANENTE POR PARTIDA", 11, Color(0.86, 0.34, 0.24))
	permanente.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(permanente)
	return fila


## Riel de clases: rombos verticales, como los sellos de una orden. Con más de
## cuatro campeones el rombo se encoge para que la columna siga cabiendo en 720
## px de alto sin scroll (5 clases: 96 px por sello).
func _crear_riel() -> Control:
	var riel := VBoxContainer.new()
	var varias := _perfiles.size() > 4
	var lado := 96.0 if varias else 112.0
	var emblema_lado := 82.0 if varias else 96.0
	riel.custom_minimum_size = Vector2(lado, 0)
	riel.alignment = BoxContainer.ALIGNMENT_CENTER
	riel.add_theme_constant_override("separation", 10 if varias else 14)

	for i in _perfiles.size():
		var perfil: Dictionary = _perfiles[i]
		var clase := StringName(perfil.get("clase", ""))
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(lado, lado)
		boton.focus_mode = Control.FOCUS_NONE
		boton.text = ""
		boton.flat = true
		var vacio := StyleBoxEmpty.new()
		for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
			boton.add_theme_stylebox_override(estado, vacio)
		var emblema := ForjaTema.Emblema.new(clase, emblema_lado)
		var margen := (lado - emblema_lado) * 0.5
		emblema.position = Vector2(margen, margen * 0.6)
		boton.add_child(emblema)
		_emblemas.append(emblema)
		boton.pressed.connect(_seleccionar.bind(i))
		riel.add_child(boton)

	return riel


func _crear_vitrina() -> Control:
	var caja := CenterContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vitrina = VitrinaCampeon.new()
	_vitrina.configurar(Vector2(470, 566))
	caja.add_child(_vitrina)
	return caja


## Columna derecha: la ficha completa del campeón.
func _crear_ficha() -> Control:
	var ficha := VBoxContainer.new()
	ficha.custom_minimum_size = Vector2(440, 0)
	ficha.add_theme_constant_override("separation", 3)

	# Cabecera: cresta + nombre + rol + lema.
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 12)
	ficha.add_child(cab)
	_marca = ForjaTema.Emblema.new(&"bastion", 52.0)
	_marca.seleccionado = true
	_marca.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cab.add_child(_marca)

	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 0)
	cab.add_child(textos)
	_nombre = ForjaTema.titulo("", 38, ForjaTema.ORO_CLARO)
	textos.add_child(_nombre)
	_rol = ForjaTema.rotulo("", 11, ForjaTema.TENUE)
	textos.add_child(_rol)
	_lema = ForjaTema.etiqueta("", 11, ForjaTema.TEXTO)
	_lema.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	textos.add_child(_lema)

	ficha.add_child(_divisor())

	# Nivel y experiencia.
	var fila_nivel := HBoxContainer.new()
	ficha.add_child(fila_nivel)
	var nivel := ForjaTema.rotulo("NIVEL 1", 11, ForjaTema.TEXTO_FUERTE)
	nivel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_nivel.add_child(nivel)
	_xp_texto = ForjaTema.etiqueta("", 10, ForjaTema.TENUE)
	fila_nivel.add_child(_xp_texto)
	_xp_barra = ProgressBar.new()
	_xp_barra.show_percentage = false
	_xp_barra.custom_minimum_size = Vector2(0, 7)
	_xp_barra.max_value = 100.0
	_xp_barra.value = 0.0
	_xp_barra.add_theme_stylebox_override("background", ForjaTema.estilo_barra(Color(0.10, 0.03, 0.03)))
	_xp_barra.add_theme_stylebox_override("fill", ForjaTema.estilo_barra(Color(0.72, 0.16, 0.12)))
	ficha.add_child(_xp_barra)

	# Atributos: tres columnas con el número grande.
	ficha.add_child(ForjaTema.rotulo("ATRIBUTOS", 11))
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 10)
	ficha.add_child(grid)
	for _i in 3:
		var caja := PanelContainer.new()
		caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var estilo := ForjaTema.estilo_panel(0.55)
		estilo.content_margin_left = 8
		estilo.content_margin_right = 8
		estilo.content_margin_top = 3
		estilo.content_margin_bottom = 4
		caja.add_theme_stylebox_override("panel", estilo)
		var dentro := VBoxContainer.new()
		dentro.add_theme_constant_override("separation", 0)
		caja.add_child(dentro)
		var clave := ForjaTema.rotulo("", 9, ForjaTema.TENUE)
		clave.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dentro.add_child(clave)
		var valor := ForjaTema.titulo("", 19, ForjaTema.TEXTO_FUERTE)
		valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dentro.add_child(valor)
		grid.add_child(caja)
		_atributos.append([clave, valor])

	# Estadísticas con icono + barra segmentada + valor.
	ficha.add_child(ForjaTema.rotulo("ESTADÍSTICAS", 11))
	for _i in 4:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		var icono := ForjaTema.IconoStat.new(&"vida", 16.0)
		icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fila.add_child(icono)
		var etiqueta := ForjaTema.etiqueta("", 11, ForjaTema.TEXTO)
		etiqueta.custom_minimum_size = Vector2(66, 0)
		fila.add_child(etiqueta)
		var barra := ForjaTema.BarraSegmentada.new(0.5)
		barra.custom_minimum_size = Vector2(190, 10)
		barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		barra.alto = 10
		fila.add_child(barra)
		var valor := ForjaTema.etiqueta("", 11, ForjaTema.ORO_CLARO)
		valor.custom_minimum_size = Vector2(64, 0)
		valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fila.add_child(valor)
		ficha.add_child(fila)
		_barras.append(barra)
		_valores.append(valor)
		_derivados.append(icono)

	# Derivadas: velocidad de ataque, crítico y armadura.
	var fila_der := HBoxContainer.new()
	fila_der.add_theme_constant_override("separation", 12)
	ficha.add_child(fila_der)
	for _i in 3:
		var dato := ForjaTema.etiqueta("", 10, ForjaTema.TENUE)
		dato.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila_der.add_child(dato)
		_derivados.append(dato)

	ficha.add_child(_divisor())

	# Habilidades: tres casillas con su tecla y su descripción al elegirlas.
	ficha.add_child(ForjaTema.rotulo("HABILIDADES", 11))
	var fila_tiles := HBoxContainer.new()
	fila_tiles.add_theme_constant_override("separation", 8)
	ficha.add_child(fila_tiles)
	for i in 3:
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(96, 58)
		tile.focus_mode = Control.FOCUS_NONE
		tile.text = ""
		tile.expand_icon = true
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		tile.add_theme_stylebox_override("normal", ForjaTema.estilo_tarjeta(ForjaTema.ORO_OSCURO, false, true))
		tile.add_theme_stylebox_override("hover", ForjaTema.estilo_tarjeta(ForjaTema.ORO, true))
		tile.add_theme_stylebox_override("pressed", ForjaTema.estilo_tarjeta(ForjaTema.ORO_CLARO, true))
		tile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		tile.pressed.connect(_elegir_habilidad.bind(i))
		var tecla := ForjaTema.rotulo(["Q", "W", "E"][i], 9, ForjaTema.ORO)
		tecla.position = Vector2(3, 2)
		tecla.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(tecla)
		fila_tiles.add_child(tile)
		_tiles.append(tile)

	_detalle_habilidad = ForjaTema.etiqueta("Elegí una habilidad para leer qué hace.", 10, ForjaTema.TENUE)
	_detalle_habilidad.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalle_habilidad.custom_minimum_size = Vector2(0, 36)
	ficha.add_child(_detalle_habilidad)

	# Equipo: el arma de la clase llega puesta; el resto se compra en la arena.
	var rotulo_equipo := HBoxContainer.new()
	ficha.add_child(rotulo_equipo)
	var titulo_equipo := ForjaTema.rotulo("EQUIPO", 11)
	titulo_equipo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo_equipo.add_child(titulo_equipo)
	var fila_piel := HBoxContainer.new()
	fila_piel.add_theme_constant_override("separation", 6)
	rotulo_equipo.add_child(fila_piel)
	_piel = ForjaTema.etiqueta("", 10, ForjaTema.TENUE)
	_piel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila_piel.add_child(_piel)
	var cambiar := ForjaTema.boton("CAMBIAR PIEL", 10)
	cambiar.custom_minimum_size = Vector2(112, 26)
	cambiar.pressed.connect(func() -> void: piel_siguiente.emit())
	fila_piel.add_child(cambiar)

	var fila_equipo := HBoxContainer.new()
	fila_equipo.add_theme_constant_override("separation", 6)
	ficha.add_child(fila_equipo)
	for i in 4:
		var ranura := PanelContainer.new()
		ranura.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ranura.custom_minimum_size = Vector2(0, 40)
		var estilo := ForjaTema.estilo_panel(0.7)
		estilo.content_margin_left = 8
		estilo.content_margin_right = 8
		estilo.content_margin_top = 3
		estilo.content_margin_bottom = 3
		ranura.add_theme_stylebox_override("panel", estilo)
		var dentro := VBoxContainer.new()
		dentro.add_theme_constant_override("separation", 0)
		ranura.add_child(dentro)
		var clave := ForjaTema.rotulo(["ARMA", "ARMADURA", "ACCESORIO", "RELIQUIA"][i], 8, ForjaTema.TENUE)
		dentro.add_child(clave)
		var valor := ForjaTema.etiqueta("", 9, ForjaTema.TENUE)
		valor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		valor.custom_minimum_size = Vector2(0, 24)
		dentro.add_child(valor)
		fila_equipo.add_child(ranura)
		_ranuras.append([ranura, valor])

	# Descripción larga de la clase + llamada a la acción.
	_descripcion = ForjaTema.etiqueta("", 10, ForjaTema.TENUE)
	_descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_descripcion.visible = false
	ficha.add_child(_descripcion)

	_btn_elegir = ForjaTema.boton("ELEGIR CAMPEÓN", 17, true)
	_btn_elegir.custom_minimum_size = Vector2(0, 44)
	_btn_elegir.pressed.connect(_confirmar)
	ficha.add_child(_btn_elegir)

	return ficha


func _divisor() -> Control:
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	var izq := ForjaTema.regla(0)
	izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(izq)
	var rombo := ForjaTema.rotulo("•", 10, ForjaTema.ORO_OSCURO)
	caja.add_child(rombo)
	var der := ForjaTema.regla(0)
	der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(der)
	return caja


func _crear_pie() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	_volver = ForjaTema.boton("VOLVER", 13)
	_volver.custom_minimum_size = Vector2(120, 34)
	_volver.pressed.connect(_cerrar)
	fila.add_child(_volver)
	var tactil := OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	var teclas := ""
	for i in _perfiles.size():
		teclas += ("" if i == 0 else " · ") + str(i + 1)
	var texto_ayuda := "Tocá una clase y confirmá" if tactil else "%s cambian de clase   ·   Enter confirma   ·   Esc cierra" % teclas
	var ayuda := ForjaTema.etiqueta(texto_ayuda, 10, ForjaTema.TENUE)
	ayuda.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(ayuda)
	return fila


# --- Actualización ----------------------------------------------------------

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
		var emblema: ForjaTema.Emblema = _emblemas[i]
		emblema.seleccionado = i == _indice
		emblema.atenuado = i != _indice
		emblema.queue_redraw()

	_marca.clase = clase
	_marca.seleccionado = true
	_marca.queue_redraw()

	if _vitrina != null:
		_vitrina.mostrar(
			clase,
			perfil.get("tinte", Color.WHITE),
			perfil.get("vis_arma", null),
			perfil.get("rot_arma", Vector3.ZERO),
			float(perfil.get("esc_arma", 1.0)),
			bool(perfil.get("pesada", false))
		)

	_nombre.text = String(perfil.get("nombre", "")).to_upper()
	_lema.text = String(perfil.get("lema", ForjaTema.LEMA_CLASE.get(clase, "")))
	_descripcion.text = String(perfil.get("descripcion", ForjaTema.DESCRIPCION_CLASE.get(clase, "")))
	_rol.text = String(perfil.get("rol", ForjaTema.ROL_CLASE.get(clase, ""))).to_upper()
	_piel.text = String(perfil.get("piel", "Tierra Baldía")).to_upper()

	var requerida := int(perfil.get("xp_requerida", 0))
	_xp_texto.text = "0 / %d XP" % requerida
	_xp_barra.max_value = maxf(1.0, float(requerida))
	_xp_barra.value = 0.0

	var vida := float(perfil.get("vida", 100.0))
	var mana := float(perfil.get("mana", 60.0))
	var dano := Vector2(float(perfil.get("dano_min", 4.0)), float(perfil.get("dano_max", 6.0)))
	var defensa := float(perfil.get("defensa", 0.0))
	var filas := [
		["VIDA", clampf(vida / 260.0, 0.0, 1.0), "%d" % int(vida), ForjaTema.VIDA, &"vida"],
		["MANÁ", clampf(mana / 180.0, 0.0, 1.0), "%d" % int(mana), ForjaTema.MANA, &"mana"],
		["ATAQUE", clampf(dano.y / 40.0, 0.0, 1.0), "%d-%d" % [int(dano.x), int(dano.y)], ForjaTema.ORO, &"dano"],
		["DEFENSA", clampf(defensa / 0.6, 0.0, 1.0), "%d %%" % int(round(defensa * 100.0)), ForjaTema.TEXTO, &"defensa"],
	]
	for i in _barras.size():
		var fila: Array = filas[i]
		_barras[i].valor = float(fila[1])
		_barras[i].color = fila[3]
		_barras[i].queue_redraw()
		_valores[i].text = String(fila[2])
		var contenedor: HBoxContainer = _barras[i].get_parent()
		(contenedor.get_child(1) as Label).text = String(fila[0])
		var icono: ForjaTema.IconoStat = contenedor.get_child(0)
		icono.tipo = StringName(fila[4])
		icono.fijar_color(fila[3])

	var atributos: Dictionary = perfil.get("atributos", {})
	var claves := [&"fuerza", &"agilidad", &"inteligencia"]
	var nombres := ["FUERZA", "AGILIDAD", "INTELIGENCIA"]
	for i in _atributos.size():
		var par: Array = _atributos[i]
		(par[0] as Label).text = nombres[i]
		(par[1] as Label).text = str(int(atributos.get(claves[i], 0)))

	var derivadas := [
		"VEL. ATAQUE %.2f/s" % float(perfil.get("vel_ataque", 0.0)),
		"CRÍTICO %d %%" % int(round(float(perfil.get("critico", 0.0)) * 100.0)),
		"ARMADURA %d" % int(perfil.get("armadura", 0.0)),
	]
	# Los tres primeros derivados son iconos de las filas; las etiquetas van al final.
	var base := _barras.size()
	for i in 3:
		var nodo = _derivados[base + i]
		if nodo is Label:
			(nodo as Label).text = derivadas[i]

	var habilidades: Array = perfil.get("habilidades", [])
	for i in _tiles.size():
		var boton: Button = _tiles[i]
		if i < habilidades.size():
			var hab: Dictionary = habilidades[i]
			var id := StringName(hab.get("id", ""))
			if id != &"":
				boton.icon = IconStudio.obtener(id, IconStudio.CATEGORIA_HABILIDAD)
				IconStudio.escuchar(id, Callable(self, "_icono_listo").bind([boton, id]))
			boton.visible = true
			boton.disabled = false
			boton.set_meta("habilidad", hab)
		else:
			boton.visible = false

	# Detalle de la primera habilidad al abrir: siempre hay algo que leer.
	var primera: Dictionary = habilidades[0] if not habilidades.is_empty() else {}
	_mostrar_detalle_habilidad(primera, 0)

	# Ranuras de equipo: el arma de la clase viene puesta; el resto se compra en
	# la arena durante la partida.
	var arma: Dictionary = perfil.get("arma", {})
	for i in _ranuras.size():
		var par: Array = _ranuras[i]
		var panel: PanelContainer = par[0]
		var valor: Label = par[1]
		if i == 0:
			valor.text = String(arma.get("nombre", "Arma de clase"))
			valor.add_theme_color_override("font_color", ForjaTema.ORO_CLARO)
			panel.add_theme_stylebox_override("panel", ForjaTema.estilo_tarjeta(ForjaTema.COLOR_RAREZA[&"raro"]))
		else:
			valor.text = "En la arena"
			valor.add_theme_color_override("font_color", ForjaTema.TENUE)
			panel.add_theme_stylebox_override("panel", ForjaTema.estilo_panel(0.55))

	# Si ya tenía campeón, el botón lo dice y no se puede repetir.
	if _actual != &"" and clase == _actual:
		_btn_elegir.text = "CAMPEÓN ACTUAL"
		_btn_elegir.disabled = true
	else:
		_btn_elegir.text = "ELEGIR CAMPEÓN"
		_btn_elegir.disabled = false
	# Sin campeón no se puede volver: la elección ya no se hace en el mapa.
	if _volver != null:
		_volver.visible = _actual != &"" and _actual != &"prisionero"


func _elegir_habilidad(indice: int) -> void:
	if _perfiles.is_empty():
		return
	var habilidades: Array = _perfiles[_indice].get("habilidades", [])
	if indice >= habilidades.size():
		return
	var hab: Dictionary = habilidades[indice]
	_mostrar_detalle_habilidad(hab, indice)
	Sfx.reproducir("click", -12.0)


func _mostrar_detalle_habilidad(hab: Dictionary, indice: int) -> void:
	if _detalle_habilidad == null:
		return
	for i in _tiles.size():
		var boton: Button = _tiles[i]
		if boton == null or not boton.visible:
			continue
		var activo := i == indice
		boton.add_theme_stylebox_override(
			"normal",
			ForjaTema.estilo_tarjeta(ForjaTema.ORO_CLARO if activo else ForjaTema.ORO_OSCURO, activo, true)
		)
	if hab.is_empty():
		_detalle_habilidad.text = "Elegí una habilidad para leer qué hace."
		return
	_detalle_habilidad.text = "%s · %d maná\n%s" % [
		String(hab.get("nombre", "")), int(hab.get("coste_mana", 0.0)), String(hab.get("descripcion", "")),
	]
	_detalle_habilidad.add_theme_color_override("font_color", ForjaTema.TEXTO)


func _icono_listo(textura: Texture2D, destino) -> void:
	# `destino` puede estar liberado: la pantalla se cierra y el icono llega tarde.
	if not is_instance_valid(destino):
		return
	var datos: Array = destino
	var boton = datos[0]
	if is_instance_valid(boton):
		boton.icon = textura


## La arena avisa cuando cambió el aspecto para refrescar la etiqueta.
func actualizar_piel(nombre: String) -> void:
	if _piel != null:
		_piel.text = nombre.to_upper()
	if _perfiles.is_empty():
		return
	# Refresca el tinte de la vitrina sin cambiar de clase.
	if _indice >= 0 and _indice < _perfiles.size():
		var perfil: Dictionary = _perfiles[_indice]
		if _vitrina != null:
			_vitrina.mostrar(
				StringName(perfil.get("clase", "")), perfil.get("tinte", Color.WHITE),
				perfil.get("vis_arma", null), perfil.get("rot_arma", Vector3.ZERO),
				float(perfil.get("esc_arma", 1.0)), bool(perfil.get("pesada", false))
			)


# --- Acciones ---------------------------------------------------------------

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
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			_seleccionar((evento as InputEventKey).keycode - KEY_1)
		KEY_ENTER, KEY_KP_ENTER:
			_confirmar()
		KEY_ESCAPE:
			if _volver != null and _volver.visible:
				_cerrar()
