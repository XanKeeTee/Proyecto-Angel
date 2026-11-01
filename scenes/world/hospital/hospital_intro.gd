extends Node2D
## Inicio del juego: el protagonista despierta solo en una habitación de hospital a oscuras,
## encuentra una linterna y sale a un pasillo vacío.
## Diseño: docs/design/escenas/inicio-hospital.md. Textos editables en el inspector.
##
## Depuración (argumentos tras `--`):
##   --skip-intro         empieza con el control, sin la secuencia de despertar
##   --flashlight         empieza con la linterna encendida
##   --at=X,Y             casilla inicial (implica --skip-intro)
##   --face=up|down|left|right|up_left|up_right|down_left|down_right
##   --ending             lanza el final nada más empezar
##   --screenshot=RUTA    guarda una captura y cierra
##   --screenshot-delay=S segundos antes de la captura (1,5 por defecto)
##   --no-vhs             sin filtro VHS
##   --auto-advance=S     los textos avanzan solos cada S segundos (pruebas sin manos)

const TILE_SIZE: int = 32
const SOURCE_ID: int = 0
## Columna del atlas con la puerta abierta (tramos alto, medio y bajo en las filas 2, 3 y 4).
const DOOR_OPEN_COLUMN: int = 5
const START_CELL: Vector2i = Vector2i(3, 13)
const ENDING_CELL: Vector2i = Vector2i(31, 4)
## Primera fila del pasillo y última (las paredes miden 3 casillas).
const CORRIDOR_ROWS: Vector2i = Vector2i(4, 6)
const STRETCHER_EMPTY: int = 0
const STRETCHER_LYING: int = 1
const STRETCHER_SITTING: int = 2
const STRETCHER_MESSY: int = 3
## Virado frío y verdoso del hospital (guía estética: laboratorios en frío).
const ZONE_TINT: Color = Color(0.9, 1.0, 0.96)
## Ciclo de la luz de emergencia: sube y baja como una bombilla que se calienta y se enfría.
const EMERGENCY_PERIOD: float = 1.5
const EMERGENCY_LIT_FRACTION: float = 0.62
## Latido del monitor (segundos entre pulsos).
const HEARTBEAT_PERIOD: float = 0.95
## Puertas que llevan a otra casilla: celda pisada -> [destino, dirección al llegar].
const WARPS: Dictionary[Vector2i, Array] = {
	Vector2i(5, 10): [Vector2i(5, 6), Vector2i.UP],
	Vector2i(5, 7): [Vector2i(5, 11), Vector2i.DOWN],
}

## Texto al despertar, antes de levantarse.
@export var intro_lines: PackedStringArray = []
## Texto al ver las huellas por primera vez.
@export var footprints_lines: PackedStringArray = []
## Columna a partir de la cual se "ven" las huellas en el pasillo.
@export var footprints_trigger_x: int = 10
@export var item_found_text: String = "Has cogido la LINTERNA."

var _interactables: Dictionary[Vector2i, Interactable] = {}
var _has_flashlight: bool = false
var _footprints_seen: bool = false
var _ending: bool = false
var _emergency_on: bool = true
var _emergency_base_energy: float = 1.0
var _monitor_base_energy: float = 1.0
var _message: MessageBox
var _vhs: VhsOverlay
var _debug: Dictionary[String, String] = {}

@onready var _map: TileMapLayer = %Map
@onready var _player: Player = %Player
@onready var _stretcher: Interactable = %Stretcher
@onready var _cabinet: Interactable = %Cabinet
@onready var _monitor_light: PointLight2D = %MonitorLight
@onready var _emergency_light: PointLight2D = %EmergencyLight
@onready var _emergency_sprite: Sprite2D = %EmergencySprite
@onready var _fade: ColorRect = %Fade


