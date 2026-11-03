class_name TargetOption
extends RefCounted
## Un objetivo posible de una opción y sus partes elegibles (contrato de la interfaz del combate).
##
## PROVISIONAL (agente P): se borra al fusionar si las reglas definen la misma clase.

var combatant: Combatant
var parts: Array[PartOption] = []
