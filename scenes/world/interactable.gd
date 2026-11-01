class_name Interactable
extends Node2D
## Algo que se puede examinar en el mapa (objeto o tile).
## Su posición es el centro de la celda base; `footprint` son las celdas que ocupa
## relativas a esa base. El texto se edita en el inspector.

const TILE_SIZE: int = 32

## Celdas ocupadas, relativas a la celda base (la de la posición del nodo).
@export var footprint: Array[Vector2i] = [Vector2i.ZERO]
## Si impide el paso. Los tiles sólidos (paredes, puertas) ya bloquean por sí solos.
@export var blocks: bool = true
## Evento especial que gestiona la escena (vacío = solo muestra texto).
@export var event_id: StringName = &""
## Texto la primera vez que se examina.
@export var lines: PackedStringArray = []
## Texto a partir de la segunda vez (vacío = repite `lines`).
@export var lines_repeat: PackedStringArray = []

var times_examined: int = 0

@onready var _sprite: Sprite2D = get_node_or_null(^"Sprite2D") as Sprite2D


## Celda base en coordenadas de mapa.
func base_cell() -> Vector2i:
	return Vector2i(floori(position.x / TILE_SIZE), floori(position.y / TILE_SIZE))


## Todas las celdas que ocupa, en coordenadas de mapa.
func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var base: Vector2i = base_cell()
	for offset: Vector2i in footprint:
		result.append(base + offset)
	return result


## Texto que toca mostrar ahora; cuenta la visita.
func next_lines() -> PackedStringArray:
	times_examined += 1
	if times_examined > 1 and not lines_repeat.is_empty():
		return lines_repeat
	return lines


func set_sprite_frame(frame: int) -> void:
	if _sprite != null:
		_sprite.frame = frame
