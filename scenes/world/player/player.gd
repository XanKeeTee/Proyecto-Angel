class_name Player
extends CharacterBody2D
## Protagonista en el mapa: movimiento libre en cualquier ángulo (analógico con mando),
## con aceleración y frenada suaves, colisión con paredes y muebles, y sprite en 16 orientaciones.
## - Apunta con el ratón (o el stick derecho): mira y alumbra hacia el puntero aunque camine
##   en otra dirección. Sin ratón ni stick derecho, mira hacia donde camina.
## - Según hacia dónde anda respecto a donde mira usa un paso distinto: hacia delante, de
##   espaldas (más corto, tanteando con la punta del pie) o de lado (la cadera gira hacia donde
##   va y el tronco y la cabeza siguen mirando al frente). Para que los pies no patinen, el cuerpo
##   se gira hasta una orientación (22,5°) hacia donde van las piernas.
## - El ciclo de paso avanza con la distancia recorrida de verdad (los pies no patinan,
##   tampoco al deslizarse contra una pared).
## - Con Shift (o el stick izquierdo pulsado / L2) corre un poco: solo hacia delante o en diagonal
##   hacia delante, con transición suave y mientras le quede aliento (RunBreath). Inclina algo
##   el cuerpo y pisa más fuerte; al agotarse respira agitado.
## - Al girar parado más de 45° arrastra los pies. En reposo respira y, de vez en cuando, hace
##   un gesto (mano a la herida o mirar alrededor con la linterna).
## - La ropa va en capas (cabeza, cuerpo, piernas, pies) encima del cuerpo. Las prendas
##   largas (las batas) se balancean con un muelle amortiguado que reacciona al movimiento.
## - Acciones de interacción (play_action) y levantarse de la camilla (play_get_up).
## - Si lleva la linterna, la sujeta con la mano derecha: la luz sale de la lente y apunta
##   hacia donde mira, con un poco de inercia y balanceo. En la mano izquierda puede llevar un
##   arma (set_held_weapon).
## - Las hojas de sprites (andar, con linterna, acciones, levantarse) se cargan solo mientras
##   se usan, también las de la ropa.
## El nodo está en los PIES del personaje.

## Pide interactuar con lo que hay delante: casillas candidatas, de la más cercana a la más lejana.
signal interact_requested(cells: Array[Vector2i])
## Pide examinar lo que hay delante.
signal examine_requested(cells: Array[Vector2i])
## Ha entrado en una casilla nueva.
signal cell_entered(cell: Vector2i)

## Forma de andar respecto a hacia dónde mira.
enum Gait { FORWARD, BACK, LEFT, RIGHT }
enum AimMode { MOVE, MOUSE, STICK }

