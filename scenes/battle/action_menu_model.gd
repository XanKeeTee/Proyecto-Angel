class_name ActionMenuModel
extends RefCounted
## Adaptador **provisional** de la API de opciones de acción (contrato P ↔ Q, ver
## docs/tech/interfaz-combate.md): construye `ActionOption`, `TargetOption`, `ActionPreview` y la
## `CombatAction` final a partir de la API que ya tiene `Battle` (`preview_hit_chance`,
## `preview_damage`, `flee_chance_*`…). La interfaz solo habla con este objeto.
##
## Cuando `Battle` tenga la API real (`action_menu`, `targets_for`, `preview`, `make_order`), cada
## método la usa directamente: al fusionar no hace falta tocar la interfaz.
##
## No decide reglas: solo traduce lo que `Battle` ya calcula a frases y números para enseñar.

const ATTACK: StringName = &"attack"
const SKILL: StringName = &"skill"
const GUARD: StringName = &"guard"
const ITEM: StringName = &"item"
const OTHER: StringName = &"other"
## Orden de las categorías en el menú principal.
const CATEGORIES: Array[StringName] = [ATTACK, SKILL, GUARD, ITEM, OTHER]
const CATEGORY_LABELS: Dictionary[StringName, String] = {
	ATTACK: "Atacar", SKILL: "Habilidades", GUARD: "Guardia", ITEM: "Objetos", OTHER: "Otras",
}
const CATEGORY_ICONS: Dictionary[StringName, StringName] = {
	ATTACK: &"attack", SKILL: &"skill", GUARD: &"guard", ITEM: &"item", OTHER: &"door",
}
## Umbral de amputación de las reglas (Battle.AMPUTATION_THRESHOLD), para estimar la probabilidad.
const STUN_HEAD_BLUNT: int = 25
const BLEED_PIERCE: int = 40

var battle: Battle
## Personaje del mapa (objetos de la custodia). Null en el prototipo: vendas genéricas.
var character: CharacterState
## Objetos ya elegidos por otros miembros esta ronda (no se ofrecen dos veces).
var reserved_items: Array = []
## Vendas genéricas ya reservadas esta ronda (prototipo sin custodia).
var reserved_bandages: int = 0


func _init(p_battle: Battle, p_character: CharacterState = null) -> void:
	battle = p_battle
	character = p_character


## Lo que puede hacer `actor` ahora mismo, agrupado por categoría (en el orden de CATEGORIES).
func action_menu(actor: Combatant) -> Array[ActionOption]:
	if battle.has_method(&"action_menu"):
		var real: Array[ActionOption] = []
		real.assign(battle.call(&"action_menu", actor))
		return real
	var options: Array[ActionOption] = []
	options.append(_attack_option(actor))
	options.append(_breathe_option(actor))
	options.append(_guard_option(actor))
	options.append_array(_item_options(actor))
	options.append_array(_other_options(actor))
	return options


## Para una opción con objetivo: los objetivos y, por cada uno, las partes elegibles.
func targets_for(actor: Combatant, option: ActionOption) -> Array[TargetOption]:
	if battle.has_method(&"targets_for"):
		var real: Array[TargetOption] = []
		real.assign(battle.call(&"targets_for", actor, option))
		return real
	var result: Array[TargetOption] = []
	match option.category:
		ATTACK:
			for enemy: Combatant in battle.enemies:
				if enemy.is_present():
					result.append(_target(actor, enemy, true))
		GUARD:
			result.append(_target(actor, actor, false))
		ITEM:
			for member: Combatant in battle.party:
				if member.is_present():
					result.append(_target(actor, member, false))
		_:
			result.append(_target(actor, actor, false))
	return result


