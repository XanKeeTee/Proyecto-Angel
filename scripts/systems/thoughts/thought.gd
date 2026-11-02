class_name Thought
extends Resource
## Un pensamiento del protagonista: lo que cree que tiene que hacer ahora. Vale si se cumplen
## todas sus condiciones (banderas y objetos en la custodia). Ver ThoughtSet.

@export_multiline var text: String = ""
## Todas estas banderas activas.
@export var requires_flags: Array[StringName] = []
## Ninguna de estas banderas activa.
@export var forbids_flags: Array[StringName] = []
## Lleva todos estos objetos (id).
@export var requires_items: Array[StringName] = []
## No lleva ninguno de estos objetos (id).
@export var forbids_items: Array[StringName] = []


## `has_flag(flag: StringName) -> bool` y `has_item(id: StringName) -> bool`.
func matches(has_flag: Callable, has_item: Callable) -> bool:
	for flag: StringName in requires_flags:
		if not has_flag.call(flag):
			return false
	for flag: StringName in forbids_flags:
		if has_flag.call(flag):
			return false
	for id: StringName in requires_items:
		if not has_item.call(id):
			return false
	for id: StringName in forbids_items:
		if has_item.call(id):
			return false
	return true
