class_name ActionPreview
extends RefCounted
## Vista previa de una orden antes de confirmarla (contrato de la interfaz del combate).
##
## PROVISIONAL (agente P): se borra al fusionar si las reglas definen la misma clase.

## Acierto (o probabilidad de éxito: huir, zafarse). -1 = no aplica.
var hit_chance: int = -1
var damage_min: int = 0
var damage_max: int = 0
var damage_type: CombatTypes.DamageType = CombatTypes.DamageType.BLUNT
## Frases cortas de lo que puede pasar («Puede romper el hueso», «Si se rompe: no podrá cortar»).
var lines: PackedStringArray = []
## Riesgos para quien actúa.
var risk_lines: PackedStringArray = []
## Probabilidad de amputar con este golpe (0-100).
var amputation_chance: int = 0
## Estado → probabilidad (0-100): {&"stun": 25, &"bleed": 40}.
var status_chances: Dictionary = {}