const TILE_SIZE: int = 32
## Velocidad máxima en píxeles por segundo. Lento a propósito: recién operado.
const MAX_SPEED: float = 78.0
const ACCELERATION: float = 520.0
const FRICTION: float = 700.0
## Distancia que cubre un ciclo completo de cada paso (dos pisadas).
const STRIDE_PIXELS: float = 64.0
const BACK_STRIDE_PIXELS: float = 44.0
const STRAFE_STRIDE_PIXELS: float = 58.0
## Respiración: 8 fotogramas en unos 2,4 s.
const IDLE_FPS: float = 3.3
## Gestos ocasionales en reposo (mano a la herida, mirar alrededor).
const FIDGET_FPS: float = 7.0
const FIDGET_EVERY: Vector2 = Vector2(7.0, 13.0)
## Tiempo por paso de orientación (22,5°) al girar; parado y arrastrando los pies, más lento.
const TURN_STEP: float = 0.028
const SHUFFLE_TURN_STEP: float = 0.055
## Arrastre de pies: a partir de cuántas orientaciones de giro parado, y a qué ritmo.
const SHUFFLE_MIN_ROWS: int = 3
const SHUFFLE_FPS: float = 14.0
## Por debajo de esta velocidad se considera parado (animación de reposo).
const WALK_THRESHOLD: float = 12.0
## Hoja de andar: 76 columnas y 16 filas (ver tools/art/sprite_meta.json). La hoja con linterna
## tiene la misma distribución (y "fidget" es mirar alrededor).
const COLUMNS: int = 76
const DIRECTIONS: int = 16
const ACTION_DIRECTIONS: int = 8
const ANIM_IDLE: Vector2i = Vector2i(0, 8)
const ANIM_FIDGET: Vector2i = Vector2i(8, 12)
const ANIM_LOOK: Vector2i = ANIM_FIDGET
const ANIM_WALK: Vector2i = Vector2i(20, 12)
const ANIM_BACK: Vector2i = Vector2i(32, 12)
const ANIM_STRAFE_LEFT: Vector2i = Vector2i(44, 12)
const ANIM_STRAFE_RIGHT: Vector2i = Vector2i(56, 12)
const ANIM_TURN: Vector2i = Vector2i(68, 8)
## Zonas de ángulo (entre hacia dónde anda y hacia dónde mira) de cada paso, con margen para
## no saltar de uno a otro en el borde.
const FORWARD_ZONE: float = deg_to_rad(50.0)
const BACK_ZONE: float = deg_to_rad(130.0)
const GAIT_HYSTERESIS: float = deg_to_rad(8.0)
## Cuánto puede girarse el cuerpo respecto a donde apunta para que los pies vayan bien.
const MAX_BODY_OFFSET: float = deg_to_rad(22.5)
const BOUNCE_DISTANCE: float = 85.0
## Distancias a las que se mira al examinar.
const REACH: Array[float] = [18.0, 30.0]
## Altura del pecho sobre los pies: desde ahí se apunta al ratón.
const AIM_HEIGHT: float = 30.0
## Por debajo de esta distancia al puntero no se cambia de orientación (evita giros locos).
const AIM_DEADZONE: float = 10.0
const STICK_DEADZONE: float = 0.35
## Velocidad relativa al andar de lado y de espaldas.
const STRAFE_SPEED: float = 0.8
const BACKWARD_SPEED: float = 0.6
## Correr: a partir de qué coseno entre hacia dónde anda y hacia dónde mira empieza a poder
## correr (0,5 = 60°) y desde cuál corre del todo (0,7 ≈ 45°, la diagonal hacia delante).
const RUN_ALONG_MIN: float = 0.5
const RUN_ALONG_FULL: float = 0.7
## Segundos que tarda en pasar de andar a correr y de correr a andar.
const RUN_BLEND_IN: float = 0.35
const RUN_BLEND_OUT: float = 0.5
## Inclinación hacia delante al correr (radianes de sesgo del sprite, solo se ve en horizontal).
const RUN_LEAN: float = 0.07
## Pisadas al correr: cuánto más fuertes (dB) y más agudas (más rápidas).
const RUN_STEP_DB: float = 4.0
const RUN_STEP_PITCH: float = 0.07
## Respiración agitada al quedarse sin aliento.
const RUN_BREATH_SOUND: String = "breath_run_male"
const RUN_BREATH_DB: float = -6.0
## Física de la tela: rigidez y amortiguación del muelle, cuánto se queda atrás con la velocidad,
## ondeo con cada paso, empujón al girar y desplazamiento máximo del bajo (píxeles).
const CLOTH_STIFFNESS: float = 48.0
const CLOTH_DAMPING: float = 5.5
const CLOTH_DRAG: float = 0.036
const CLOTH_WAVE: float = 0.8
const CLOTH_TURN_KICK: float = 10.0
const CLOTH_MAX: float = 3.6
## Orden de dibujo de las capas de ropa (de abajo arriba).
const OUTFIT_LAYERS: Array[StringName] = [&"feet", &"legs", &"body", &"head"]
## Acciones: a qué distancia del objeto se coloca antes de empezar (píxeles), cuánto puede
## acercarse andando y cuánto espera como mucho a terminar de girarse.
const ACTION_DISTANCE: float = 30.0
const ACTION_APPROACH_MAX: float = 14.0
const ACTION_TURN_TIMEOUT: float = 0.5
## Arma en la mano: largo en píxeles al que se escala la textura y píxel de la empuñadura
## (desde el borde izquierdo de la textura, que apunta hacia la derecha).
const WEAPON_LENGTH: float = 15.0
const WEAPON_GRIP: float = 0.18
## Hojas.
const SHEET_MOVE: StringName = &"move"
const SHEET_MOVE_FLASH: StringName = &"move_flash"
const SHEET_ACTION: StringName = &"action"
const SHEET_ACTION_FLASH: StringName = &"action_flash"
const SHEET_GETUP: StringName = &"getup"

## Origen de la luz (la mano) por fila de orientación, de reserva.
@export var flashlight_offsets: Array[Vector2] = []
## Datos de cada hoja (de tools/art/sprite_meta.json): sufijo, fotograma, origen, columnas,
## filas, animaciones, y por fila y columna la lente ("lens") y la mano libre ("hand").
@export var sheets: Dictionary = {}
## Hoja -> ruta de la CanvasTexture del cuerpo.
@export var body_paths: Dictionary = {}
## Ruta base del cuerpo (sin extensión), para las capas de brillo de la lente.
@export var glow_base: String = "res://assets/sprites/characters/protagonist"
## Dónde cae el origen del dibujo de la camilla respecto a su nodo (sprite_meta "stretcher").
@export var bed_anchor: Vector2 = Vector2(0, -16)
## Rapidez con que el haz sigue al giro (más alto = menos inercia).
@export var light_turn_speed: float = 9.0
## Balanceo del haz al andar, en radianes.
@export var light_sway: float = 0.045

var input_enabled: bool = false
## Con qué se apunta ahora mismo (cambia solo según lo último que se ha tocado).
var aim_mode: AimMode = AimMode.MOUSE
## Si no es cero, apunta en esa dirección sin mirar ratón ni mando (pruebas y escenas guionizadas).
var forced_aim: Vector2 = Vector2.ZERO
## Ángulo hacia el que mira (radianes, 0 = derecha, PI/2 = abajo).
var facing_angle: float = PI / 2.0
## Forma de andar actual.
var gait: Gait = Gait.FORWARD
## Casilla en la que están los pies.
var cell: Vector2i:
	get:
		return Vector2i(floori(position.x / TILE_SIZE), floori(position.y / TILE_SIZE))
