class_name Battle
extends RefCounted
## Lógica de un combate por rondas (docs/design/sistemas/combate.md).
## No depende de nodos: la escena solo la muestra, y se puede testear en headless.
##
## Uso: begin_round() → el jugador elige órdenes → start_resolution(órdenes)
## → llamar a step() hasta que devuelva false → begin_round() otra vez.

signal logged(text: String)
## Texto corto de impacto en mayúsculas ("AMPUTACIÓN.").
signal impact(text: String)
signal finished(outcome: Outcome, summary: String)
## Empieza a ejecutarse una acción (para animar al que actúa).
signal action_started(action: CombatAction)
## Resultado de un golpe, para la presentación. Claves: attacker, target, part_id, hit, chance,
## part_damage, body_damage, critical, guarded, broke, amputated, damage_type, mind_damage, status.
signal struck(info: Dictionary)
## Un estado se aplica o se termina.
signal status_changed(combatant: Combatant)

enum Outcome { ONGOING, VICTORY, PARTY_FLED, PROTAGONIST_ESCAPED, GAME_OVER }

const BANDAGE_HEAL: int = 20
const BLEED_PER_STACK: int = 3
const MAX_BLEED: int = 3
const BROKEN_TORSO_COST: int = 3
const BREATHE_BASE: int = 10
const AMPUTATION_THRESHOLD: float = 0.25
const MAX_AMPUTATION_RESIST: int = 40
## Sangrado que añade una amputación (sin pasar de MAX_BLEED). `[PROPUESTA]`
const AMPUTATION_BLEED: int = 2
## Zafarse: base y puntos por cada punto de FUE de diferencia con quien sujeta.
const BREAK_FREE_BASE: int = 45
const BREAK_FREE_PER_STRENGTH: int = 5

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
## Uso de objetos del inventario real: `func(actor: Combatant, item: Variant) -> String` (texto del
## registro; "" = no se ha podido). Si no se asigna, se usan las vendas de prototipo (`bandages`).
var item_user: Callable
## Agarres: víctima → quien la sujeta, y la parte con la que sujeta.
var _grab_holder: Dictionary[Combatant, Combatant] = {}
var _grab_part: Dictionary[Combatant, StringName] = {}

var _queue: Array[CombatAction] = []
var _resolving: bool = false


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


# --- Ronda -----------------------------------------------------------------

func begin_round() -> void:
	round_number += 1
	intents.clear()
	for combatant: Combatant in _everyone():
		combatant.guarded_part = &""
	for enemy: Combatant in enemies:
		if enemy.is_active():
			var intent: CombatAction = EnemyAI.choose_intent(enemy, party, rng)
			if intent != null:
				intents[enemy] = intent
	logged.emit("— RONDA %d —" % round_number)


## Prepara la resolución. Las guardias se aplican antes que nada.
func start_resolution(orders: Array[CombatAction]) -> void:
	_queue.clear()
	var pending: Array[CombatAction] = []
	for order: CombatAction in orders:
		if order.type == CombatTypes.ActionType.GUARD:
			order.actor.guarded_part = order.part_id
			logged.emit("%s se cubre: %s." % [order.actor.display_name(), _part_name(order.actor, order.part_id)])
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


## Ejecuta la siguiente acción. Devuelve false cuando la ronda ha terminado.
func step() -> bool:
	if not _resolving:
		return false
	while not _queue.is_empty() and outcome == Outcome.ONGOING:
		var action: CombatAction = _queue.pop_front()
		if not action.actor.is_active():
			continue
		_execute(action)
		_check_outcome()
		return true
	_resolving = false
	if outcome == Outcome.ONGOING:
		_end_round()
	return false


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


func preview_hit_chance(attacker: Combatant, target: Combatant, part_id: StringName) -> int:
	return CombatRules.hit_chance(attacker, target, attacker.current_weapon().accuracy, target.parts[part_id].def)


## Daño estimado (sin crítico) del arma actual sobre una parte: {"part": Vector2i(mín, máx),
## "body": Vector2i(mín, máx)} con el que pasa al Cuerpo.
func preview_damage(attacker: Combatant, target: Combatant, part_id: StringName) -> Dictionary:
	var weapon: WeaponDef = attacker.current_weapon()
	return CombatRules.damage_range(weapon.power, attacker.def.strength, target.def.armor, weapon.damage_type,
			target.parts[part_id].def)


## Probabilidad de zafarse de un agarre.
func break_free_chance(member: Combatant) -> int:
	var holder: Combatant = _grab_holder.get(member)
	var other: int = holder.def.strength if holder != null else member.def.strength
	return clampi(BREAK_FREE_BASE + BREAK_FREE_PER_STRENGTH * (member.def.strength - other), 15, 90)


