class_name UiStyle
extends RefCounted
## Identidad visual de la interfaz: oscura, industrial y médica.
## Colores de la guía estética (docs/art/guia-estetica.md) y fuentes del sistema
## mientras no haya fuentes pixel propias en assets/fonts/.

const BONE: Color = Color("e8e1d3")
const BONE_DIM: Color = Color("bfb6a3")
const ASH: Color = Color("7a7468")
const INK: Color = Color("1c1a1e")
const STEEL_DARK: Color = Color("16181b")
const STEEL: Color = Color("2b2f33")
const STEEL_LIGHT: Color = Color("4a5056")
const RUST: Color = Color("7a4a30")
const BLOOD: Color = Color("8e2a2a")
const SICK_GREEN: Color = Color("9cb85a")
const PAPER: Color = Color("cfc6b0")
const PAPER_DARK: Color = Color("a89f88")

static var _serif: SystemFont
static var _mono: SystemFont
static var _hand: SystemFont


static func serif() -> Font:
	if _serif == null:
		_serif = SystemFont.new()
		_serif.font_names = ["Georgia", "Times New Roman", "Liberation Serif", "DejaVu Serif", "serif"]
	return _serif


## Máquina de escribir: documentos mecanografiados, etiquetas y fichas.
static func mono() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = ["Courier New", "Liberation Mono", "DejaVu Sans Mono", "monospace"]
	return _mono


## Letra a mano: notas.
static func hand() -> Font:
	if _hand == null:
		_hand = SystemFont.new()
		_hand.font_names = ["Segoe Print", "Comic Sans MS", "Bradley Hand", "serif"]
	return _hand


static func label(text: String, size: int = 11, color: Color = BONE, font: Font = null) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font != null else serif())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Panel metálico con borde fino y remaches en las esquinas (los dibuja `PanelFrame`).
static func steel_box(bg: Color = STEEL_DARK, border: Color = STEEL_LIGHT, alpha: float = 0.94) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(bg, alpha)
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.set_content_margin_all(6)
	return s


static func paper_box() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = PAPER
	s.border_color = PAPER_DARK
	s.set_border_width_all(1)
	s.set_content_margin_all(12)
	s.shadow_color = Color(0, 0, 0, 0.6)
	s.shadow_size = 4
	return s


static func button(text: String) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", serif())
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", BONE_DIM)
	b.add_theme_color_override("font_hover_color", BONE)
	b.add_theme_color_override("font_focus_color", BONE)
	b.add_theme_color_override("font_disabled_color", ASH)
	var normal: StyleBoxFlat = steel_box(STEEL_DARK, STEEL, 0.9)
	normal.set_content_margin_all(3)
	normal.content_margin_left = 8
	var hover: StyleBoxFlat = steel_box(STEEL, BONE_DIM, 0.95)
	hover.set_content_margin_all(3)
	hover.content_margin_left = 8
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", normal)
	return b


## Barra fina (constantes, batería).
static func bar(color: Color) -> ProgressBar:
	var p: ProgressBar = ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(80, 5)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.border_color = STEEL_LIGHT
	bg.set_border_width_all(1)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fill)
	return p
