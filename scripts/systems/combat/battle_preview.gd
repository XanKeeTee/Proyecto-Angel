class_name BattlePreview
extends RefCounted
## Vista previa honesta de una acción (`Battle.preview`): calcula acierto, daño y la probabilidad
## de romper, amputar, derribar, aturdir o hacer sangrar recorriendo las tiradas posibles (21
## valores del azar de daño × crítico sí/no), con las mismas reglas que `Battle._strike`.

const ROLL_STEPS: int = 21


## Acierto (0–100) de una opción contra una parte.
static func hit_chance(battle: Battle, actor: Combatant, option: ActionOption, target: Combatant,
		part_id: StringName) -> int:
	if not target.has_part(part_id):
		return 0
	var spec: Dictionary = _spec(battle, actor, option, target)
	if spec.is_empty():
		return 100
	return CombatRules.hit_chance(actor, target, spec["accuracy"], target.parts[part_id].def)


static func build(battle: Battle, actor: Combatant, option: ActionOption, target: Combatant,
		part_id: StringName) -> ActionPreview:
	var preview: ActionPreview = ActionPreview.new()
	preview.hit_chance = 100
	match option.action_type:
		CombatTypes.ActionType.ATTACK, CombatTypes.ActionType.SKILL:
			if option.skill != null and option.skill.target == SkillDef.Target.NONE:
				_self_skill(actor, option.skill, preview)
			elif target != null:
				_offense(battle, actor, option, target, part_id, preview)
		CombatTypes.ActionType.GUARD:
			_guard(battle, actor, part_id, preview)
		CombatTypes.ActionType.ITEM:
			_item(battle, option, target if target != null else actor, part_id, preview)
		CombatTypes.ActionType.BREATHE:
			preview.lines.append("+%d Mente." % (Battle.BREATHE_BASE + actor.def.willpower))
		CombatTypes.ActionType.BREAK_FREE:
			preview.hit_chance = battle.break_free_chance(actor)
			preview.lines.append("Si se suelta, puede huir y deja de ser blanco fácil.")
		CombatTypes.ActionType.FLEE_SOLO:
			preview.hit_chance = battle.flee_chance_solo(actor)
			preview.risk_lines.append("Si falla, pierde la ronda.")
		CombatTypes.ActionType.FLEE_ALL:
			preview.hit_chance = battle.flee_chance_all()
			preview.risk_lines.append("Si falla, se pierde la ronda.")
		CombatTypes.ActionType.RECOVER:
			preview.lines.append("Pierdes la acción mientras te recompones.")
	_actor_risks(battle, actor, option, part_id, preview)
	return preview


# --- ataque y habilidades contra un enemigo -----------------------------------------------------------

## Poder, precisión… de la opción (vacío si no golpea).
static func _spec(battle: Battle, actor: Combatant, option: ActionOption, target: Combatant) -> Dictionary:
	if option.action_type == CombatTypes.ActionType.ATTACK:
		var grip: WeaponGrip = actor.offhand_grip() if option.use_offhand else null
		if grip == null:
			grip = actor.grip()
		return {"power": grip.weapon.power, "accuracy": grip.weapon.accuracy + grip.accuracy_mod,
			"damage_type": grip.weapon.damage_type, "crit_mod": grip.weapon.crit_mod, "power_mult": grip.power_mult,
			"grip": grip}
	if option.skill != null and option.skill.target == SkillDef.Target.ENEMY:
		var grip: WeaponGrip = battle.skill_grip(actor, option.skill)
		var spec: Dictionary = battle.skill_spec(actor, option.skill, grip, target)
		spec["grip"] = grip
		return spec
	return {}


