class_name WaitAction
extends EventAction
## Espera antes de la siguiente acción.

@export var seconds: float = 1.0


func run(director: EventDirector) -> void:
	await director.get_tree().create_timer(seconds).timeout
