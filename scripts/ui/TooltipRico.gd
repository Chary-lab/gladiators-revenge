class_name TooltipRico
extends PanelContainer
## Tooltip flotante con icono, título, subtítulo y cuerpo BBCode.
## Sigue al ratón, se limita a la pantalla y aparece con un fade/scale suave.

const TITULO := Color(0.96, 0.82, 0.48)
const SUBTITULO := Color(0.72, 0.68, 0.58)
const CUERPO := Color(0.88, 0.84, 0.76)

var _icono: TextureRect
var _titulo: Label
var _subtitulo: Label
var _cuerpo: RichTextLabel
var _estilo: StyleBoxFlat
var _id_icono: StringName = &""
var _tween: Tween


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	custom_minimum_size = Vector2(260, 0)

	_estilo = StyleBoxFlat.new()
	_estilo.bg_color = Color(0.055, 0.05, 0.045, 0.98)
	_estilo.border_color = Color(0.86, 0.68, 0.32)
	_estilo.set_border_width_all(2)
	_estilo.set_corner_radius_all(8)
	_estilo.content_margin_left = 12
	_estilo.content_margin_right = 12
	_estilo.content_margin_top = 10
	_estilo.content_margin_bottom = 10
	_estilo.shadow_color = Color(0, 0, 0, 0.6)
	_estilo.shadow_size = 9
	_estilo.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", _estilo)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 6)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(columna)

	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 10)
	cabecera.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(cabecera)

	_icono = TextureRect.new()
	_icono.custom_minimum_size = Vector2(48, 48)
	_icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icono.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	cabecera.add_child(_icono)

	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 1)
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cabecera.add_child(textos)

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 16)
	_titulo.add_theme_color_override("font_color", TITULO)
	_titulo.add_theme_constant_override("outline_size", 3)
	_titulo.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.8))
	_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(_titulo)

	_subtitulo = Label.new()
	_subtitulo.add_theme_font_size_override("font_size", 10)
	_subtitulo.add_theme_color_override("font_color", SUBTITULO)
	_subtitulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(_subtitulo)

	var linea := ColorRect.new()
	linea.color = Color(0.55, 0.42, 0.22, 0.8)
	linea.custom_minimum_size = Vector2(0, 1)
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(linea)

	_cuerpo = RichTextLabel.new()
	_cuerpo.bbcode_enabled = true
	_cuerpo.fit_content = true
	_cuerpo.scroll_active = false
	_cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cuerpo.custom_minimum_size = Vector2(240, 0)
	_cuerpo.add_theme_font_size_override("normal_font_size", 11)
	_cuerpo.add_theme_color_override("default_color", CUERPO)
	columna.add_child(_cuerpo)


func mostrar(
	titulo: String,
	subtitulo: String,
	cuerpo: String,
	icono_id: StringName = &"",
	categoria: StringName = IconStudio.CATEGORIA_COMANDO,
	acento: Color = TITULO
) -> void:
	_titulo.text = titulo
	_subtitulo.text = subtitulo
	_cuerpo.text = cuerpo
	_estilo.border_color = acento
	_titulo.add_theme_color_override("font_color", acento)
	_id_icono = icono_id
	_icono.visible = icono_id != &""
	if _icono.visible:
		_icono.texture = IconStudio.obtener(icono_id, categoria)
		IconStudio.escuchar(icono_id, Callable(self, "_icono_listo").bind(icono_id))

	visible = true
	reset_size()
	pivot_offset = size * 0.5
	modulate.a = 0.0
	scale = Vector2(0.97, 0.97)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.12)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD)


func ocultar() -> void:
	if not visible:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(self, "modulate:a", 0.0, 0.09)
	var _cb_tooltip := Callable(self, "_on_tooltip_tween_completo")
	_tween.tween_callback(_cb_tooltip)


func _process(_delta: float) -> void:
	if not visible:
		return
	var vista := get_viewport_rect().size
	var raton := get_global_mouse_position()
	var tam := size
	var pos := raton + Vector2(18, 18)
	if pos.x + tam.x > vista.x - 8.0:
		pos.x = raton.x - tam.x - 18.0
	if pos.y + tam.y > vista.y - 8.0:
		pos.y = raton.y - tam.y - 18.0
	pos.x = clampf(pos.x, 8.0, maxf(8.0, vista.x - tam.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, vista.y - tam.y - 8.0))
	global_position = pos
	pivot_offset = tam * 0.5


func _icono_listo(textura: Texture2D, id: StringName) -> void:
	if id == _id_icono:
		_icono.texture = textura

func _on_tooltip_tween_completo() -> void:
	visible = false