static func _offense(battle: Battle, actor: Combatant, option: ActionOption, target: Combatant, part_id: StringName,
		preview: ActionPreview) -> void:
	var spec: Dictionary = _spec(battle, actor, option, target)
	var skill: SkillDef = option.skill
	var parts: Array[StringName] = [part_id if part_id != &"" else CombatTypes.TORSO]
	if skill != null:
		parts = battle.skill_parts(skill, target, part_id)
	preview.damage_type = spec["damage_type"]
	var deals_damage: bool = skill == null or skill.deals_damage
	var hit_total: float = 0.0
	var any_hurt: bool = false
	var knock: float = 0.0
	for id: StringName in parts:
		var real: StringName = battle._redirect_part(target, id)
		if real != id:
			preview.lines.append("%s ya no está: irá a %s." % [_part_label(target, id), _part_label(target, real).to_lower()])
		var part: BodyPartState = target.parts[real]
		if part.state != CombatTypes.PartState.HEALTHY:
			any_hurt = true
		var hit: int = CombatRules.hit_chance(actor, target, spec["accuracy"], part.def)
		hit_total += hit
		if not deals_damage:
			continue
		var odds: Dictionary = estimate(actor, target, real, spec["power"], spec["damage_type"], spec["crit_mod"],
				spec["power_mult"], skill.crit_bonus if skill != null else 0, skill.organ_bonus if skill != null else 0.0)
		var p_hit: float = hit / 100.0
		var damage: Dictionary = CombatRules.damage_range(spec["power"], actor.def.strength, target.def.armor,
				spec["damage_type"], part.def, spec["power_mult"])
		var body: Vector2i = damage["body"]
		var integrity: Vector2i = damage["part"]
		preview.damage_min += body.x
		preview.damage_max += body.y
		preview.part_damage_min += CombatRules.integrity_damage(integrity.x, spec["damage_type"], real)
		preview.part_damage_max += CombatRules.integrity_damage(integrity.y, spec["damage_type"], real)
		preview.break_chance = maxi(preview.break_chance, roundi(100.0 * p_hit * odds["break"]))
		preview.amputation_chance = maxi(preview.amputation_chance, roundi(100.0 * p_hit * odds["amputate"]))
		_add_chance(preview, CombatTypes.STATUS_STUN, p_hit * odds["stun"])
		_add_chance(preview, CombatTypes.STATUS_BLEED, p_hit * minf(1.0, odds["bleed"]
				+ (1.0 if skill != null and skill.extra_bleed > 0 else 0.0)))
		_add_chance(preview, &"organo", p_hit * odds["organ"])
		knock = maxf(knock, p_hit * odds["knockdown"])
		_part_lines(target, real, spec["damage_type"], odds, p_hit, preview)
	preview.hit_chance = roundi(hit_total / maxf(1.0, parts.size()))
	if skill != null and skill.inflicts_status != null and target.is_active():
		var chance: float = preview.hit_chance / 100.0 * minf(1.0, skill.status_chance
				+ (skill.status_bonus_hurt_part if any_hurt else 0.0))
		if skill.inflicts_status.id == CombatTypes.STATUS_DOWN and target.is_crawling():
			chance = 0.0
		if skill.inflicts_status.id == CombatTypes.STATUS_DOWN:
			chance = 1.0 - (1.0 - chance) * (1.0 - knock)
			knock = 0.0
		_add_chance(preview, skill.inflicts_status.id, chance)
	if knock > 0.0 and not target.is_crawling():
		_add_chance(preview, CombatTypes.STATUS_DOWN, knock)
	if preview.status_chances.get(CombatTypes.STATUS_DOWN, 0) > 0:
		preview.lines.append("Puede tirarlo al suelo (%d %%): luego se le puede rematar." % preview.status_chances[CombatTypes.STATUS_DOWN])
	if preview.status_chances.get(CombatTypes.STATUS_STUN, 0) > 0:
		preview.lines.append("Puede aturdirlo (%d %%): perdería su siguiente acción." % preview.status_chances[CombatTypes.STATUS_STUN])
	if skill != null:
		preview.lines.append_array(skill.preview_lines)
	_intent_timing(battle, actor, option, target, part_id, preview)
	if spec.has("grip") and spec["grip"] != null:
		var grip: WeaponGrip = spec["grip"]
		preview.risk_lines.append_array(grip.notes)
		if grip.weapon.two_handed and (skill == null or skill.uses_weapon):
			preview.risk_lines.append("Arma de dos manos: actúas más tarde.")


