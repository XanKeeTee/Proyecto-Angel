class_name Stalker
extends Node2D
## La entidad oscura que a veces sigue al jugador por la espalda. Solo existe en la vista:
## no tiene colisión, no hace daño y no se guarda.
## Casi no se ve: una sombra alta y deforme más negra que el negro, que en la oscuridad solo se
## intuye por cómo tiembla el fondo detrás de ella y por el humo de sus bordes; a ratos, dos puntos
## pálidos. Se nota más con el rabillo del ojo que de frente (`set_gaze`).
## Sigue el camino que ha recorrido el jugador (así nunca atraviesa paredes); si el haz de la
## linterna la toca, se estira hacia arriba y se deshace en humo. Si alcanza al jugador sin que la
## mire, se hunde y se desvanece con un susurro. Lo crea y gobierna `HorrorDirector`.
## Arte: tools/art/entity.py (mapa de datos) + shaders/entity_shade.gdshader.

## Se ha ido: &"light" (la alumbraron), &"reached" (alcanzó al jugador),
## &"timeout" (se cansó) o &"lost" (el jugador cambió de sala por una puerta).
signal vanished(reason: StringName)

enum State { HIDDEN, APPEARING, FOLLOWING, DISSOLVING, FADING }

const SHEET: Texture2D = preload("res://assets/sprites/horror/entity.png")
const SHADER: Shader = preload("res://shaders/entity_shade.gdshader")
const FRAMES: int = 8
const FPS: float = 6.0
## Pies dentro del fotograma de 72×136 (ver tools/art/entity.py): pies en (36, 130).
const FEET_OFFSET: Vector2 = Vector2(0, -62)
## Punto del cuerpo (desde los pies) al que apunta la linterna para tocarla.
const AIM_OFFSET: Vector2 = Vector2(0, -40)
## Aparición: primero solo tiembla el aire (HAZE_LEAD s) y luego se condensa a saltos.
const APPEAR_TIME: float = 1.6
const HAZE_LEAD: float = 0.5
const APPEAR_STEPS: float = 5.0
const DISSOLVE_TIME: float = 0.5
const FADE_TIME: float = 0.9
## Distancia (por el camino) que intenta mantener mientras el jugador anda.
const KEEP_DISTANCE: float = 70.0
## Velocidad máxima del jugador (píxeles/s), para escalar la suya.
const PLAYER_SPEED: float = 78.0
## Cuando se queda atrás, acelera hasta este factor para no perderlo.
const CATCH_UP: float = 1.08
## Al estar el jugador quieto, avanza más despacio, como si dudara.
const CREEP: float = 0.45
## Cuánto negro pinta mirada de frente (1 = de lado o a la espalda). Solo queda el temblor del fondo.
const GAZE_PRESENCE: float = 0.12
## Velocidad (1/s) a la que se ajusta la presencia al mirarla o dejar de mirarla.
const PRESENCE_RATE: float = 2.5
## Ojos: cada cuánto se encienden [mín, máx] s, cuánto duran y su brillo máximo (tenue).
const EYES_EVERY: Vector2 = Vector2(2.5, 7.0)
const EYES_FOR: Vector2 = Vector2(0.4, 1.1)
const EYES_MAX: float = 0.55
## Tirones: cada cuánto [mín, máx] s se sacude de lado un instante.
const TWITCH_EVERY: Vector2 = Vector2(1.5, 4.5)
const TWITCH_TIME: float = 0.09

var state: State = State.HIDDEN
## Velocidad relativa a la del jugador.
var speed_factor: float = 0.82
## Distancia a la que «alcanza» (píxeles).
var reach: float = 24.0
## Cuánto la mira el jugador ahora (0 = a la espalda o de reojo, 1 = de frente).
var gaze: float = 0.0
## Depuración (capturas): ojos siempre encendidos (de reojo).
var debug_eyes: bool = false
## Negro que pinta ahora (se acerca a lo que pide `gaze`).
var presence: float = 1.0

var _path: Array[Vector2] = []
var _pending_reason: StringName = &""
var _life: float = 0.0
var _state_time: float = 0.0
var _anim: float = 0.0
var _eyes_at: float = 0.0
var _eyes_until: float = 0.0
var _eyes_start: float = 0.0
var _twitch_at: float = 0.0
var _twitch_end: float = 0.0
var _frame_skip: int = 0
var _body: Sprite2D
var _smoke: CPUParticles2D
var _material: ShaderMaterial
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	visible = false
	z_index = 0
	_rng.randomize()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_body = Sprite2D.new()
	_body.name = "Body"
	_body.texture = SHEET
	_body.hframes = FRAMES
	_body.offset = FEET_OFFSET
	_body.material = _material
	add_child(_body)
	_smoke = _make_smoke()
	add_child(_smoke)


func _process(delta: float) -> void:
	if state == State.HIDDEN:
		return
	_state_time += delta
	_anim += delta
	_body.frame = (int(_anim * FPS) + _frame_skip) % FRAMES
	presence = move_toward(presence, lerpf(1.0, GAZE_PRESENCE, gaze), PRESENCE_RATE * delta)
	_material.set_shader_parameter(&"presence", presence)
	_update_eyes()
	_update_twitch()
	match state:
		State.APPEARING:
			_set_appear(_state_time / APPEAR_TIME)
			if _state_time >= APPEAR_TIME:
				_set_state(State.FOLLOWING)
		State.DISSOLVING:
			var t: float = clampf(_state_time / DISSOLVE_TIME, 0.0, 1.0)
			_material.set_shader_parameter(&"dissolve", t)
			_material.set_shader_parameter(&"tear", 1.0 - t * 0.5)
			_material.set_shader_parameter(&"haze", 1.0 - t)
			# Se estira hacia arriba, como humo que se lleva una corriente.
			var ease_t: float = t * t
			_body.scale = Vector2(1.0 - 0.3 * ease_t, 1.0 + 0.4 * ease_t)
			if t >= 1.0:
				_finish(&"light")
		State.FADING:
			var u: float = clampf(_state_time / FADE_TIME, 0.0, 1.0)
			# Se hunde: se encoge un poco y se apaga a saltos; el aire tiembla hasta el final.
			_set_fade(floorf((1.0 - u) * APPEAR_STEPS) / APPEAR_STEPS)
			_material.set_shader_parameter(&"haze", 1.0 - u * u)
			_body.scale = Vector2(1.0 + 0.08 * u, 1.0 - 0.12 * u)
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
	return position.distance_to(player_pos) <= reach


