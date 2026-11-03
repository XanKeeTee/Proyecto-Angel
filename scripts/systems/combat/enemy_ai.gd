class_name EnemyAI
extends RefCounted
## Elige la intención (telegrafiada) de cada enemigo al empezar la ronda.
## Lee el estado del grupo: remata a los Caídos, va a por quien sangra o está en el suelo, y cambia
## de táctica según lo que ha perdido (`EnemyAttackDef.bonuses`). Cada intención lleva su razón
## (`CombatAction.reason`) para que el jugador entienda qué hace.

const FINISH_CHANCE: float = 0.7
## Probabilidad de ir a por el aliado con menos Cuerpo.
const FOCUS_WEAKEST_CHANCE: float = 0.5
## Probabilidad de ir a por quien sangra o está en el suelo (si hay alguien así).
const FOCUS_PREY_CHANCE: float = 0.75
## Probabilidad de volver a golpear una parte ya Herida o Rota.
const OPEN_WOUND_CHANCE: float = 0.65
## Probabilidad de ir a la parte que sangra.
const BLEEDING_PART_CHANCE: float = 0.7
## Cuerpo (fracción) por debajo del cual cuenta como malherido (AttackBonus.SELF_HURT).
const HURT_THRESHOLD: float = 0.5

static var _struggle: EnemyAttackDef


static func choose_intent(enemy: Combatant, party: Array[Combatant], rng: RandomNumberGenerator) -> CombatAction:
	var available: Array[EnemyAttackDef] = available_attacks(enemy, party)
	if available.is_empty():
		available.append(struggle_attack())

	var active: Array[Combatant] = []
	var fallen: Array[Combatant] = []
	for member: Combatant in party:
		if member.is_active():
			active.append(member)
		elif member.fallen and member.is_present():
			fallen.append(member)

	var action: CombatAction = CombatAction.new()
	action.type = CombatTypes.ActionType.ENEMY_ATTACK
	action.actor = enemy

	if enemy.def.finisher and not fallen.is_empty() and rng.randf() < FINISH_CHANCE:
		action.finishing = true
		action.target = fallen[rng.randi_range(0, fallen.size() - 1)]
		action.attack = _strongest_physical(available)
		action.part_id = CombatTypes.TORSO
		action.reason = "Va a rematar al caído"
		return action

	var targets: Array[Combatant] = active if not active.is_empty() else fallen
	if targets.is_empty():
		return null
	# Presa: quien sangra o está en el suelo atrae al enemigo.
	var prey: Array[Combatant] = []
	for member: Combatant in targets:
		if member.bleeding > 0 or member.is_down():
			prey.append(member)
	var focus: Combatant = null
	if not prey.is_empty() and rng.randf() < FOCUS_PREY_CHANCE:
		focus = prey[rng.randi_range(0, prey.size() - 1)]
	var picked: Dictionary = _pick_attack(enemy, available, focus if focus != null else targets[0], rng)
	action.attack = picked["attack"]
	action.reason = picked["reason"]
	enemy.pending_reaction = false
	if action.attack.cooldown > 0:
		enemy.cooldowns[action.attack] = action.attack.cooldown + 1
	var status_id: StringName = action.attack.requires_target_status
	var holders: Array[Combatant] = []
	if status_id != &"":
		for member: Combatant in targets:
			if member.has_status(status_id):
				holders.append(member)
	if not holders.is_empty():
		action.target = holders[rng.randi_range(0, holders.size() - 1)]
	elif focus != null:
		action.target = focus
	elif rng.randf() < FOCUS_WEAKEST_CHANCE:
		action.target = _weakest(targets)
	else:
		action.target = targets[rng.randi_range(0, targets.size() - 1)]
	action.part_id = pick_part(action.attack, action.target, rng)
	if action.reason == "" and action.target.bleeding > 0 and action.target.parts.has(action.part_id) \
			and action.target.parts[action.part_id].bleeding > 0:
		action.reason = "Va a la herida que sangra"
	return action


## Ataques que el enemigo puede usar ahora: tiene la parte que piden, está de pie o arrastrándose
## según el ataque, no está en recarga y, si piden un estado en el objetivo, alguien lo sufre.
static func available_attacks(enemy: Combatant, party: Array[Combatant]) -> Array[EnemyAttackDef]:
	var result: Array[EnemyAttackDef] = []
	var crawling: bool = enemy.is_crawling()
	for attack: EnemyAttackDef in enemy.def.attacks:
		if attack.required_part != &"" and enemy.part_disabled(attack.required_part):
			continue
		if attack.required_part != &"" and not enemy.has_part(attack.required_part):
			continue
		if attack.requires_standing and crawling:
			continue
		if attack.crawl_only and not crawling:
			continue
		if enemy.cooldowns.get(attack, 0) > 0:
			continue
		if attack.reaction and not enemy.pending_reaction:
			continue
		if attack.requires_target_status != &"":
			var someone: bool = false
			for member: Combatant in party:
				if member.is_present() and member.has_status(attack.requires_target_status):
					someone = true
			if not someone:
				continue
		result.append(attack)
	return result