## Probabilidades (condicionadas a acertar, 0–1) de lo que hace un golpe en una parte:
## {"break", "amputate", "stun", "knockdown", "bleed", "organ"}.
static func estimate(attacker: Combatant, target: Combatant, part_id: StringName, power: int,
		damage_type: CombatTypes.DamageType, crit_mod: int, power_mult: float, crit_bonus: int = 0,
		organ_bonus: float = 0.0) -> Dictionary:
	var part: BodyPartState = target.parts[part_id]
	var type_def: DamageTypeDef = CombatCatalog.damage_type(damage_type)
	var kind: CombatTypes.PartKind = CombatTypes.part_kind(part_id)
	var crit: float = clampf(CombatRules.crit_chance(attacker.def.dexterity, crit_mod + crit_bonus) / 100.0, 0.0, 1.0)
	var armor: int = CombatRules.armor_against(target.def.armor, damage_type)
	var guarded: bool = target.guarded_part == part_id
	var base: float = power * power_mult * (1.0 + attacker.def.strength / 20.0)
	var threshold: float = part.max_integrity * Battle.AMPUTATION_THRESHOLD
	var resist: float = mini(target.def.resilience * 2, Battle.MAX_AMPUTATION_RESIST) / 100.0
	var cuts: bool = type_def != null and type_def.can_amputate and part.def.amputable
	var tears: bool = damage_type == CombatTypes.DamageType.BLUNT and part.def.severable_by_blunt \
			and part.state == CombatTypes.PartState.BROKEN
	var p_break: float = 0.0
	var p_amputate: float = 0.0
	for step: int in ROLL_STEPS:
		var roll: float = 0.9 + 0.2 * step / float(ROLL_STEPS - 1)
		for critical: bool in [false, true]:
			var p: float = (crit if critical else 1.0 - crit) / ROLL_STEPS
			var damage: int = maxi(1, roundi(base * roll * (1.5 if critical else 1.0)) - armor)
			if guarded:
				damage = maxi(1, roundi(damage * 0.5))
			var integrity_hit: int = CombatRules.integrity_damage(damage, damage_type, part_id)
			var breaks: bool = false
			var amputates: bool = false
			if not part.is_disabled():
				var left: int = part.integrity - integrity_hit
				breaks = left <= 0 or (critical and part.state == CombatTypes.PartState.WOUNDED)
				if (cuts or tears) and not guarded and left <= 0:
					amputates = -left >= threshold or critical
			elif part.state == CombatTypes.PartState.BROKEN and (cuts or tears) and not guarded:
				amputates = integrity_hit >= threshold
			if breaks:
				p_break += p
			if amputates:
				p_amputate += p * (1.0 - resist)
	var stun: float = 0.0
	if kind == CombatTypes.PartKind.HEAD and part.state != CombatTypes.PartState.BROKEN:
		var stun_chance: float = type_def.head_stun_chance if type_def != null else 0.0
		stun = p_break + (1.0 - p_break) * stun_chance
	var knockdown: float = 0.0
	if kind == CombatTypes.PartKind.LEG and type_def != null and not target.is_down():
		knockdown = (p_break + p_amputate) * type_def.leg_break_knockdown
	var bleed: float = 0.0
	var organ: float = 0.0
	if type_def != null and not guarded:
		bleed = type_def.bleed_chance
		var torso: CombatTypes.PartState = target.part_state(CombatTypes.TORSO)
		if bleed > 0.0 and (torso == CombatTypes.PartState.WOUNDED or torso == CombatTypes.PartState.BROKEN):
			bleed += Battle.OPEN_TORSO_BLEED_CHANCE
		if kind == CombatTypes.PartKind.TORSO:
			organ = clampf(type_def.organ_chance + organ_bonus, 0.0, 1.0) if type_def.organ_chance + organ_bonus > 0.0 else 0.0
		bleed = 1.0 - (1.0 - minf(1.0, bleed)) * (1.0 - organ)
	return {"break": p_break, "amputate": p_amputate, "stun": stun, "knockdown": knockdown, "bleed": bleed,
		"organ": organ}


