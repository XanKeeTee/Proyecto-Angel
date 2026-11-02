class_name CombatRules
extends RefCounted
## Fórmulas del combate (docs/design/sistemas/combate.md). Funciones puras.

const MIN_HIT: int = 5
const MAX_HIT: int = 95


static func hit_chance(attacker: Combatant, target: Combatant, accuracy: int, part_def: BodyPartDef) -> int:
	if target.fallen:
		return MAX_HIT
	var chance: float = (
		accuracy
		+ 2.0 * attacker.def.dexterity
		- 2.0 * target.effective_agility()
		+ part_def.hit_mod
		+ attacker.accuracy_modifier()
		+ target.incoming_hit_modifier()
	)
	return clampi(roundi(chance), MIN_HIT, MAX_HIT)


## Daño sin crítico (azar 0,9–1,1) a la parte y al Cuerpo: {"part": Vector2i, "body": Vector2i}.
static func damage_range(power: int, strength: int, armor: int, damage_type: CombatTypes.DamageType,
		part_def: BodyPartDef) -> Dictionary:
	if damage_type == CombatTypes.DamageType.PIERCE:
		armor = floori(armor / 2.0)
	var low: int = maxi(1, roundi(power * (1.0 + strength / 20.0) * 0.9) - armor)
	var high: int = maxi(1, roundi(power * (1.0 + strength / 20.0) * 1.1) - armor)
	return {
		"part": Vector2i(low, high),
		"body": Vector2i(roundi(low * part_def.body_mult), roundi(high * part_def.body_mult)),
	}


static func roll_initiative(action: CombatAction, rng: RandomNumberGenerator) -> int:
	var agility: float = action.actor.effective_agility()
	var modifier: int = 0
	match action.type:
		CombatTypes.ActionType.ITEM:
			modifier = 5
		CombatTypes.ActionType.ATTACK:
			if action.actor.current_weapon().two_handed:
				modifier = -5
	return roundi(agility * 2.0) + rng.randi_range(0, roundi(agility)) + modifier


static func roll_damage(power: int, strength: int, rng: RandomNumberGenerator) -> float:
	return power * (1.0 + strength / 20.0) * rng.randf_range(0.9, 1.1)


static func crit_chance(dexterity: int, crit_mod: int) -> int:
	return roundi(dexterity / 2.0) + crit_mod


static func flee_chance(own_agility: float, enemy_agility: float) -> int:
	return clampi(roundi(50.0 + 3.0 * (own_agility - enemy_agility)), 10, 90)
