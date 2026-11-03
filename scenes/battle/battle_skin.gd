class_name BattleSkin
extends RefCounted
## Arte y paleta de la interfaz del combate: chapa oxidada con remaches, papel de expediente,
## cinta, sellos de caucho y tinta de máquina (mismo mundo que el menú principal aprobado).
## Las imágenes salen de `tools/art2d/ui_battle.py` (assets/ui/battle/); aquí se cargan, se
## convierten en estilos de 9 cortes y se dibujan. Todo se mide en píxeles de la vista (640×360):
## al pasar a 1280×720 basta con regenerar el arte a `--scale 2` y multiplicar `SCALE`.

const DIR: String = "res://assets/ui/battle/"
## Factor de escala de la interfaz (1 = 640×360).
const SCALE: int = 1
## Márgenes de 9 cortes de cada pieza (en píxeles de la imagen a escala 1).
const METAL_MARGIN: int = 13
const PAPER_MARGIN: int = 6
const TAB_MARGIN: int = 6
const BAND_MARGIN: int = 3
const TUBE_MARGIN: int = 5
## Grosor visible del marco de chapa (donde empieza el contenido).
const METAL_INSET: float = 7.0

## Tinta y papel.
const INK: Color = Color("2a2620")
const INK_SOFT: Color = Color("5a5044")
const INK_BLUE: Color = Color("2c3a5a")
const INK_RED: Color = Color("8e1f1a")
const PAPER: Color = Color("cfc6b0")
## Texto sobre la chapa.
const BONE: Color = Color("e8e1d3")
const BONE_DIM: Color = Color("bfb6a3")
const ASH: Color = Color("8a8376")
const AMBER: Color = Color("d0a24a")
const BLOOD: Color = Color("b03a34")
const BLOOD_DARK: Color = Color("6e1410")
## Líquidos de los tubos.
const LIQUID_BODY: Color = Color("8e1d16")
const LIQUID_MIND: Color = Color("4f6a8e")
## Color de cada estado de una parte (Sana, Herida, Rota, Amputada), en la lámina y el mapa de heridas.
const STATE_COLORS: Array[Color] = [Color(0.45, 0.55, 0.42, 0.0), Color("c8902c"), Color("a3241c"), Color("2a0a0a")]
## Tinta de cada estado (texto sobre papel).
const STATE_INK: Array[Color] = [Color("3c5a3a"), Color("8a5a10"), Color("8e1f1a"), Color("3a0c0a")]

static var _textures: Dictionary[String, Texture2D] = {}
static var _boxes: Dictionary[String, StyleBoxTexture] = {}
static var _images: Dictionary[String, Image] = {}


## Imagen de assets/ui/battle (null si falta: la interfaz dibuja algo sencillo en su lugar).
static func texture(file: String) -> Texture2D:
	if _textures.has(file):
		return _textures[file]
	var path: String = DIR + file + ".png"
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_textures[file] = tex
	return tex


## Píxeles de una imagen (para saber si el ratón está sobre una parte de la lámina).
static func image(file: String) -> Image:
	if _images.has(file):
		return _images[file]
	var tex: Texture2D = texture(file)
	var img: Image = tex.get_image() if tex != null else null
	if img != null and img.is_compressed():
		img.decompress()
	_images[file] = img
	return img


## Icono de una orden (16×16) por su clave (&"pipe", &"guard", &"lungs"…).
static func order_icon(key: StringName) -> Texture2D:
	var tex: Texture2D = texture("icons/order_" + String(key))
	return tex if tex != null else texture("icons/order_item")


## Icono de estado (12×12): &"bleed", &"wound", &"broken", &"amputated", &"grabbed", &"sedated",
## &"stunned", &"guard", &"panic", &"down", &"pushed", &"terror", &"analgesia". Los ids de los
## estados de datos se traducen (agarre → grabbed, derribado → down…).
static func status_icon(key: StringName) -> Texture2D:
	return texture("icons/status_" + String(status_key(key)))


## Clave de icono para un id de estado o de marca.
static func status_key(key: StringName) -> StringName:
	match key:
		&"agarre", &"grab", &"grabbed":
			return &"grabbed"
		&"sedacion", &"sedation", &"sedated":
			return &"sedated"
		&"aturdido", &"stun", &"stunned":
			return &"stunned"
		&"derribado", &"down":
			return &"down"
		&"apartado", &"pushed":
			return &"pushed"
		&"aterrado", &"terror":
			return &"terror"
		&"analgesia":
			return &"analgesia"
		&"sangrado":
			return &"bleed"
	return key


## Sello de caucho por su clave (&"autorizado", &"amputacion"…), o null.
static func stamp(key: String) -> Texture2D:
	return texture("stamp_" + key)


## Clave del sello que corresponde a un rótulo de impacto de `Battle` («AMPUTACIÓN.» → amputacion).
static func stamp_key(text: String) -> String:
	var clean: String = text.strip_edges().trim_suffix(".").to_lower()
	match clean:
		"fractura":
			return "fractura"
		"amputación":
			return "amputacion"
		"mutilación":
			return "mutilacion"
		"decapitación":
			return "decapitacion"
		"caída":
			return "caida"
		"muerte":
			return "muerte"
		"quiebre":
			return "quiebre"
		"huida":
			return "huida"
		"victoria":
			return "victoria"
		"fin de la partida":
			return "fin"
		"solo quedas tú":
			return "solo"
	return ""


