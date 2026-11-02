class_name Stalker
extends Node2D
## La entidad oscura que a veces sigue al jugador por la espalda. Solo existe en la vista:
## no tiene colisión, no hace daño y no se guarda.
## Sigue el camino que ha recorrido el jugador (así nunca atraviesa paredes); si el haz de la
## linterna la toca, se deshace en estática. Si alcanza al jugador sin que la mire, se desvanece
## con un susurro. Lo crea y gobierna `HorrorDirector`.

## Se ha ido: &"light" (la alumbraron), &"reached" (alcanzó al jugador),
## &"timeout" (se cansó) o &"lost" (el jugador cambió de sala por una puerta).
signal vanished(reason: StringName)

enum State { HIDDEN, APPEARING, FOLLOWING, DISSOLVING, FADING }

const SHEET: Texture2D = preload("res://assets/sprites/horror/entity.png")
const GLOW: Texture2D = preload("res://assets/sprites/horror/entity_glow.png")
const SHADER: Shader = preload("res://shaders/entity_dissolve.gdshader")
const FRAMES: int = 8
const FPS: float = 7.0
## Pies dentro del fotograma de 64×112 (ver tools/art/entity.py).
const FEET_OFFSET: Vector2 = Vector2(0, -48)
const APPEAR_TIME: float = 0.9
const DISSOLVE_TIME: float = 0.5
const FADE_TIME: float = 0.7
## Distancia (por el camino) que intenta mantener mientras el jugador anda.
const KEEP_DISTANCE: float = 70.0
## Velocidad máxima del jugador (píxeles/s), para escalar la suya.
const PLAYER_SPEED: float = 78.0
## Cuando se queda atrás, acelera hasta este factor para no perderlo.
const CATCH_UP: float = 1.08
## Al estar el jugador quieto, avanza más despacio, como si dudara.
const CREEP: float = 0.45

var state: State = State.HIDDEN
## Velocidad relativa a la del jugador.
var speed_factor: float = 0.82
## Distancia a la que «alcanza» (píxeles).
var reach: float = 24.0

var _path: Array[Vector2] = []
var _pending_reason: StringName = &""
var _life: float = 0.0
var _state_time: float = 0.0
var _anim: float = 0.0
var _body: Sprite2D
var _glow: Sprite2D
var _sparks: CPUParticles2D
var _material: ShaderMaterial


func _init() -> void:
	visible = false
	z_index = 0
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_body = Sprite2D.new()
	_body.name = "Body"
	_body.texture = SHEET
	_body.hframes = FRAMES
	_body.offset = FEET_OFFSET
	_body.material = _material
	add_child(_body)
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.texture = GLOW
	_glow.hframes = FRAMES
	_glow.offset = FEET_OFFSET
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow.material = additive
	add_child(_glow)
	_sparks = _make_sparks()
	add_child(_sparks)


func _process(delta: float) -> void:
	if state == State.HIDDEN:
		return
	_state_time += delta
	_anim += delta
	_body.frame = int(_anim * FPS) % FRAMES
	_glow.frame = _body.frame
	# La máscara late muy despacio, casi invisible.
	_glow.modulate.a = (0.6 + 0.4 * sin(_anim * 2.3)) * _material.get_shader_parameter(&"fade")
	match state:
		State.APPEARING:
			_set_fade(clampf(_state_time / APPEAR_TIME, 0.0, 1.0))
			if _state_time >= APPEAR_TIME:
				_set_state(State.FOLLOWING)
		State.DISSOLVING:
			var t: float = clampf(_state_time / DISSOLVE_TIME, 0.0, 1.0)
			_material.set_shader_parameter(&"dissolve", t)
			_material.set_shader_parameter(&"tear", 1.0 - t * 0.5)
			_glow.modulate.a = 1.0 - t
			if t >= 1.0:
				_finish(&"light")
		State.FADING:
			_set_fade(1.0 - clampf(_state_time / FADE_TIME, 0.0, 1.0))
			if _state_time >= FADE_TIME:
				_finish(_pending_reason)


