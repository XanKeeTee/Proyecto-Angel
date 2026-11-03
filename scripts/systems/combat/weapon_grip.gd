class_name WeaponGrip
extends RefCounted
## Cómo empuña un combatiente un arma ahora mismo: con qué mano y con qué penalizadores (brazo
## herido, mano torpe). Lo calcula `Combatant.grip()`.

var weapon: WeaponDef
## Brazo que la sostiene (para dos manos, el dominante).
var hand: StringName = &""
## Multiplica el poder (brazo herido: 0,85; mano torpe: 0,75).
var power_mult: float = 1.0
## Suma al acierto (además de `Combatant.accuracy_modifier()`).
var accuracy_mod: int = 0
## Sin arma: forcejea.
var unarmed: bool = false
## Frases para la interfaz («En la mano torpe: −15 acierto»).
var notes: PackedStringArray = []


func reach() -> CombatTypes.Reach:
	return CombatTypes.Reach.SHORT if unarmed else weapon.reach


func damage_type() -> CombatTypes.DamageType:
	return weapon.damage_type
