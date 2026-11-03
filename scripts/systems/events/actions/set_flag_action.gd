class_name SetFlagAction
extends EventAction
## Activa (o desactiva) una bandera.

@export var flag: StringName = &""
@export var value: bool = true


func run(_director: EventDirector) -> void:
	GameState.set_flag(flag, value)
