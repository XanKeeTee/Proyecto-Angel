class_name BattleMenu
extends RefCounted
## Construye las opciones del menú de combate a partir de las reglas (contrato con la interfaz,
## docs/design/sistemas/combate.md § API de opciones). Funciones puras sobre un Battle.

const CATEGORY_ATTACK: StringName = &"attack"
const CATEGORY_SKILL: StringName = &"skill"
const CATEGORY_GUARD: StringName = &"guard"
const CATEGORY_ITEM: StringName = &"item"
const CATEGORY_OTHER: StringName = &"other"
const SIDE_ENEMY: StringName = &"enemy"
const SIDE_ALLY: StringName = &"ally"


## Lo que puede hacer `actor` ahora mismo, agrupado por categoría (en este orden: atacar,
## habilidades, guardia, objetos, otras).
static func action_menu(battle: Battle, actor: Combatant) -> Array[ActionOption]:
	var result: Array[ActionOption] = []
	var enemies_present: bool = not _present(battle.enemies).is_empty()
	var grips: Array[WeaponGrip] = actor.grips()
	for i: int in grips.size():
		result.append(_attack_option(grips[i], i > 0, enemies_present))
	for skill: SkillDef in actor.def.skills:
		var option: ActionOption = _skill_option(battle, actor, skill)
		if option != null:
			result.append(option)
	result.append(_guard_option(actor))
	result.append_array(_item_options(battle, actor))
	result.append_array(_other_options(battle, actor))
	var skip: CombatStatusDef = actor.pending_skip()
	if skip != null:
		for option: ActionOption in result:
			if option.category == CATEGORY_GUARD and skip.allows_guard:
				option.label = "Encogerse"
				option.description = "En el suelo, te cubres una parte mientras te levantas."
				continue
			_disable(option, "%s: pierdes la acción" % skip.display_name)
		var recover: ActionOption = ActionOption.new()
		recover.id = &"recover"
		recover.category = CATEGORY_OTHER
		recover.action_type = CombatTypes.ActionType.RECOVER
		recover.label = "Levantarse" if skip.id == CombatTypes.STATUS_DOWN else "Recobrarse"
		recover.description = skip.description
		recover.icon_key = &"recover"
		result.insert(0, recover)
	return result


## Objetivos y partes elegibles de una opción.
static func targets_for(battle: Battle, actor: Combatant, option: ActionOption) -> Array[TargetOption]:
	var result: Array[TargetOption] = []
	match option.target_side:
		SIDE_ENEMY:
			for enemy: Combatant in _present(battle.enemies):
				result.append(_enemy_target(battle, actor, option, enemy))
		SIDE_ALLY:
			var members: Array[Combatant] = [actor] if option.category == CATEGORY_GUARD else _present(battle.party)
			for member: Combatant in members:
				result.append(_ally_target(battle, option, member))
	return result


## La orden que se resuelve.
static func make_order(_battle: Battle, actor: Combatant, option: ActionOption, target: Combatant,
		part_id: StringName) -> CombatAction:
	var order: CombatAction = CombatAction.new()
	order.type = option.action_type
	order.actor = actor
	order.target = target if target != null else actor
	order.part_id = part_id
	order.item = option.item
	order.skill = option.skill
	order.treatment = option.treatment
	order.use_offhand = option.use_offhand
	if option.action_type == CombatTypes.ActionType.ITEM and option.treatment == null and option.item is StringName:
		order.item = null
	return order


# --- opciones ----------------------------------------------------------------------------------------

static func _attack_option(grip: WeaponGrip, offhand: bool, enemies_present: bool) -> ActionOption:
	var option: ActionOption = ActionOption.new()
	option.category = CATEGORY_ATTACK
	option.action_type = CombatTypes.ActionType.ATTACK
	option.use_offhand = offhand
	option.id = &"attack_offhand" if option.use_offhand else &"attack"
	option.label = "Atacar" if not option.use_offhand else "Atacar con %s" % grip.weapon.display_name.to_lower()
	option.icon_key = &"attack"
	var text: PackedStringArray = []
	if grip.unarmed:
		text.append("Sin arma: forcejea con lo que le queda.")
	else:
		text.append("%s · %s." % [grip.weapon.display_name, grip.weapon.handling_text()])
		text.append(grip.weapon.effect_text())
	text.append_array(grip.notes)
	option.description = " ".join(text)
	option.needs_target = true
	option.needs_part = true
	option.target_side = SIDE_ENEMY
	if not enemies_present:
		_disable(option, "No hay a quién")
	return option