func _ready() -> void:
	_parse_debug_args()
	_message = MessageBox.new()
	_message.auto_advance = _debug.get("auto-advance", "0").to_float()
	add_child(_message)
	_vhs = VhsOverlay.new()
	add_child(_vhs)
	_vhs.set_tint(ZONE_TINT)
	_vhs.set_param("grain_amount", 0.085)
	_vhs.set_param("vignette_strength", 0.95)
	_vhs.set_enabled(not _debug.has("no-vhs"))

	for node: Node in find_children("*", "Interactable", true, false):
		var interactable: Interactable = node as Interactable
		for c: Vector2i in interactable.cells():
			_interactables[c] = interactable

	_monitor_base_energy = _monitor_light.energy
	_emergency_base_energy = _emergency_light.energy
	# Sin límites de cámara: fuera del mapa es negro y el personaje queda siempre centrado.
	_player.interact_requested.connect(_on_interact_requested)
	_player.cell_entered.connect(_on_cell_entered)

	if _debug.has("screenshot"):
		_take_screenshot_later(_debug["screenshot"], _debug.get("screenshot-delay", "1.5").to_float())
	if _debug.has("skip-intro") or _debug.has("at") or _debug.has("ending"):
		_start_without_intro()
	else:
		_run_intro()


func _process(_delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	# Monitor: destello corto en cada latido y caída lenta.
	var beat: float = fposmod(now, HEARTBEAT_PERIOD) / HEARTBEAT_PERIOD
	_monitor_light.energy = _monitor_base_energy * (0.75 + 0.45 * exp(-beat * 9.0))
	if randf() < 0.006:
		_monitor_light.energy *= 0.35
	if not _emergency_on:
		return
	var phase: float = fposmod(now, EMERGENCY_PERIOD) / EMERGENCY_PERIOD
	var level: float = 0.0
	if phase < EMERGENCY_LIT_FRACTION:
		level = pow(sin(phase / EMERGENCY_LIT_FRACTION * PI), 0.7)
	_set_emergency_level(level)


# --- secuencia de inicio -------------------------------------------------------

func _run_intro() -> void:
	# Oculto pero colocado, para que la cámara encuadre la camilla.
	_player.place(START_CELL, Vector2i.DOWN)
	_player.visible = false
	_stretcher.set_sprite_frame(STRETCHER_LYING)
	_fade.color.a = 1.0
	await _wait(1.2)
	await _message.stamp("Despierta.", 1.4)
	await _wait(0.5)
	# Párpados que se abren y se vuelven a cerrar.
	await _fade_to(0.55, 0.9)
	await _fade_to(1.0, 0.25)
	await _wait(0.5)
	await _fade_to(0.3, 1.1)
	await _fade_to(0.8, 0.3)
	await _fade_to(0.0, 1.6)
	await _message.show_lines(intro_lines)
	_stretcher.set_sprite_frame(STRETCHER_SITTING)
	await _wait(0.9)
	_vhs.glitch(0.3, 0.35)
	_stretcher.set_sprite_frame(STRETCHER_MESSY)
	_player.place(START_CELL, Vector2i.DOWN)
	_player.visible = true
	await _wait(0.4)
	_message.show_hint("Flechas: moverse    Intro: examinar    F2: filtro VHS", 7.0)
	_unlock()


func _start_without_intro() -> void:
	_fade.color.a = 0.0
	_stretcher.set_sprite_frame(STRETCHER_MESSY)
	var start: Vector2i = ENDING_CELL if _debug.has("ending") else START_CELL
	if _debug.has("at"):
		var parts: PackedStringArray = _debug["at"].split(",")
		start = Vector2i(parts[0].to_int(), parts[1].to_int())
	var facing_by_name: Dictionary[String, Vector2i] = {
		"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT,
		"up_left": Vector2i(-1, -1), "up_right": Vector2i(1, -1),
		"down_left": Vector2i(-1, 1), "down_right": Vector2i(1, 1),
	}
	var default_face: String = "up" if _debug.has("ending") else "down"
	_player.place(start, facing_by_name.get(_debug.get("face", default_face), Vector2i.DOWN))
	if _debug.has("flashlight") or _debug.has("ending") or start.y <= CORRIDOR_ROWS.y:
		_give_flashlight(false)
		_open_room_door()
	if _debug.has("ending"):
		_run_ending(_interactables[ENDING_CELL + Vector2i.UP])
		return
	# Algunos mandos mandan valores falsos en los primeros fotogramas.
	await _wait(0.5)
	_unlock()


# --- interacción ---------------------------------------------------------------

func _on_interact_requested(cells: Array[Vector2i]) -> void:
	var interactable: Interactable = null
	for cell: Vector2i in cells:
		interactable = _interactables.get(cell)
		if interactable != null:
			break
	if interactable == null:
		return
	_lock()
	match interactable.event_id:
		&"flashlight":
			await _examine_cabinet(interactable)
		&"room_door":
			await _examine_room_door(interactable)
		&"ending":
			await _run_ending(interactable)
			return
		_:
			await _message.show_lines(interactable.next_lines())
	_unlock()


func _on_cell_entered(cell: Vector2i) -> void:
	if WARPS.has(cell):
		await _warp(WARPS[cell][0], WARPS[cell][1])
		return
	if _footprints_seen or cell.y < CORRIDOR_ROWS.x or cell.y > CORRIDOR_ROWS.y or cell.x < footprints_trigger_x:
		return
	_footprints_seen = true
	_lock()
	_player.face(Vector2i.RIGHT)
	await _message.show_lines(footprints_lines)
	_unlock()


func _examine_cabinet(cabinet: Interactable) -> void:
	if _has_flashlight:
		await _message.show_lines(cabinet.lines_repeat)
		return
	cabinet.set_sprite_frame(1)
	await _message.show_lines(cabinet.lines)
	await _message.show_lines(PackedStringArray([item_found_text]))
	_give_flashlight(true)


func _examine_room_door(door: Interactable) -> void:
	if not _has_flashlight:
		await _message.show_lines(door.next_lines())
		return
	_open_room_door()


func _give_flashlight(animated: bool) -> void:
	_has_flashlight = true
	_cabinet.set_sprite_frame(1)
	if animated:
		_vhs.glitch(0.2, 0.25)
	_player.set_flashlight(true)


func _open_room_door() -> void:
	for cell: Vector2i in _interactables.keys():
		var door: Interactable = _interactables[cell]
		if door.event_id == &"room_door":
			# La puerta ocupa la casilla de abajo y las dos de encima.
			for row: int in 3:
				_map.set_cell(cell + Vector2i(0, row - 2), SOURCE_ID, Vector2i(DOOR_OPEN_COLUMN, 2 + row))
			_interactables.erase(cell)


func _warp(target: Vector2i, facing: Vector2i) -> void:
	_lock()
	await _fade_to(1.0, 0.25)
	_player.place(target, facing)
	await _wait(0.15)
	await _fade_to(0.0, 0.35)
	_unlock()


func _set_emergency_level(level: float) -> void:
	_emergency_light.enabled = level > 0.01
	_emergency_light.energy = _emergency_base_energy * level
	_emergency_sprite.frame = 0 if level > 0.3 else 1
	var glow: Sprite2D = _emergency_sprite.get_node_or_null(^"Glow") as Sprite2D
	if glow != null:
		glow.frame = 0
		glow.modulate.a = level
		glow.visible = level > 0.01



# --- final ------------------------------------------------------------------------

func _run_ending(doors: Interactable) -> void:
	_lock()
	await _message.show_lines(doors.lines)
	_player.face(Vector2i.UP)
	await _wait(0.6)
	_ending = true
	_vhs.glitch(2.4, 0.8)
	await _player.flicker_flashlight(1.4)
	_emergency_on = false
	_set_emergency_level(0.0)
	await _wait(0.8)
	await _fade_to(1.0, 0.6)
	await _wait(1.2)
	_message.set_stamp("Continuará.")
	await _wait(1.0)
	_message.show_hint("Fin del prototipo. Intro: empezar de nuevo.", 0.0)
	await _message.wait_accept()
	# En modo captura no se recarga: el temporizador de la captura moriría con la escena.
	if not _debug.has("screenshot"):
		get_tree().reload_current_scene()


# --- utilidades -------------------------------------------------------------------

func _lock() -> void:
	_player.input_enabled = false
	_player.stop()


## Devuelve el control un fotograma después, para que el Intro que cerró
## un texto no vuelva a examinar.
func _unlock() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	# En modo captura no se mueve nadie: la imagen tiene que ser la pedida.
	if not _message.is_open() and not _ending and not _debug.has("screenshot"):
		_player.input_enabled = true


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _fade_to(alpha: float, seconds: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", alpha, seconds)
	await tween.finished


func _parse_debug_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var pair: PackedStringArray = arg.substr(2).split("=", true, 1)
		_debug[pair[0]] = pair[1] if pair.size() > 1 else ""


func _take_screenshot_later(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(path)
	print("Captura guardada en ", path)
	get_tree().quit()