## Aparece en `at` y seguirá los puntos de `path` (el camino del jugador desde ahí).
func appear(at: Vector2, path: Array[Vector2], lifetime: float) -> void:
	position = at
	_path = path.duplicate()
	_life = lifetime
	_anim = _rng.randf() * 10.0
	_body.scale = Vector2.ONE
	_body.position = Vector2.ZERO
	_material.set_shader_parameter(&"dissolve", 0.0)
	_material.set_shader_parameter(&"tear", 0.0)
	_material.set_shader_parameter(&"eyes", 0.0)
	_eyes_at = _anim + _rng.randf_range(EYES_EVERY.x, EYES_EVERY.y)
	_eyes_until = 0.0
	_twitch_at = _anim + _rng.randf_range(TWITCH_EVERY.x, TWITCH_EVERY.y)
	_twitch_end = 0.0
	presence = lerpf(1.0, GAZE_PRESENCE, gaze)
	_set_appear(0.0)
	visible = true
	_set_state(State.APPEARING)


## Cuánto la mira el jugador (0 = de reojo o a la espalda, 1 = de frente). De frente casi
## desaparece: solo queda el temblor del fondo; de reojo es más negra y se le ven los ojos.
func set_gaze(value: float) -> void:
	gaze = clampf(value, 0.0, 1.0)


## Se deshace por la luz: se estira hacia arriba, humo negro y motas de estática.
func dissolve() -> void:
	if not is_active() or state == State.DISSOLVING:
		return
	# Que el haz la «revele» un instante antes de romperse: negro entero.
	presence = 1.0
	_material.set_shader_parameter(&"presence", presence)
	_set_fade(1.0)
	_smoke.restart()
	_smoke.emitting = true
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


## Punto del cuerpo al que apunta la linterna para tocarla.
func aim_point() -> Vector2:
	return position + AIM_OFFSET


## Valor actual de un parámetro del shader (para pruebas y depuración).
func shader_value(param: StringName) -> float:
	return float(_material.get_shader_parameter(param))


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


func _set_fade(value: float) -> void:
	_material.set_shader_parameter(&"fade", value)


## Aparición (u de 0 a 1): primero solo tiembla el aire; luego la sombra se condensa a saltos,
## como una imagen que no acaba de sintonizar, y se asienta estirada hacia abajo.
func _set_appear(u: float) -> void:
	var lead: float = HAZE_LEAD / APPEAR_TIME
	_material.set_shader_parameter(&"haze", clampf(u / lead, 0.0, 1.0))
	var v: float = clampf((u - lead) / (1.0 - lead), 0.0, 1.0)
	_set_fade(1.0 if v >= 1.0 else floorf(v * APPEAR_STEPS) / APPEAR_STEPS)
	_body.scale = Vector2(1.0, 1.0 + 0.1 * (1.0 - v))


func _update_eyes() -> void:
	if _anim >= _eyes_at:
		_eyes_start = _anim
		_eyes_until = _anim + _rng.randf_range(EYES_FOR.x, EYES_FOR.y)
		_eyes_at = _eyes_until + _rng.randf_range(EYES_EVERY.x, EYES_EVERY.y)
	var value: float = 0.0
	if _anim < _eyes_until:
		value = EYES_MAX * clampf(minf(_anim - _eyes_start, _eyes_until - _anim) / 0.15, 0.0, 1.0)
	if debug_eyes:
		value = EYES_MAX
	# De frente no se le ven: solo de reojo.
	value *= clampf(1.0 - gaze * 1.6, 0.0, 1.0)
	if state == State.DISSOLVING or state == State.FADING:
		value = 0.0
	_material.set_shader_parameter(&"eyes", value)


func _update_twitch() -> void:
	if _anim >= _twitch_at:
		# Un tirón de lado y un fotograma que se salta.
		_body.position.x = (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(1.0, 2.0)
		_frame_skip += 1
		_twitch_end = _anim + TWITCH_TIME
		_twitch_at = _twitch_end + _rng.randf_range(TWITCH_EVERY.x, TWITCH_EVERY.y)
	elif _anim >= _twitch_end:
		_body.position.x = 0.0


func _finish(reason: StringName) -> void:
	_set_state(State.HIDDEN)
	visible = false
	_path.clear()
	_body.scale = Vector2.ONE
	_body.position = Vector2.ZERO
	vanished.emit(reason)


## Humo negro que sube al deshacerse (se ve contra el suelo iluminado por el haz).
func _make_smoke() -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.name = "Smoke"
	p.emitting = false
	p.one_shot = true
	p.amount = 60
	p.lifetime = 0.9
	p.explosiveness = 0.7
	p.position = Vector2(0, -62)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(10, 52)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 48.0
	p.gravity = Vector2(0, -30)
	p.damping_min = 10.0
	p.damping_max = 25.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(0.0, 0.0, 0.0, 0.95))
	ramp.set_color(1, Color(0.05, 0.05, 0.07, 0.0))
	p.color_ramp = ramp
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	return p