static func _skill_option(battle: Battle, actor: Combatant, skill: SkillDef) -> ActionOption:
	var reason: String = battle.skill_block_reason(actor, skill)
	# Las habilidades de otra arma no se enseñan (el menú solo dice lo que tiene sentido).
	if reason != "" and battle.skill_grip(actor, skill) == null:
		return null
	var option: ActionOption = ActionOption.new()
	option.id = skill.id
	option.category = CATEGORY_SKILL
	option.action_type = CombatTypes.ActionType.SKILL
	option.skill = skill
	option.label = skill.display_name
	option.description = skill.description
	option.icon_key = skill.icon_key if skill.icon_key != &"" else StringName("skill_" + String(skill.id))
	option.cost_body = skill.cost_body
	option.cost_mind = skill.cost_mind
	if skill.target == SkillDef.Target.ENEMY:
		option.needs_target = true
		option.needs_part = skill.choose_part and not skill.hits_all_parts
		option.target_side = SIDE_ENEMY
	elif skill.mind_gain > 0:
		option.value_text = "+%d Mente" % (skill.mind_gain + (actor.def.willpower if skill.adds_willpower else 0))
	if reason == "" and skill.target == SkillDef.Target.ENEMY:
		var any: bool = false
		for enemy: Combatant in _present(battle.enemies):
			if battle.skill_target_reason(skill, enemy) == "":
				any = true
		if not any:
			reason = battle.skill_target_reason(skill, _present(battle.enemies)[0]) \
					if not _present(battle.enemies).is_empty() else "No hay a quién"
	if reason != "":
		_disable(option, reason)
	elif option.value_text == "":
		var costs: PackedStringArray = []
		if skill.cost_body > 0:
			costs.append("−%d C" % skill.cost_body)
		if skill.cost_mind > 0:
			costs.append("−%d M" % skill.cost_mind)
		option.value_text = " ".join(costs)
	return option


static func _guard_option(actor: Combatant) -> ActionOption:
	var option: ActionOption = ActionOption.new()
	option.id = &"guard"
	option.category = CATEGORY_GUARD
	option.action_type = CombatTypes.ActionType.GUARD
	option.label = "Guardia"
	option.description = "Cubrir una parte: recibe la mitad de daño esta ronda y no se puede amputar. Va antes que todo."
	option.icon_key = &"guard"
	option.needs_target = true
	option.needs_part = true
	option.target_side = SIDE_ALLY
	return option


static func _item_options(battle: Battle, actor: Combatant) -> Array[ActionOption]:
	var result: Array[ActionOption] = []
	for item: Variant in battle.combat_items():
		var option: ActionOption = ActionOption.new()
		var id: StringName = Battle.item_id(item)
		option.category = CATEGORY_ITEM
		option.action_type = CombatTypes.ActionType.ITEM
		option.item = item
		option.id = StringName("item:" + String(id))
		option.treatment = battle.treatment_of(item)
		option.icon_key = StringName("item_" + String(id))
		var quantity: int = battle.supplies.get(id, 1)
		if item is Object:
			quantity = int((item as Object).get("quantity"))
			var def: ItemDef = (item as Object).get("def")
			option.label = def.display_name
			option.description = def.description
		else:
			option.label = option.treatment.display_name if option.treatment != null else String(id)
		option.value_text = "×%d" % quantity if quantity > 1 else ""
		if option.treatment != null:
			option.description = option.treatment.description
			option.needs_target = true
			option.needs_part = option.treatment.needs_part()
			option.target_side = SIDE_ALLY
			if option.needs_part and not _something_to_treat(battle, option.treatment):
				_disable(option, "Nada que tratar")
		if not actor.can_use_items():
			_disable(option, "Sin brazos no puede")
		result.append(option)
	if result.is_empty() and not battle.item_source.is_valid() and battle.supplies.is_empty() and battle.bandages > 0:
		var bandage: ActionOption = ActionOption.new()
		bandage.id = &"bandage"
		bandage.category = CATEGORY_ITEM
		bandage.action_type = CombatTypes.ActionType.ITEM
		bandage.label = "Venda"
		bandage.description = "+%d Cuerpo y deja de sangrar." % Battle.BANDAGE_HEAL
		bandage.icon_key = &"item_venda"
		bandage.value_text = "×%d" % battle.bandages
		bandage.needs_target = true
		bandage.target_side = SIDE_ALLY
		if not actor.can_use_items():
			_disable(bandage, "Sin brazos no puede")
		result.append(bandage)
	return result


