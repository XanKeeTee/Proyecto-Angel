class_name UiStyle
extends RefCounted
## Identidad visual de la interfaz: oscura, industrial y médica.
## Colores de la guía estética (docs/art/guia-estetica.md).
##
## Fuentes (licencia OFL, en assets/fonts/; créditos en docs/art/fuentes.md). Se importan **sin
## antialias** ni posición subpíxel y con hinting completo (ver los .import): así se dibujan píxel a
## píxel en la rejilla de 640x360, nítidas y con un toque pixelado, sin el borroso de antes.
## - `ui()` / `ui_bold()`: PT Serif. Menús, caja de mensajes, descripciones y botones (la guía
##   estética pide serifa legible para los menús).
## - `pixel()`: Pixelify Sans, fuente pixel para títulos y rótulos grandes (a 20 px es nítida).
## - `mono()`: Courier Prime, de máquina de escribir. Datos, fichas, pistas y documentos mecanografiados.
## - `hand()`: Patrick Hand. Notas escritas a mano.
## Usa las constantes de tamaño de abajo: son las que se ven bien. `fit_size` redondea a ellas.

const BONE: Color = Color("e8e1d3")
const BONE_DIM: Color = Color("bfb6a3")
const ASH: Color = Color("8a8376")
const INK: Color = Color("1c1a1e")
const STEEL_DARK: Color = Color("16181b")
const STEEL: Color = Color("2b2f33")
const STEEL_LIGHT: Color = Color("4a5056")
const RUST: Color = Color("7a4a30")
const BLOOD: Color = Color("b03a34")
const SICK_GREEN: Color = Color("9cb85a")
const AMBER: Color = Color("d0a24a")
const PAPER: Color = Color("cfc6b0")
const PAPER_DARK: Color = Color("a89f88")
const PAPER_INK: Color = Color("2a2620")

const FONT_UI: String = "res://assets/fonts/pt_serif/PTSerif-Regular.ttf"
const FONT_UI_BOLD: String = "res://assets/fonts/pt_serif/PTSerif-Bold.ttf"
const FONT_PIXEL: String = "res://assets/fonts/pixelify_sans/PixelifySans.ttf"
const FONT_MONO: String = "res://assets/fonts/courier_prime/CourierPrime-Regular.ttf"
const FONT_HAND: String = "res://assets/fonts/patrick_hand/PatrickHand-Regular.ttf"

## Tamaños de `ui()` y `ui_bold()`.
const SIZE_SMALL: int = 11
const SIZE_TEXT: int = 12
const SIZE_LARGE: int = 14
## Tamaño de `pixel()`: 20 px es su rejilla nativa (cada píxel de la letra son 2 de pantalla).
const SIZE_TITLE: int = 20
## Tamaños de `mono()`.
const MONO_SMALL: int = 10
const MONO_TEXT: int = 11
const MONO_LARGE: int = 24
## Tamaño de `hand()`.
const HAND_TEXT: int = 15

static var _ui: Font
static var _ui_bold: Font
static var _pixel: Font
static var _mono: Font
static var _hand: Font


## Fuente de la interfaz. La primera vez la instala también como fuente por defecto
## (tooltips, casillas de verificación y cualquier control sin estilo propio).
static func ui() -> Font:
	if _ui == null:
		_ui = _load_font(FONT_UI)
		ThemeDB.fallback_font = _ui
		ThemeDB.fallback_font_size = SIZE_TEXT
	return _ui


## Interfaz en negrita (nombres y títulos pequeños).
static func ui_bold() -> Font:
	if _ui_bold == null:
		_ui_bold = _load_font(FONT_UI_BOLD)
	return _ui_bold


## Fuente pixel para títulos grandes (usa SIZE_TITLE).
static func pixel() -> Font:
	if _pixel == null:
		_pixel = _load_font(FONT_PIXEL)
	return _pixel


## Antes había una fuente con serifa del sistema; ahora es `ui()`. Se mantiene por compatibilidad.
static func serif() -> Font:
	return ui()


## Máquina de escribir: documentos mecanografiados, etiquetas, fichas y datos.
static func mono() -> Font:
	if _mono == null:
		_mono = _load_font(FONT_MONO)
	return _mono


## Letra a mano: notas.
static func hand() -> Font:
	if _hand == null:
		_hand = _load_font(FONT_HAND)
	return _hand


