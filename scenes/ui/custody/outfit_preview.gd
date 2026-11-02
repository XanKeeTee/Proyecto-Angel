class_name OutfitPreview
extends Control
## Retrato del protagonista con la ropa puesta, ampliado, para la pantalla de equipo. Respira
## (animación de reposo) y gira solo por las 16 orientaciones; se gira a mano con `turn()` o
## arrastrando con el ratón.
##
## Rendimiento: las hojas del personaje y de la ropa son enormes (3648×1088, 76 columnas × 16
## orientaciones, con normales aparte). Antes se pedía `ItemDef.wear_sheet` en cada `_draw`, que
## volvía a leer del disco el CanvasTexture entero (difuso + normales, ~70 ms) cada fotograma, y la
## textura se soltaba antes de dibujarse (salía un rectángulo blanco). Ahora:
## - de cada hoja se lee **una vez** solo el bloque de reposo (8 fotogramas × 16 orientaciones,
##   384×1088) y se guarda en una caché estática (`_strips`); se lee el PNG difuso, no las normales;
## - el cuerpo y la ropa se **componen en una sola textura pequeña** al cambiar de ropa;
## - se dibuja **un solo fotograma** de esa textura y solo se redibuja cuando cambia el fotograma
##   o la orientación. Girar no carga nada.

const BODY_SHEET: String = "res://assets/sprites/characters/protagonist.png"
const FRAME: Vector2i = Vector2i(48, 68)
const SCALE: float = 3.0
const IDLE_FRAMES: int = 8
const IDLE_FPS: float = 3.3
const DIRECTIONS: int = 16
## Segundos por cada paso de giro automático (1/16 de vuelta).
const AUTO_TURN: float = 0.5
## Hojas recortadas que se guardan como máximo (cada una ocupa ~1,6 MB).
const MAX_CACHED_STRIPS: int = 16
## Orden de dibujo de las ranuras (de abajo arriba).
const LAYER_ORDER: Array[ItemDef.EquipSlot] = [
	ItemDef.EquipSlot.FEET, ItemDef.EquipSlot.LEGS, ItemDef.EquipSlot.BODY, ItemDef.EquipSlot.HEAD,
]

## Lecturas de hojas grandes desde que arrancó el juego (para las pruebas de regresión).
static var sheet_loads: int = 0
static var _strips: Dictionary[String, Image] = {}

## Personaje que se muestra. Al cambiarlo (o su ropa) se recompone la textura.
var character: CharacterState:
	set(value):
		if character == value:
			return
		if character != null and character.outfit_changed.is_connected(refresh):
			character.outfit_changed.disconnect(refresh)
		character = value
		if character != null:
			character.outfit_changed.connect(refresh)
		refresh()
## Orientación que se ve (0 = de frente; 16 en total, en sentido horario).
var direction: int = 0
## Veces que se ha dibujado (para las pruebas: solo al cambiar de fotograma u orientación).
var draws: int = 0

var _texture: ImageTexture
var _image: Image
var _signature: String = "-"
var _time: float = 0.0
var _turn_time: float = 0.0
var _auto: bool = true
var _drag_from: float = 0.0
var _shown: Vector2i = Vector2i(-1, -1)


func _init() -> void:
	custom_minimum_size = Vector2(FRAME) * SCALE
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	if _auto:
		_turn_time += delta
		if _turn_time > AUTO_TURN:
			_turn_time = 0.0
			direction = posmod(direction + 1, DIRECTIONS)
	if current_frame() != _shown:
		queue_redraw()


## Fotograma que toca: (columna de la animación de reposo, orientación).
func current_frame() -> Vector2i:
	return Vector2i(int(_time * IDLE_FPS) % IDLE_FRAMES, direction)


## Gira el retrato a mano (deja de girar solo).
func turn(step: int) -> void:
	_auto = false
	direction = posmod(direction + step, DIRECTIONS)
	queue_redraw()