## Multiplicador de velocidad (heridas, sangrado…).
var speed_scale: float = 1.0
## Sonido de pisada (prefijo; hay variantes _1 a _4) y su volumen. Cambian con el calzado.
var step_sound: String = "step"
var step_volume_db: float = -10.0
## Aliento para correr (lógica en RunBreath).
var breath: RunBreath = RunBreath.new()

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
## Fase del ciclo de paso (en ciclos): avanza con la distancia recorrida.
var _phase: float = 0.0
## Ángulo (pantalla) hacia el que se mueve de verdad.
var _move_angle: float = 0.0
## Arrastre de pies al girar parado: tiempo desde que empezó (negativo = no).
var _shuffle_time: float = -1.0
var _cloth_offset: Vector2 = Vector2.ZERO
var _cloth_velocity: Vector2 = Vector2.ZERO
var _prev_velocity: Vector2 = Vector2.ZERO
var _layers: Dictionary[StringName, Sprite2D] = {}
var _cloth_amount: Dictionary[StringName, float] = {}
## Capa -> ruta de la hoja de andar de la prenda puesta ("" = nada).
var _wear: Dictionary[StringName, String] = {}
var _sheet: StringName = &""
## Mientras corre una acción o levantarse, el fotograma lo pone esa corrutina.
var _scripted: bool = false
## Movimiento pedido por una corrutina (acercarse al objeto).
var _scripted_wish: Vector2 = Vector2.ZERO
var _weapon_texture: Texture2D
var _weapon_upright: bool = false
## Depuración (capturas): --walk=grados anda sin parar hacia ese ángulo de pantalla;
## --act=acción la repite sin parar (con medio segundo de reposo entre una y otra);
## --weapon=id pone en la mano el icono de ese objeto.
var _debug_walk: Vector2 = Vector2.ZERO
var _debug_action: StringName = &""
## Depuración: --run corre al andar con --walk.
var _debug_run: bool = false
## Intensidad de la carrera (0 = andar, 1 = correr), con transición suave.
var _run_blend: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _glow: Sprite2D = $Sprite2D/Glow
@onready var _weapon: Sprite2D = get_node_or_null(^"Sprite2D/Weapon") as Sprite2D
@onready var _flashlight: PointLight2D = $Flashlight
@onready var _bounce: PointLight2D = $Bounce
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	_flashlight_energy = _flashlight.energy
	_bounce_energy = _bounce.energy
	_set_light_enabled(false)
	_light_angle = facing_angle
	_last_cell = cell
	for layer: StringName in OUTFIT_LAYERS:
		var node: Sprite2D = _sprite.get_node_or_null(NodePath(String(layer).capitalize())) as Sprite2D
		if node != null:
			_layers[layer] = node
			node.visible = false
	if _weapon == null:
		_weapon = Sprite2D.new()
		_weapon.name = "Weapon"
		_weapon.visible = false
		_weapon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.add_child(_weapon)
	_use_sheet(SHEET_MOVE)
	_update_frame()
	breath.exhausted.connect(_on_exhausted)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--walk="):
			_debug_walk = Vector2.from_angle(deg_to_rad(arg.trim_prefix("--walk=").to_float()))
		elif arg.begins_with("--act="):
			_debug_action = StringName(arg.trim_prefix("--act="))
		elif arg == "--run":
			_debug_run = true
		elif arg.begins_with("--weapon="):
			var item: ItemDef = Registry.item(StringName(arg.trim_prefix("--weapon=")))
			if item != null:
				set_held_weapon(item.icon)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		aim_mode = AimMode.MOUSE
	elif event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		if absf(motion.axis_value) > STICK_DEADZONE:
			if motion.axis == JOY_AXIS_RIGHT_X or motion.axis == JOY_AXIS_RIGHT_Y:
				aim_mode = AimMode.STICK
			elif aim_mode == AimMode.MOUSE and (motion.axis == JOY_AXIS_LEFT_X or motion.axis == JOY_AXIS_LEFT_Y):
				aim_mode = AimMode.MOVE


