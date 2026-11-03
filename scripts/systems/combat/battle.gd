class_name Battle
extends RefCounted
## Lógica de un combate por rondas (docs/design/sistemas/combate.md).
## No depende de nodos: la escena solo la muestra, y se puede testear en headless.
##
## Uso: begin_round() → el jugador elige órdenes → start_resolution(órdenes)
## → llamar a step() hasta que devuelva false → begin_round() otra vez.
##
## La interfaz pregunta qué se puede hacer con la API de opciones (`action_menu`, `targets_for`,
## `preview`, `make_order`; ver BattleMenu y BattlePreview) y no necesita conocer las reglas.

signal logged(text: String)
## Texto corto de impacto en mayúsculas ("AMPUTACIÓN.").
signal impact(text: String)
signal finished(outcome: Outcome, summary: String)
## Empieza a ejecutarse una acción (para animar al que actúa).
signal action_started(action: CombatAction)
## Resultado de un golpe, para la presentación. Claves: attacker, target, part_id, hit, chance,
## part_damage, body_damage, critical, guarded, broke, amputated, damage_type, mind_damage, status,
## organ (alcanzó un órgano), knocked_down (lo derribó), bled (acumulaciones de sangrado abiertas),
## skill (id de la habilidad o &"").
signal struck(info: Dictionary)
## Un estado se aplica o se termina, o cambia su sangrado (para refrescar iconos).
signal status_changed(combatant: Combatant)
## Se aplica un estado nuevo (id de CombatStatusDef).
signal status_added(combatant: Combatant, status_id: StringName)
## Se termina un estado.
signal status_removed(combatant: Combatant, status_id: StringName)
## Cambia el sangrado de una parte (acumulaciones que quedan).
signal bleeding_changed(combatant: Combatant, part_id: StringName, stacks: int)
## La intención de un enemigo se ha fijado o ha cambiado (también si la pierde por un estado).
signal intent_changed(enemy: Combatant)
## Ha cambiado el orden de la cola de resolución (`turn_order()`).
signal turn_order_changed

enum Outcome { ONGOING, VICTORY, PARTY_FLED, PROTAGONIST_ESCAPED, GAME_OVER }

const BANDAGE_HEAL: int = 20
const BLEED_PER_STACK: int = 3
## Compatibilidad: acumulaciones máximas por parte.
const MAX_BLEED: int = BodyPartState.MAX_BLEED
const BROKEN_TORSO_COST: int = 3
const BREATHE_BASE: int = 10
const AMPUTATION_THRESHOLD: float = 0.25
const MAX_AMPUTATION_RESIST: int = 40
## Sangrado que añade una amputación al muñón. `[PROPUESTA]`
const AMPUTATION_BLEED: int = 2
## Sangrado extra por golpe con el torso Herido o Roto.
const OPEN_TORSO_BLEED_CHANCE: float = 0.2
## Coagulación al final de la ronda: probabilidad de que una parte pierda una acumulación.
## Rota: la mitad. Amputada: nunca (hace falta torniquete o venda). `[PROPUESTA]`
const CLOT_BASE: float = 0.25
const CLOT_PER_RESILIENCE: float = 0.025
## Zafarse: base y puntos por cada punto de FUE de diferencia con quien sujeta.
const BREAK_FREE_BASE: int = 45
const BREAK_FREE_PER_STRENGTH: int = 5
## Mente bajo la que se aplica el estado Aterrado (fracción del máximo).
const TERROR_THRESHOLD: float = 0.25

var party: Array[Combatant] = []
var enemies: Array[Combatant] = []
var bandages: int = 3
var round_number: int = 0
var outcome: Outcome = Outcome.ONGOING
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Intención de cada enemigo esta ronda. Se guarda aquí, y no en el combatiente,
## para no crear ciclos de referencias (fugas de memoria).
var intents: Dictionary[Combatant, CombatAction] = {}
## Se puede huir de este combate (los combates `sin_huida` lo ponen a false).
var can_flee: bool = true
## Uso de objetos del inventario real sin tratamiento propio: `func(actor: Combatant, item: Variant)
## -> String` (texto del registro; "" = no se ha podido).
var item_user: Callable
## Objetos que se pueden usar en combate: `func() -> Array[ItemStack]` (CombatBridge lo asigna).
var item_source: Callable
## Gasta una unidad de un objeto del inventario real: `func(item: Variant) -> void`.
var item_consumer: Callable
## Inventario de prueba (prototipo y simulador): id de objeto → unidades. Solo si no hay
## `item_source`.
var supplies: Dictionary[StringName, int] = {}
## Agarres: víctima → quien la sujeta, y la parte con la que sujeta.
var _grab_holder: Dictionary[Combatant, Combatant] = {}
var _grab_part: Dictionary[Combatant, StringName] = {}

var _queue: Array[CombatAction] = []
var _resolving: bool = false
## Quién ha actuado ya esta ronda.
var _acted: Dictionary[Combatant, bool] = {}