## Vista previa completa antes de confirmar.
func preview(actor: Combatant, option: ActionOption, target: Combatant, part_id: StringName) -> ActionPreview:
	if battle.has_method(&"preview"):
		return battle.call(&"preview", actor, option, target, part_id) as ActionPreview
	var result: ActionPreview = ActionPreview.new()
	match option.id:
		&"attack":
			if target != null and target.has_part(part_id):
				_attack_preview(result, actor, target, part_id)
		&"guard":
			_guard_preview(result, actor, part_id)
		&"breathe":
			var gain: int = Battle.BREATHE_BASE + actor.def.willpower
			result.lines.append("+%d Mente (ahora %d de %d)." % [gain, actor.mind, actor.def.mind_max])
			result.lines.append("No ataca ni se cubre esta ronda.")
		&"break_free":
			result.hit_chance = battle.break_free_chance(actor)
			var holder: Combatant = battle.grabbed_by(actor)
			result.lines.append("Forcejea contra %s." % (holder.display_name() if holder != null else "quien le sujeta"))
			result.lines.append("Si sale bien, vuelve a poder huir.")
			result.risk_lines.append("Si falla, pierde la acción.")
		&"flee_all":
			result.hit_chance = battle.flee_chance_all()
			result.lines.append("Si sale bien, termina el combate para todos.")
			result.risk_lines.append("Si falla, se pierde la acción y el golpe llega igual.")
		&"flee_solo":
			result.hit_chance = battle.flee_chance_solo(actor)
			result.lines.append("Sale del combate; el resto sigue luchando.")
			result.risk_lines.append("Los que se quedan pierden Mente al verle irse.")
		_:
			if option.category == ITEM:
				_item_preview(result, actor, option, target)
	return result


## Convierte la elección en la orden que se resuelve.
func make_order(actor: Combatant, option: ActionOption, target: Combatant, part_id: StringName) -> CombatAction:
	if battle.has_method(&"make_order"):
		return battle.call(&"make_order", actor, option, target, part_id) as CombatAction
	var order: CombatAction = CombatAction.new()
	order.actor = actor
	order.target = target if target != null else actor
	order.part_id = part_id
	match option.id:
		&"attack":
			order.type = CombatTypes.ActionType.ATTACK
		&"guard":
			order.type = CombatTypes.ActionType.GUARD
			order.target = actor
		&"breathe":
			order.type = CombatTypes.ActionType.BREATHE
		&"break_free":
			order.type = CombatTypes.ActionType.BREAK_FREE
		&"flee_all":
			order.type = CombatTypes.ActionType.FLEE_ALL
		&"flee_solo":
			order.type = CombatTypes.ActionType.FLEE_SOLO
		_:
			order.type = CombatTypes.ActionType.ITEM
			order.item = option.item
	return order


## Reserva lo que gasta una orden ya elegida (objetos), para no ofrecerlo otra vez esta ronda.
func reserve(order: CombatAction) -> void:
	if order.type != CombatTypes.ActionType.ITEM:
		return
	if order.item != null:
		reserved_items.append(order.item)
	else:
		reserved_bandages += 1


## Deshace la reserva de una orden (al volver atrás).
func release(order: CombatAction) -> void:
	if order.type != CombatTypes.ActionType.ITEM:
		return
	if order.item != null:
		reserved_items.erase(order.item)
	else:
		reserved_bandages = maxi(0, reserved_bandages - 1)


## Se empieza una ronda nueva: no hay nada reservado.
func clear_reservations() -> void:
	reserved_items.clear()
	reserved_bandages = 0


## Opciones de una categoría.
static func of_category(options: Array[ActionOption], category: StringName) -> Array[ActionOption]:
	var result: Array[ActionOption] = []
	for option: ActionOption in options:
		if option.category == category:
			result.append(option)
	return result


# --- construcción de opciones ------------------------------------------------------------------

func _attack_option(actor: Combatant) -> ActionOption:
	var weapon: WeaponDef = actor.current_weapon()
	var option: ActionOption = ActionOption.new()
	option.id = &"attack"
	option.category = ATTACK
	option.label = weapon.display_name
	option.icon_key = weapon_icon_key(weapon)
	option.needs_target = true
	option.needs_part = true
	option.description = "%s. %s" % [_weapon_kind(weapon), _weapon_note(weapon)]
	if weapon == Combatant.unarmed_weapon() and actor.def.weapon != null:
		option.description += " Sin brazo útil para el arma, solo puede forcejear."
	var targets: bool = false
	for enemy: Combatant in battle.enemies:
		targets = targets or enemy.is_present()
	option.enabled = targets
	option.disabled_reason = "" if targets else "No queda nadie a quien golpear."
	return option