## Mueve la entidad por el camino. `player_pos` es la posición actual del jugador;
## `player_moving` si está andando. Devuelve true si lo ha alcanzado en este paso.
func follow(delta: float, player_pos: Vector2, player_moving: bool) -> bool:
	if state != State.FOLLOWING and state != State.APPEARING:
		return false
	_life -= delta
	if _life <= 0.0:
		vanish(&"timeout")
		return false
	if _path.is_empty() or _path[-1].distance_to(player_pos) > 2.0:
		_path.append(player_pos)
	var remaining: float = path_length()
	var speed: float = PLAYER_SPEED * speed_factor
	if not player_moving:
		speed *= CREEP
	elif remaining > KEEP_DISTANCE * 1.8:
		speed = PLAYER_SPEED * CATCH_UP
	elif remaining < KEEP_DISTANCE:
		speed *= 0.6
	var step: float = speed * delta
	var before: Vector2 = position
	while step > 0.0 and not _path.is_empty():
		var to: Vector2 = _path[0] - position
		if to.length() <= step:
			position = _path[0]
			step -= to.length()
			_path.pop_front()
		else:
			position += to.normalized() * step
			step = 0.0
	var moved: Vector2 = position - before
	if absf(moved.x) > 0.05:
		_body.flip_h = moved.x < 0.0
		_glow.flip_h = _body.flip_h
	return position.distance_to(player_pos) <= reach


## Aparece en `at` y seguirá los puntos de `path` (el camino del jugador desde ahí).
func appear(at: Vector2, path: Array[Vector2], lifetime: float) -> void:
	position = at
	_path = path.duplicate()
	_life = lifetime
	_anim = randf() * 10.0
	_material.set_shader_parameter(&"dissolve", 0.0)
	_material.set_shader_parameter(&"tear", 0.0)
	_set_fade(0.0)
	visible = true
	_set_state(State.APPEARING)


## Se deshace por la luz: estática, chispas y desgarro de cinta.
func dissolve() -> void:
	if not is_active() or state == State.DISSOLVING:
		return
	_sparks.restart()
	_sparks.emitting = true
	_set_state(State.DISSOLVING)


## Se desvanece sin estallar (la razón se emite al terminar).
func vanish(reason: StringName) -> void:
	if not is_active() or state == State.FADING or state == State.DISSOLVING:
		return
	_pending_reason = reason
	_set_state(State.FADING)


## Desaparece en el acto (cambio de sala, texto en pantalla…).
func hide_now(reason: StringName = &"lost") -> void:
	if state == State.HIDDEN:
		return
	_finish(reason)


func is_active() -> bool:
	return state != State.HIDDEN


## Si puede ser alcanzada por la luz (no mientras ya se deshace o se va).
func is_solid() -> bool:
	return state == State.APPEARING or state == State.FOLLOWING


## Largo del camino que le queda hasta el jugador.
func path_length() -> float:
	var total: float = 0.0
	var prev: Vector2 = position
	for p: Vector2 in _path:
		total += prev.distance_to(p)
		prev = p
	return total


## Punto del cuerpo al que apunta la linterna para tocarla (pecho).
func aim_point() -> Vector2:
	return position + Vector2(0, -38)


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


func _set_fade(value: float) -> void:
	_material.set_shader_parameter(&"fade", value)


func _finish(reason: StringName) -> void:
	_set_state(State.HIDDEN)
	visible = false
	_path.clear()
	vanished.emit(reason)


func _make_sparks() -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.name = "Sparks"
	p.emitting = false
	p.one_shot = true
	p.amount = 46
	p.lifetime = 0.55
	p.explosiveness = 0.85
	p.position = Vector2(0, -44)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(12, 34)
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 46.0
	p.gravity = Vector2(0, -12)
	p.damping_min = 20.0
	p.damping_max = 40.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(0.91, 0.88, 0.83, 1.0))
	ramp.set_color(1, Color(0.37, 0.72, 0.69, 0.0))
	p.color_ramp = ramp
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	return p
