class_name ItemDef
extends Resource
## Definición de un objeto que puede ir en el Sistema de Custodia.
## Se crea un `.tres` por objeto en `data/items/`; el código no necesita cambios.

## Tipo de objeto (lo usan los sonidos y algunas reglas). Para la interfaz cuenta `section`.
enum Category { TOOL, KEY, MEDICAL, CONSUMABLE, POWER, PART, MISC, CLOTHING, WEAPON }
## Categoría del inventario en la que se lista (pestañas de la custodia). AUTO = según `category`.
enum Section { AUTO, WEAPONS, ARMOR, UTILITY, MEDICINE, MAIN, OTHER }
## Dónde se lleva puesta una prenda (NONE = no es ropa).
enum EquipSlot { NONE, HEAD, BODY, LEGS, FEET }
## De qué está hecho (para los sonidos al cogerlo, soltarlo, girarlo…). AUTO = según la categoría.
enum SoundMaterial {
	AUTO, METAL_HEAVY, METAL_SMALL, KEYS, CLOTH, PAPER, PLASTIC, GLASS, PILLS, BATTERY, TOOL, RUBBER, CERAMIC,
}

## Medida de referencia de los iconos: miden `size * ICON_CELL - 4` píxeles. (Ya no hay casillas:
## el inventario es una lista; `size` solo da la forma del icono.)
const ICON_CELL: int = 36
## Orden de las categorías en la custodia (sin AUTO).
const SECTIONS: Array[Section] = [
	Section.WEAPONS, Section.ARMOR, Section.UTILITY, Section.MEDICINE, Section.MAIN, Section.OTHER,
]
## Nombre de cada categoría para la interfaz (por índice de Section).
const SECTION_NAMES: Array[String] = ["—", "Armas", "Armaduras", "Útiles", "Medicina", "Objetos principales", "Otros"]
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
## Categoría del inventario: Armas, Armaduras, Útiles, Medicina, Objetos principales (los del camino
## principal: no se descartan) u Otros. AUTO la deduce de `category` (ver resolved_section).
@export var section: Section = Section.AUTO
## Icono del objeto; mide `size * ICON_CELL - 4` píxeles.
@export var icon: Texture2D
## Hoja con vistas giradas para el inspector (una fila de `inspect_views` imágenes).
@export var inspect_sheet: Texture2D
@export var inspect_views: int = 1
## Forma del icono (ancho x alto en unidades de ICON_CELL). No ocupa sitio: no hay casillas.
@export var size: Vector2i = Vector2i.ONE
## Se apila si es mayor que 1: todas las unidades iguales van en un mismo montón, sin límite (el
## valor solo indica cuántas se dan de golpe con --give).
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
## Los objetos clave no se pueden descartar (tampoco los de la categoría Objetos principales).
@export var key_item: bool = false

@export_group("Ropa")
## Ranura del personaje en la que se pone (NONE = no se puede poner).
@export var equip_slot: EquipSlot = EquipSlot.NONE
## Hoja de la prenda puesta (CanvasTexture con normales, mismo formato que la del protagonista).
## Es una ruta y no una textura para que la hoja solo se cargue en memoria mientras se lleva
## puesta. Las demás hojas de la prenda (con linterna, acciones, levantarse) están al lado,
## con el sufijo de cada hoja (ver Player.wear_sheet_path).
@export_file("*.tres") var wear_path: String = ""
## Cuánto se balancea con la física (0 = rígida, 1 = bata larga).
@export_range(0.0, 1.5) var cloth_sway: float = 0.0
## Alturas (píxeles sobre los pies) donde la tela empieza a moverse y donde está el bajo, que
## se mueve del todo.
@export var cloth_waist: float = 32.0
@export var cloth_hem: float = 14.0
## Calzado: sonido de pisada (prefijo de los sonidos _1 a _4) y su volumen. Vacío = descalzo.
@export var step_sound: String = ""
@export var step_volume_db: float = -10.0
## Defensa que da puesta [PROPUESTA]. Se suma en la pantalla de equipo (CharacterState.defense).
@export_range(0, 20) var defense: int = 0

@export_group("Arma")
## Si no es null, se puede empuñar (manos derecha e izquierda de la pestaña EQUIPO).
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

## Hoja de la prenda puesta (de andar, sin linterna). Se carga al pedirla; mientras alguien la
## use, Godot devuelve la misma textura. null si no es ropa.
var wear_sheet: Texture2D:
	get:
		if wear_path == "" or not ResourceLoader.exists(wear_path):
			return null
		return load(wear_path)


func is_stackable() -> bool:
	return max_stack > 1


func is_wearable() -> bool:
	return equip_slot != EquipSlot.NONE


func is_weapon() -> bool:
	return weapon != null


## Se puede descartar (dejar en el suelo). Los objetos clave y los principales, nunca.
func can_discard() -> bool:
	return not key_item and resolved_section() != Section.MAIN


## Categoría del inventario (resuelve AUTO): armas, ropa, útiles, medicina, principales u otros.
func resolved_section() -> Section:
	if section != Section.AUTO:
		return section
	if is_wearable():
		return Section.ARMOR
	match category:
		Category.WEAPON:
			return Section.WEAPONS
		Category.CLOTHING:
			return Section.ARMOR
		Category.TOOL, Category.POWER:
			return Section.UTILITY
		Category.MEDICAL, Category.CONSUMABLE:
			return Section.MEDICINE
		Category.KEY, Category.PART:
			return Section.MAIN
	if is_weapon():
		return Section.WEAPONS
	return Section.OTHER


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


## Nombre de una categoría del inventario.
static func section_name(value: Section) -> String:
	return SECTION_NAMES[value]


## Nombre de la ranura para la interfaz.
static func slot_name(slot: EquipSlot) -> String:
	return ["—", "Cabeza", "Cuerpo", "Piernas", "Pies"][slot]


## Capa del sprite del jugador para cada ranura.
static func slot_layer(slot: EquipSlot) -> StringName:
	return [&"", &"head", &"body", &"legs", &"feet"][slot]
