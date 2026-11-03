class_name AimReticle
extends CanvasLayer
## Punto de mira del ratón mientras se explora. Oculta el cursor del sistema durante el juego
## y lo devuelve en menús, textos y pausas. Si se apunta con el mando, no se dibuja.

const RADIUS: float = 4.0
const COLOR: Color = Color(0.86, 0.82, 0.72, 0.75)
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.55)

var player: Player

var _dot: Control


func _init() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_dot = Control.new()
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.draw.connect(_draw_reticle)
	add_child(_dot)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	var active: bool = player != null and player.input_enabled and not get_tree().paused \
			and player.aim_mode == Player.AimMode.MOUSE
	_dot.visible = active
	var wanted: Input.MouseMode = Input.MOUSE_MODE_HIDDEN if active else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != wanted and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = wanted
	if active:
		_dot.position = _dot.get_viewport().get_mouse_position().floor()
		_dot.queue_redraw()


func _draw_reticle() -> void:
	# Cuatro trazos con hueco en el centro y un punto: legible sobre fondo claro y oscuro.
	for pass_index: int in 2:
		var color: Color = SHADOW if pass_index == 0 else COLOR
		var o: Vector2 = Vector2(1, 1) if pass_index == 0 else Vector2.ZERO
		for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var a: Vector2 = dir * (RADIUS - 1.0) + o
			var b: Vector2 = dir * (RADIUS + 2.0) + o
			_dot.draw_line(a, b, color, 1.0)
		_dot.draw_rect(Rect2(o - Vector2(0.5, 0.5), Vector2(1, 1)), color)