## Ajusta un tamaño pedido al más cercano que se lee bien con esa fuente (nunca más pequeño
## que el mínimo legible). Así el código antiguo con tamaños de 7-9 px sigue siendo legible.
static func fit_size(font: Font, size: int) -> int:
	if font == pixel():
		return SIZE_TITLE if size <= 28 else 40
	if font == mono():
		if size <= 10:
			return MONO_SMALL
		if size <= 13:
			return MONO_TEXT
		return 14 if size <= 20 else MONO_LARGE
	if font == hand():
		return maxi(size, HAND_TEXT - 2)
	if size <= 11:
		return SIZE_SMALL
	if size <= 13:
		return SIZE_TEXT
	if size <= 17:
		return SIZE_LARGE
	return SIZE_TITLE if size <= 22 else size


## Rótulo con la fuente pixel (títulos de pantalla y pestañas grandes).
static func title(text: String, color: Color = BONE) -> Label:
	return label(text, SIZE_TITLE, color, pixel())


static func label(text: String, size: int = SIZE_TEXT, color: Color = BONE, font: Font = null) -> Label:
	var l: Label = Label.new()
	var f: Font = font if font != null else ui()
	l.text = text
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", fit_size(f, size))
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 1)
	return l


## Sombra de 1 px bajo el texto (para textos sobre la imagen del juego).
static func add_shadow(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)


## Panel metálico con borde fino.
static func steel_box(bg: Color = STEEL_DARK, border: Color = STEEL_LIGHT, alpha: float = 0.94) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(bg, alpha)
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.set_content_margin_all(8)
	return s


static func paper_box() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = PAPER
	s.border_color = PAPER_DARK
	s.set_border_width_all(1)
	s.set_content_margin_all(14)
	s.shadow_color = Color(0, 0, 0, 0.6)
	s.shadow_size = 4
	s.anti_aliasing = false
	return s


static func button(text: String, size: int = SIZE_TEXT) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", ui())
	b.add_theme_font_size_override("font_size", fit_size(ui(), size))
	b.add_theme_color_override("font_color", BONE_DIM)
	b.add_theme_color_override("font_hover_color", BONE)
	b.add_theme_color_override("font_focus_color", BONE)
	b.add_theme_color_override("font_pressed_color", BONE)
	b.add_theme_color_override("font_disabled_color", Color(ASH, 0.7))
	b.add_theme_constant_override("icon_max_width", 32)
	var normal: StyleBoxFlat = steel_box(STEEL_DARK, STEEL, 0.9)
	_button_margins(normal)
	var hover: StyleBoxFlat = steel_box(STEEL, BONE_DIM, 0.95)
	_button_margins(hover)
	var disabled: StyleBoxFlat = steel_box(STEEL_DARK, Color(STEEL, 0.6), 0.6)
	_button_margins(disabled)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", disabled)
	return b


## Barra fina (constantes, batería).
static func bar(color: Color, width: float = 90.0) -> ProgressBar:
	var p: ProgressBar = ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(width, 6)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.border_color = STEEL_LIGHT
	bg.set_border_width_all(1)
	bg.anti_aliasing = false
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	fill.anti_aliasing = false
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fill)
	return p


## Aplica las fuentes y colores a un deslizador o casilla de opciones (controles sin `button()`).
static func style_control(c: Control) -> void:
	c.add_theme_font_override("font", ui())
	c.add_theme_font_size_override("font_size", SIZE_TEXT)
	c.add_theme_color_override("font_color", BONE_DIM)
	c.add_theme_color_override("font_hover_color", BONE)
	c.add_theme_color_override("font_focus_color", BONE)
	c.add_theme_color_override("font_pressed_color", BONE)


## Triángulo pequeño (las fuentes pixel no traen ▶ ▼): `dir` es hacia dónde apunta.
static func draw_arrow(ci: CanvasItem, center: Vector2, dir: Vector2, size: float, color: Color) -> void:
	var d: Vector2 = dir.normalized()
	var side: Vector2 = Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PackedVector2Array([
		center + d * size, center - d * size + side * size, center - d * size - side * size,
	]), color)


static func _load_font(path: String) -> Font:
	var f: Font = load(path) as Font
	if f == null:
		push_warning("Falta la fuente " + path)
		var sys: SystemFont = SystemFont.new()
		sys.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		return sys
	return f


static func _button_margins(s: StyleBoxFlat) -> void:
	s.content_margin_top = 3
	s.content_margin_bottom = 4
	s.content_margin_left = 8
	s.content_margin_right = 8