func _physics_process(delta: float) -> void:
	var wish: Vector2 = _scripted_wish
	var wants_run: bool = false
	if _debug_walk != Vector2.ZERO and not _scripted and visible:
		wish = _debug_walk
		wants_run = _debug_run
	elif input_enabled and not _scripted:
		wants_run = Input.is_action_pressed(InputActions.RUN)
		if Input.is_action_just_pressed(InputActions.INTERACT):
			interact_requested.emit(_probe_cells())
		elif Input.is_action_just_pressed(InputActions.EXAMINE):
			examine_requested.emit(_probe_cells())
		wish = Input.get_vector(InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT, InputActions.MOVE_UP, InputActions.MOVE_DOWN)
	if not _scripted:
		var aim: Vector2 = _aim_vector() if input_enabled else forced_aim
		if aim != Vector2.ZERO:
			facing_angle = aim.angle()
		elif wish != Vector2.ZERO:
			facing_angle = wish.angle()
	var run_target: float = 0.0
	if wish != Vector2.ZERO:
		# De lado y de espaldas se anda más despacio.
		var along: float = wish.normalized().dot(Vector2.from_angle(facing_angle))
		var pace: float = lerpf(STRAFE_SPEED, 1.0, along) if along >= 0.0 else lerpf(STRAFE_SPEED, BACKWARD_SPEED, -along)
		# Correr: solo hacia delante (o en diagonal hacia delante) y si le queda aliento.
		if wants_run and breath.can_run():
			run_target = clampf((along - RUN_ALONG_MIN) / (RUN_ALONG_FULL - RUN_ALONG_MIN), 0.0, 1.0)
		_run_blend = move_toward(_run_blend, run_target, delta / (RUN_BLEND_IN if run_target > _run_blend else RUN_BLEND_OUT))
		pace *= lerpf(1.0, breath.speed_multiplier(), _run_blend)
		velocity = velocity.move_toward(wish * MAX_SPEED * speed_scale * pace, ACCELERATION * delta)
	else:
		_run_blend = move_toward(_run_blend, 0.0, delta / RUN_BLEND_OUT)
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	var before: Vector2 = position
	move_and_slide()
	var moved: Vector2 = position - before
	var stepped: float = moved.length()
	if stepped > 0.01:
		_move_angle = moved.angle()
		_update_gait()
	# El ciclo avanza con la distancia real, a la medida del paso que está dando.
	var phase_before: float = _phase
	_phase += stepped / _stride_length()
	_update_cloth(delta)
	# Gasta aliento solo si avanza de verdad (no empujando una pared).
	var advancing: bool = stepped > WALK_THRESHOLD * delta
	breath.tick(delta, _run_blend if advancing else 0.0, advancing)
	# Una pisada cada medio ciclo; corriendo, más fuerte y algo más rápida.
	if floori(phase_before * 2.0) != floori(_phase * 2.0):
		var step: AudioStreamPlayer2D = Sfx.at(get_parent(), "%s_%d" % [step_sound, randi_range(1, 4)], position,
			step_volume_db + RUN_STEP_DB * _run_blend, 0.08)
		if step != null:
			step.pitch_scale += RUN_STEP_PITCH * _run_blend
	_walk_distance += stepped
	if cell != _last_cell:
		_last_cell = cell
		cell_entered.emit(cell)


func _process(delta: float) -> void:
	if _scripted:
		_sprite.skew = 0.0
		_update_light(delta)
		return
	if not _is_walking():
		_idle_time += delta
		if _fidget_time < 0.0 and _idle_time > _next_fidget and _shuffle_time < 0.0:
			_fidget_time = 0.0
		elif _fidget_time >= 0.0:
			_fidget_time += delta
			if _fidget_time * FIDGET_FPS >= ANIM_FIDGET.y:
				_fidget_time = -1.0
				_idle_time = 0.0
				_next_fidget = randf_range(FIDGET_EVERY.x, FIDGET_EVERY.y)
	else:
		_idle_time = 0.0
		_fidget_time = -1.0
	_turn(delta)
	_update_frame()
	_update_lean(delta)
	_update_light(delta)
	if _debug_action != &"" and _idle_time > 0.5 and visible:
		play_action(_debug_action, position + Vector2.from_angle(facing_angle) * 32.0)


# --- ropa ------------------------------------------------------------------------------------

## Viste al personaje: por capa (&"head", &"body", &"legs", &"feet"), la ruta de la hoja de andar
## de la prenda (ItemDef.wear_path; "" = nada), cuánto se mueve con la física (0 = rígida) y
## a qué alturas está la cintura y el bajo. La hoja se carga ahora y se suelta al quitársela.
func set_outfit(layer: StringName, wear_path: String, cloth: float = 0.0, waist: float = 32.0, hem: float = 14.0) -> void:
	var node: Sprite2D = _layers.get(layer)
	if node == null:
		return
	_wear[layer] = wear_path
	_cloth_amount[layer] = cloth
	var mat: ShaderMaterial = node.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"waist", waist)
		mat.set_shader_parameter(&"hem", hem)
	_apply_layer_sheet(layer)


## Compatibilidad: viste una capa con una textura ya cargada (solo para la hoja de andar).
func set_outfit_layer(layer: StringName, sheet: Texture2D, cloth: float = 0.0) -> void:
	set_outfit(layer, sheet.resource_path if sheet != null else "", cloth)


## Ruta de la hoja `sheet` de una prenda a partir de la de andar (…/<id>_canvas.tres).
func wear_sheet_path(move_path: String, sheet: StringName) -> String:
	if move_path == "" or not sheets.has(sheet):
		return ""
	return move_path.trim_suffix("_canvas.tres") + String(sheets[sheet]["suffix"]) + "_canvas.tres"


## Desplazamiento actual del bajo de la ropa (píxeles), para pruebas.
func cloth_offset() -> Vector2:
	return _cloth_offset