func _breathe_option(actor: Combatant) -> ActionOption:
	var option: ActionOption = ActionOption.new()
	option.id = &"breathe"
	option.category = SKILL
	option.label = "Respirar"
	option.icon_key = &"lungs"
	option.description = "Respira hondo y se obliga a mirar. Recupera Mente; ocupa la acción."
	option.enabled = actor.def.has_mind and actor.mind < actor.def.mind_max
	if not actor.def.has_mind:
		option.disabled_reason = "No tiene Mente que recuperar."
	elif actor.mind >= actor.def.mind_max:
		option.disabled_reason = "La Mente ya está entera."
	return option


func _guard_option(actor: Combatant) -> ActionOption:
	var option: ActionOption = ActionOption.new()
	option.id = &"guard"
	option.category = GUARD
	option.label = "Cubrirse"
	option.icon_key = &"guard"
	option.needs_part = true
	option.description = "Elige una parte propia: esta ronda recibe la mitad de daño y no se puede amputar."
	return option


func _item_options(actor: Combatant) -> Array[ActionOption]:
	var result: Array[ActionOption] = []
	var hands: bool = actor.can_use_items()
	if character != null:
		for stack: ItemStack in CombatBridge.combat_items(character):
			if reserved_items.has(stack):
				continue
			var option: ActionOption = ActionOption.new()
			option.id = StringName("item:" + String(stack.def.id))
			option.category = ITEM
			option.label = stack.def.display_name
			option.description = stack.def.description
			option.icon_key = item_icon_key(stack.def.id)
			option.item = stack
			option.quantity = stack.quantity
			option.enabled = hands
			option.disabled_reason = "" if hands else "Sin brazos útiles no puede usar objetos."
			result.append(option)
		return result
	var left: int = battle.bandages - reserved_bandages
	if left > 0:
		var option: ActionOption = ActionOption.new()
		option.id = &"item:venda"
		option.category = ITEM
		option.label = "Venda"
		option.description = "Tira de gasa limpia. Corta el sangrado y cierra algo la herida."
		option.icon_key = &"bandage"
		option.quantity = left
		option.needs_target = battle.party.size() > 1
		option.enabled = hands
		option.disabled_reason = "" if hands else "Sin brazos útiles no puede usar objetos."
		result.append(option)
	return result


func _other_options(actor: Combatant) -> Array[ActionOption]:
	var result: Array[ActionOption] = []
	if actor.breakable_status() != null:
		var free: ActionOption = ActionOption.new()
		free.id = &"break_free"
		free.category = OTHER
		free.label = "Zafarse"
		free.icon_key = &"break_free"
		free.description = "Forcejear para soltarse de quien le sujeta."
		result.append(free)
	var reason: String = _flee_block(actor)
	if battle.party.size() > 1:
		var solo: ActionOption = ActionOption.new()
		solo.id = &"flee_solo"
		solo.category = OTHER
		solo.label = "Huir solo"
		solo.icon_key = &"flee_solo"
		solo.description = "Escapar sin el resto del grupo."
		solo.enabled = reason == ""
		solo.disabled_reason = reason
		result.append(solo)
	var flee: ActionOption = ActionOption.new()
	flee.id = &"flee_all"
	flee.category = OTHER
	flee.label = "Huir"
	flee.icon_key = &"door"
	flee.description = "Dar la espalda y correr hacia la puerta, todos a la vez."
	flee.enabled = reason == ""
	flee.disabled_reason = reason
	result.append(flee)
	return result


func _flee_block(actor: Combatant) -> String:
	if not battle.can_flee:
		return "Este combate no tiene salida."
	if actor.effective_agility() <= 0.0:
		return "No puede andar: las dos piernas están inútiles."
	for id: StringName in actor.statuses:
		if actor.status_defs[id].blocks_flee:
			return "%s: no puede huir." % actor.status_defs[id].display_name
	return ""


func _target(actor: Combatant, target: Combatant, with_chance: bool) -> TargetOption:
	var result: TargetOption = TargetOption.new()
	result.combatant = target
	for id: StringName in target.part_order:
		var part: BodyPartState = target.parts[id]
		var option: PartOption = PartOption.new()
		option.id = id
		option.label = part.def.display_name
		option.state = part.state
		option.enabled = not part.is_amputated()
		option.disabled_reason = "" if option.enabled else "Ya no está."
		if with_chance and option.enabled:
			option.hit_chance = battle.preview_hit_chance(actor, target, id)
		result.parts.append(option)
	return result


# --- vistas previas --------------------------------------------------------------------------

