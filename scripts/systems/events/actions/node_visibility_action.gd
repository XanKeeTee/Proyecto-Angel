class_name NodeVisibilityAction
extends EventAction
## Muestra u oculta un elemento del escenario (y lo guarda).

@export var node_name: String = ""
@export var visible: bool = true


func run(director: EventDirector) -> void:
	director.world.set_scenery_visible(node_name, visible)
