class_name Player
extends CharacterBody2D
## Protagonista en el mapa: movimiento libre en cualquier ángulo (analógico con mando),
## con aceleración y frenada suaves, colisión con paredes y muebles, y sprite en 8 orientaciones.
## - El ciclo de paso avanza con la distancia recorrida de verdad (los pies no patinan,
##   tampoco al deslizarse contra una pared).
## - En reposo respira.
## - Si lleva la linterna, la sujeta con la mano derecha: la luz sale de la mano y apunta
##   hacia donde camina, con un poco de inercia y balanceo.
## El nodo está en los PIES del personaje.

## Pide examinar lo que hay delante: casillas candidatas, de la más cercana a la más lejana.
signal interact_requested(cells: Array[Vector2i])
## Ha entrado en una casilla nueva.
signal cell_entered(cell: Vector2i)

const TILE_SIZE: int = 32
## Velocidad máxima en píxeles por segundo. Lento a propósito: recién operado.
const MAX_SPEED: float = 78.0
const ACCELERATION: float = 520.0
const FRICTION: float = 700.0
## Un ciclo completo de paso (8 fotogramas) cubre esta distancia.
const STRIDE_PIXELS: float = 64.0
const IDLE_FPS: float = 1.6
## Por debajo de esta velocidad se considera parado (animación de reposo).
const WALK_THRESHOLD: float = 12.0
## Hoja del protagonista: 24 columnas y 8 filas (ver tools/art/sprite_meta.json).
const COLUMNS: int = 24
const DIRECTIONS: int = 8
const ANIM_IDLE: Vector2i = Vector2i(0, 4)
const ANIM_WALK: Vector2i = Vector2i(4, 8)
const ANIM_IDLE_FLASH: Vector2i = Vector2i(12, 4)
const ANIM_WALK_FLASH: Vector2i = Vector2i(16, 8)
const BOUNCE_DISTANCE: float = 76.0
## Distancias a las que se mira al examinar.
const REACH: Array[float] = [18.0, 30.0]

## Origen de la luz (la mano) por fila de orientación: abajo, abajo-izq., izq., arriba-izq.,
## arriba, arriba-der., der., abajo-der.
@export var flashlight_offsets: Array[Vector2] = []
## Rapidez con que el haz sigue al giro (más alto = menos inercia).
@export var light_turn_speed: float = 9.0
## Balanceo del haz al andar, en radianes.
@export var light_sway: float = 0.045

var input_enabled: bool = false
## Ángulo hacia el que mira (radianes, 0 = derecha, PI/2 = abajo).
var facing_angle: float = PI / 2.0
## Casilla en la que están los pies.
var cell: Vector2i:
	get:
		return Vector2i(floori(position.x / TILE_SIZE), floori(position.y / TILE_SIZE))

var _last_cell: Vector2i = Vector2i(-999, -999)
var _walk_distance: float = 0.0
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
	_set_light_enabled(false)
	_light_angle = facing_angle
	_last_cell = cell
	_update_frame()


func _physics_process(delta: float) -> void:
	var wish: Vector2 = Vector2.ZERO
	if input_enabled:
		if Input.is_action_just_pressed("ui_accept"):
			interact_requested.emit(_probe_cells())
		wish = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if wish != Vector2.ZERO:
		velocity = velocity.move_toward(wish * MAX_SPEED, ACCELERATION * delta)
		facing_angle = wish.angle()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	var before: Vector2 = position
	move_and_slide()
	_walk_distance += position.distance_to(before)
	if cell != _last_cell:
		_last_cell = cell
		cell_entered.emit(cell)


func _process(delta: float) -> void:
	if not _is_walking():
		_idle_time += delta
	_update_frame()
	_update_light(delta)


## Coloca al personaje en el centro de una celda, parado.
func place(target: Vector2i, direction: Vector2i) -> void:
	position = Vector2(target * TILE_SIZE) + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	velocity = Vector2.ZERO
	_last_cell = target
	face(direction)
	_light_angle = facing_angle
	_camera.reset_smoothing()


## Gira hacia una dirección (vector de casilla, admite diagonales).
func face(direction: Vector2i) -> void:
	facing_angle = Vector2(direction).angle()


## Detiene al personaje en seco (para textos y eventos).
func stop() -> void:
	velocity = Vector2.ZERO


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


func _probe_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dir: Vector2 = Vector2.from_angle(facing_angle)
	for reach: float in REACH:
		var probe: Vector2 = position + dir * reach
		var c: Vector2i = Vector2i(floori(probe.x / TILE_SIZE), floori(probe.y / TILE_SIZE))
		if c != cell and not result.has(c):
			result.append(c)
	# En diagonal, prueba también las dos casillas rectas vecinas.
	var step: Vector2i = Vector2i(roundi(dir.x), roundi(dir.y))
	if step.x != 0 and step.y != 0:
		for c: Vector2i in [cell + Vector2i(step.x, 0), cell + Vector2i(0, step.y)]:
			if not result.has(c):
				result.append(c)
	return result


func _is_walking() -> bool:
	return velocity.length() > WALK_THRESHOLD


func _row() -> int:
	var index: int = roundi((rad_to_deg(facing_angle) - 90.0) / 45.0)
	return posmod(index, DIRECTIONS)


func _update_frame() -> void:
	var anim: Vector2i
	var index: int
	if _is_walking():
		anim = ANIM_WALK_FLASH if _holding_flashlight else ANIM_WALK
		index = int(fposmod(_walk_distance, STRIDE_PIXELS) / STRIDE_PIXELS * anim.y) % anim.y
	else:
		anim = ANIM_IDLE_FLASH if _holding_flashlight else ANIM_IDLE
		index = int(_idle_time * IDLE_FPS) % anim.y
	_sprite.frame = _row() * COLUMNS + anim.x + index
	_glow.frame = _sprite.frame
	_glow.visible = _flashlight.enabled


func _update_light(delta: float) -> void:
	_light_angle = lerp_angle(_light_angle, facing_angle, 1.0 - exp(-light_turn_speed * delta))
	var sway: float
	if _is_walking():
		sway = sin(_walk_distance / STRIDE_PIXELS * TAU * 2.0) * light_sway
	else:
		sway = sin(_idle_time * TAU * IDLE_FPS / 4.0) * light_sway * 0.25
	_flashlight.rotation = _light_angle + sway
	var row: int = _row()
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
