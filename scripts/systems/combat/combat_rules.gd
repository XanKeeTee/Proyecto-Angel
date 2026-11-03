class_name CombatRules
extends RefCounted
## Fórmulas del combate (docs/design/sistemas/combate.md). Funciones puras.

const MIN_HIT: int = 5
const MAX_HIT: int = 95
## Iniciativa: objeto +5, arma de dos manos −5 (las habilidades llevan la suya).
const ITEM_INITIATIVE: int = 5
const TWO_HANDED_INITIATIVE: int = -5
## Forcejear y empujar: puntos de acierto por cada punto de FUE de diferencia.
const STRENGTH_CONTEST_PER_POINT: int = 3


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


## Armadura que cuenta para un tipo de daño (punzante: la mitad).
static func armor_against(armor: int, damage_type: CombatTypes.DamageType) -> int:
	var type_def: DamageTypeDef = CombatCatalog.damage_type(damage_type)
	if type_def == null:
		return armor
	return floori(armor * type_def.armor_factor)


## Daño sin crítico (azar 0,9–1,1) a la parte y al Cuerpo: {"part": Vector2i, "body": Vector2i}.
## «part» es lo que resta de integridad sin contar el multiplicador del tipo de daño por parte.
static func damage_range(power: int, strength: int, armor: int, damage_type: CombatTypes.DamageType,
		part_def: BodyPartDef, power_mult: float = 1.0) -> Dictionary:
	armor = armor_against(armor, damage_type)
	var base: float = power * power_mult * (1.0 + strength / 20.0)
	var low: int = maxi(1, roundi(base * 0.9) - armor)
	var high: int = maxi(1, roundi(base * 1.1) - armor)
	return {
		"part": Vector2i(low, high),
		"body": Vector2i(roundi(low * part_def.body_mult), roundi(high * part_def.body_mult)),
	}


## Daño a la integridad de una parte según el tipo de daño (contundente rompe huesos…).
static func integrity_damage(part_damage: int, damage_type: CombatTypes.DamageType, part_id: StringName) -> int:
	var type_def: DamageTypeDef = CombatCatalog.damage_type(damage_type)
	if type_def == null:
		return part_damage
	return maxi(1, roundi(part_damage * type_def.integrity_mult(CombatTypes.part_kind(part_id))))


## Modificador de iniciativa de una acción.
static func initiative_mod(action: CombatAction) -> int:
	match action.type:
		CombatTypes.ActionType.ITEM:
			return ITEM_INITIATIVE
		CombatTypes.ActionType.ATTACK:
			return TWO_HANDED_INITIATIVE if action.actor.current_weapon().two_handed else 0
		CombatTypes.ActionType.SKILL:
			var mod: int = action.skill.initiative_mod if action.skill != null else 0
			if action.skill != null and action.skill.uses_weapon and action.skill.deals_damage \
					and action.actor.current_weapon().two_handed:
				mod += TWO_HANDED_INITIATIVE
			return mod
	return 0


static func roll_initiative(action: CombatAction, rng: RandomNumberGenerator) -> int:
	var agility: float = action.actor.effective_agility()
	return roundi(agility * 2.0) + rng.randi_range(0, roundi(agility)) + initiative_mod(action)


## Probabilidad (0–100) de que una acción vaya antes que otra (empate: primero el grupo).
static func first_chance(action: CombatAction, other: CombatAction) -> int:
	var a_agility: float = action.actor.effective_agility()
	var b_agility: float = other.actor.effective_agility()
	var a_base: int = roundi(a_agility * 2.0) + initiative_mod(action)
	var b_base: int = roundi(b_agility * 2.0) + initiative_mod(other)
	var a_span: int = roundi(a_agility)
	var b_span: int = roundi(b_agility)
	var wins: int = 0
	for a: int in a_span + 1:
		for b: int in b_span + 1:
			var mine: int = a_base + a
			var theirs: int = b_base + b
			if mine > theirs or (mine == theirs and not action.actor.is_enemy and other.actor.is_enemy):
				wins += 1
	return roundi(100.0 * wins / float((a_span + 1) * (b_span + 1)))


static func roll_damage(power: int, strength: int, rng: RandomNumberGenerator) -> float:
	return power * (1.0 + strength / 20.0) * rng.randf_range(0.9, 1.1)


static func crit_chance(dexterity: int, crit_mod: int) -> int:
	return roundi(dexterity / 2.0) + crit_mod


static func flee_chance(own_agility: float, enemy_agility: float) -> int:
	return clampi(roundi(50.0 + 3.0 * (own_agility - enemy_agility)), 10, 90)