## Vuelve a componer la textura si ha cambiado la ropa (si no, no hace nada).
func refresh() -> void:
	var signature: String = _outfit_signature()
	if signature == _signature and _texture != null:
		return
	_signature = signature
	_image = _compose()
	if _image == null:
		_texture = null
	elif _texture != null and _texture.get_size() == Vector2(_image.get_size()):
		_texture.update(_image)
	else:
		_texture = ImageTexture.create_from_image(_image)
	queue_redraw()


## Imagen compuesta (cuerpo + ropa) con todos los fotogramas de reposo, para las pruebas.
func composed_image() -> Image:
	return _image


## Bloque de reposo de una hoja sin ropa ni nada encima (para las pruebas).
static func body_strip() -> Image:
	return _strip(BODY_SHEET)


## Vacía la caché de hojas (pruebas).
static func clear_cache() -> void:
	_strips.clear()


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		_drag_from = button.position.x
		_auto = false
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if absf(motion.position.x - _drag_from) > 12.0:
			turn(1 if motion.position.x < _drag_from else -1)
			_drag_from = motion.position.x


func _draw() -> void:
	draws += 1
	_shown = current_frame()
	# Sombra en el suelo.
	var feet: Vector2 = Vector2(size.x / 2.0, size.y - 6.0 * SCALE)
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 8.0 * SCALE, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	if _texture == null:
		return
	var region: Rect2 = Rect2(Vector2(_shown * FRAME), Vector2(FRAME))
	var target: Rect2 = Rect2(((size - Vector2(FRAME) * SCALE) / 2.0).floor(), Vector2(FRAME) * SCALE)
	draw_texture_rect_region(_texture, target, region)


func _outfit_signature() -> String:
	if character == null:
		return ""
	var parts: PackedStringArray = []
	for slot: ItemDef.EquipSlot in LAYER_ORDER:
		var stack: ItemStack = character.worn(slot)
		parts.append(String(stack.def.id) if stack != null else "")
	return "|".join(parts)


func _compose() -> Image:
	var body: Image = _strip(BODY_SHEET)
	if body == null:
		return null
	var image: Image = body.duplicate() as Image
	if character == null:
		return image
	var whole: Rect2i = Rect2i(Vector2i.ZERO, image.get_size())
	for slot: ItemDef.EquipSlot in LAYER_ORDER:
		var stack: ItemStack = character.worn(slot)
		if stack == null:
			continue
		var layer: Image = _strip(_diffuse_path(stack.def.wear_path))
		if layer != null and layer.get_size() == image.get_size():
			image.blend_rect(layer, whole, Vector2i.ZERO)
	return image


## PNG difuso de una prenda a partir de su CanvasTexture (…/<id>_canvas.tres -> …/<id>.png).
static func _diffuse_path(wear_path: String) -> String:
	if wear_path == "":
		return ""
	var png: String = wear_path.trim_suffix("_canvas.tres") + ".png"
	return png if ResourceLoader.exists(png) else wear_path


## Bloque de reposo (columnas 0..IDLE_FRAMES-1 de las 16 orientaciones) de una hoja, recortado
## una sola vez y guardado en caché.
static func _strip(path: String) -> Image:
	if path == "":
		return null
	if _strips.has(path):
		return _strips[path]
	if not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path) as Texture2D
	sheet_loads += 1
	var canvas: CanvasTexture = texture as CanvasTexture
	if canvas != null:
		texture = canvas.diffuse_texture
	if texture == null:
		return null
	var full: Image = texture.get_image()
	if full == null or full.is_empty():
		return null
	if full.is_compressed():
		full.decompress()
	if full.get_format() != Image.FORMAT_RGBA8:
		full.convert(Image.FORMAT_RGBA8)
	var block: Vector2i = Vector2i(IDLE_FRAMES * FRAME.x, DIRECTIONS * FRAME.y)
	var strip: Image = Image.create_empty(block.x, block.y, false, Image.FORMAT_RGBA8)
	strip.blit_rect(full, Rect2i(Vector2i.ZERO, block), Vector2i.ZERO)
	if _strips.size() >= MAX_CACHED_STRIPS:
		_strips.erase(_strips.keys()[0])
	_strips[path] = strip
	return strip
