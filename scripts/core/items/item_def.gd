class_name ItemDef
extends Resource
## Definición de un objeto que puede ir en el Sistema de Custodia.
## Se crea un `.tres` por objeto en `data/items/`; el código no necesita cambios.

enum Category { TOOL, KEY, MEDICAL, CONSUMABLE, POWER, PART, MISC, CLOTHING, WEAPON }
## Dónde se lleva puesta una prenda (NONE = no es ropa).
enum EquipSlot { NONE, HEAD, BODY, LEGS, FEET }
## De qué está hecho (para los sonidos al cogerlo, soltarlo, girarlo…). AUTO = según la categoría.
enum SoundMaterial {
	AUTO, METAL_HEAVY, METAL_SMALL, KEYS, CLOTH, PAPER, PLASTIC, GLASS, PILLS, BATTERY, TOOL, RUBBER, CERAMIC,
}

## Casilla de la bandeja en píxeles. Los iconos miden `size * ICON_CELL - 4`.
const ICON_CELL: int = 40
## Nombre de cada material en los nombres de los sonidos (`inv_<material>_<acción>`).
const SOUND_MATERIAL_NAMES: Array[String] = [
	"", "metal_heavy", "metal_small", "keys", "cloth", "paper", "plastic", "glass", "pills", "battery", "tool",
	"rubber", "ceramic",
]
## Tiras de tela que da rasgar una prenda, por ranura, si `tear_amount` es -1 (automático).
const TEAR_BY_SLOT: Array[int] = [0, 1, 3, 2, 0]

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

@export_group("Arma")
## Si no es null, se puede empuñar (ranura MANO de la pestaña PERSONAJE).
@export var weapon: WeaponDef

@export_group("Rasgar")
## Tiras de tela que da al rasgarlo. -1 = automático (la ropa según su ranura); 0 = no se rasga.
@export var tear_amount: int = -1
## Lo que sale al rasgarlo (vacío = «tela»).
@export var tear_result: StringName = &""

@export_group("Sonido")
@export var sound_material: SoundMaterial = SoundMaterial.AUTO
## Sonido al usarlo (vacío = ninguno). Ver ItemSounds para las alternativas provisionales.
@export var use_sound: String = ""


func footprint(rotated: bool) -> Vector2i:
	return Vector2i(size.y, size.x) if rotated else size


func is_stackable() -> bool:
	return max_stack > 1


func is_wearable() -> bool:
	return equip_slot != EquipSlot.NONE


func is_weapon() -> bool:
	return weapon != null


## Se puede descartar (dejar en el suelo). Los objetos clave, nunca.
func can_discard() -> bool:
	return not key_item


## Tiras de tela que da al rasgarlo (0 = no se puede).
func tear_yield() -> int:
	if tear_amount >= 0:
		return tear_amount
	if is_wearable() and step_sound == "":
		return TEAR_BY_SLOT[equip_slot]
	return 0


func tear_result_id() -> StringName:
	return tear_result if tear_result != &"" else &"tela"


## Material para los sonidos (resuelve AUTO según la categoría).
func resolved_sound_material() -> SoundMaterial:
	if sound_material != SoundMaterial.AUTO:
		return sound_material
	match category:
		Category.CLOTHING:
			return SoundMaterial.RUBBER if step_sound.begins_with("step_boot") else SoundMaterial.CLOTH
		Category.KEY:
			return SoundMaterial.KEYS
		Category.MEDICAL:
			return SoundMaterial.PLASTIC
		Category.POWER:
			return SoundMaterial.BATTERY
		Category.TOOL:
			return SoundMaterial.TOOL
		Category.PART, Category.WEAPON:
			return SoundMaterial.METAL_HEAVY
	return SoundMaterial.PLASTIC


## Nombre de la ranura para la interfaz.
static func slot_name(slot: EquipSlot) -> String:
	return ["—", "Cabeza", "Cuerpo", "Piernas", "Pies"][slot]


## Capa del sprite del jugador para cada ranura.
static func slot_layer(slot: EquipSlot) -> StringName:
	return [&"", &"head", &"body", &"legs", &"feet"][slot]
