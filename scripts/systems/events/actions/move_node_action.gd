class_name MoveNodeAction
extends EventAction
## Desplaza un objeto del escenario (una cama movida al volver). La posición se guarda.

@export var node_name: String = ""
@export var offset: Vector2 = Vector2.ZERO
## Fotograma nuevo del sprite (-1 = igual).
@export var frame: int = -1


func run(director: EventDirector) -> void:
	director.world.move_scenery(node_name, offset, frame)
