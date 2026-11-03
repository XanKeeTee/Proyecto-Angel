class_name WeaponDef
extends Resource
## Arma que puede equipar un combatiente. En la custodia la lleva un `ItemDef` (campo `weapon`).
## El tipo de daño decide qué hace en cada parte (DamageTypeDef, data/damage_types/); el alcance y
## las manos deciden qué habilidades permite (SkillDef). Ver docs/design/sistemas/combate.md § Armas.

@export var display_name: String = ""
@export_range(1, 50) var power: int = 10
@export_range(0, 100) var accuracy: int = 75
@export var damage_type: CombatTypes.DamageType = CombatTypes.DamageType.CUT
## Necesita los dos brazos útiles.
@export var two_handed: bool = false
## Puntos extra de probabilidad de crítico.
@export_range(0, 50) var crit_mod: int = 0
## Alcance: corto (se puede clavar, forcejear), medio (tubo) o largo (barra, palanca).
@export var reach: CombatTypes.Reach = CombatTypes.Reach.MEDIUM


## Nombre del tipo de daño para la interfaz.
func damage_type_name() -> String:
	return CombatTypes.DAMAGE_TYPE_NAMES[damage_type]


## Qué hace a las partes del cuerpo según el tipo de daño (docs/design/sistemas/combate.md).
func effect_text() -> String:
	var type_def: DamageTypeDef = CombatCatalog.damage_type(damage_type)
	if type_def != null and type_def.summary != "":
		return type_def.summary
	return "Daña la mente, no el cuerpo."


## Manos, alcance y tipo, para la interfaz («Una mano · alcance medio · contundente»).
func handling_text() -> String:
	return "%s · alcance %s · %s" % ["Dos manos" if two_handed else "Una mano",
		CombatTypes.REACH_NAMES[reach].to_lower(), damage_type_name().to_lower()]