func _init(party_defs: Array[CombatantDef], enemy_defs: Array[CombatantDef], seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for combatant_def: CombatantDef in party_defs:
		party.append(Combatant.new(combatant_def, false))
	for combatant_def: CombatantDef in enemy_defs:
		enemies.append(Combatant.new(combatant_def, true))


func protagonist() -> Combatant:
	for member: Combatant in party:
		if member.def.is_protagonist:
			return member
	return party[0]


# --- API de opciones (contrato con la interfaz) ------------------------------------------------------

## Lo que puede hacer `actor` ahora mismo, agrupado por categoría de menú.
func action_menu(actor: Combatant) -> Array[ActionOption]:
	return BattleMenu.action_menu(self, actor)


## Para una opción con objetivo: los objetivos y, por cada uno, las partes elegibles.
func targets_for(actor: Combatant, option: ActionOption) -> Array[TargetOption]:
	return BattleMenu.targets_for(self, actor, option)


## Vista previa completa antes de confirmar (acierto, daño, efectos probables, riesgos).
func preview(actor: Combatant, option: ActionOption, target: Combatant, part_id: StringName) -> ActionPreview:
	return BattlePreview.build(self, actor, option, target, part_id)


## Convierte la elección en la orden que se resuelve.
func make_order(actor: Combatant, option: ActionOption, target: Combatant, part_id: StringName) -> CombatAction:
	return BattleMenu.make_order(self, actor, option, target, part_id)


# --- Ronda -----------------------------------------------------------------

func begin_round() -> void:
	round_number += 1
	intents.clear()
	_acted.clear()
	for combatant: Combatant in _everyone():
		combatant.guarded_part = &""
		_refresh_terror(combatant)
	for enemy: Combatant in enemies:
		if not enemy.is_active():
			continue
		var intent: CombatAction = _choose_intent(enemy)
		if intent != null:
			intents[enemy] = intent
			intent_changed.emit(enemy)
	logged.emit("— RONDA %d —" % round_number)


func _choose_intent(enemy: Combatant) -> CombatAction:
	var skip: CombatStatusDef = enemy.pending_skip()
	if skip != null:
		var action: CombatAction = CombatAction.new()
		action.type = CombatTypes.ActionType.RECOVER
		action.actor = enemy
		action.reason = skip.display_name
		return action
	return EnemyAI.choose_intent(enemy, party, rng)


## Prepara la resolución. Las guardias se aplican antes que nada.
func start_resolution(orders: Array[CombatAction]) -> void:
	_queue.clear()
	var pending: Array[CombatAction] = []
	for order: CombatAction in orders:
		if order.type == CombatTypes.ActionType.GUARD:
			order.actor.guarded_part = order.part_id
			logged.emit("%s se cubre: %s." % [order.actor.display_name(), _part_name(order.actor, order.part_id)])
			if order.actor.pending_skip() != null and order.actor.pending_skip().allows_guard:
				_spend_skip(order.actor)
		else:
			pending.append(order)
	for enemy: Combatant in enemies:
		if intents.has(enemy) and enemy.is_active():
			pending.append(intents[enemy])
	for action: CombatAction in pending:
		action.initiative = CombatRules.roll_initiative(action, rng)
	pending.sort_custom(_sort_by_initiative)
	_queue = pending
	_resolving = true
	turn_order_changed.emit()


## Ejecuta la siguiente acción. Devuelve false cuando la ronda ha terminado.
func step() -> bool:
	if not _resolving:
		return false
	while not _queue.is_empty() and outcome == Outcome.ONGOING:
		var action: CombatAction = _queue.pop_front()
		turn_order_changed.emit()
		if not action.actor.is_active():
			continue
		_acted[action.actor] = true
		_execute(action)
		_check_outcome()
		return true
	_resolving = false
	if outcome == Outcome.ONGOING:
		_end_round()
	return false


## Acciones que quedan por resolver esta ronda, en orden.
func turn_order() -> Array[CombatAction]:
	return _queue.duplicate()


## Ya ha actuado esta ronda.
func has_acted(combatant: Combatant) -> bool:
	return _acted.has(combatant)


# --- Consultas para la interfaz ----------------------------------------------

func party_can_read_intents() -> bool:
	for member: Combatant in party:
		if member.is_active() and member.can_read_intents():
			return true
	return false


func intent_text(enemy: Combatant) -> String:
	var action: CombatAction = intents.get(enemy)
	if action == null or not enemy.is_active():
		return ""
	if action.type == CombatTypes.ActionType.RECOVER:
		return "%s: PIERDE EL TURNO" % action.reason.to_upper()
	if not party_can_read_intents():
		return "??? → ???"
	var who: String = action.target.display_name() if action.target != null else "???"
	if action.finishing:
		return "REMATA → %s" % who
	var what: String = action.attack.display_name.to_upper()
	match action.attack.visibility:
		CombatTypes.Visibility.HIDE_WHAT:
			return "??? → %s" % who
		CombatTypes.Visibility.HIDE_WHO:
			return "%s → ???" % what
	if action.part_id != &"" and action.target != null and action.target.has_part(action.part_id):
		return "%s → %s de %s" % [what, _part_name(action.target, action.part_id), who]
	return "%s → %s" % [what, who]


## Aviso legible de lo que prepara un enemigo («Levanta el brazo de bisturíes»), o "" si no se ve.
func intent_telegraph(enemy: Combatant) -> String:
	var action: CombatAction = intents.get(enemy)
	if action == null or not enemy.is_active() or not party_can_read_intents() or action.attack == null:
		return ""
	if action.attack.visibility == CombatTypes.Visibility.HIDE_WHAT:
		return ""
	return action.attack.telegraph


## Por qué hace lo que hace («Huele tu sangre»), o "" si no hay razón especial o no se ve.
func intent_reason(enemy: Combatant) -> String:
	var action: CombatAction = intents.get(enemy)
	if action == null or not enemy.is_active() or not party_can_read_intents():
		return ""
	if action.type == CombatTypes.ActionType.RECOVER:
		return ""
	return action.reason


func preview_hit_chance(attacker: Combatant, target: Combatant, part_id: StringName) -> int:
	var grip: WeaponGrip = attacker.grip()
	return CombatRules.hit_chance(attacker, target, grip.weapon.accuracy + grip.accuracy_mod, target.parts[part_id].def)


## Daño estimado (sin crítico) del arma actual sobre una parte: {"part": Vector2i(mín, máx),
## "body": Vector2i(mín, máx)} con el que pasa al Cuerpo.
func preview_damage(attacker: Combatant, target: Combatant, part_id: StringName) -> Dictionary:
	var grip: WeaponGrip = attacker.grip()
	return CombatRules.damage_range(grip.weapon.power, attacker.def.strength, target.def.armor,
			grip.weapon.damage_type, target.parts[part_id].def, grip.power_mult)


## Probabilidad de zafarse de un agarre.
func break_free_chance(member: Combatant) -> int:
	var holder: Combatant = _grab_holder.get(member)
	var other: int = holder.def.strength if holder != null else member.def.strength
	return clampi(BREAK_FREE_BASE + BREAK_FREE_PER_STRENGTH * (member.def.strength - other), 15, 90)


## Quién sujeta a `member` (o null).
func grabbed_by(member: Combatant) -> Combatant:
	return _grab_holder.get(member)


## A quién sujeta `holder` (víctimas).
func held_by(holder: Combatant) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for victim: Combatant in _grab_holder:
		if _grab_holder[victim] == holder:
			result.append(victim)
	return result


func flee_chance_solo(member: Combatant) -> int:
	var chance: int = CombatRules.flee_chance(member.effective_agility(), _average_agility(enemies))
	return clampi(chance - member.flee_penalty(), 5, 90)


func flee_chance_all() -> int:
	var penalty: int = 0
	for member: Combatant in party:
		if member.is_active():
			penalty = maxi(penalty, member.flee_penalty())
	return clampi(CombatRules.flee_chance(_average_agility(party), _average_agility(enemies)) - penalty, 5, 90)


## Cuerpo que perderá al final de la ronda por el sangrado (sin contar la coagulación).
func bleed_loss(combatant: Combatant) -> int:
	return combatant.bleeding * BLEED_PER_STACK


## Por qué no puede usar una habilidad ahora ("" = puede). No mira el objetivo.
func skill_block_reason(actor: Combatant, skill: SkillDef) -> String:
	if actor.skill_cooldowns.get(skill.id, 0) > 0:
		return "Aún no (%d)" % actor.skill_cooldowns[skill.id]
	if skill.cost_body > 0 and actor.body <= skill.cost_body:
		return "No te queda Cuerpo"
	if skill.cost_mind > 0 and actor.def.has_mind and actor.mind <= skill.cost_mind:
		return "No te queda Mente"
	if skill.target == SkillDef.Target.NONE and skill.mind_gain > 0 and not actor.def.has_mind:
		return "No le sirve"
	if skill.needs_head and actor.part_disabled(CombatTypes.HEAD):
		return "Con la cabeza rota no puede"
	if skill.needs_standing and actor.is_down():
		return "Primero hay que levantarse"
	if actor.useful_arms() < skill.needs_arms:
		return "Necesitas los dos brazos" if skill.needs_arms >= 2 else "Necesitas un brazo útil"
	if skill_grip(actor, skill) == null:
		return _weapon_requirement_text(skill)
	return ""


## Con qué empuña una habilidad: la mano principal, la otra o una mano libre (sin arma). null si
## ninguna cumple lo que pide.
func skill_grip(actor: Combatant, skill: SkillDef) -> WeaponGrip:
	var candidates: Array[WeaponGrip] = actor.grips()
	var main: WeaponGrip = actor.grip()
	# Mano libre: la otra está útil y no lleva nada (el arma principal es de una mano).
	if not main.unarmed and not main.weapon.two_handed and actor.def.offhand_weapon == null \
			and actor.part_useful(actor.off_arm()):
		var free: WeaponGrip = WeaponGrip.new()
		free.weapon = Combatant.unarmed_weapon()
		free.unarmed = true
		free.hand = actor.off_arm()
		candidates.append(free)
	for candidate: WeaponGrip in candidates:
		if _grip_fits(candidate, skill):
			return candidate
	return null


func _grip_fits(grip: WeaponGrip, skill: SkillDef) -> bool:
	if skill.needs_weapon and grip.unarmed:
		return false
	var reach: CombatTypes.Reach = grip.reach()
	if reach < skill.min_reach or reach > skill.max_reach:
		return false
	if not skill.weapon_damage_types.is_empty() and not skill.weapon_damage_types.has(grip.damage_type()):
		return false
	return true


func _weapon_requirement_text(skill: SkillDef) -> String:
	if skill.max_reach == CombatTypes.Reach.SHORT:
		return "Necesitas un arma corta" if skill.needs_weapon else "Necesitas una mano libre o un arma corta"
	if skill.min_reach >= CombatTypes.Reach.MEDIUM:
		if skill.weapon_damage_types == [CombatTypes.DamageType.BLUNT]:
			return "Necesitas un arma contundente larga"
		return "Necesitas un arma larga"
	return "No con esta arma"


## Por qué una habilidad no sirve contra este objetivo ("" = sirve).
func skill_target_reason(skill: SkillDef, target: Combatant) -> String:
	if skill.target_must_be_down and not target.is_down():
		return "Solo a quien está en el suelo"
	if skill.target_must_stand and target.is_down():
		return "Ya está en el suelo"
	return ""


## Objetos que se pueden usar en combate (ItemStack del inventario real, o ids del de prueba).
func combat_items() -> Array:
	if item_source.is_valid():
		return item_source.call()
	var result: Array = []
	for id: StringName in supplies:
		if supplies[id] > 0:
			result.append(id)
	return result


## Tratamiento por partes de un objeto (ItemStack o id), o null.
func treatment_of(item: Variant) -> TreatmentDef:
	return CombatCatalog.treatment_for(item_id(item))


## Id de un objeto (ItemStack o StringName).
static func item_id(item: Variant) -> StringName:
	if item is StringName or item is String:
		return StringName(item)
	if item is Object and (item as Object).get("def") != null:
		return ((item as Object).get("def") as ItemDef).id
	return &""


## Si un tratamiento sirve en esta parte ("" = sí).
func treatment_part_reason(treatment: TreatmentDef, target: Combatant, part_id: StringName) -> String:
	if not target.has_part(part_id):
		return "No está"
	var part: BodyPartState = target.parts[part_id]
	match treatment.part_rule:
		TreatmentDef.PartRule.LIMB_BLEEDING:
			if not CombatTypes.is_limb(part_id):
				return "Solo en brazos o piernas"
			if part.bleeding <= 0:
				return "No sangra"
		TreatmentDef.PartRule.ANY_HURT:
			if part.bleeding <= 0 and part.state != CombatTypes.PartState.WOUNDED:
				return "No sangra" if part.state == CombatTypes.PartState.HEALTHY else "Esto no lo arregla una venda"
	return ""


# --- Ejecución -----------------------------------------------------------------

func _execute(action: CombatAction) -> void:
	var actor: Combatant = action.actor
	var skip: CombatStatusDef = actor.pending_skip()
	if skip != null:
		_spend_skip(actor)
		logged.emit(_named(skip.skip_text, actor) if skip.skip_text != ""
				else "%s no reacciona (%s)." % [actor.display_name(), skip.display_name.to_lower()])
		return
	if action.type == CombatTypes.ActionType.RECOVER:
		logged.emit("%s se recompone." % actor.display_name())
		return
	for id: StringName in actor.statuses:
		var status: CombatStatusDef = actor.status_defs[id]
		if status.skip_chance > 0.0 and not actor.is_suppressed(id) and rng.randf() < status.skip_chance:
			logged.emit("%s no consigue moverse (%s)." % [actor.display_name(), status.display_name.to_lower()])
			return
	if actor.part_state(CombatTypes.TORSO) == CombatTypes.PartState.BROKEN and not actor.ignores_wounds():
		logged.emit("Moverse le cuesta a %s (−%d Cuerpo)." % [actor.display_name(), BROKEN_TORSO_COST])
		_lose_body(actor, BROKEN_TORSO_COST, false)
		if not actor.is_active():
			return

	action_started.emit(action)
	match action.type:
		CombatTypes.ActionType.ATTACK:
			var grip: WeaponGrip = actor.offhand_grip() if action.use_offhand else null
			if grip == null:
				grip = actor.grip()
			var weapon: WeaponDef = grip.weapon
			_strike(actor, action.target, action.part_id, weapon.display_name, weapon.power,
					weapon.accuracy + grip.accuracy_mod, weapon.damage_type, weapon.crit_mod, true,
					{"power_mult": grip.power_mult})
		CombatTypes.ActionType.SKILL:
			_use_skill(action)
		CombatTypes.ActionType.ENEMY_ATTACK:
			_enemy_attack(action)
		CombatTypes.ActionType.BREATHE:
			_breathe(actor, BREATHE_BASE + actor.def.willpower)
		CombatTypes.ActionType.ITEM:
			if action.treatment != null:
				_treat(action)
			elif item_user.is_valid() and action.item != null:
				var text: String = item_user.call(actor, action.item)
				logged.emit(text if text != "" else "%s no consigue usarlo." % actor.display_name())
				status_changed.emit(actor)
			else:
				_use_bandage(actor, action.target)
		CombatTypes.ActionType.BREAK_FREE:
			_break_free(actor)
		CombatTypes.ActionType.FLEE_SOLO:
			_flee_solo(actor)
		CombatTypes.ActionType.FLEE_ALL:
			_flee_all()


## Gasta la acción perdida: todos los estados de «pierde la siguiente acción» se dan por cumplidos
## y duran solo hasta el final de esta ronda.
func _spend_skip(actor: Combatant) -> void:
	for id: StringName in actor.statuses:
		if actor.status_defs[id].loses_next_action and not actor.spent_skips.has(id):
			actor.spent_skips[id] = true
			actor.statuses[id] = 1
	status_changed.emit(actor)


func _breathe(actor: Combatant, gained: int) -> void:
	actor.change_mind(gained)
	_refresh_terror(actor)
	logged.emit("%s respira hondo (+%d Mente)." % [actor.display_name(), gained])


func _enemy_attack(action: CombatAction) -> void:
	var actor: Combatant = action.actor
	var attack: EnemyAttackDef = action.attack
	if attack.required_part != &"" and actor.part_disabled(attack.required_part):
		logged.emit("%s ya no puede usar %s." % [actor.display_name(), attack.display_name.to_upper()])
		return
	if attack.requires_target_status != &"" and (action.target == null or not action.target.has_status(attack.requires_target_status)):
		logged.emit("%s busca a su presa, pero ya no la tiene a su merced: %s se pierde." % [actor.display_name(),
				attack.display_name.to_upper()])
		return
	if attack.damage_type == CombatTypes.DamageType.HORROR:
		var target: Combatant = _redirect_target(actor, action.target)
		if target == null:
			return
		var amount: int = _mind_after_will(target, attack.mind_damage)
		logged.emit("%s usa %s → %s: −%d Mente." % [actor.display_name(), attack.display_name.to_upper(),
				target.display_name(), amount])
		_change_mind(target, -amount)
		if attack.inflicts_status != null and rng.randf() < attack.status_chance:
			_apply_status(target, attack.inflicts_status, actor, attack.required_part)
		struck.emit({"attacker": actor, "target": target, "part_id": &"", "hit": true, "chance": 100,
				"part_damage": 0, "body_damage": 0, "critical": false, "guarded": false, "broke": false,
				"amputated": false, "damage_type": attack.damage_type, "mind_damage": amount, "status": &"",
				"organ": false, "knocked_down": false, "bled": 0, "skill": &""})
		return
	var info: Dictionary = _strike(actor, action.target, action.part_id, attack.display_name.to_upper(), attack.power,
			attack.accuracy, attack.damage_type, 0, false)
	if not info.get("hit", false):
		struck.emit(info)
		return
	var target: Combatant = info["target"]
	if attack.mind_damage > 0 and not target.dead and target.def.has_mind:
		var amount: int = _mind_after_will(target, attack.mind_damage)
		if amount > 0:
			info["mind_damage"] = amount
			logged.emit("%s: −%d Mente." % [target.display_name(), amount])
			_change_mind(target, -amount)
	if attack.inflicts_status != null and target.is_active() and rng.randf() < attack.status_chance:
		if _apply_status(target, attack.inflicts_status, actor, attack.required_part):
			info["status"] = attack.inflicts_status.id
			if attack.inflicts_status.id == CombatTypes.STATUS_DOWN:
				info["knocked_down"] = true
	struck.emit(info)


func _mind_after_will(target: Combatant, amount: int) -> int:
	return maxi(0, amount - floori(target.def.willpower / 2.0))


## Aplica un estado. Devuelve true si se ha aplicado (derribar a quien se arrastra no hace nada).
func _apply_status(target: Combatant, status: CombatStatusDef, source: Combatant, source_part: StringName) -> bool:
	if status == null or not target.is_present():
		return false
	if status.id == CombatTypes.STATUS_DOWN and target.is_crawling():
		return false
	for other: StringName in status.removes:
		_end_status(target, other)
	var fresh: bool = target.add_status(status)
	if status.breakable and source != null:
		_grab_holder[target] = source
		_grab_part[target] = source_part
	if status.breaks_holds:
		for victim: Combatant in held_by(target):
			var held: CombatStatusDef = victim.breakable_status()
			if held != null:
				_end_status(victim, held.id)
	if fresh and status.apply_text != "":
		logged.emit(_named(status.apply_text, target))
	if fresh:
		status_added.emit(target, status.id)
	status_changed.emit(target)
	if target.is_enemy and status.loses_next_action and intents.has(target) and not has_acted(target):
		intent_changed.emit(target)
	return true


func _end_status(target: Combatant, id: StringName) -> void:
	if not target.has_status(id):
		return
	var status: CombatStatusDef = target.status_defs[id]
	target.remove_status(id)
	if status.breakable:
		_grab_holder.erase(target)
		_grab_part.erase(target)
	if status.end_text != "" and target.is_present():
		logged.emit(_named(status.end_text, target))
	status_removed.emit(target, id)
	status_changed.emit(target)


## Suelta a quien sujeta alguien que ya no puede sujetar (muerto, Caído, en el suelo o sin la parte
## con la que sujetaba).
func _release_grabs() -> void:
	for victim: Combatant in _grab_holder.keys():
		var holder: Combatant = _grab_holder[victim]
		var part: StringName = _grab_part.get(victim, &"")
		if holder.is_active() and not (part != &"" and holder.part_disabled(part)) and victim.is_present() \
				and not holder.has_status(CombatTypes.STATUS_DOWN):
			continue
		var status: CombatStatusDef = victim.breakable_status()
		if status != null:
			_end_status(victim, status.id)
		else:
			_grab_holder.erase(victim)
			_grab_part.erase(victim)


func _break_free(actor: Combatant) -> void:
	var status: CombatStatusDef = actor.breakable_status()
	if status == null:
		logged.emit("%s ya está libre." % actor.display_name())
		return
	var chance: int = break_free_chance(actor)
	if rng.randi_range(1, 100) > chance:
		logged.emit("%s forcejea, pero no consigue soltarse (%d%%)." % [actor.display_name(), chance])
		return
	logged.emit("%s se zafa." % actor.display_name())
	_end_status(actor, status.id)


## Golpe físico. Devuelve la información del golpe (ver la señal `struck`). Si `emit_info`, emite
## `struck` aquí; los ataques enemigos y las habilidades la emiten ellos tras añadir lo suyo.
## `extra`: power_mult (float), crit_bonus (int), extra_bleed (int), organ_bonus (float), skill (id).
func _strike(attacker: Combatant, target: Combatant, part_id: StringName, attack_name: String,
		power: int, accuracy: int, damage_type: CombatTypes.DamageType, crit_mod: int, emit_info: bool = true,
		extra: Dictionary = {}) -> Dictionary:
	var info: Dictionary = {"attacker": attacker, "target": target, "part_id": part_id, "hit": false, "chance": 0,
		"part_damage": 0, "body_damage": 0, "critical": false, "guarded": false, "broke": false, "amputated": false,
		"damage_type": damage_type, "mind_damage": 0, "status": &"", "organ": false, "knocked_down": false,
		"bled": 0, "skill": extra.get("skill", &"")}
	target = _redirect_target(attacker, target)
	if target == null:
		logged.emit("%s no encuentra a quién atacar." % attacker.display_name())
		return info
	part_id = _redirect_part(target, part_id)
	info["target"] = target
	info["part_id"] = part_id
	var part: BodyPartState = target.parts[part_id]
	var where: String = "%s de %s" % [part.def.display_name.to_upper(), target.display_name()]
	var chance: int = CombatRules.hit_chance(attacker, target, accuracy, part.def)
	info["chance"] = chance
	if rng.randi_range(1, 100) > chance:
		logged.emit("%s: %s → %s. Falla (%d%%)." % [attacker.display_name(), attack_name, where, chance])
		if emit_info:
			struck.emit(info)
		return info
	info["hit"] = true

	var type_def: DamageTypeDef = CombatCatalog.damage_type(damage_type)
	var kind: CombatTypes.PartKind = CombatTypes.part_kind(part_id)
	var base: float = CombatRules.roll_damage(power, attacker.def.strength, rng) * float(extra.get("power_mult", 1.0))
	var critical: bool = rng.randi_range(1, 100) <= CombatRules.crit_chance(attacker.def.dexterity,
			crit_mod + int(extra.get("crit_bonus", 0)))
	if critical:
		base *= 1.5
	var armor: int = CombatRules.armor_against(target.def.armor, damage_type)
	var part_damage: int = maxi(1, roundi(base) - armor)
	var guarded: bool = target.guarded_part == part_id
	if guarded:
		part_damage = maxi(1, roundi(part_damage * 0.5))
	var organ: bool = false
	if kind == CombatTypes.PartKind.TORSO and type_def != null:
		var organ_chance: float = type_def.organ_chance + float(extra.get("organ_bonus", 0.0))
		organ = organ_chance > 0.0 and not guarded and rng.randf() < organ_chance
	var body_damage: int = roundi(part_damage * part.def.body_mult * (type_def.organ_body_mult if organ else 1.0))
	var integrity_hit: int = CombatRules.integrity_damage(part_damage, damage_type, part_id)
	var was_fallen: bool = target.fallen
	var previous_state: CombatTypes.PartState = part.state
	var overflow: int = part.take_damage(integrity_hit)

	var tags: String = ""
	if critical:
		tags += " ¡CRÍTICO!"
	if guarded:
		tags += " (cubierto)"
	logged.emit("%s: %s → %s. −%d Cuerpo.%s" % [attacker.display_name(), attack_name, where, body_damage, tags])
	if organ:
		logged.emit("Entra hondo: algo se rompe por dentro de %s." % target.display_name())

	var amputated: bool = false
	var cuts: bool = type_def != null and type_def.can_amputate and part.def.amputable
	# [PROPUESTA] Partes que se arrancan a golpes: solo si ya estaban Rotas.
	var tears: bool = damage_type == CombatTypes.DamageType.BLUNT and part.def.severable_by_blunt \
			and previous_state == CombatTypes.PartState.BROKEN
	if (cuts or tears) and not guarded and not part.is_amputated():
		var threshold: float = part.max_integrity * AMPUTATION_THRESHOLD
		var should_amputate: bool = false
		if previous_state == CombatTypes.PartState.BROKEN:
			should_amputate = integrity_hit >= threshold
		elif part.state == CombatTypes.PartState.BROKEN:
			should_amputate = overflow >= threshold or critical
		if should_amputate:
			if rng.randi_range(1, 100) <= mini(target.def.resilience * 2, MAX_AMPUTATION_RESIST):
				logged.emit("%s aguanta: %s no se desprende." % [target.display_name(), part.def.display_name.to_upper()])
			else:
				_amputate(target, part)
				amputated = true

	if critical and not amputated and not part.is_disabled():
		part.worsen()
		logged.emit("El crítico agrava la herida.")

	var broke_now: bool = false
	if not amputated and part.state != previous_state:
		logged.emit("%s: %s." % [where, CombatTypes.PART_STATE_NAMES[part.state]])
		if part.state == CombatTypes.PartState.BROKEN:
			broke_now = true
			info["broke"] = true
			impact.emit("FRACTURA.")
			if part.def.broken_text != "":
				logged.emit(_named(part.def.broken_text, target))
			if target.is_enemy:
				target.pending_reaction = true
	info["amputated"] = amputated
	info["critical"] = critical
	info["guarded"] = guarded
	info["part_damage"] = part_damage
	info["body_damage"] = body_damage
	info["organ"] = organ

	if target.dead:
		_release_grabs()
		if emit_info:
			struck.emit(info)
		return info

	# Efectos del tipo de daño según la parte.
	if part_id == CombatTypes.HEAD and broke_now:
		_stun(target)
	elif part_id == CombatTypes.HEAD and type_def != null and type_def.head_stun_chance > 0.0 \
			and rng.randf() < type_def.head_stun_chance:
		_stun(target)
	if kind == CombatTypes.PartKind.LEG and (broke_now or amputated) and type_def != null \
			and type_def.leg_break_knockdown > 0.0 and rng.randf() < type_def.leg_break_knockdown:
		info["knocked_down"] = _knock_down(target)

	var bleed_chance: float = type_def.bleed_chance if type_def != null else 0.0
	var torso_state: CombatTypes.PartState = target.part_state(CombatTypes.TORSO)
	if bleed_chance > 0.0 and (torso_state == CombatTypes.PartState.WOUNDED or torso_state == CombatTypes.PartState.BROKEN):
		bleed_chance += OPEN_TORSO_BLEED_CHANCE
	var bled: int = 0
	if not guarded and bleed_chance > 0.0 and rng.randf() < bleed_chance:
		bled += target.add_bleed(part_id, 1)
	if int(extra.get("extra_bleed", 0)) > 0:
		bled += target.add_bleed(part_id, int(extra["extra_bleed"]))
	if organ:
		bled += target.add_bleed(CombatTypes.TORSO, 1)
	if bled > 0:
		info["bled"] = bled
		logged.emit("%s empieza a sangrar (%s)." % [target.display_name(), part.def.display_name.to_lower()])
		bleeding_changed.emit(target, part_id, target.parts[part_id].bleeding)
		status_changed.emit(target)

	_lose_body(target, body_damage, was_fallen)
	_release_grabs()
	if emit_info:
		struck.emit(info)
	return info


# --- Habilidades -----------------------------------------------------------------

func _use_skill(action: CombatAction) -> void:
	var actor: Combatant = action.actor
	var skill: SkillDef = action.skill
	var reason: String = skill_block_reason(actor, skill)
	if reason != "":
		logged.emit("%s no puede: %s (%s)." % [actor.display_name(), skill.display_name.to_upper(), reason.to_lower()])
		return
	var grip: WeaponGrip = skill_grip(actor, skill)
	if skill.cost_body > 0:
		logged.emit("%s se fuerza (−%d Cuerpo)." % [actor.display_name(), skill.cost_body])
		_lose_body(actor, skill.cost_body, false)
	if skill.cost_mind > 0 and actor.def.has_mind:
		_change_mind(actor, -skill.cost_mind)
	if not actor.is_active():
		return
	if skill.cooldown > 0:
		actor.skill_cooldowns[skill.id] = skill.cooldown + 1
	if skill.use_text != "":
		logged.emit(_named(skill.use_text, actor))
	if skill.frees_self:
		var held: CombatStatusDef = actor.breakable_status()
		if held != null:
			_end_status(actor, held.id)
	if skill.target == SkillDef.Target.NONE:
		if skill.mind_gain > 0:
			_breathe(actor, skill.mind_gain + (actor.def.willpower if skill.adds_willpower else 0))
		return
	var target: Combatant = _redirect_target(actor, action.target)
	if target == null:
		return
	var target_reason: String = skill_target_reason(skill, target)
	if target_reason != "":
		logged.emit("%s: %s se pierde (%s)." % [actor.display_name(), skill.display_name.to_upper(), target_reason.to_lower()])
		return
	var spec: Dictionary = skill_spec(actor, skill, grip, target)
	var part_ids: Array[StringName] = skill_parts(skill, target, action.part_id)
	var hits: int = 0
	var hurt_before: bool = false
	var last_part: StringName = &""
	for part_id: StringName in part_ids:
		var id: StringName = _redirect_part(target, part_id)
		last_part = id
		if target.parts[id].state != CombatTypes.PartState.HEALTHY:
			hurt_before = true
		var info: Dictionary
		if skill.deals_damage:
			info = _strike(actor, target, id, skill.display_name.to_upper(), spec["power"], spec["accuracy"],
					spec["damage_type"], spec["crit_mod"], false, {"power_mult": spec["power_mult"],
					"crit_bonus": skill.crit_bonus, "extra_bleed": skill.extra_bleed, "organ_bonus": skill.organ_bonus,
					"skill": skill.id})
		else:
			info = _touch(actor, target, id, skill, spec["accuracy"])
		if info.get("hit", false):
			hits += 1
		if skill.inflicts_status != null and info.get("hit", false) and hits == 1 and part_ids.size() == 1:
			_skill_status(actor, target, skill, grip, hurt_before, 1.0, info)
		struck.emit(info)
		if target.dead or not target.is_present():
			return
	if skill.inflicts_status != null and part_ids.size() > 1 and hits > 0:
		var info: Dictionary = {"attacker": actor, "target": target, "part_id": last_part, "status": &""}
		_skill_status(actor, target, skill, grip, hurt_before, float(hits) / part_ids.size(), info)


## Poder, precisión, tipo y crítico de una habilidad con un arma (la vista previa usa lo mismo).
## Claves: power, accuracy, damage_type, crit_mod, power_mult.
func skill_spec(actor: Combatant, skill: SkillDef, grip: WeaponGrip, target: Combatant) -> Dictionary:
	var power: int = skill.power
	var accuracy: int = skill.accuracy
	var damage_type: CombatTypes.DamageType = skill.damage_type
	var crit_mod: int = 0
	var power_mult: float = skill.power_mult
	if skill.uses_weapon and grip != null:
		power = grip.weapon.power
		accuracy = grip.weapon.accuracy + grip.accuracy_mod
		damage_type = grip.weapon.damage_type
		crit_mod = grip.weapon.crit_mod
		power_mult *= grip.power_mult
	if skill.damage_type_override >= 0:
		damage_type = skill.damage_type_override as CombatTypes.DamageType
	accuracy += skill.accuracy_mod
	if skill.strength_contest and target != null:
		accuracy += CombatRules.STRENGTH_CONTEST_PER_POINT * (actor.def.strength - target.def.strength)
	if skill.grapple_accuracy_bonus > 0 and target != null and _grappling(actor, target):
		accuracy += skill.grapple_accuracy_bonus
	return {"power": power, "accuracy": accuracy, "damage_type": damage_type, "crit_mod": crit_mod,
		"power_mult": power_mult}


## Partes a las que va una habilidad.
func skill_parts(skill: SkillDef, target: Combatant, chosen: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	if skill.hits_all_parts:
		for id: StringName in skill.allowed_parts:
			if target.has_part(id) and not target.parts[id].is_amputated():
				result.append(id)
		if result.is_empty():
			result.append(CombatTypes.TORSO)
		return result
	if chosen != &"" and (skill.allowed_parts.is_empty() or skill.allowed_parts.has(chosen)):
		result.append(chosen)
	elif not skill.allowed_parts.is_empty():
		result.append(skill.allowed_parts[0])
	else:
		result.append(CombatTypes.TORSO)
	return result


## Uno de los dos sujeta al otro.
func _grappling(actor: Combatant, target: Combatant) -> bool:
	return _grab_holder.get(actor) == target or _grab_holder.get(target) == actor


## Contacto sin daño (empujón): tirada de acierto y nada más.
func _touch(actor: Combatant, target: Combatant, part_id: StringName, skill: SkillDef, accuracy: int) -> Dictionary:
	var part: BodyPartState = target.parts[part_id]
	var chance: int = CombatRules.hit_chance(actor, target, accuracy, part.def)
	var hit: bool = rng.randi_range(1, 100) <= chance
	logged.emit("%s: %s → %s. %s (%d%%)." % [actor.display_name(), skill.display_name.to_upper(),
			target.display_name(), "Acierta" if hit else "Falla", chance])
	return {"attacker": actor, "target": target, "part_id": part_id, "hit": hit, "chance": chance,
		"part_damage": 0, "body_damage": 0, "critical": false, "guarded": false, "broke": false, "amputated": false,
		"damage_type": skill.damage_type, "mind_damage": 0, "status": &"", "organ": false, "knocked_down": false,
		"bled": 0, "skill": skill.id}


## Tirada del estado de una habilidad (derribar, apartar, agarrar). `scale`: fracción de golpes que
## han entrado (barrido).
func _skill_status(actor: Combatant, target: Combatant, skill: SkillDef, grip: WeaponGrip, hurt_before: bool,
		scale: float, info: Dictionary) -> void:
	if not target.is_active():
		return
	var chance: float = (skill.status_chance + (skill.status_bonus_hurt_part if hurt_before else 0.0)) * scale
	if rng.randf() >= chance:
		return
	var hand: StringName = grip.hand if grip != null else actor.def.dominant_arm
	if _apply_status(target, skill.inflicts_status, actor, hand):
		info["status"] = skill.inflicts_status.id
		if skill.inflicts_status.id == CombatTypes.STATUS_DOWN:
			info["knocked_down"] = true
			impact.emit("AL SUELO.")


func _knock_down(target: Combatant) -> bool:
	var status: CombatStatusDef = CombatCatalog.status(CombatTypes.STATUS_DOWN)
	if status == null or target.has_status(CombatTypes.STATUS_DOWN) or not target.is_active():
		return false
	if _apply_status(target, status, null, &""):
		impact.emit("AL SUELO.")
		return true
	return false


# --- Objetos y tratamientos -------------------------------------------------------

## Trata una herida con un objeto: efectos por parte (TreatmentDef) y se gasta una unidad.
func _treat(action: CombatAction) -> void:
	var actor: Combatant = action.actor
	var treatment: TreatmentDef = action.treatment
	if not actor.can_use_items():
		logged.emit("%s no puede usar objetos sin brazos." % actor.display_name())
		return
	var target: Combatant = action.target if action.target != null and action.target.is_present() else actor
	if not _consume(action.item, treatment):
		logged.emit("%s busca %s, pero ya no le queda." % [actor.display_name(), treatment.display_name.to_lower()])
		return
	var effects: PackedStringArray = []
	var part_name: String = ""
	if treatment.needs_part() and target.has_part(action.part_id):
		var part: BodyPartState = target.parts[action.part_id]
		part_name = part.def.display_name.to_upper()
		var stopped: int = part.stop_bleed(treatment.stops_bleed)
		if stopped > 0:
			effects.append("−%d sangrado" % stopped)
		if treatment.seals_part:
			part.sealed = true
			part.bleeding = 0
		var previous: CombatTypes.PartState = part.state
		if part.restore(treatment.restores_integrity) > 0 and part.state != previous:
			effects.append(CombatTypes.PART_STATE_NAMES[part.state].to_lower())
		bleeding_changed.emit(target, action.part_id, part.bleeding)
	if treatment.body > 0:
		var healed: int = mini(target.def.body_max, target.body + treatment.body) - target.body
		target.body += healed
		if healed > 0:
			effects.append("+%d Cuerpo" % healed)
	if treatment.mind > 0 and target.def.has_mind:
		var before: int = target.mind
		target.change_mind(treatment.mind)
		effects.append("+%d Mente" % (target.mind - before))
	for id: StringName in treatment.removes_statuses:
		_end_status(target, id)
	if _is_contaminated(action.item) and treatment.contaminated_penalty > 0:
		_lose_body(target, treatment.contaminated_penalty, false)
		_change_mind(target, -treatment.contaminated_penalty)
		effects.append("−%d Cuerpo y Mente (sucio)" % treatment.contaminated_penalty)
	var text: String = "%s: %s." % [actor.display_name(), treatment.display_name]
	match treatment.use_text.count("%s"):
		1:
			text = treatment.use_text % actor.display_name()
		2:
			text = treatment.use_text % [actor.display_name(), part_name if part_name != "" else target.display_name()]
	logged.emit("%s%s" % [text, (" (%s)" % ", ".join(effects)) if not effects.is_empty() else ""])
	if _is_contaminated(action.item) and treatment.contaminated_text != "":
		logged.emit(treatment.contaminated_text)
	if treatment.applies_status != null:
		_apply_status(target, treatment.applies_status, null, &"")
	if target.fallen and target.body > 0 and not target.dead:
		target.fallen = false
		logged.emit("%s se levanta." % target.display_name())
	_refresh_terror(target)
	status_changed.emit(target)


## Gasta una unidad del objeto (inventario real o de prueba). false si no queda.
func _consume(item: Variant, treatment: TreatmentDef) -> bool:
	if item is Object and item_consumer.is_valid():
		item_consumer.call(item)
		return true
	var id: StringName = item_id(item)
	if id == &"":
		for candidate: StringName in treatment.item_ids:
			if supplies.get(candidate, 0) > 0:
				id = candidate
				break
	if supplies.get(id, 0) <= 0:
		return item is Object
	supplies[id] = supplies[id] - 1
	return true


func _is_contaminated(item: Variant) -> bool:
	return item is Object and bool((item as Object).get("contaminated"))


func _use_bandage(actor: Combatant, target: Combatant) -> void:
	if bandages <= 0:
		logged.emit("No quedan vendas.")
		return
	if not actor.can_use_items():
		logged.emit("%s no puede usar objetos sin brazos." % actor.display_name())
		return
	if target == null or not target.is_present():
		target = actor
	bandages -= 1
	var healed: int = mini(target.def.body_max, target.body + BANDAGE_HEAL) - target.body
	target.body += healed
	target.bleeding = 0
	logged.emit("%s venda a %s (+%d Cuerpo, deja de sangrar)." % [actor.display_name(), target.display_name(), healed])
	status_changed.emit(target)
	if target.fallen and target.body > 0:
		target.fallen = false
		logged.emit("%s se levanta." % target.display_name())


func _flee_solo(actor: Combatant) -> void:
	if not can_flee:
		logged.emit("No hay escapatoria.")
		return
	if not actor.can_flee():
		logged.emit("%s no puede huir: no puede andar." % actor.display_name())
		return
	var chance: int = flee_chance_solo(actor)
	if rng.randi_range(1, 100) > chance:
		logged.emit("%s intenta huir y no lo consigue (%d%%)." % [actor.display_name(), chance])
		return
	actor.fled = true
	logged.emit("%s huye del combate." % actor.display_name())
	impact.emit("HUIDA.")
	_witness(actor, 10, 5)


func _flee_all() -> void:
	if not can_flee:
		logged.emit("No hay escapatoria.")
		return
	var chance: int = flee_chance_all()
	if rng.randi_range(1, 100) > chance:
		logged.emit("El grupo intenta huir y no lo consigue (%d%%)." % chance)
		return
	for member: Combatant in party:
		if not member.is_present():
			continue
		if member.is_active() and member.can_flee():
			member.fled = true
		else:
			logged.emit("%s se queda atrás." % member.display_name())
	logged.emit("El grupo huye.")
	impact.emit("HUIDA.")


# --- Daño, muerte y Mente ------------------------------------------------------

func _lose_body(target: Combatant, amount: int, lethal_if_fallen: bool) -> void:
	if amount <= 0 or target.dead:
		return
	if target.fallen and lethal_if_fallen:
		_kill(target)
		return
	target.body = maxi(0, target.body - amount)
	if target.body > 0 or target.fallen:
		return
	if target.is_enemy:
		_kill(target)
		return
	target.fallen = true
	target.bleeding = 0
	logged.emit("%s cae al suelo." % target.display_name())
	impact.emit("CAÍDA.")
	_witness(target, 15, 15)


func _kill(target: Combatant) -> void:
	if target.dead:
		return
	target.dead = true
	target.fallen = true
	target.bleeding = 0
	logged.emit("%s muere." % target.display_name())
	impact.emit("MUERTE.")
	_witness(target, 15, 15)


func _amputate(target: Combatant, part: BodyPartState) -> void:
	part.amputate()
	logged.emit("%s pierde %s." % [target.display_name(), part.def.display_name.to_upper()])
	if part.def.amputated_text != "":
		logged.emit(_named(part.def.amputated_text, target))
	if part.def.vital:
		impact.emit("DECAPITACIÓN." if part.def.id == CombatTypes.HEAD else "MUTILACIÓN.")
		_kill(target)
		return
	impact.emit("AMPUTACIÓN.")
	if target.is_enemy:
		target.pending_reaction = true
	if part.add_bleed(AMPUTATION_BLEED) > 0:
		logged.emit("%s sangra a borbotones." % target.display_name())
		bleeding_changed.emit(target, part.def.id, part.bleeding)
	_change_mind(target, -20)
	_witness(target, 10, 5)
	_release_grabs()


func _stun(target: Combatant) -> void:
	var status: CombatStatusDef = CombatCatalog.status(CombatTypes.STATUS_STUN)
	if status != null:
		_apply_status(target, status, null, &"")
	logged.emit("%s queda sin reaccionar." % target.display_name())


## Los aliados de la víctima que lo ven pierden Mente (menos con VOL ≥ 12).
func _witness(victim: Combatant, amount: int, strong_willed_amount: int) -> void:
	var side: Array[Combatant] = enemies if victim.is_enemy else party
	var affected: bool = false
	for other: Combatant in side:
		if other == victim or not other.is_active() or not other.def.has_mind:
			continue
		_change_mind(other, -(strong_willed_amount if other.def.willpower >= 12 else amount))
		affected = true
	if affected:
		logged.emit("Verlo pesa en el resto (−%d Mente)." % amount)


func _change_mind(target: Combatant, delta: int) -> void:
	if target.change_mind(delta):
		logged.emit("%s se quiebra." % target.display_name())
		impact.emit("QUIEBRE.")
	_refresh_terror(target)


## Con la Mente por debajo del 25 %, Aterrado (puede quedarse paralizado); por encima, se le pasa.
func _refresh_terror(target: Combatant) -> void:
	if not target.def.has_mind:
		return
	var terrified: bool = not target.mind_broken and target.is_present() \
			and target.mind < target.def.mind_max * TERROR_THRESHOLD
	if terrified and not target.has_status(CombatTypes.STATUS_TERROR):
		var status: CombatStatusDef = CombatCatalog.status(CombatTypes.STATUS_TERROR)
		if status != null:
			_apply_status(target, status, null, &"")
	elif not terrified and target.has_status(CombatTypes.STATUS_TERROR):
		_end_status(target, CombatTypes.STATUS_TERROR)


# --- Fin de ronda y de combate ---------------------------------------------------

func _end_round() -> void:
	for combatant: Combatant in _everyone():
		if combatant.is_enemy:
			EnemyAI.tick_cooldowns(combatant)
		for id: StringName in combatant.skill_cooldowns.keys():
			combatant.skill_cooldowns[id] = combatant.skill_cooldowns[id] - 1
			if combatant.skill_cooldowns[id] <= 0:
				combatant.skill_cooldowns.erase(id)
		for id: StringName in combatant.statuses.keys():
			if id == CombatTypes.STATUS_TERROR:
				continue
			combatant.statuses[id] = combatant.statuses[id] - 1
			if combatant.statuses[id] <= 0:
				_end_status(combatant, id)
	for combatant: Combatant in _everyone():
		if combatant.dead or combatant.fled:
			continue
		_bleed_out(combatant)
		_wound_strain(combatant)
	_check_outcome()


## Pérdida de Cuerpo por el sangrado de cada parte y coagulación.
func _bleed_out(combatant: Combatant) -> void:
	var bleeding: Dictionary[StringName, int] = combatant.bleeding_parts()
	if bleeding.is_empty():
		return
	var loss: int = combatant.bleeding * BLEED_PER_STACK
	logged.emit("%s se desangra (−%d Cuerpo)." % [combatant.display_name(), loss])
	_lose_body(combatant, loss, false)
	if combatant.dead or combatant.fallen:
		return
	var clot: float = CLOT_BASE + CLOT_PER_RESILIENCE * combatant.def.resilience
	for id: StringName in bleeding:
		var part: BodyPartState = combatant.parts[id]
		var chance: float = clot
		match part.state:
			CombatTypes.PartState.BROKEN:
				chance *= 0.5
			CombatTypes.PartState.AMPUTATED:
				chance = 0.0
		if chance > 0.0 and rng.randf() < chance:
			part.stop_bleed(1)
			bleeding_changed.emit(combatant, id, part.bleeding)
	status_changed.emit(combatant)


## Heridas que pesan cada ronda (cabeza herida: Mente).
func _wound_strain(combatant: Combatant) -> void:
	if not combatant.def.has_mind or combatant.mind_broken or not combatant.is_active() or combatant.ignores_wounds():
		return
	var loss: int = 0
	for id: StringName in combatant.part_order:
		var part: BodyPartState = combatant.parts[id]
		match part.state:
			CombatTypes.PartState.WOUNDED:
				loss += part.def.round_mind_loss_wounded
			CombatTypes.PartState.BROKEN:
				loss += part.def.round_mind_loss_broken
	if loss > 0:
		logged.emit("A %s le zumba la cabeza (−%d Mente)." % [combatant.display_name(), loss])
		_change_mind(combatant, -loss)


func _check_outcome() -> void:
	if outcome != Outcome.ONGOING:
		return
	var hero: Combatant = protagonist()
	if hero.dead:
		_finish(Outcome.GAME_OVER, "FIN DE LA PARTIDA.")
		return
	var enemies_left: bool = false
	for enemy: Combatant in enemies:
		if enemy.is_active():
			enemies_left = true
	if not enemies_left:
		_finish(Outcome.VICTORY, "VICTORIA.")
		return
	var in_combat: Array[Combatant] = []
	var can_fight: bool = false
	for member: Combatant in party:
		if member.is_present():
			in_combat.append(member)
			if member.is_active():
				can_fight = true
	if in_combat.is_empty():
		_finish(Outcome.PARTY_FLED, "HUIDA.")
		return
	if not can_fight:
		if hero.fled:
			for member: Combatant in in_combat:
				_kill(member)
			_finish(Outcome.PROTAGONIST_ESCAPED, "SOLO QUEDAS TÚ.")
		else:
			_finish(Outcome.GAME_OVER, "FIN DE LA PARTIDA.")


func _finish(result: Outcome, title: String) -> void:
	outcome = result
	_grab_holder.clear()
	_grab_part.clear()
	_queue.clear()
	intents.clear()
	logged.emit(title)
	impact.emit(title)
	finished.emit(result, _summary())


func _summary() -> String:
	var lines: PackedStringArray = []
	for member: Combatant in party:
		var lost: PackedStringArray = []
		for id: StringName in member.part_order:
			if member.parts[id].is_amputated():
				lost.append(member.parts[id].def.display_name.to_upper())
		var state: String = "sigue con vida"
		if member.dead:
			state = "muerte"
		elif member.fallen:
			state = "en el suelo"
		elif member.fled:
			state = "ha huido"
		var line: String = "%s: %s." % [member.display_name(), state]
		if not lost.is_empty():
			line += " Pierde: %s." % ", ".join(lost)
		lines.append(line)
	return "\n".join(lines)


# --- Utilidades ----------------------------------------------------------------

func _redirect_target(attacker: Combatant, target: Combatant) -> Combatant:
	if target != null and target.is_present():
		return target
	var side: Array[Combatant] = party if attacker.is_enemy else enemies
	var options: Array[Combatant] = []
	for candidate: Combatant in side:
		if candidate.is_active():
			options.append(candidate)
	if options.is_empty():
		for candidate: Combatant in side:
			if candidate.is_present():
				options.append(candidate)
	if options.is_empty():
		return null
	var chosen: Combatant = options[rng.randi_range(0, options.size() - 1)]
	logged.emit("%s cambia de objetivo: %s." % [attacker.display_name(), chosen.display_name()])
	return chosen


func _redirect_part(target: Combatant, part_id: StringName) -> StringName:
	if part_id != &"" and target.has_part(part_id) and not target.parts[part_id].is_amputated():
		return part_id
	if target.has_part(CombatTypes.TORSO) and not target.parts[CombatTypes.TORSO].is_amputated():
		return CombatTypes.TORSO
	for id: StringName in target.part_order:
		if not target.parts[id].is_amputated():
			return id
	return target.part_order[0]


func _average_agility(side: Array[Combatant]) -> float:
	var total: float = 0.0
	var count: int = 0
	for combatant: Combatant in side:
		if combatant.is_active():
			total += combatant.effective_agility()
			count += 1
	return total / count if count > 0 else 0.0


func _part_name(combatant: Combatant, id: StringName) -> String:
	if not combatant.has_part(id):
		return String(id).to_upper()
	return combatant.parts[id].def.display_name.to_upper()


func _named(text: String, combatant: Combatant) -> String:
	return text % combatant.display_name() if text.contains("%s") else text


func _everyone() -> Array[Combatant]:
	var everyone: Array[Combatant] = []
	everyone.append_array(party)
	everyone.append_array(enemies)
	return everyone


func _sort_by_initiative(a: CombatAction, b: CombatAction) -> bool:
	if a.initiative != b.initiative:
		return a.initiative > b.initiative
	return not a.actor.is_enemy and b.actor.is_enemy
