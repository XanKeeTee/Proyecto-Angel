class_name ActionPreview
extends RefCounted
## Vista previa de una acción antes de confirmarla (`Battle.preview`). Las probabilidades son
## totales (ya cuentan el acierto), en porcentaje 0–100.

var hit_chance: int = 0
## Daño al Cuerpo del objetivo (sin crítico), sumando todas las partes que golpea.
var damage_min: int = 0
var damage_max: int = 0
var damage_type: CombatTypes.DamageType = CombatTypes.DamageType.BLUNT
## Frases cortas: «Puede romper el hueso», «Si se rompe: no podrá cortar».
var lines: PackedStringArray = []
## Riesgos para quien actúa: costes, sangrado, golpes que vienen y no se cubren.
var risk_lines: PackedStringArray = []
var amputation_chance: int = 0
## Estado → probabilidad (0–100): &"derribado", &"aturdido", &"sangrado", &"apartado", &"organo"…
var status_chances: Dictionary = {}

# --- Campos añadidos por Q ---
## Probabilidad de romper la parte (0–100).
var break_chance: int = 0
## Probabilidad de actuar antes que lo que prepara el enemigo (−1 = no aplica).
var act_first_chance: int = -1
## Daño a la integridad de la parte (sin crítico).
var part_damage_min: int = 0
var part_damage_max: int = 0