## Cuánto se desplazan en pantalla los píxeles de la prenda de una capa que están a `height`
## píxeles sobre los pies (lo mismo que calcula cloth_sway.gdshader).
func cloth_shift_at(layer: StringName, height: float) -> Vector2:
	var node: Sprite2D = _layers.get(layer)
	if node == null or not node.visible:
		return Vector2.ZERO
	var mat: ShaderMaterial = node.material as ShaderMaterial
	var sway: Vector2 = mat.get_shader_parameter(&"sway")
	var waist: float = mat.get_shader_parameter(&"waist")
	var hem: float = mat.get_shader_parameter(&"hem")
	var w: float = clampf((waist - height) / maxf(waist - hem, 0.001), 0.0, 1.0)
	return sway * w * w


# --- colocación y estado -----------------------------------------------------------------------

## Coloca al personaje en el centro de una celda, parado.
func place(target: Vector2i, direction: Vector2i) -> void:
	place_at(Vector2(target * TILE_SIZE) + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0), Vector2(direction).angle())


## Coloca al personaje en un punto exacto, parado y mirando hacia `angle`.
func place_at(point: Vector2, angle: float) -> void:
	position = point
	velocity = Vector2.ZERO
	_last_cell = cell
	facing_angle = angle
	_light_angle = facing_angle
	_display_row = _row()
	_camera.reset_smoothing()


## Gira hacia una dirección (vector de casilla, admite diagonales).
func face(direction: Vector2i) -> void:
	facing_angle = Vector2(direction).angle()


## Detiene al personaje en seco (para textos y eventos).
func stop() -> void:
	velocity = Vector2.ZERO
	_run_blend = 0.0


## Intensidad de la carrera ahora mismo (0 = andando, 1 = corriendo del todo).
func run_amount() -> float:
	return _run_blend


## Aliento que le queda (0..1), para el indicador del HUD.
func breath_ratio() -> float:
	return breath.amount


## Forma física para correr: Cuerpo (0..1) y si sangra. Lo llama el mundo cada fotograma.
func set_run_condition(body_ratio: float, bleeding: bool) -> void:
	breath.set_condition(body_ratio, bleeding)


func has_flashlight_on() -> bool:
	return _flashlight.enabled


## Si sujeta la linterna (cambia la animación). No la enciende.
func set_holding_flashlight(holding: bool) -> void:
	if holding == _holding_flashlight:
		return
	_holding_flashlight = holding
	if not _scripted:
		_use_sheet(_move_sheet())


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
	set_holding_flashlight(_holding_flashlight or on)
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


## Arma en la mano libre (la izquierda), escalada a WEAPON_LENGTH. Si la textura es más ancha
## que alta, apunta hacia la derecha con la empuñadura a la izquierda; si es más alta (como los
## iconos de la bandeja), apunta hacia arriba con la empuñadura abajo. null = nada.
func set_held_weapon(texture: Texture2D) -> void:
	_weapon_texture = texture
	_weapon.texture = texture
	if texture != null:
		var size: Vector2 = texture.get_size()
		var k: float = WEAPON_LENGTH / maxf(size.x, size.y)
		_weapon.scale = Vector2(k, k)
		_weapon_upright = size.y > size.x
		if _weapon_upright:
			_weapon.offset = Vector2(0.0, -size.y * (0.5 - WEAPON_GRIP))
		else:
			_weapon.offset = Vector2(size.x * (0.5 - WEAPON_GRIP), 0.0)
	_update_weapon()


# --- acciones y levantarse ---------------------------------------------------------------------

## Acción de interacción (corrutina): se gira hacia `target` (y se acerca un poco si está lejos),
## reproduce la animación y vuelve al reposo. Acciones: &"reach_low", &"reach_mid",
## &"reach_high", &"pickup", &"key", &"valve", &"lever", &"pry". Una acción desconocida no hace
## nada. Quien llama ya ha bloqueado el control.
func play_action(action: StringName, target: Vector2) -> void:
	var sheet: StringName = SHEET_ACTION_FLASH if _holding_flashlight else SHEET_ACTION
	if _scripted or not sheets.has(sheet) or not (sheets[sheet]["anims"] as Dictionary).has(String(action)):
		return
	_scripted = true
	velocity = Vector2.ZERO
	_run_blend = 0.0
	var to_target: Vector2 = target - position
	if to_target.length() > 1.0:
		facing_angle = to_target.angle()
	# Si está algo lejos, da un paso hacia el objeto (andando de verdad, con colisión).
	var approach: float = minf(to_target.length() - ACTION_DISTANCE, ACTION_APPROACH_MAX)
	if approach > 2.0:
		var start: Vector2 = position
		var elapsed: float = 0.0
		_scripted_wish = to_target.normalized() * 0.55
		while position.distance_to(start) < approach and elapsed < 0.6:
			await get_tree().physics_frame
			elapsed += get_physics_process_delta_time()
			_turn(get_physics_process_delta_time())
			_update_frame()
		_scripted_wish = Vector2.ZERO
	# Termina de girarse (pasando por las intermedias).
	var waited: float = 0.0
	while _display_row != _row() and waited < ACTION_TURN_TIMEOUT:
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		waited += dt
		_turn(dt)
		_update_frame()
	velocity = Vector2.ZERO
	var spec: Dictionary = sheets[sheet]
	var anim: Array = spec["anims"][String(action)]
	var fps: float = float((spec.get("fps", {}) as Dictionary).get(String(action), 12.0))
	var row: int = posmod(roundi((rad_to_deg(facing_angle) - 90.0) / (360.0 / ACTION_DIRECTIONS)), ACTION_DIRECTIONS)
	_use_sheet(sheet)
	for i: int in int(anim[1]):
		_set_frame(row * int(spec["hframes"]) + int(anim[0]) + i)
		await get_tree().create_timer(1.0 / fps).timeout
	_idle_time = 0.0
	_fidget_time = -1.0
	_use_sheet(_move_sheet())
	_scripted = false
	_update_frame()