func _attack_preview(result: ActionPreview, actor: Combatant, target: Combatant, part_id: StringName) -> void:
	var weapon: WeaponDef = actor.current_weapon()
	var part: BodyPartState = target.parts[part_id]
	result.hit_chance = battle.preview_hit_chance(actor, target, part_id)
	result.damage_type = weapon.damage_type
	var damage: Dictionary = battle.preview_damage(actor, target, part_id)
	var body: Vector2i = damage["body"]
	var part_range: Vector2i = damage["part"]
	result.damage_min = body.x
	result.damage_max = body.y
	var blunt: bool = weapon.damage_type == CombatTypes.DamageType.BLUNT
	var cuts: bool = weapon.damage_type == CombatTypes.DamageType.CUT and part.def.amputable
	var tears: bool = blunt and part.def.severable_by_blunt
	var threshold: float = part.max_integrity * Battle.AMPUTATION_THRESHOLD
	var resist: int = mini(target.def.resilience * 2, Battle.MAX_AMPUTATION_RESIST)
	match part.state:
		CombatTypes.PartState.HEALTHY, CombatTypes.PartState.WOUNDED:
			if part_range.y >= part.integrity:
				result.lines.append("Puede romperse con este golpe." if part_range.x < part.integrity
						else "Este golpe la rompe.")
			else:
				result.lines.append("Aguanta %d golpes así, más o menos." % ceili(float(part.integrity) / maxi(1, part_range.y)))
			if cuts:
				var over: float = _fraction_at_least(part_range, part.integrity + threshold)
				result.amputation_chance = roundi(over * (100 - resist))
		CombatTypes.PartState.BROKEN:
			if cuts or tears:
				var enough: float = _fraction_at_least(part_range, threshold)
				result.amputation_chance = roundi(enough * (100 - resist))
				result.lines.append("Está rota: se puede %s." % ("cortar" if cuts else "arrancar"))
			else:
				result.lines.append("Ya está rota: el golpe solo pasa al Cuerpo.")
	if result.amputation_chance > 0 and part.def.vital:
		result.lines.append("Si se desprende, muere.")
	var lost: PackedStringArray = []
	for attack: EnemyAttackDef in target.def.attacks:
		if attack.required_part == part_id and not attack.reaction and not lost.has(attack.display_name.to_upper()):
			lost.append(attack.display_name.to_upper())
	if not lost.is_empty() and not part.is_disabled():
		result.lines.append("Si se rompe: sin %s." % ", ".join(lost))
	if part_id == CombatTypes.TORSO and not part.is_disabled():
		result.lines.append("Si se rompe: cada acción le cuesta Cuerpo.")
	if part_id == CombatTypes.HEAD and blunt:
		result.status_chances[&"stun"] = STUN_HEAD_BLUNT
		result.lines.append("Puede aturdirle (%d %%)." % STUN_HEAD_BLUNT)
	if weapon.damage_type == CombatTypes.DamageType.PIERCE:
		result.status_chances[&"bleed"] = BLEED_PIERCE
		result.lines.append("Puede hacerle sangrar (%d %%)." % BLEED_PIERCE)
	if target.guarded_part == part_id:
		result.lines.append("La tiene cubierta: mitad de daño.")
	if actor.accuracy_modifier() < 0:
		result.risk_lines.append("Sus heridas y su Mente le restan %d de acierto." % -actor.accuracy_modifier())
	_threat_risk(result, actor, &"")


func _guard_preview(result: ActionPreview, actor: Combatant, part_id: StringName) -> void:
	if not actor.has_part(part_id):
		return
	var part: BodyPartState = actor.parts[part_id]
	result.lines.append("Esta ronda recibe la mitad de daño.")
	result.lines.append("No se puede amputar mientras la cubre.")
	if part.state != CombatTypes.PartState.HEALTHY:
		result.lines.append("Ahora: %s." % CombatTypes.PART_STATE_NAMES[part.state].to_lower())
	_threat_risk(result, actor, part_id)