## Quién sujeta a `member` (o null).
func grabbed_by(member: Combatant) -> Combatant:
	return _grab_holder.get(member)


func flee_chance_solo(member: Combatant) -> int:
	return CombatRules.flee_chance(member.effective_agility(), _average_agility(enemies))


func flee_chance_all() -> int:
	return CombatRules.flee_chance(_average_agility(party), _average_agility(enemies))


# --- Ejecución -----------------------------------------------------------------

func _execute(action: CombatAction) -> void:
	var actor: Combatant = action.actor
	if actor.stunned > 0:
		actor.stunned -= 1
		logged.emit("%s no reacciona (aturdimiento)." % actor.display_name())
		return
	if actor.is_panicking() and rng.randf() < 0.25:
		logged.emit("%s se queda paralizado por el pánico." % actor.display_name())
		return
	for id: StringName in actor.statuses:
		var status: CombatStatusDef = actor.status_defs[id]
		if status.skip_chance > 0.0 and rng.randf() < status.skip_chance:
			logged.emit("%s no consigue moverse (%s)." % [actor.display_name(), status.display_name.to_lower()])
			return
	if actor.part_state(CombatTypes.TORSO) == CombatTypes.PartState.BROKEN:
		logged.emit("Moverse le cuesta a %s (−%d Cuerpo)." % [actor.display_name(), BROKEN_TORSO_COST])
		_lose_body(actor, BROKEN_TORSO_COST, false)
		if not actor.is_active():
			return

	action_started.emit(action)
	match action.type:
		CombatTypes.ActionType.ATTACK:
			var weapon: WeaponDef = actor.current_weapon()
			_strike(actor, action.target, action.part_id, weapon.display_name, weapon.power,
					weapon.accuracy, weapon.damage_type, weapon.crit_mod)
		CombatTypes.ActionType.ENEMY_ATTACK:
			_enemy_attack(action)
		CombatTypes.ActionType.BREATHE:
			var gained: int = BREATHE_BASE + actor.def.willpower
			actor.change_mind(gained)
			logged.emit("%s respira hondo (+%d Mente)." % [actor.display_name(), gained])
		CombatTypes.ActionType.ITEM:
			if item_user.is_valid() and action.item != null:
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


func _enemy_attack(action: CombatAction) -> void:
	var actor: Combatant = action.actor
	var attack: EnemyAttackDef = action.attack
	if attack.required_part != &"" and actor.part_disabled(attack.required_part):
		logged.emit("%s ya no puede usar %s." % [actor.display_name(), attack.display_name.to_upper()])
		return
	if attack.requires_target_status != &"" and (action.target == null or not action.target.has_status(attack.requires_target_status)):
		logged.emit("%s busca a quien sujetaba, pero ya no lo tiene: %s se pierde." % [actor.display_name(),
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
				"amputated": false, "damage_type": attack.damage_type, "mind_damage": amount, "status": &""})
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
		_apply_status(target, attack.inflicts_status, actor, attack.required_part)
		info["status"] = attack.inflicts_status.id
	struck.emit(info)


func _mind_after_will(target: Combatant, amount: int) -> int:
	return maxi(0, amount - floori(target.def.willpower / 2.0))


func _apply_status(target: Combatant, status: CombatStatusDef, source: Combatant, source_part: StringName) -> void:
	var fresh: bool = target.add_status(status)
	if status.breakable and source != null:
		_grab_holder[target] = source
		_grab_part[target] = source_part
	if fresh and status.apply_text != "":
		logged.emit(_named(status.apply_text, target))
	status_changed.emit(target)


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
	status_changed.emit(target)


