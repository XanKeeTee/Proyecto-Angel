class_name BounceClamp
extends Node
## Impide que la luz rebotada de la linterna quede al otro lado de un muro o de un mueble:
## si entre la linterna y el punto de rebote hay algo sólido, la acerca hasta justo delante.
## Va como hijo del jugador para ejecutarse después de que él coloque el rebote.

## Separación con la superficie en la que rebota (píxeles).
const MARGIN: float = 6.0
## Capas de física que paran la luz (muros, puertas cerradas y muebles).
const SOLID_MASK: int = 1

var source: PointLight2D
var bounce: PointLight2D


func _process(_delta: float) -> void:
	if source == null or bounce == null or not bounce.enabled:
		return
	var body: Node2D = get_parent() as Node2D
	if body == null or not body.is_inside_tree():
		return
	# El rayo va por el suelo, desde los pies, porque la mano está «en alto» (más arriba en
	# pantalla) y podría quedar ya dentro del dibujo de la pared.
	var reach: Vector2 = bounce.global_position - source.global_position
	if reach.length_squared() < 1.0:
		return
	var from: Vector2 = body.global_position
	var to: Vector2 = from + reach
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, SOLID_MASK)
	var space: PhysicsDirectSpaceState2D = body.get_world_2d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return
	var point: Vector2 = hit["position"]
	var back: Vector2 = (from - point).normalized() * MARGIN
	bounce.global_position = point + back
