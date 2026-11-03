class_name SetObjectAction
extends EventAction
## Cambia el estado de un objeto del mundo: una puerta que se cierra sola, un cadáver que ya no está…

@export var object_id: StringName = &""
@export var open: bool = false
@export var locked: bool = false
## Lo retira del mundo (y queda así guardado).
@export var remove: bool = false


func run(director: EventDirector) -> void:
	var target: Interactable = director.world.find_object(object_id)
	if target == null:
		push_warning("Evento: no existe el objeto " + String(object_id))
		return
	if remove:
		target.remove_from_world()
	else:
		target.force_state(open, locked)