static func metal_box() -> StyleBoxTexture:
	return _box("frame_metal", METAL_MARGIN, true)


static func paper_box() -> StyleBoxTexture:
	return _box("frame_paper", PAPER_MARGIN, true)


static func folder_box() -> StyleBoxTexture:
	return _box("frame_folder", PAPER_MARGIN, true)


static func tab_box() -> StyleBoxTexture:
	return _box("tab_paper", TAB_MARGIN, false)


static func band_box() -> StyleBoxTexture:
	return _box("band", BAND_MARGIN, false)


static func tube_box() -> StyleBoxTexture:
	return _box("tube", TUBE_MARGIN, false)


## Marco de chapa en cualquier lienzo.
static func draw_metal(canvas: CanvasItem, rect: Rect2) -> void:
	var box: StyleBoxTexture = metal_box()
	if box.texture != null:
		canvas.draw_style_box(box, rect)
	else:
		canvas.draw_rect(rect, Color(0.04, 0.04, 0.05, 0.9))
		canvas.draw_rect(rect.grow(-0.5), Color("6d5a4a"), false, 2.0)


## Papel de expediente con sombra en cualquier lienzo.
static func draw_paper(canvas: CanvasItem, rect: Rect2, folder: bool = false) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0, 0, 0, 0.45))
	var box: StyleBoxTexture = folder_box() if folder else paper_box()
	if box.texture != null:
		canvas.draw_style_box(box, rect)
	else:
		canvas.draw_rect(rect, PAPER)


## Pestaña de papel con texto a máquina; devuelve su rectángulo. `at` es la esquina superior izquierda.
static func draw_tab(canvas: CanvasItem, at: Vector2, text: String, color: Color = INK, tape_left: bool = true) -> Rect2:
	var font: Font = UiStyle.mono()
	var font_size: int = UiStyle.MONO_SMALL
	var width: float = ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + 14.0
	var rect: Rect2 = Rect2(at.round(), Vector2(width, 13))
	canvas.draw_rect(Rect2(rect.position + Vector2(1, 2), rect.size), Color(0, 0, 0, 0.5))
	var box: StyleBoxTexture = tab_box()
	if box.texture != null:
		canvas.draw_style_box(box, rect)
	else:
		canvas.draw_rect(rect, PAPER)
	canvas.draw_string(font, rect.position + Vector2(7, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	if tape_left:
		draw_tape(canvas, rect.position + Vector2(-6, -2), -0.35)
	return rect


## Trozo de cinta adhesiva (esquina superior izquierda en `at`, girado `angle` radianes).
static func draw_tape(canvas: CanvasItem, at: Vector2, angle: float = 0.0) -> void:
	var tex: Texture2D = texture("tape")
	if tex == null:
		return
	canvas.draw_set_transform(at, angle, Vector2.ONE)
	canvas.draw_texture(tex, Vector2.ZERO)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Separador de tinta a mano, de `from` a lo ancho `width`.
static func draw_rule(canvas: CanvasItem, from: Vector2, width: float) -> void:
	var tex: Texture2D = texture("rule")
	if tex == null:
		canvas.draw_line(from, from + Vector2(width, 0), INK_SOFT, 1.0)
		return
	canvas.draw_texture_rect(tex, Rect2(from.round(), Vector2(width, tex.get_height())), true)


## Icono centrado en `center` (con su tamaño natural o encajado en `fit` px).
static func draw_icon_at(canvas: CanvasItem, tex: Texture2D, center: Vector2, fit: float = 0.0,
		modulate: Color = Color.WHITE) -> void:
	if tex == null:
		return
	var tex_size: Vector2 = tex.get_size()
	if fit > 0.0:
		tex_size *= minf(fit / tex_size.x, fit / tex_size.y)
	var rect: Rect2 = Rect2((center - tex_size * 0.5).round(), tex_size.round())
	canvas.draw_texture_rect(tex, rect, false, modulate)


## Texto a máquina partido en líneas de `width` px. Devuelve la altura usada.
static func draw_wrapped(canvas: CanvasItem, font: Font, at: Vector2, text: String, width: float, font_size: int,
		color: Color, line_h: float, max_lines: int = 99) -> float:
	var lines: PackedStringArray = wrap_text(font, text, width, font_size)
	var count: int = mini(lines.size(), max_lines)
	for i: int in count:
		canvas.draw_string(font, at + Vector2(0, line_h * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	return line_h * count


## Parte un texto en líneas que caben en `width`.
static func wrap_text(font: Font, text: String, width: float, font_size: int) -> PackedStringArray:
	var result: PackedStringArray = []
	for paragraph: String in text.split("\n"):
		var line: String = ""
		for word: String in paragraph.split(" ", false):
			var probe: String = word if line == "" else line + " " + word
			if font.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and line != "":
				result.append(line)
				line = word
			else:
				line = probe
		result.append(line)
	return result


static func _box(file: String, margin: int, tile_center: bool) -> StyleBoxTexture:
	if _boxes.has(file):
		return _boxes[file]
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = texture(file)
	box.set_texture_margin_all(margin * SCALE)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT if tile_center \
			else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	box.axis_stretch_vertical = box.axis_stretch_horizontal
	_boxes[file] = box
	return box