## Frases de lo que se consigue en esa parte.
static func _part_lines(target: Combatant, part_id: StringName, damage_type: CombatTypes.DamageType, odds: Dictionary,
		p_hit: float, preview: ActionPreview) -> void:
	var part: BodyPartState = target.parts[part_id]
	var type_def: DamageTypeDef = CombatCatalog.damage_type(damage_type)
	var kind: CombatTypes.PartKind = CombatTypes.part_kind(part_id)
	if type_def != null and type_def.part_text(kind) != "":
		preview.lines.append(type_def.part_text(kind))
	var label: String = part.def.display_name.to_lower()
	if part.state == CombatTypes.PartState.BROKEN:
		preview.lines.append("Ya está rota: el golpe pasa al Cuerpo.")
	elif odds["break"] > 0.0:
		var verb: String = "romper el hueso" if damage_type == CombatTypes.DamageType.BLUNT else "dejarla inútil"
		preview.lines.append("Puede %s (%d %%)." % [verb, roundi(100.0 * p_hit * odds["break"])])
		var consequence: String = broken_consequence(target, part_id)
		if consequence != "":
			preview.lines.append("Si se rompe: %s." % consequence)
	if odds["amputate"] > 0.0:
		var what: String = "decapitarlo" if part.def.vital and kind == CombatTypes.PartKind.HEAD else "arrancarle %s" % label
		preview.lines.append("Puede %s (%d %%)." % [what, roundi(100.0 * p_hit * odds["amputate"])])
	if odds["organ"] > 0.0:
		preview.lines.append("Puede alcanzar algo vital (%d %%)." % roundi(100.0 * p_hit * odds["organ"]))


## Qué pierde el objetivo si esa parte queda inútil («sin TAJO, SERRAR»).
static func broken_consequence(target: Combatant, part_id: StringName) -> String:
	var things: PackedStringArray = []
	var kind: CombatTypes.PartKind = CombatTypes.part_kind(part_id)
	if kind == CombatTypes.PartKind.LEG:
		var other: StringName = CombatTypes.LEG_L if part_id == CombatTypes.LEG_R else CombatTypes.LEG_R
		things.append("se arrastrará" if target.part_disabled(other) else "cojeará")
	elif kind == CombatTypes.PartKind.HEAD:
		things.append("queda aturdido")
	elif kind == CombatTypes.PartKind.TORSO:
		things.append("cada acción le costará Cuerpo")
	if target.is_enemy:
		var lost: PackedStringArray = []
		for attack: EnemyAttackDef in target.def.attacks:
			if attack.required_part == part_id and not lost.has(attack.display_name.to_upper()):
				lost.append(attack.display_name.to_upper())
		if not lost.is_empty():
			things.append("sin " + ", ".join(lost))
	elif kind == CombatTypes.PartKind.ARM and part_id == target.def.dominant_arm:
		things.append("no podrá usar su arma")
	return "; ".join(things)


## Interrupciones: si la habilidad hace perder la acción, cuánto de probable es llegar antes.
static func _intent_timing(battle: Battle, actor: Combatant, option: ActionOption, target: Combatant,
		part_id: StringName, preview: ActionPreview) -> void:
	var intent: CombatAction = battle.intents.get(target)
	if intent == null or intent.type == CombatTypes.ActionType.RECOVER or battle.has_acted(target):
		return
	var order: CombatAction = BattleMenu.make_order(battle, actor, option, target, part_id)
	preview.act_first_chance = CombatRules.first_chance(order, intent)
	var skill: SkillDef = option.skill
	if skill != null and skill.inflicts_status != null and skill.inflicts_status.loses_next_action:
		preview.lines.append("Si actúas antes (%d %%), pierde lo que prepara." % preview.act_first_chance)


# --- otras acciones -------------------------------------------------------------------------------------

static func _self_skill(actor: Combatant, skill: SkillDef, preview: ActionPreview) -> void:
	if skill.mind_gain > 0:
		preview.lines.append("+%d Mente." % (skill.mind_gain + (actor.def.willpower if skill.adds_willpower else 0)))
	preview.lines.append_array(skill.preview_lines)


static func _guard(battle: Battle, actor: Combatant, part_id: StringName, preview: ActionPreview) -> void:
	preview.lines.append("Mitad de daño en esa parte esta ronda y no se puede amputar.")
	for enemy: Combatant in battle.intents:
		var intent: CombatAction = battle.intents[enemy]
		if intent.target == actor and intent.part_id == part_id and intent.attack != null and battle.party_can_read_intents():
			preview.lines.append("Para el %s que viene." % intent.attack.display_name.to_upper())