## Coloca al personaje (invisible) donde se levantará de la camilla, para que la cámara ya esté
## ahí durante el fundido de entrada.
func prepare_get_up(bed_position: Vector2) -> void:
	place_at(bed_position + Vector2(0.0, 1.0), 0.0)


## Levantarse de la camilla al empezar (corrutina): el personaje se dibuja sobre la camilla
## (que debe mostrarse vacía) en su sitio exacto, y acaba de pie a su lado mirando a la derecha.
func play_get_up(bed_position: Vector2) -> void:
	if not sheets.has(SHEET_GETUP):
		place_at(bed_position + bed_anchor + Vector2(19.0, 3.0), 0.0)
		visible = true
		return
	var spec: Dictionary = sheets[SHEET_GETUP]
	_scripted = true
	_run_blend = 0.0
	_sprite.skew = 0.0
	# El nodo, justo delante de la camilla en el orden de dibujo (y-sort); el dibujo, encima.
	prepare_get_up(bed_position)
	_use_sheet(SHEET_GETUP)
	_sprite.position = bed_anchor - Vector2(0.0, 1.0)
	_cloth_offset = Vector2.ZERO
	_cloth_velocity = Vector2.ZERO
	visible = true
	var sounds: Dictionary = spec.get("sounds", {})
	var fps: float = float(spec.get("fps", 8.0))
	for i: int in int(spec["hframes"]):
		_set_frame(i)
		if sounds.has(str(i)):
			var s: Array = sounds[str(i)]
			Sfx.at(get_parent(), String(s[0]), position, float(s[1]), 0.04)
		await get_tree().create_timer(1.0 / fps).timeout
	var stand: Array = spec["stand"]
	_sprite.position = Vector2.ZERO
	position = bed_position + bed_anchor + Vector2(stand[0], stand[1])
	_last_cell = cell
	facing_angle = 0.0
	_light_angle = 0.0
	_display_row = _row()
	_idle_time = 0.0
	_use_sheet(_move_sheet())
	_scripted = false
	_update_frame()


## Si está en medio de una acción o de levantarse.
func is_busy() -> bool:
	return _scripted


# --- internos ----------------------------------------------------------------------------------

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


## Fila (orientación) para un ángulo de pantalla.
static func row_for_angle(angle: float, directions: int = DIRECTIONS) -> int:
	return posmod(roundi((rad_to_deg(angle) - 90.0) / (360.0 / directions)), directions)


## Ángulo de pantalla de una fila.
static func angle_of_row(row: int, directions: int = DIRECTIONS) -> float:
	return deg_to_rad(90.0 + row * 360.0 / directions)


## Fila hacia la que tiene que girarse el cuerpo: hacia donde mira, corregida (como mucho una
## orientación) para que las piernas vayan hacia donde se mueve de verdad.
func _row() -> int:
	var angle: float = facing_angle
	if _is_walking() and not _scripted:
		var legs: float = facing_angle + _gait_offset(gait)
		angle += clampf(angle_difference(legs, _move_angle), -MAX_BODY_OFFSET, MAX_BODY_OFFSET)
	return row_for_angle(angle)


## Hacia dónde van las piernas de cada paso respecto a donde mira (pantalla, radianes).
static func _gait_offset(g: Gait) -> float:
	match g:
		Gait.BACK:
			return PI
		Gait.LEFT:
			return -PI / 2.0
		Gait.RIGHT:
			return PI / 2.0
	return 0.0


## Elige el paso según el ángulo entre hacia dónde anda y hacia dónde mira, con margen.
func _update_gait() -> void:
	var rel: float = angle_difference(facing_angle, _move_angle)
	var a: float = absf(rel)
	var margin: float = GAIT_HYSTERESIS
	match gait:
		Gait.FORWARD:
			if a <= FORWARD_ZONE + margin:
				return
		Gait.BACK:
			if a >= BACK_ZONE - margin:
				return
		Gait.LEFT:
			if rel < 0.0 and a > FORWARD_ZONE - margin and a < BACK_ZONE + margin:
				return
		Gait.RIGHT:
			if rel > 0.0 and a > FORWARD_ZONE - margin and a < BACK_ZONE + margin:
				return
	gait = choose_gait(rel)