## Reacciones primero (tras perder una parte); si no, al azar según el peso más las tácticas que
## se cumplen contra `target`. Devuelve {"attack": EnemyAttackDef, "reason": String}.
static func _pick_attack(enemy: Combatant, available: Array[EnemyAttackDef], target: Combatant,
		rng: RandomNumberGenerator) -> Dictionary:
	var reactions: Array[EnemyAttackDef] = []
	for attack: EnemyAttackDef in available:
		if attack.reaction:
			reactions.append(attack)
	if enemy.pending_reaction and not reactions.is_empty():
		return {"attack": reactions[rng.randi_range(0, reactions.size() - 1)], "reason": "Reacciona al dolor"}
	var weights: Array[float] = []
	var reasons: PackedStringArray = []
	var total: float = 0.0
	for attack: EnemyAttackDef in available:
		var bonus: Dictionary = attack_bonus(enemy, attack, target)
		var weight: float = attack.weight + float(bonus["weight"])
		weights.append(weight)
		reasons.append(bonus["reason"])
		total += weight
	if total <= 0.0:
		var index: int = rng.randi_range(0, available.size() - 1)
		return {"attack": available[index], "reason": reasons[index]}
	var roll: float = rng.randf() * total
	for i: int in available.size():
		roll -= weights[i]
		if roll < 0.0:
			return {"attack": available[i], "reason": reasons[i]}
	return {"attack": available[available.size() - 1], "reason": reasons[available.size() - 1]}


## Peso extra de un ataque por sus tácticas contra `target`: {"weight": float, "reason": String}
## (la razón de la táctica que más pesa).
static func attack_bonus(enemy: Combatant, attack: EnemyAttackDef, target: Combatant) -> Dictionary:
	var extra: float = 0.0
	var reason: String = ""
	var best: float = 0.0
	for bonus: AttackBonus in attack.bonuses:
		if bonus == null or not _condition_met(enemy, bonus, target):
			continue
		extra += bonus.weight
		if bonus.weight > best:
			best = bonus.weight
			reason = bonus.reason
	return {"weight": extra, "reason": reason}


static func _condition_met(enemy: Combatant, bonus: AttackBonus, target: Combatant) -> bool:
	match bonus.condition:
		AttackBonus.Condition.TARGET_BLEEDING:
			return target != null and target.bleeding > 0
		AttackBonus.Condition.TARGET_DOWN:
			return target != null and target.is_down()
		AttackBonus.Condition.SELF_PART_LOST:
			return enemy.part_disabled(bonus.part) or (bonus.part != &"" and not enemy.has_part(bonus.part))
		AttackBonus.Condition.SELF_HURT:
			return enemy.body < enemy.def.body_max * HURT_THRESHOLD
		AttackBonus.Condition.TARGET_DISARMED:
			return target != null and target.grip().unarmed
	return false


## Fin de ronda: avanza las recargas.
static func tick_cooldowns(enemy: Combatant) -> void:
	for attack: EnemyAttackDef in enemy.cooldowns.keys():
		enemy.cooldowns[attack] = enemy.cooldowns[attack] - 1
		if enemy.cooldowns[attack] <= 0:
			enemy.cooldowns.erase(attack)


static func pick_part(attack: EnemyAttackDef, target: Combatant, rng: RandomNumberGenerator) -> StringName:
	if attack.damage_type == CombatTypes.DamageType.HORROR:
		return &""
	var candidates: Array[StringName] = []
	match attack.target_part:
		CombatTypes.ANY_ARM:
			candidates = [CombatTypes.ARM_L, CombatTypes.ARM_R]
		CombatTypes.ANY_LEG:
			candidates = [CombatTypes.LEG_L, CombatTypes.LEG_R]
		&"":
			pass
		_:
			candidates = [attack.target_part]
	if candidates.is_empty():
		candidates = target.part_order.duplicate()
	var valid: Array[StringName] = []
	var wounded: Array[StringName] = []
	var bleeding: Array[StringName] = []
	for id: StringName in candidates:
		if not target.has_part(id) or target.parts[id].is_amputated():
			continue
		valid.append(id)
		if target.parts[id].state != CombatTypes.PartState.HEALTHY:
			wounded.append(id)
		if target.parts[id].bleeding > 0:
			bleeding.append(id)
	# Los enemigos huelen la sangre: prefieren lo que sangra y las heridas abiertas.
	if not bleeding.is_empty() and rng.randf() < BLEEDING_PART_CHANCE:
		return bleeding[rng.randi_range(0, bleeding.size() - 1)]
	if not wounded.is_empty() and rng.randf() < OPEN_WOUND_CHANCE:
		return wounded[rng.randi_range(0, wounded.size() - 1)]
	if not valid.is_empty() and attack.target_part != &"":
		return valid[rng.randi_range(0, valid.size() - 1)]

	# Al azar, con el torso tres veces más probable.
	var pool: Array[StringName] = []
	for id: StringName in target.part_order:
		if target.parts[id].is_amputated():
			continue
		pool.append(id)
		if id == CombatTypes.TORSO:
			pool.append(id)
			pool.append(id)
	if pool.is_empty():
		return CombatTypes.TORSO
	return pool[rng.randi_range(0, pool.size() - 1)]


static func struggle_attack() -> EnemyAttackDef:
	if _struggle == null:
		_struggle = EnemyAttackDef.new()
		_struggle.display_name = "Forcejeo"
		_struggle.power = 5
		_struggle.accuracy = 70
		_struggle.damage_type = CombatTypes.DamageType.BLUNT
	return _struggle


static func _weakest(targets: Array[Combatant]) -> Combatant:
	var weakest: Combatant = targets[0]
	for candidate: Combatant in targets:
		if float(candidate.body) / candidate.def.body_max < float(weakest.body) / weakest.def.body_max:
			weakest = candidate
	return weakest


static func _strongest_physical(available: Array[EnemyAttackDef]) -> EnemyAttackDef:
	var best: EnemyAttackDef = null
	for attack: EnemyAttackDef in available:
		if attack.damage_type == CombatTypes.DamageType.HORROR:
			continue
		if best == null or attack.power > best.power:
			best = attack
	return best if best != null else struggle_attack()