static func _other_options(battle: Battle, actor: Combatant) -> Array[ActionOption]:
	var result: Array[ActionOption] = []
	if actor.breakable_status() != null:
		var free: ActionOption = _simple(&"break_free", "Zafarse", CombatTypes.ActionType.BREAK_FREE,
				"Soltarse de quien te sujeta.")
		free.value_text = "%d%%" % battle.break_free_chance(actor)
		result.append(free)
	if battle.party.size() > 1:
		var solo: ActionOption = _simple(&"flee_solo", "Huir solo", CombatTypes.ActionType.FLEE_SOLO,
				"Sale del combate él solo; el resto sigue peleando.")
		solo.value_text = "%d%%" % battle.flee_chance_solo(actor)
		_flee_block(battle, actor, solo)
		result.append(solo)
	var flee: ActionOption = _simple(&"flee", "Huir", CombatTypes.ActionType.FLEE_ALL,
			"Intentar salir del combate. Si falla, se pierde la ronda.")
	flee.value_text = "%d%%" % battle.flee_chance_all()
	_flee_block(battle, actor, flee)
	result.append(flee)
	return result


static func _flee_block(battle: Battle, actor: Combatant, option: ActionOption) -> void:
	if not battle.can_flee:
		_disable(option, "No hay escapatoria")
	elif not actor.can_flee():
		_disable(option, "No puede andar" if actor.effective_agility() <= 0.0 else "No le sueltan")


static func _simple(id: StringName, label: String, type: CombatTypes.ActionType, description: String) -> ActionOption:
	var option: ActionOption = ActionOption.new()
	option.id = id
	option.category = CATEGORY_OTHER
	option.action_type = type
	option.label = label
	option.description = description
	option.icon_key = id
	return option


static func _disable(option: ActionOption, reason: String) -> void:
	option.enabled = false
	if option.disabled_reason == "":
		option.disabled_reason = reason


# --- objetivos ---------------------------------------------------------------------------------------

static func _enemy_target(battle: Battle, actor: Combatant, option: ActionOption, enemy: Combatant) -> TargetOption:
	var target: TargetOption = TargetOption.new()
	target.combatant = enemy
	if option.skill != null:
		target.disabled_reason = battle.skill_target_reason(option.skill, enemy)
		target.enabled = target.disabled_reason == ""
	for id: StringName in enemy.part_order:
		var part: BodyPartState = enemy.parts[id]
		var part_option: PartOption = _part_option(enemy, id)
		if part.is_amputated():
			part_option.enabled = false
			part_option.disabled_reason = "Ya no está"
		elif option.skill != null and not option.skill.allowed_parts.is_empty() \
				and not option.skill.allowed_parts.has(id):
			part_option.enabled = false
			part_option.disabled_reason = "No con esta técnica"
		if not part.is_amputated():
			part_option.hit_chance = BattlePreview.hit_chance(battle, actor, option, enemy, id)
		target.parts.append(part_option)
	return target


static func _ally_target(battle: Battle, option: ActionOption, member: Combatant) -> TargetOption:
	var target: TargetOption = TargetOption.new()
	target.combatant = member
	if option.category == CATEGORY_GUARD:
		for id: StringName in member.part_order:
			var part_option: PartOption = _part_option(member, id)
			part_option.hit_chance = 100
			if member.parts[id].is_amputated():
				part_option.enabled = false
				part_option.disabled_reason = "Ya no está"
			target.parts.append(part_option)
		return target
	if option.treatment != null and option.treatment.needs_part():
		var any: bool = false
		for id: StringName in member.part_order:
			var part_option: PartOption = _part_option(member, id)
			part_option.hit_chance = 100
			part_option.disabled_reason = battle.treatment_part_reason(option.treatment, member, id)
			part_option.enabled = part_option.disabled_reason == ""
			any = any or part_option.enabled
			target.parts.append(part_option)
		if not any:
			target.enabled = false
			target.disabled_reason = "Nada que tratar"
	return target


static func _part_option(combatant: Combatant, id: StringName) -> PartOption:
	var part: BodyPartState = combatant.parts[id]
	var part_option: PartOption = PartOption.new()
	part_option.id = id
	part_option.label = part.def.display_name
	part_option.state = part.state
	part_option.bleeding = part.bleeding
	return part_option


static func _something_to_treat(battle: Battle, treatment: TreatmentDef) -> bool:
	for member: Combatant in _present(battle.party):
		for id: StringName in member.part_order:
			if battle.treatment_part_reason(treatment, member, id) == "":
				return true
	return false


static func _present(side: Array[Combatant]) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for combatant: Combatant in side:
		if combatant.is_present():
			result.append(combatant)
	return result
