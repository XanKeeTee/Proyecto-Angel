class_name EventAction
extends Resource
## Una acción de un evento narrativo. Las subclases están en `actions/`.
## `run` puede esperar (await) para encadenar acciones con tiempo.


func run(_director: EventDirector) -> void:
	pass
