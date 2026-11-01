class_name Player
extends Node2D
## Personaje en el mapa: movimiento por casillas (estilo RPG Maker) con animación realista.
## - El ciclo de paso avanza con la distancia recorrida (los pies no patinan).
## - En reposo respira. Un toque corto en otra dirección solo gira.
## - Si lleva la linterna, la sujeta delante con la mano derecha: la luz sale de la mano,
##   sigue los giros con un poco de retraso y se balancea al andar.
## La escena decide qué casillas se pueden pisar con `walkable_check`.

signal interact_requested(cell: Vector2i)
signal step_finished(cell: Vector2i)

const TILE_SIZE: int = 32
## Segundos por casilla. Lento a propósito: recién operado.
const STEP_TIME: float = 0.4
## Un ciclo completo de paso (8 fotogramas) cubre dos casillas.
const STRIDE_PIXELS: float = 64.0
const IDLE_FPS: float = 1.6
## Mantener la dirección este tiempo antes de andar; un toque más corto solo gira.
const TURN_DELAY: float = 0.1
## Hoja del protagonista: 24 columnas por dirección (ver tools/art/sprite_meta.json).
const COLUMNS: int = 24
const ANIM_IDLE: Vector2i = Vector2i(0, 4)
const ANIM_WALK: Vector2i = Vector2i(4, 8)
const ANIM_IDLE_FLASH: Vector2i = Vector2i(12, 4)
const ANIM_WALK_FLASH: Vector2i = Vector2i(16, 8)
const ROW_BY_FACING: Dictionary[Vector2i, int] = {
	Vector2i.DOWN: 0,
	Vector2i.LEFT: 1,
	Vector2i.RIGHT: 2,
	Vector2i.UP: 3,
}
const BOUNCE_DISTANCE: float = 76.0

## Origen de la luz (la mano) por dirección: abajo, izquierda, derecha, arriba.
@export var flashlight_offsets: Array[Vector2] = [Vector2(-8, 18), Vector2(-20, 4), Vector2(20, 6), Vector2(8, -6)]
## Rapidez con que el haz sigue al giro (más alto = menos inercia).
@export var light_turn_speed: float = 11.0
## Balanceo del haz al andar, en radianes.
@export var light_sway: float = 0.045

var cell: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i.DOWN
var input_enabled: bool = false
## Recibe una celda y devuelve si se puede pisar.
var walkable_check: Callable = func(_target: Vector2i) -> bool: return true

var _moving: bool = false
var _step_dir: Vector2i = Vector2i.ZERO
var _step_left: float = 0.0
var _walk_distance: float = 0.0
var _kept_walking: bool = false
var _hold_time: float = 0.0
var _idle_time: float = 0.0
var _holding_flashlight: bool = false
var _light_angle: float = PI / 2.0
var _flashlight_energy: float = 1.0
var _bounce_energy: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _glow: Sprite2D = $Sprite2D/Glow
@onready var _flashlight: PointLight2D = $Flashlight
@onready var _bounce: PointLight2D = $Bounce
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	_flashlight_energy = _flashlight.energy
	_bounce_energy = _bounce.energy
	_flashlight.enabled = false
	_bounce.enabled = false
	_light_angle = Vector2(facing).angle()
	_update_frame()


func _physics_process(delta: float) -> void:
	if _moving:
		_advance_step(delta)
		return
	if not input_enabled:
		_kept_walking = false
		return
	if Input.is_action_just_pressed("ui_accept"):
		interact_requested.emit(cell + facing)
		return
	var direction: Vector2i = _read_direction()
	if direction == Vector2i.ZERO:
		_hold_time = 0.0
		_kept_walking = false
		return
	if direction != facing and not _kept_walking:
		face(direction)
		_hold_time = 0.0
		return
	_hold_time += delta
	if _hold_time < TURN_DELAY and not _kept_walking:
		return
	face(direction)
	if walkable_check.call(cell + direction):
		_start_step(direction)
	else:
		_kept_walking = false


func _process(delta: float) -> void:
	if not _moving and not _kept_walking:
		_idle_time += delta
	_update_frame()
	_update_light(delta)


## Coloca al personaje en una celda sin animación.
func place(target: Vector2i, direction: Vector2i) -> void:
	cell = target
	_moving = false
	_kept_walking = false
	position = Vector2(target * TILE_SIZE) + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	face(direction)
	_light_angle = Vector2(direction).angle()
	_camera.reset_smoothing()