## Paso para un ángulo `rel` (de hacia dónde mira a hacia dónde anda, en pantalla). Su izquierda
## queda a -90° de donde mira.
static func choose_gait(rel: float) -> Gait:
	var a: float = absf(rel)
	if a <= FORWARD_ZONE:
		return Gait.FORWARD
	if a >= BACK_ZONE:
		return Gait.BACK
	return Gait.LEFT if rel < 0.0 else Gait.RIGHT


func _stride_length() -> float:
	match gait:
		Gait.BACK:
			return BACK_STRIDE_PIXELS
		Gait.LEFT, Gait.RIGHT:
			return STRAFE_STRIDE_PIXELS
	# Corriendo usa la misma zancada que andando (la hoja es la de andar): sube la cadencia y
	# los pies no patinan más que al andar.
	return STRIDE_PIXELS


## Al correr se inclina un poco hacia donde va (sesgo del sprite con los pies quietos; solo se
## nota al moverse en horizontal).
func _update_lean(delta: float) -> void:
	var target: float = 0.0
	if _is_walking():
		target = RUN_LEAN * _run_blend * velocity.normalized().x
	_sprite.skew = lerpf(_sprite.skew, target, 1.0 - exp(-10.0 * delta))
	if target == 0.0 and absf(_sprite.skew) < 0.002:
		_sprite.skew = 0.0


func _on_exhausted() -> void:
	Sfx.at(get_parent(), RUN_BREATH_SOUND, position, RUN_BREATH_DB, 0.04)


func _gait_anim() -> Vector2i:
	match gait:
		Gait.BACK:
			return ANIM_BACK
		Gait.LEFT:
			return ANIM_STRAFE_LEFT
		Gait.RIGHT:
			return ANIM_STRAFE_RIGHT
	return ANIM_WALK


## Hacia dónde apunta (vector sin normalizar) o cero si no hay puntero ni stick.
func _aim_vector() -> Vector2:
	if forced_aim != Vector2.ZERO:
		return forced_aim
	match aim_mode:
		AimMode.MOUSE:
			if not is_inside_tree() or DisplayServer.get_name() == "headless":
				return Vector2.ZERO
			var to_mouse: Vector2 = get_global_mouse_position() - (global_position + Vector2(0.0, -AIM_HEIGHT))
			return to_mouse if to_mouse.length() > AIM_DEADZONE else Vector2.ZERO
		AimMode.STICK:
			var stick: Vector2 = Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
			return stick if stick.length() > STICK_DEADZONE else Vector2.ZERO
	return Vector2.ZERO


## Muelle amortiguado para el bajo de la ropa: se queda atrás con la velocidad, se lanza
## hacia delante al frenar, ondea con cada paso y oscila al girar.
func _update_cloth(delta: float) -> void:
	if delta <= 0.0:
		return
	var accel: Vector2 = (velocity - _prev_velocity) / delta
	_prev_velocity = velocity
	var target: Vector2 = -velocity * CLOTH_DRAG
	target.y *= 0.35
	var walk: float = clampf(velocity.length() / MAX_SPEED, 0.0, 1.0)
	target.x += sin(_phase * TAU * 2.0) * CLOTH_WAVE * walk
	var force: Vector2 = (target - _cloth_offset) * CLOTH_STIFFNESS - _cloth_velocity * CLOTH_DAMPING
	force -= accel * 0.014  # inercia: al arrancar se queda atrás, al frenar sigue de largo
	_cloth_velocity += force * delta
	_cloth_offset += _cloth_velocity * delta
	if _cloth_offset.length() > CLOTH_MAX:
		_cloth_offset = _cloth_offset.limit_length(CLOTH_MAX)
		_cloth_velocity *= 0.5
	var still: bool = _sheet == SHEET_GETUP
	for layer: StringName in _layers:
		var mat: ShaderMaterial = _layers[layer].material as ShaderMaterial
		if mat != null:
			var amount: float = 0.0 if still else float(_cloth_amount.get(layer, 0.0))
			mat.set_shader_parameter(&"sway", _cloth_offset * amount)


## Gira el sprite hacia la orientación deseada pasando por las intermedias. Parado, si el giro
## es grande, arrastra los pies (y gira más despacio).
func _turn(delta: float) -> void:
	var target: int = _row()
	if target == _display_row:
		_turn_timer = 0.0
		if _shuffle_time >= 0.0:
			_shuffle_time += delta
			# Termina el paso que estaba dando.
			if _shuffle_time * SHUFFLE_FPS >= ANIM_TURN.y or _is_walking():
				_shuffle_time = -1.0
		return
	var diff: int = posmod(target - _display_row, DIRECTIONS)
	var rows: int = mini(diff, DIRECTIONS - diff)
	if _shuffle_time < 0.0 and not _is_walking() and not _scripted and rows >= SHUFFLE_MIN_ROWS:
		_shuffle_time = 0.0
		_fidget_time = -1.0
	if _shuffle_time >= 0.0:
		_shuffle_time += delta
	_turn_timer += delta
	if _turn_timer < (SHUFFLE_TURN_STEP if _shuffle_time >= 0.0 else TURN_STEP):
		return
	_turn_timer = 0.0
	var step: int = 1 if diff <= DIRECTIONS / 2 else -1
	_display_row = posmod(_display_row + step, DIRECTIONS)
	# Al girar, la tela sale despedida hacia fuera.
	_cloth_velocity.x -= float(step) * CLOTH_TURN_KICK


