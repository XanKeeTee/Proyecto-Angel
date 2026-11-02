class_name WeaponDef
extends Resource
## Arma que puede equipar un combatiente. En la custodia la lleva un `ItemDef` (campo `weapon`).

@export var display_name: String = ""
@export_range(1, 50) var power: int = 10
@export_range(0, 100) var accuracy: int = 75
@export var damage_type: CombatTypes.DamageType = CombatTypes.DamageType.CUT
## Necesita los dos brazos útiles.
@export var two_handed: bool = false
## Puntos extra de probabilidad de crítico.
@export_range(0, 50) var crit_mod: int = 0


## Nombre del tipo de daño para la interfaz.
func damage_type_name() -> String:
	return ["Cortante", "Contundente", "Perforante", "Horror"][damage_type]


## Qué hace a las partes del cuerpo según el tipo de daño (docs/design/sistemas/combate.md).
func effect_text() -> String:
	match damage_type:
		CombatTypes.DamageType.CUT:
			return "Puede amputar extremidades."
		CombatTypes.DamageType.BLUNT:
			return "Fractura sin amputar. En la cabeza puede aturdir."
		CombatTypes.DamageType.PIERCE:
			return "Atraviesa media armadura. Puede hacer sangrar."
	return "Daña la mente, no el cuerpo."
