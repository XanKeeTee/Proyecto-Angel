class_name Inspector
extends CanvasLayer
## Inspector: muestra un objeto grande y deja girarlo (flechas, ratón o se gira solo).
## Las vistas vienen en una hoja horizontal de N imágenes (tools/art genera 8).

signal closed

const SCALE: float = 3.0
const AUTO_SPIN: float = 0.9

var _views: int = 1
var _view: float = 0.0
var _sheet: Texture2D
var _atlas: AtlasTexture
var _image: TextureRect
var _title: Label
var _text: Label
var _hint: Label
var _dragging: bool = false
var _auto: bool = true


func _init() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_image = TextureRect.new()
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.position = Vector2(170, 30)
	_image.size = Vector2(300, 220)
	add_child(_image)
	_title = UiStyle.label("", 14, UiStyle.BONE)
	_title.position = Vector2(40, 254)
	add_child(_title)
	_text = UiStyle.label("", 10, UiStyle.BONE_DIM)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.position = Vector2(40, 274)
	_text.size = Vector2(560, 60)
	add_child(_text)
	_hint = UiStyle.label("← → girar  ·  Esc cerrar", 8, UiStyle.ASH, UiStyle.mono())
	_hint.position = Vector2(480, 340)
	add_child(_hint)


## Abre el inspector. Sin hoja de vistas, muestra la imagen fija (`fallback`).
func show_item(title: String, description: String, sheet: Texture2D, views: int, fallback: Texture2D = null) -> void:
	_title.text = title
	_text.text = description
	_sheet = sheet if sheet != null else fallback
	_views = maxi(1, views) if sheet != null else 1
	_view = 0.0
	_auto = _views > 1
	_hint.visible = _views > 1
	_atlas = AtlasTexture.new()
	_atlas.atlas = _sheet
	_update_frame()
	visible = true
	get_tree().paused = true
	_image.modulate.a = 0.0
	create_tween().tween_property(_image, "modulate:a", 1.0, 0.2)


func close() -> void:
	visible = false
	closed.emit()


func _process(delta: float) -> void:
	if visible and _auto and _views > 1:
		_view = fposmod(_view + delta * AUTO_SPIN, _views)
		_update_frame()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed(InputActions.PAUSE) \
			or event.is_action_pressed(InputActions.EXAMINE) or event.is_action_pressed("ui_accept"):
		close()
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed(InputActions.MOVE_LEFT):
		_step(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed(InputActions.MOVE_RIGHT):
		_step(1)
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_dragging = mb.pressed
		_auto = false
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _dragging and _views > 1:
		_view = fposmod(_view + mm.relative.x * 0.05, _views)
		_update_frame()


func _step(dir: int) -> void:
	_auto = false
	_view = fposmod(floorf(_view) + dir, _views)
	_update_frame()


func _update_frame() -> void:
	if _sheet == null:
		_image.texture = null
		return
	var w: float = _sheet.get_width() / float(_views)
	_atlas.region = Rect2(floorf(_view) * w, 0, w, _sheet.get_height())
	_image.texture = _atlas
