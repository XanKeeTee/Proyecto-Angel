class_name CombatBridge
extends RefCounted
## Traslada el estado del mapa al combate y de vuelta (docs/design/sistemas/combate.md
## § Del mapa al combate). Sin nodos: se prueba en headless.
##
## Protagonista (CharacterState ↔ Combatant):
## - Cuerpo y Mente: los mismos números (Vitals.MAX = Cuerpo y Mente máximos del combate).
## - Sangrado: en el mapa es sí/no. Al entrar, sangrando = 1 acumulación; al salir, sangra si le
##   queda alguna.
## - Heridas: `Vitals.wounds` guarda el estado de cada parte que no está Sana. Al entrar, una parte
##   Herida empieza al 50 % de integridad y una Rota a 0; al salir, se guarda el estado de cada parte.
##   Las sanas recuperan su integridad entera fuera del combate (cuerpo-y-heridas.md).
## - Arma: la empuñada (`CharacterState.wielded()`); sin ninguna, Forcejear.
## - Objetos: los de la custodia que curan (HealEffect); se usan con sus efectos de siempre.
## Enemigo (Combatant ↔ diccionario del guardado): Cuerpo, sangrado y estado de cada parte, para
## que si el jugador huye vuelva con las mismas heridas.


## Crea el combate del encuentro con el protagonista tal y como está en el mapa.
static func build_battle(encounter: EncounterDef, character: CharacterState, enemy_state: Dictionary = {},
		seed_value: int = -1) -> Battle:
	var party_def: CombatantDef = encounter.party_base.duplicate()
	var held: ItemStack = character.wielded()
	party_def.weapon = held.def.weapon if held != null and held.def.weapon != null else null
	var party_defs: Array[CombatantDef] = [party_def]
	var enemy_defs: Array[CombatantDef] = [encounter.enemy]
	var battle: Battle = Battle.new(party_defs, enemy_defs, seed_value)
	battle.can_flee = encounter.can_flee
	from_vitals(battle.protagonist(), character.vitals)
	if not enemy_state.is_empty():
		apply_enemy_state(battle.enemies[0], enemy_state)
	battle.item_user = func(actor: Combatant, item: Variant) -> String:
		return use_item(actor, character, item as ItemStack)
	battle.bandages = 0
	return battle


## Vitals → combatiente.
static func from_vitals(member: Combatant, vitals: Vitals) -> void:
	member.body = clampi(vitals.body, 1, member.def.body_max)
	member.mind = clampi(vitals.mind, 0, member.def.mind_max)
	member.bleeding = 1 if vitals.bleeding else 0
	apply_wounds(member, vitals.wounds)


## Combatiente → Vitals (al terminar el combate sin morir).
static func to_vitals(member: Combatant, vitals: Vitals) -> void:
	vitals.body = clampi(member.body, 1, Vitals.MAX)
	vitals.mind = clampi(member.mind, 0, Vitals.MAX)
	vitals.bleeding = member.bleeding > 0
	vitals.wounds = wounds_of(member)
	vitals.changed.emit()


## Pone cada parte en el estado guardado (id → CombatTypes.PartState).
static func apply_wounds(member: Combatant, wounds: Dictionary) -> void:
	for key: Variant in wounds:
		var id: StringName = StringName(key)
		if not member.parts.has(id):
			continue
		var part: BodyPartState = member.parts[id]
		match int(wounds[key]):
			CombatTypes.PartState.WOUNDED:
				part.integrity = int(part.max_integrity / 2.0)
				part.state = CombatTypes.PartState.WOUNDED
			CombatTypes.PartState.BROKEN:
				part.integrity = 0
				part.state = CombatTypes.PartState.BROKEN
			CombatTypes.PartState.AMPUTATED:
				part.amputate()


## Estado de las partes que no están Sanas (id → CombatTypes.PartState).
static func wounds_of(member: Combatant) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for id: StringName in member.part_order:
		var state: CombatTypes.PartState = member.parts[id].state
		if state != CombatTypes.PartState.HEALTHY:
			result[id] = state
	return result


## Estado del enemigo para el guardado.
static func enemy_state(enemy: Combatant) -> Dictionary:
	var parts: Dictionary = {}
	for id: StringName in enemy.part_order:
		parts[String(id)] = [enemy.parts[id].state, enemy.parts[id].integrity]
	return {"body": enemy.body, "bleeding": enemy.bleeding, "parts": parts}


## Restaura un enemigo herido de un combate anterior.
static func apply_enemy_state(enemy: Combatant, state: Dictionary) -> void:
	enemy.body = clampi(int(state.get("body", enemy.body)), 1, enemy.def.body_max)
	enemy.bleeding = int(state.get("bleeding", 0))
	var parts: Dictionary = state.get("parts", {})
	for key: Variant in parts:
		var id: StringName = StringName(key)
		if not enemy.parts.has(id):
			continue
		var data: Array = parts[key]
		var part: BodyPartState = enemy.parts[id]
		part.state = int(data[0]) as CombatTypes.PartState
		part.integrity = clampi(int(data[1]), 0, part.max_integrity)


## Partes amputadas de un estado guardado (para dibujar el cuerpo que queda).
static func lost_parts(state: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	var parts: Dictionary = state.get("parts", {})
	for key: Variant in parts:
		if int((parts[key] as Array)[0]) == CombatTypes.PartState.AMPUTATED:
			result.append(StringName(key))
	return result


## Objetos de la custodia que sirven en combate: los que curan (vendas, analgésicos, sedante…).
static func combat_items(character: CharacterState) -> Array[ItemStack]:
	var result: Array[ItemStack] = []
	var seen: Array[ItemStack] = []
	for stack: ItemStack in character.custody.items:
		if stack == null or seen.has(stack) or not stack.def.usable:
			continue
		seen.append(stack)
		for effect: ItemEffect in stack.def.use_effects:
			if effect is HealEffect:
				result.append(stack)
				break
	return result


## Usa un objeto en combate con sus efectos normales: el combate se vuelca a Vitals, se aplica el
## objeto y se vuelve a leer. Devuelve el texto para el registro ("" = no ha servido).
static func use_item(actor: Combatant, character: CharacterState, stack: ItemStack) -> String:
	if stack == null or not character.custody.contains(stack):
		return ""
	if not actor.can_use_items():
		return "%s no puede usar objetos sin brazos." % actor.display_name()
	var wounds: Dictionary[StringName, int] = wounds_of(actor)
	to_vitals(actor, character.vitals)
	var text: String = character.use_item(stack)
	if text == "":
		return "%s: ahora no sirve de nada." % stack.def.display_name
	actor.body = clampi(character.vitals.body, 1, actor.def.body_max)
	actor.mind = clampi(character.vitals.mind, 0, actor.def.mind_max)
	if not character.vitals.bleeding:
		actor.bleeding = 0
	character.vitals.wounds = wounds
	return "%s usa %s. %s" % [actor.display_name(), stack.def.display_name.to_lower(), text if text != "·" else ""]