func face(direction: Vector2i) -> void:
	facing = direction


func set_camera_limits(bounds: Rect2i) -> void:
	_camera.limit_left = bounds.position.x
	_camera.limit_top = bounds.position.y
	_camera.limit_right = bounds.end.x
	_camera.limit_bottom = bounds.end.y


func has_flashlight_on() -> bool:
	return _flashlight.enabled


## Coge la linterna y la enciende con un parpadeo corto (o la apaga).
func set_flashlight(on: bool) -> void:
	_holding_flashlight = _holding_flashlight or on
	if not on:
		_set_light_enabled(false)
		return
	for i: int in 3:
		_set_light_enabled(i % 2 == 0)
		await get_tree().create_timer(0.07).timeout
	_set_light_enabled(true)


## Parpadeo irregular durante `duration` segundos; termina apagada (la sigue sujetando).
func flicker_flashlight(duration: float) -> void:
	var elapsed: float = 0.0
	while elapsed < duration:
		var wait: float = randf_range(0.04, 0.18)
		_set_light_enabled(not _flashlight.enabled)
		await get_tree().create_timer(wait).timeout
		elapsed += wait
	_set_light_enabled(false)


func _start_step(direction: Vector2i) -> void:
	_moving = true
	_step_dir = direction
	_step_left = TILE_SIZE
	cell += direction


func _advance_step(delta: float) -> void:
	var amount: float = minf(_step_left, TILE_SIZE * delta / STEP_TIME)
	position += Vector2(_step_dir) * amount
	_step_left -= amount
	_walk_distance += amount
	if _step_left > 0.0:
		return
	_moving = false
	position = Vector2(cell * TILE_SIZE) + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	# Si se sigue pulsando, el paso siguiente encadena sin cortar la animación.
	_kept_walking = input_enabled and _read_direction() != Vector2i.ZERO
	if not _kept_walking:
		_settle_walk()
	step_finished.emit(cell)


## Al parar, deja el ciclo en el punto de pies juntos más cercano para el siguiente arranque.
func _settle_walk() -> void:
	var half: float = STRIDE_PIXELS / 2.0
	_walk_distance = roundf(_walk_distance / half) * half
	_idle_time = 0.0


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


func _update_frame() -> void:
	var walking: bool = _moving or _kept_walking
	var anim: Vector2i
	var index: int
	if walking:
		anim = ANIM_WALK_FLASH if _holding_flashlight else ANIM_WALK
		index = int(fposmod(_walk_distance, STRIDE_PIXELS) / STRIDE_PIXELS * anim.y) % anim.y
	else:
		anim = ANIM_IDLE_FLASH if _holding_flashlight else ANIM_IDLE
		index = int(_idle_time * IDLE_FPS) % anim.y
	_sprite.frame = ROW_BY_FACING[facing] * COLUMNS + anim.x + index
	_glow.frame = _sprite.frame
	_glow.visible = _flashlight.enabled


func _update_light(delta: float) -> void:
	var row: int = ROW_BY_FACING[facing]
	var target: float = Vector2(facing).angle()
	_light_angle = lerp_angle(_light_angle, target, 1.0 - exp(-light_turn_speed * delta))
	var sway: float = 0.0
	if _moving or _kept_walking:
		sway = sin(_walk_distance / STRIDE_PIXELS * TAU * 2.0) * light_sway
	else:
		sway = sin(_idle_time * TAU * IDLE_FPS / 4.0) * light_sway * 0.25
	_flashlight.rotation = _light_angle + sway
	var hand: Vector2 = flashlight_offsets[row] if row < flashlight_offsets.size() else Vector2.ZERO
	_flashlight.position = _flashlight.position.lerp(hand, 1.0 - exp(-14.0 * delta))
	# Pequeñas variaciones de una bombilla vieja.
	var jitter: float = 0.96 + 0.04 * randf()
	if randf() < 0.004:
		jitter = 0.55
	_flashlight.energy = _flashlight_energy * jitter
	_bounce.position = _flashlight.position + Vector2.from_angle(_flashlight.rotation) * BOUNCE_DISTANCE
	_bounce.energy = _bounce_energy * jitter


func _set_light_enabled(on: bool) -> void:
	_flashlight.enabled = on
	_bounce.enabled = on
	_glow.visible = on
