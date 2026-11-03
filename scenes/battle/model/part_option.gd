class_name PartOption
extends RefCounted
## Una parte del cuerpo que se puede elegir como objetivo (contrato de la interfaz del combate).
##
## PROVISIONAL (agente P): se borra al fusionar si las reglas definen la misma clase.

var id: StringName = &""
var label: String = ""
## CombatTypes.PartState.
var state: int = CombatTypes.PartState.HEALTHY
## Probabilidad de acierto (0 si no aplica, como en la Guardia).
var hit_chance: int = 0
var enabled: bool = true
var disabled_reason: String = ""
