class_name OutfitPreview
extends Control
## Retrato del protagonista con la ropa puesta, ampliado. Respira (animación de reposo)
## y gira solo entre las 8 orientaciones; se puede girar a mano con `turn()` o arrastrando.

const BODY_SHEET: String = "res://assets/sprites/characters/protagonist.png"
const FRAME: Vector2 = Vector2(48, 68)
const SCALE: float = 3.0
const IDLE_FRAMES: int = 8
const IDLE_FPS: float = 3.3
const AUTO_TURN: float = 1.6
## Orden de dibujo de las ranuras (de abajo arriba).
const LAYER_ORDER: Array[ItemDef.EquipSlot] = [
	ItemDef.EquipSlot.FEET, ItemDef.EquipSlot.LEGS, ItemDef.EquipSlot.BODY, ItemDef.EquipSlot.HEAD,
]

var character: CharacterState
## Fila de orientación que se ve (0 = de frente).
var direction: int = 0

var _body: Texture2D
var _time: float = 0.0
var _turn_time: float = 0.0
var _auto: bool = true
var _drag_from: float = 0.0


func _init() -> void:
	custom_minimum_size = FRAME * SCALE
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body = load(BODY_SHEET)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	if _auto:
		_turn_time += delta
		if _turn_time > AUTO_TURN:
			_turn_time = 0.0
			direction = posmod(direction + 1, 8)
	queue_redraw()


## Gira el retrato a mano (deja de girar solo).
func turn(step: int) -> void:
	_auto = false
	direction = posmod(direction + step, 8)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		_drag_from = button.position.x
		_auto = false
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if absf(motion.position.x - _drag_from) > 18.0:
			turn(1 if motion.position.x < _drag_from else -1)
			_drag_from = motion.position.x


func _draw() -> void:
	# Sombra en el suelo.
	var feet: Vector2 = Vector2(size.x / 2.0, size.y - 6.0 * SCALE)
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 8.0 * SCALE, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	var column: int = int(_time * IDLE_FPS) % IDLE_FRAMES
	# La hoja tiene 16 orientaciones; el retrato usa una de cada dos (las 8 principales).
	var region: Rect2 = Rect2(Vector2(column, direction * 2) * FRAME, FRAME)
	var target: Rect2 = Rect2((size - FRAME * SCALE) / 2.0, FRAME * SCALE)
	draw_texture_rect_region(_body, target, region)
	if character == null:
		return
	for slot: ItemDef.EquipSlot in LAYER_ORDER:
		var stack: ItemStack = character.worn(slot)
		if stack != null and stack.def.wear_sheet != null:
			draw_texture_rect_region(stack.def.wear_sheet, target, region)
