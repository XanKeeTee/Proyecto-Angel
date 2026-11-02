class_name LootSlot
extends Resource
## Un mueble con botín aleatorio: su tabla (opcional) y, si hace falta, un texto de registrar
## que no nombre objetos concretos (el contenido cambia de una partida a otra).

@export var object_id: StringName = &""
## Tabla propia (null = solo lo que le toque por los repartos).
@export var table: LootTable
## Si es true, `search_text` sustituye al texto de registrar del mueble.
@export var override_search: bool = false
@export_multiline var search_text: String = ""