func _move_sheet() -> StringName:
	return SHEET_MOVE_FLASH if _holding_flashlight else SHEET_MOVE


func _update_frame() -> void:
	var anim: Vector2i
	var index: int
	if _is_walking():
		anim = _gait_anim()
		index = int(fposmod(_phase, 1.0) * anim.y) % anim.y
	elif _shuffle_time >= 0.0:
		anim = ANIM_TURN
		index = int(_shuffle_time * SHUFFLE_FPS) % anim.y
	elif _fidget_time >= 0.0:
		anim = ANIM_FIDGET
		index = mini(int(_fidget_time * FIDGET_FPS), anim.y - 1)
	else:
		anim = ANIM_IDLE
		index = int(_idle_time * IDLE_FPS) % anim.y
	_set_frame(_display_row * COLUMNS + anim.x + index)


func _set_frame(frame: int) -> void:
	_sprite.frame = clampi(frame, 0, _sprite.hframes * _sprite.vframes - 1)
	for node: Sprite2D in _layers.values():
		if node.texture != null:
			node.frame = _sprite.frame
	if _glow.texture != null:
		_glow.frame = _sprite.frame
	_glow.visible = _flashlight.enabled and _glow.texture != null
	_update_weapon()


## Cambia de hoja (cuerpo, brillo y ropa). Solo se queda cargado lo que se usa.
func _use_sheet(sheet: StringName) -> void:
	if sheet == _sheet or not sheets.has(sheet):
		return
	_sheet = sheet
	var spec: Dictionary = sheets[sheet]
	var hframes: int = int(spec["hframes"])
	var vframes: int = int(spec["vframes"])
	var frame: Array = spec["frame"]
	var origin: Array = spec["origin"]
	var offset: Vector2 = Vector2(frame[0] / 2.0 - origin[0], frame[1] / 2.0 - origin[1])
	_sprite.texture = _load(String(body_paths.get(sheet, "")))
	_sprite.hframes = hframes
	_sprite.vframes = vframes
	_sprite.offset = offset
	var glow_path: String = glow_base + String(spec["suffix"]) + "_glow.png"
	_glow.texture = _load(glow_path) if bool(spec.get("glow", false)) else null
	_glow.hframes = hframes
	_glow.vframes = vframes
	_glow.offset = offset
	for layer: StringName in _layers:
		var node: Sprite2D = _layers[layer]
		node.hframes = hframes
		node.vframes = vframes
		node.offset = offset
		var mat: ShaderMaterial = node.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter(&"frames", Vector2(hframes, vframes))
			mat.set_shader_parameter(&"frame_px", Vector2(frame[0], frame[1]))
			mat.set_shader_parameter(&"feet_y", float(origin[1]))
		_apply_layer_sheet(layer)


## Pone en la capa la hoja actual de la prenda que lleva (o nada).
func _apply_layer_sheet(layer: StringName) -> void:
	var node: Sprite2D = _layers.get(layer)
	if node == null:
		return
	var path: String = wear_sheet_path(String(_wear.get(layer, "")), _sheet)
	node.texture = _load(path)
	node.visible = node.texture != null
	if node.visible:
		node.frame = clampi(_sprite.frame, 0, node.hframes * node.vframes - 1)


func _load(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Coloca el arma en la mano libre del fotograma actual (delante o detrás del cuerpo).
func _update_weapon() -> void:
	if _weapon == null:
		return
	var data: Variant = null
	if _weapon_texture != null and (_sheet == SHEET_MOVE or _sheet == SHEET_MOVE_FLASH):
		data = _frame_data(&"hand")
	_weapon.visible = data != null
	if data == null:
		return
	var hand: Array = data
	_weapon.position = Vector2(float(hand[0]), float(hand[1]))
	_weapon.rotation = deg_to_rad(float(hand[2])) + (PI / 2.0 if _weapon_upright else 0.0)
	_weapon.show_behind_parent = int(hand[3]) == 0


## Dato por fotograma de la hoja actual ("lens" o "hand") o null.
func _frame_data(key: StringName) -> Variant:
	var spec: Dictionary = sheets.get(_sheet, {})
	var table: Array = spec.get(String(key), [])
	var columns: int = int(spec.get("hframes", 1))
	var row: int = _sprite.frame / columns
	var column: int = _sprite.frame % columns
	if row < table.size():
		var row_data: Array = table[row]
		if column < row_data.size():
			return row_data[column]
	return null


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
	var data: Variant = _frame_data(&"lens")
	if data != null:
		var p: Array = data
		# Con la transformación del sprite: así sigue a la lente también inclinado al correr.
		return _sprite.transform * Vector2(float(p[0]), float(p[1]))
	var row: int = row_for_angle(facing_angle)
	return flashlight_offsets[row] if row < flashlight_offsets.size() else Vector2.ZERO


func _set_light_enabled(on: bool) -> void:
	_flashlight.enabled = on
	_bounce.enabled = on
	_glow.visible = on and _glow.texture != null
