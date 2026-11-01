class_name ItemDef
extends Resource
## Definición de un objeto que puede ir en el Sistema de Custodia.
## Se crea un `.tres` por objeto en `data/items/`; el código no necesita cambios.

enum Category { TOOL, KEY, MEDICAL, CONSUMABLE, POWER, PART, MISC }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.MISC
## Icono para la bandeja; debe medir `size * ICON_CELL` píxeles.
@export var icon: Texture2D
## Hoja con vistas giradas para el inspector (una fila de `inspect_views` imágenes).
@export var inspect_sheet: Texture2D
@export var inspect_views: int = 1
## Casillas que ocupa en la bandeja (ancho x alto, sin girar).
@export var size: Vector2i = Vector2i.ONE
## Cantidad máxima por montón (1 = no se apila).
@export var max_stack: int = 1
## Usos antes de romperse (0 = no se gasta).
@export var max_durability: int = 0
## Carga máxima (linterna); 0 = no tiene carga.
@export var max_charge: float = 0.0
## Si viene contaminado de serie.
@export var contaminated: bool = false
## Se puede usar desde el inventario o un bolsillo.
@export var usable: bool = false
## Desaparece una unidad al usarlo.
@export var consumed_on_use: bool = true
## Qué pasa al usarlo (se ejecutan en orden).
@export var use_effects: Array[ItemEffect] = []
## Texto del botón de uso ("Aplicar", "Tomar", "Encender"…).
@export var use_verb: String = "Usar"
## Los objetos clave no se pueden descartar.
@export var key_item: bool = false

const ICON_CELL: int = 24


func footprint(rotated: bool) -> Vector2i:
	return Vector2i(size.y, size.x) if rotated else size


func is_stackable() -> bool:
	return max_stack > 1
