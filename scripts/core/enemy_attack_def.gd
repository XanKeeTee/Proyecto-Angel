class_name EnemyAttackDef
extends Resource
## Ataque de un enemigo y cómo se telegrafía.

## Nombre que aparece en el telegrafiado (se muestra en mayúsculas).
@export var display_name: String = ""
@export_range(0, 50) var power: int = 10
@export_range(0, 100) var accuracy: int = 75
@export var damage_type: CombatTypes.DamageType = CombatTypes.DamageType.CUT
## Daño a la Mente. Solo se usa con daño de horror.
@export_range(0, 100) var mind_damage: int = 0
## Parte objetivo: un id concreto, any_arm, any_leg o vacío (al azar, con preferencia por el torso).
@export var target_part: StringName = &""
## Parte que el enemigo necesita útil para usar el ataque. Vacío = ninguna.
@export var required_part: StringName = &""
@export var visibility: CombatTypes.Visibility = CombatTypes.Visibility.FULL