static func _item(battle: Battle, option: ActionOption, target: Combatant, part_id: StringName,
		preview: ActionPreview) -> void:
	var treatment: TreatmentDef = option.treatment
	if treatment == null:
		preview.lines.append(option.description)
		return
	if treatment.needs_part() and target.has_part(part_id):
		var part: BodyPartState = target.parts[part_id]
		var stopped: int = mini(part.bleeding, treatment.stops_bleed)
		if stopped > 0:
			preview.lines.append("Corta %d de sangrado de %s (−%d Cuerpo menos por ronda)." % [stopped,
					part.def.display_name.to_lower(), stopped * Battle.BLEED_PER_STACK])
		if treatment.seals_part:
			preview.lines.append("No volverá a sangrar en este combate.")
		if treatment.restores_integrity > 0.0 and part.state == CombatTypes.PartState.WOUNDED:
			var gain: int = maxi(1, roundi(part.max_integrity * treatment.restores_integrity))
			if (part.integrity + gain) * 2 > part.max_integrity:
				preview.lines.append("La herida se cierra: vuelve a estar sana.")
			else:
				preview.lines.append("Alivia la herida.")
		var reason: String = battle.treatment_part_reason(treatment, target, part_id)
		if reason != "":
			preview.risk_lines.append(reason + ".")
	if treatment.body > 0:
		preview.lines.append("+%d Cuerpo." % treatment.body)
	if treatment.mind > 0:
		preview.lines.append("+%d Mente." % treatment.mind)
	if treatment.applies_status != null:
		preview.lines.append("%s %d rondas: %s" % [treatment.applies_status.display_name, treatment.applies_status.rounds,
				treatment.applies_status.description])
		_add_chance(preview, treatment.applies_status.id, 1.0)
	if option.item is Object and bool((option.item as Object).get("contaminated")) and treatment.contaminated_penalty > 0:
		preview.risk_lines.append("Está sucia: −%d Cuerpo y Mente." % treatment.contaminated_penalty)


## Lo que arriesga quien actúa: costes, sangrado y golpes que vienen a por él.
static func _actor_risks(battle: Battle, actor: Combatant, option: ActionOption, part_id: StringName,
		preview: ActionPreview) -> void:
	if option.cost_body > 0:
		preview.risk_lines.append("Cuesta %d de Cuerpo." % option.cost_body)
	if option.cost_mind > 0:
		preview.risk_lines.append("Cuesta %d de Mente." % option.cost_mind)
	if option.skill != null:
		preview.risk_lines.append_array(option.skill.risk_lines)
	if actor.part_state(CombatTypes.TORSO) == CombatTypes.PartState.BROKEN and not actor.ignores_wounds() \
			and option.action_type != CombatTypes.ActionType.GUARD:
		preview.risk_lines.append("Con el torso roto, actuar cuesta %d de Cuerpo." % Battle.BROKEN_TORSO_COST)
	var loss: int = battle.bleed_loss(actor)
	if loss > 0 and option.treatment == null:
		preview.risk_lines.append("Sangras: −%d Cuerpo al final de la ronda." % loss)
	if not battle.party_can_read_intents():
		return
	for enemy: Combatant in battle.intents:
		var intent: CombatAction = battle.intents[enemy]
		if intent.target != actor or intent.attack == null or battle.has_acted(enemy):
			continue
		if intent.attack.damage_type == CombatTypes.DamageType.HORROR:
			continue
		var covered: bool = option.action_type == CombatTypes.ActionType.GUARD and part_id == intent.part_id
		if covered:
			continue
		var where: String = _part_label(actor, intent.part_id).to_lower() if intent.part_id != &"" else "ti"
		preview.risk_lines.append("%s prepara %s → %s, sin cubrir." % [enemy.display_name(),
				intent.attack.display_name.to_upper(), where])


static func _add_chance(preview: ActionPreview, id: StringName, probability: float) -> void:
	var value: int = clampi(roundi(probability * 100.0), 0, 100)
	if value <= 0:
		return
	preview.status_chances[id] = maxi(int(preview.status_chances.get(id, 0)), value)


static func _part_label(combatant: Combatant, id: StringName) -> String:
	if combatant.has_part(id):
		return combatant.parts[id].def.display_name
	return String(id)
