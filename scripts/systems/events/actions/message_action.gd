class_name MessageAction
extends EventAction
## Muestra texto en la caja (bloquea al jugador mientras lo lee).

@export var lines: PackedStringArray = []


func run(director: EventDirector) -> void:
	await director.world.show_lines(lines)
