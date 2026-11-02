class_name ItemDef
extends Resource
## Definición de un objeto que puede ir en el Sistema de Custodia.
## Se crea un `.tres` por objeto en `data/items/`; el código no necesita cambios.

enum Category { TOOL, KEY, MEDICAL, CONSUMABLE, POWER, PART, MISC, CLOTHING }
## Dónde se lleva puesta una prenda (NONE = no es ropa).
enum EquipSlot { NONE, HEAD, BODY, LEGS, FEET }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.MISC
## Icono para la bandeja; mide `size * ICON_CELL - 4` píxeles (la casilla menos el margen).
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

@export_group("Ropa")
## Ranura del personaje en la que se pone (NONE = no se puede poner).
@export var equip_slot: EquipSlot = EquipSlot.NONE
## Hoja de sprites de la prenda puesta (mismo formato que la del protagonista, con normales).
@export var wear_sheet: Texture2D
## Cuánto se balancea con la física (0 = rígida, 1 = bata larga).
@export_range(0.0, 1.5) var cloth_sway: float = 0.0
## Calzado: sonido de pisada (prefijo de los sonidos _1 a _4) y su volumen. Vacío = descalzo.
@export var step_sound: String = ""
@export var step_volume_db: float = -10.0

const ICON_CELL: int = 30


func footprint(rotated: bool) -> Vector2i:
	return Vector2i(size.y, size.x) if rotated else size


func is_stackable() -> bool:
	return max_stack > 1


func is_wearable() -> bool:
	return equip_slot != EquipSlot.NONE


## Nombre de la ranura para la interfaz.
static func slot_name(slot: EquipSlot) -> String:
	return ["—", "Cabeza", "Cuerpo", "Piernas", "Pies"][slot]


## Capa del sprite del jugador para cada ranura.
static func slot_layer(slot: EquipSlot) -> StringName:
	return [&"", &"head", &"body", &"legs", &"feet"][slot]
