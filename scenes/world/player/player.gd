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

## Pide interactuar con lo que hay delante: casillas candidatas, de la más cercana a la más lejana.
signal interact_requested(cells: Array[Vector2i])
## Pide examinar lo que hay delante.
signal examine_requested(cells: Array[Vector2i])
## Ha entrado en una casilla nueva.
signal cell_entered(cell: Vector2i)

const TILE_SIZE: int = 32
## Velocidad máxima en píxeles por segundo. Lento a propósito: recién operado.
const MAX_SPEED: float = 78.0
const ACCELERATION: float = 520.0
const FRICTION: float = 700.0
## Un ciclo completo de paso (8 fotogramas) cubre esta distancia.
const STRIDE_PIXELS: float = 64.0
## Respiración: 8 fotogramas en unos 2,4 s.
const IDLE_FPS: float = 3.3
## Gestos ocasionales en reposo (mano a la herida, mirar alrededor).
const FIDGET_FPS: float = 7.0
const FIDGET_EVERY: Vector2 = Vector2(7.0, 13.0)
## Tiempo por paso de orientación al girar (pasa por las intermedias).
const TURN_STEP: float = 0.045
## Por debajo de esta velocidad se considera parado (animación de reposo).
const WALK_THRESHOLD: float = 12.0
## Hoja del protagonista: 24 columnas y 8 filas (ver tools/art/sprite_meta.json).
const COLUMNS: int = 64
const DIRECTIONS: int = 8
const ANIM_IDLE: Vector2i = Vector2i(0, 8)
const ANIM_FIDGET: Vector2i = Vector2i(8, 12)
const ANIM_WALK: Vector2i = Vector2i(20, 12)
const ANIM_IDLE_FLASH: Vector2i = Vector2i(32, 8)
const ANIM_LOOK: Vector2i = Vector2i(40, 12)
const ANIM_WALK_FLASH: Vector2i = Vector2i(52, 12)
const BOUNCE_DISTANCE: float = 76.0
## Distancias a las que se mira al examinar.
const REACH: Array[float] = [18.0, 30.0]

## Origen de la luz (la mano) por fila de orientación: abajo, abajo-izq., izq., arriba-izq.,
## arriba, arriba-der., der., abajo-der.
@export var flashlight_offsets: Array[Vector2] = []
## Posición de la lente en cada fotograma con linterna: [fila][columna] -> [x, y] respecto a los pies
## (la luz sale de la propia linterna). La rellena tools/levels/build_player.
@export var lens_frames: Array = []
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
## Intensidad de la linterna según la batería (0..1); por debajo de 0,2 parpadea y amarillea.
var _light_level: float = 1.0
var _display_row: int = 0
var _turn_timer: float = 0.0
var _fidget_time: float = -1.0
var _next_fidget: float = 9.0
## Multiplicador de velocidad (heridas, sangrado…).
var speed_scale: float = 1.0

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
		if Input.is_action_just_pressed(InputActions.INTERACT):
			interact_requested.emit(_probe_cells())
		elif Input.is_action_just_pressed(InputActions.EXAMINE):
			examine_requested.emit(_probe_cells())
		wish = Input.get_vector(InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT, InputActions.MOVE_UP, InputActions.MOVE_DOWN)
	if wish != Vector2.ZERO:
		velocity = velocity.move_toward(wish * MAX_SPEED * speed_scale, ACCELERATION * delta)
		facing_angle = wish.angle()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	var before: Vector2 = position
	move_and_slide()
	var stepped: float = position.distance_to(before)
	# Un paso cada media zancada: suena el pie descalzo.
	if floori(_walk_distance / (STRIDE_PIXELS / 2.0)) != floori((_walk_distance + stepped) / (STRIDE_PIXELS / 2.0)):
		Sfx.at(get_parent(), "step_%d" % randi_range(1, 4), position, -10.0, 0.08)
	_walk_distance += stepped
	if cell != _last_cell:
		_last_cell = cell
		cell_entered.emit(cell)


func _process(delta: float) -> void:
	if not _is_walking():
		_idle_time += delta
		if _fidget_time < 0.0 and _idle_time > _next_fidget:
			_fidget_time = 0.0
		elif _fidget_time >= 0.0:
			_fidget_time += delta
			var anim: Vector2i = ANIM_LOOK if _holding_flashlight else ANIM_FIDGET
			if _fidget_time * FIDGET_FPS >= anim.y:
				_fidget_time = -1.0
				_idle_time = 0.0
				_next_fidget = randf_range(FIDGET_EVERY.x, FIDGET_EVERY.y)
	else:
		_idle_time = 0.0
		_fidget_time = -1.0
	_turn(delta)
	_update_frame()
	_update_light(delta)