## Suelta a quien sujeta un enemigo que ya no puede sujetar (muerto, Caído o sin la parte con
## la que sujetaba).
func _release_grabs() -> void:
	for victim: Combatant in _grab_holder.keys():
		var holder: Combatant = _grab_holder[victim]
		var part: StringName = _grab_part.get(victim, &"")
		if holder.is_active() and not (part != &"" and holder.part_disabled(part)) and victim.is_present():
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
## `struck` aquí; los ataques enemigos la emiten ellos tras añadir Mente y estados.
func _strike(attacker: Combatant, target: Combatant, part_id: StringName, attack_name: String,
		power: int, accuracy: int, damage_type: CombatTypes.DamageType, crit_mod: int, emit_info: bool = true) -> Dictionary:
	var info: Dictionary = {"attacker": attacker, "target": target, "part_id": part_id, "hit": false, "chance": 0,
		"part_damage": 0, "body_damage": 0, "critical": false, "guarded": false, "broke": false, "amputated": false,
		"damage_type": damage_type, "mind_damage": 0, "status": &""}
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

	var base: float = CombatRules.roll_damage(power, attacker.def.strength, rng)
	var critical: bool = rng.randi_range(1, 100) <= CombatRules.crit_chance(attacker.def.dexterity, crit_mod)
	if critical:
		base *= 1.5
	var armor: int = target.def.armor
	if damage_type == CombatTypes.DamageType.PIERCE:
		armor = floori(armor / 2.0)
	var part_damage: int = maxi(1, roundi(base) - armor)
	var guarded: bool = target.guarded_part == part_id
	if guarded:
		part_damage = maxi(1, roundi(part_damage * 0.5))
	var body_damage: int = roundi(part_damage * part.def.body_mult)
	var was_fallen: bool = target.fallen
	var previous_state: CombatTypes.PartState = part.state
	var overflow: int = part.take_damage(part_damage)

	var tags: String = ""
	if critical:
		tags += " ¡CRÍTICO!"
	if guarded:
		tags += " (cubierto)"
	logged.emit("%s: %s → %s. −%d Cuerpo.%s" % [attacker.display_name(), attack_name, where, body_damage, tags])

	var amputated: bool = false
	var cuts: bool = damage_type == CombatTypes.DamageType.CUT and part.def.amputable
	# [PROPUESTA] Partes que se arrancan a golpes: solo si ya estaban Rotas.
	var tears: bool = damage_type == CombatTypes.DamageType.BLUNT and part.def.severable_by_blunt \
			and previous_state == CombatTypes.PartState.BROKEN
	if (cuts or tears) and not guarded and not part.is_amputated():
		var threshold: float = part.max_integrity * AMPUTATION_THRESHOLD
		var should_amputate: bool = false
		if previous_state == CombatTypes.PartState.BROKEN:
			should_amputate = part_damage >= threshold
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

	if not amputated and part.state != previous_state:
		logged.emit("%s: %s." % [where, CombatTypes.PART_STATE_NAMES[part.state]])
		if part.state == CombatTypes.PartState.BROKEN:
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

	if target.dead:
		_release_grabs()
		if emit_info:
			struck.emit(info)
		return info

	if part_id == CombatTypes.HEAD and part.state == CombatTypes.PartState.BROKEN \
			and previous_state != CombatTypes.PartState.BROKEN:
		_stun(target)
	elif part_id == CombatTypes.HEAD and damage_type == CombatTypes.DamageType.BLUNT and rng.randf() < 0.25:
		_stun(target)

	var bleed_chance: float = 0.0
	if damage_type == CombatTypes.DamageType.PIERCE:
		bleed_chance += 0.4
	var torso_state: CombatTypes.PartState = target.part_state(CombatTypes.TORSO)
	if torso_state == CombatTypes.PartState.WOUNDED or torso_state == CombatTypes.PartState.BROKEN:
		bleed_chance += 0.2
	if bleed_chance > 0.0 and target.bleeding < MAX_BLEED and rng.randf() < bleed_chance:
		target.bleeding += 1
		logged.emit("%s empieza a sangrar." % target.display_name())

	_lose_body(target, body_damage, was_fallen)
	_release_grabs()
	if emit_info:
		struck.emit(info)
	return info


func _named(text: String, combatant: Combatant) -> String:
	return text % combatant.display_name() if text.contains("%s") else text


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
	if target.bleeding < MAX_BLEED:
		target.bleeding = mini(MAX_BLEED, target.bleeding + AMPUTATION_BLEED)
		logged.emit("%s sangra a borbotones." % target.display_name())
	_change_mind(target, -20)
	_witness(target, 10, 5)


func _stun(target: Combatant) -> void:
	target.stunned = maxi(target.stunned, 1)
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


# --- Fin de ronda y de combate ---------------------------------------------------

func _end_round() -> void:
	for combatant: Combatant in _everyone():
		if combatant.is_enemy:
			EnemyAI.tick_cooldowns(combatant)
		for id: StringName in combatant.statuses.keys():
			combatant.statuses[id] = combatant.statuses[id] - 1
			if combatant.statuses[id] <= 0:
				_end_status(combatant, id)
	for combatant: Combatant in _everyone():
		if combatant.dead or combatant.fled or combatant.bleeding <= 0:
			continue
		var loss: int = combatant.bleeding * BLEED_PER_STACK
		logged.emit("%s se desangra (−%d Cuerpo)." % [combatant.display_name(), loss])
		_lose_body(combatant, loss, false)
		combatant.bleeding = maxi(0, combatant.bleeding - 1)
	_check_outcome()


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


func _everyone() -> Array[Combatant]:
	var everyone: Array[Combatant] = []
	everyone.append_array(party)
	everyone.append_array(enemies)
	return everyone


func _sort_by_initiative(a: CombatAction, b: CombatAction) -> bool:
	if a.initiative != b.initiative:
		return a.initiative > b.initiative
	return not a.actor.is_enemy and b.actor.is_enemy
