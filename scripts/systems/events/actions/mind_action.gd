class_name MindAction
extends EventAction
## Sube o baja la Mente del protagonista.

@export var amount: int = -5


func run(_director: EventDirector) -> void:
	GameState.character.vitals.change_mind(amount)