func _item_preview(result: ActionPreview, actor: Combatant, option: ActionOption, target: Combatant) -> void:
	var who: Combatant = target if target != null else actor
	var stack: ItemStack = option.item as ItemStack
	if stack == null:
		var healed: int = mini(who.def.body_max, who.body + Battle.BANDAGE_HEAL) - who.body
		result.lines.append("+%d Cuerpo (ahora %d de %d)." % [healed, who.body, who.def.body_max])
		result.lines.append("Corta el sangrado." if who.bleeding > 0 else "No sangra: solo cierra la herida.")
	else:
		for effect: ItemEffect in stack.def.use_effects:
			var heal: HealEffect = effect as HealEffect
			if heal == null:
				continue
			if heal.body != 0:
				result.lines.append("%+d Cuerpo (ahora %d de %d)." % [heal.body, who.body, who.def.body_max])
			if heal.mind != 0:
				result.lines.append("%+d Mente (ahora %d de %d)." % [heal.mind, who.mind, who.def.mind_max])
			if heal.stops_bleeding:
				result.lines.append("Corta el sangrado." if who.bleeding > 0 else "Corta el sangrado (ahora no sangra).")
			if heal.requires_bleeding and who.bleeding <= 0:
				result.risk_lines.append("Solo sirve si sangra.")
		if stack.def.contaminated:
			result.risk_lines.append("Está sucio: puede infectar.")
		if option.quantity > 0:
			result.lines.append("Quedan ×%d." % option.quantity)


## Riesgo de lo que prepara el enemigo contra `actor` (y si la parte cubierta es la señalada).
func _threat_risk(result: ActionPreview, actor: Combatant, covered: StringName) -> void:
	if not battle.party_can_read_intents():
		return
	for enemy: Combatant in battle.enemies:
		var intent: CombatAction = battle.intents.get(enemy)
		if intent == null or intent.target != actor or intent.attack == null or not enemy.is_active():
			continue
		if intent.attack.visibility != CombatTypes.Visibility.FULL:
			continue
		var what: String = intent.attack.display_name.to_upper()
		if intent.part_id != &"" and actor.has_part(intent.part_id):
			var where: String = actor.parts[intent.part_id].def.display_name.to_lower()
			if covered == intent.part_id:
				result.lines.append("%s apunta aquí (%s): la cubre." % [enemy.display_name(), what])
			elif covered != &"":
				result.risk_lines.append("%s va a por el %s (%s), no aquí." % [enemy.display_name(), where, what])
			else:
				result.risk_lines.append("%s prepara %s → %s: no se cubre." % [enemy.display_name(), what, where])
		else:
			result.risk_lines.append("%s prepara %s contra él." % [enemy.display_name(), what])


## Fracción del intervalo de daño [x, y] que llega a `amount`.
static func _fraction_at_least(range_value: Vector2i, amount: float) -> float:
	if range_value.y < amount:
		return 0.0
	if range_value.x >= amount:
		return 1.0
	return float(range_value.y - ceili(amount) + 1) / float(range_value.y - range_value.x + 1)


# --- iconos y textos -----------------------------------------------------------------------------

## Clave del icono de un arma.
static func weapon_icon_key(weapon: WeaponDef) -> StringName:
	if weapon == null or weapon == Combatant.unarmed_weapon():
		return &"fist"
	match weapon.damage_type:
		CombatTypes.DamageType.CUT, CombatTypes.DamageType.PIERCE:
			return &"blade"
	return &"pipe"


## Clave del icono de un objeto por su id (vendas, pastillas, jeringas…).
static func item_icon_key(item_id: StringName) -> StringName:
	var id: String = String(item_id)
	if id.contains("venda") or id.contains("torniquete") or id.contains("tela"):
		return &"bandage"
	if id.contains("jeringa") or id.contains("sedante") or id.contains("ampolla"):
		return &"syringe"
	if id.contains("analges") or id.contains("pastill"):
		return &"pills"
	return &"item"


static func _weapon_kind(weapon: WeaponDef) -> String:
	match weapon.damage_type:
		CombatTypes.DamageType.CUT:
			return "Arma cortante"
		CombatTypes.DamageType.PIERCE:
			return "Arma punzante"
	return "Golpe contundente"


static func _weapon_note(weapon: WeaponDef) -> String:
	match weapon.damage_type:
		CombatTypes.DamageType.CUT:
			return "Puede amputar lo que ya está roto."
		CombatTypes.DamageType.PIERCE:
			return "Atraviesa la armadura y hace sangrar."
	return "Rompe huesos; en la cabeza, puede aturdir. No corta."
