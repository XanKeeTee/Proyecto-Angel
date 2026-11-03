class_name TreatmentDef
extends Resource
## Lo que hace un objeto de cura **en combate**, parte por parte (vendar un brazo que sangra, apretar
## un torniquete en un muñón, tragar analgésicos…). El objeto (ItemDef) sigue siendo de la custodia;
## esto solo dice qué hace en la pelea. Se gasta una unidad. Instancias en data/treatments/.
## Ver docs/design/sistemas/combate.md § Tratar heridas.

## Qué partes se pueden elegir.
enum PartRule { NONE, ANY_HURT, LIMB_BLEEDING }

@export var id: StringName = &""
## Verbo para el menú («Vendar»).
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon_key: StringName = &""
## Objetos de la custodia que dan este tratamiento (venda, venda usada…).
@export var item_ids: Array[StringName] = []
@export var part_rule: PartRule = PartRule.NONE

@export_group("Efectos")
## Acumulaciones de sangrado que quita de la parte (99 = todas).
@export_range(0, 99) var stops_bleed: int = 0
## Deja la parte sin poder volver a sangrar en este combate (torniquete).
@export var seals_part: bool = false
## Integridad que devuelve a la parte, en fracción de su máximo. No arregla una parte Rota.
@export_range(0.0, 1.0, 0.05) var restores_integrity: float = 0.0
@export_range(0, 100) var body: int = 0
@export_range(0, 100) var mind: int = 0
## Estado que aplica a quien lo recibe (analgesia, sedación) y estados que le quita.
@export var applies_status: CombatStatusDef
@export var removes_statuses: Array[StringName] = []

@export_group("Contaminado")
## Si el ejemplar está contaminado, resta esto de Cuerpo y Mente (y hace lo demás igual).
@export_range(0, 30) var contaminated_penalty: int = 0
@export var contaminated_text: String = ""

@export_group("Textos")
## Texto del registro. `%s` = quien lo usa, `%s` = la parte (o el nombre si no hay parte).
@export var use_text: String = ""


func needs_part() -> bool:
	return part_rule != PartRule.NONE
