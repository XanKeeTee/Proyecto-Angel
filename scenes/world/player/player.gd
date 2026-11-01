class_name Player
extends Node2D
## Personaje en el mapa: movimiento por casillas (estilo RPG Maker), 4 direcciones,
## linterna que apunta hacia donde mira.
## La escena decide qué casillas se pueden pisar con `walkable_check`.

signal interact_requested(cell: Vector2i)
signal step_finished(cell: Vector2i)

const TILE_SIZE: int = 32
## Lento a propósito: recién operado y desorientado.
const STEP_TIME: float = 0.27
const ROW_BY_FACING: Dictionary[Vector2i, int] = {
	Vector2i.DOWN: 0,
	Vector2i.LEFT: 1,
	Vector2i.RIGHT: 2,
	Vector2i.UP: 3,
}
const FRAME_STAND: int = 1

var cell: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i.DOWN
var input_enabled: bool = false
## Recibe una celda y devuelve si se puede pisar.
var walkable_check: Callable = func(_target: Vector2i) -> bool: return true

var _moving: bool = false
var _left_foot: bool = false
var _flashlight_on: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _flashlight: PointLight2D = $Flashlight
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	_flashlight.enabled = false
	_update_sprite(FRAME_STAND)


func _physics_process(_delta: float) -> void:
	if not input_enabled or _moving:
		return
	if Input.is_action_just_pressed("ui_accept"):
		interact_requested.emit(cell + facing)
		return
	var direction: Vector2i = _read_direction()
	if direction == Vector2i.ZERO:
		return
	face(direction)
	if walkable_check.call(cell + direction):
		_step(direction)


## Coloca al personaje en una celda sin animación.
func place(target: Vector2i, direction: Vector2i) -> void:
	cell = target
	position = Vector2(target * TILE_SIZE) + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	face(direction)
	_camera.reset_smoothing()


func face(direction: Vector2i) -> void:
	facing = direction
	_flashlight.rotation = Vector2(direction).angle()
	_update_sprite(FRAME_STAND)


func set_camera_limits(bounds: Rect2i) -> void:
	_camera.limit_left = bounds.position.x
	_camera.limit_top = bounds.position.y
	_camera.limit_right = bounds.end.x
	_camera.limit_bottom = bounds.end.y


func has_flashlight_on() -> bool:
	return _flashlight_on


## Enciende o apaga la linterna con un parpadeo corto.
func set_flashlight(on: bool) -> void:
	_flashlight_on = on
	if not on:
		_flashlight.enabled = false
		return
	for i: int in 3:
		_flashlight.enabled = i % 2 == 0
		await get_tree().create_timer(0.07).timeout
	_flashlight.enabled = true


## Parpadeo irregular durante `duration` segundos; termina apagada.
func flicker_flashlight(duration: float) -> void:
	var elapsed: float = 0.0
	while elapsed < duration:
		var wait: float = randf_range(0.04, 0.18)
		_flashlight.enabled = not _flashlight.enabled
		await get_tree().create_timer(wait).timeout
		elapsed += wait
	_flashlight.enabled = false
	_flashlight_on = false


func _read_direction() -> Vector2i:
	if Input.is_action_pressed("ui_up"):
		return Vector2i.UP
	if Input.is_action_pressed("ui_down"):
		return Vector2i.DOWN
	if Input.is_action_pressed("ui_left"):
		return Vector2i.LEFT
	if Input.is_action_pressed("ui_right"):
		return Vector2i.RIGHT
	return Vector2i.ZERO


func _step(direction: Vector2i) -> void:
	_moving = true
	cell += direction
	_left_foot = not _left_foot
	_update_sprite(0 if _left_foot else 2)
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", position + Vector2(direction * TILE_SIZE), STEP_TIME)
	tween.parallel().tween_callback(_update_sprite.bind(FRAME_STAND)).set_delay(STEP_TIME * 0.6)
	await tween.finished
	_moving = false
	step_finished.emit(cell)


func _update_sprite(frame: int) -> void:
	_sprite.frame = ROW_BY_FACING[facing] * 3 + frame
