class_name WeaponDef
extends Resource
## Arma que puede equipar un combatiente.

@export var display_name: String = ""
@export_range(1, 50) var power: int = 10
@export_range(0, 100) var accuracy: int = 75
@export var damage_type: CombatTypes.DamageType = CombatTypes.DamageType.CUT
## Necesita los dos brazos útiles.
@export var two_handed: bool = false
## Puntos extra de probabilidad de crítico.
@export_range(0, 50) var crit_mod: int = 0