## Coloca al personaje en el centro de una celda, parado.
func place(target: Vector2i, direction: Vector2i) -> void:
	position = Vector2(target * TILE_SIZE) + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	velocity = Vector2.ZERO
	_last_cell = target
	face(direction)
	_light_angle = facing_angle
	_display_row = _row()
	_camera.reset_smoothing()


## Gira hacia una dirección (vector de casilla, admite diagonales).
func face(direction: Vector2i) -> void:
	facing_angle = Vector2(direction).angle()


## Detiene al personaje en seco (para textos y eventos).
func stop() -> void:
	velocity = Vector2.ZERO


func has_flashlight_on() -> bool:
	return _flashlight.enabled


## Si sujeta la linterna (cambia la animación). No la enciende.
func set_holding_flashlight(holding: bool) -> void:
	_holding_flashlight = holding


## Enciende o apaga la luz sin parpadeo (lo decide la escena según la batería).
func set_light_on(on: bool) -> void:
	if on != _flashlight.enabled:
		_set_light_enabled(on)


## Nivel de la batería (0..1).
func set_light_level(level: float) -> void:
	_light_level = clampf(level, 0.0, 1.0)


## Casillas que tiene delante (para el indicador de interacción).
func probe_cells() -> Array[Vector2i]:
	return _probe_cells()


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


## Gira el sprite hacia la orientación deseada pasando por las intermedias.
func _turn(delta: float) -> void:
	var target: int = _row()
	if target == _display_row:
		_turn_timer = 0.0
		return
	_turn_timer += delta
	if _turn_timer < TURN_STEP:
		return
	_turn_timer = 0.0
	var diff: int = posmod(target - _display_row, DIRECTIONS)
	_display_row = posmod(_display_row + (1 if diff <= DIRECTIONS / 2 else -1), DIRECTIONS)


func _update_frame() -> void:
	var anim: Vector2i
	var index: int
	if _is_walking():
		anim = ANIM_WALK_FLASH if _holding_flashlight else ANIM_WALK
		index = int(fposmod(_walk_distance, STRIDE_PIXELS) / STRIDE_PIXELS * anim.y) % anim.y
	elif _fidget_time >= 0.0:
		anim = ANIM_LOOK if _holding_flashlight else ANIM_FIDGET
		index = mini(int(_fidget_time * FIDGET_FPS), anim.y - 1)
	else:
		anim = ANIM_IDLE_FLASH if _holding_flashlight else ANIM_IDLE
		index = int(_idle_time * IDLE_FPS) % anim.y
	_sprite.frame = _display_row * COLUMNS + anim.x + index
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
	# La luz sale de la lente de la linterna, fotograma a fotograma.
	var hand: Vector2 = _lens_offset()
	_flashlight.position = _flashlight.position.lerp(hand, 1.0 - exp(-30.0 * delta))
	# Pequeñas variaciones de una bombilla vieja.
	var jitter: float = 0.96 + 0.04 * randf()
	if randf() < 0.004:
		jitter = 0.55
	# Batería baja: más débil, más amarilla y con caídas frecuentes.
	var weak: float = clampf(_light_level / 0.25, 0.0, 1.0)
	if _light_level < 0.2 and randf() < 0.05:
		jitter *= randf_range(0.1, 0.5)
	jitter *= lerpf(0.45, 1.0, weak)
	_flashlight.color = Color(1.0, 0.93, 0.8).lerp(Color(1.0, 0.72, 0.42), 1.0 - weak)
	_flashlight.energy = _flashlight_energy * jitter
	_bounce.position = _flashlight.position + Vector2.from_angle(_flashlight.rotation) * BOUNCE_DISTANCE
	_bounce.energy = _bounce_energy * jitter


func _lens_offset() -> Vector2:
	var row: int = _display_row
	var column: int = _sprite.frame % COLUMNS
	if row < lens_frames.size():
		var row_data: Array = lens_frames[row]
		if column < row_data.size() and row_data[column] != null:
			var p: Array = row_data[column]
			return Vector2(float(p[0]), float(p[1]))
	return flashlight_offsets[row] if row < flashlight_offsets.size() else Vector2.ZERO


func _set_light_enabled(on: bool) -> void:
	_flashlight.enabled = on
	_bounce.enabled = on
	_glow.visible = on
