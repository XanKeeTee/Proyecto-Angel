class_name Glint
extends Node2D
## Destello sutil sobre un objeto importante: una chispa pequeña de cuatro puntas que aparece
## un instante cada pocos segundos (como un reflejo de la linterna en metal o cristal).
## No recibe luz. Solo se ve si el protagonista está cerca (`max_distance`).

const NODE_NAME: StringName = &"Glint"
const PERIOD: float = 3.6
const FLASH: float = 0.55
const COLOR: Color = Color(0.95, 0.93, 0.82)

## Nodo cuyo `position` se usa para medir la distancia (el jugador).
var watcher: Node2D
var max_distance: float = 190.0

var _phase: float = 0.0
var _time: float = 0.0


static func attach(target: Node2D, at: Vector2) -> Glint:
	var existing: Glint = target.get_node_or_null(NodePath(String(NODE_NAME))) as Glint
	if existing != null:
		return existing
	var glint: Glint = Glint.new()
	glint.name = NODE_NAME
	glint.position = at
	glint.z_index = 1
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glint.material = mat
	glint._phase = fposmod(target.position.x * 0.013 + target.position.y * 0.007, 1.0) * PERIOD
	target.add_child(glint)
	return glint


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if watcher != null and is_instance_valid(watcher) and watcher.global_position.distance_to(global_position) > max_distance:
		return
	var t: float = fposmod(_time + _phase, PERIOD)
	if t > FLASH:
		return
	var k: float = sin(t / FLASH * PI)
	var size: float = 1.0 + 3.0 * k
	var c: Color = Color(COLOR, 0.55 * k)
	draw_line(Vector2(-size, 0), Vector2(size, 0), c, 1.0)
	draw_line(Vector2(0, -size), Vector2(0, size), c, 1.0)
	draw_rect(Rect2(-0.5, -0.5, 1, 1), Color(COLOR, 0.8 * k))
