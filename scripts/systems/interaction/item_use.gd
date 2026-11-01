class_name ItemUse
extends Resource
## Usar un objeto de la custodia sobre algo del mundo: una palanca en una puerta atascada,
## el destornillador en un panel averiado, el fusible en su hueco…

@export var item: ItemDef
## Texto de la acción ("Forzar con la palanca"). Vacío = "Usar <objeto>".
@export var label: String = ""
## Banderas que deben estar activas para que aparezca la acción.
@export var requires_flags: Array[StringName] = []
## Se gasta una unidad del objeto (p. ej. el fusible queda instalado).
@export var consumes_item: bool = false
## Gasta un uso de durabilidad (herramientas).
@export var uses_durability: bool = false
## Qué cambia en el objeto del mundo.
@export var opens: bool = false
@export var unlocks: bool = false
@export var sets_flag: StringName = &""
@export_multiline var text: String = ""
## Fotograma del sprite tras usarlo (-1 = sin cambio).
@export var frame_after: int = -1


func action_label() -> String:
	return label if label != "" else "Usar " + item.display_name.to_lower()
