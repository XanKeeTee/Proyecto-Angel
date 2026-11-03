class_name TargetOption
extends RefCounted
## Un objetivo posible de una opción, con sus partes elegibles (`Battle.targets_for`).

var combatant: Combatant
var parts: Array[PartOption] = []
# --- Añadidos por Q ---
## Se puede elegir este objetivo (y por qué no).
var enabled: bool = true
var disabled_reason: String = ""
