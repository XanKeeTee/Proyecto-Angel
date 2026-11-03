class_name PartOption
extends RefCounted
## Una parte elegible de un objetivo (`TargetOption.parts`).

var id: StringName = &""
var label: String = ""
## Estado de la parte (CombatTypes.PartState).
var state: CombatTypes.PartState = CombatTypes.PartState.HEALTHY
## Probabilidad de acierto (0–100). En guardias y tratamientos, 100.
var hit_chance: int = 0
var enabled: bool = true
var disabled_reason: String = ""
# --- Añadido por Q ---
## Acumulaciones de sangrado de la parte.
var bleeding: int = 0
