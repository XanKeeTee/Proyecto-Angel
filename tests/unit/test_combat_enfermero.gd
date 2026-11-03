extends TestCase
## Combate: el enfermero transfigurado (IA, mutilaciones y sus efectos), estados y el puente
## mapa ↔ combate. Lógica pura, sin escena.

const NURSE: CombatantDef = preload("res://data/enemies/enfermero.tres")
const PATIENT: CombatantDef = preload("res://data/party/paciente_09.tres")
const PIPE: WeaponDef = preload("res://data/weapons/pipe.tres")
const SCALPEL: WeaponDef = preload("res://data/weapons/scalpel.tres")
const GRAB: CombatStatusDef = preload("res://data/statuses/agarre.tres")
const SEDATION: CombatStatusDef = preload("res://data/statuses/sedacion.tres")


func _battle(seed_value: int = 1, weapon: WeaponDef = PIPE) -> Battle:
	var party: CombatantDef = PATIENT.duplicate()
	party.weapon = weapon
	var party_defs: Array[CombatantDef] = [party]
	var enemy_defs: Array[CombatantDef] = [NURSE]
	return Battle.new(party_defs, enemy_defs, seed_value)


func _names(attacks: Array[EnemyAttackDef]) -> PackedStringArray:
	var result: PackedStringArray = []
	for attack: EnemyAttackDef in attacks:
		result.append(attack.display_name)
	return result


func _break(combatant: Combatant, id: StringName) -> void:
	var part: BodyPartState = combatant.parts[id]
	part.integrity = 0
	part.state = CombatTypes.PartState.BROKEN


func test_el_enfermero_tiene_cuerpo_y_ataques() -> void:
	var nurse: Combatant = Combatant.new(NURSE, true)
	for id: StringName in CombatTypes.HUMANOID_PARTS:
		check(nurse.has_part(id), "tiene " + String(id))
	check(nurse.parts[CombatTypes.HEAD].def.vital and nurse.parts[CombatTypes.HEAD].def.amputable, "decapitarlo lo mata")
	check(nurse.parts[CombatTypes.ARM_R].def.severable_by_blunt, "el brazo de instrumental se puede arrancar a golpes")
	check(not nurse.def.has_mind, "un transfigurado no entra en pánico")
	for attack: EnemyAttackDef in NURSE.attacks:
		check(attack.display_name != "", "ataque con nombre")
		check(attack.telegraph != "", "%s tiene aviso legible" % attack.display_name)
	var names: PackedStringArray = _names(NURSE.attacks)
	for expected: String in ["Tajo", "Agarrar", "Serrar", "Pinchazo", "Chillido"]:
		check(names.has(expected), "tiene " + expected)


func test_entero_corta_y_pincha() -> void:
	var battle: Battle = _battle()
	var names: PackedStringArray = _names(EnemyAI.available_attacks(battle.enemies[0], battle.party))
	check(names.has("Tajo") and names.has("Pinchazo") and names.has("Agarrar"), "de pie y entero: tajo, pinchazo y agarre")
	check(not names.has("Serrar"), "sin nadie agarrado no sierra")
	check(not names.has("Chillido"), "el chillido es solo una reacción")
	check(not names.has("Zarpazo"), "de pie no se arrastra")


func test_sin_brazo_de_instrumental_ya_no_corta() -> void:
	var battle: Battle = _battle()
	var nurse: Combatant = battle.enemies[0]
	_break(nurse, CombatTypes.ARM_R)
	battle.party[0].add_status(GRAB)
	var names: PackedStringArray = _names(EnemyAI.available_attacks(nurse, battle.party))
	check(not names.has("Tajo") and not names.has("Serrar"), "sin el brazo de instrumental no hay tajo ni serrado")
	check(names.has("Pinchazo") and names.has("Embestida"), "le quedan la jeringa y la embestida")
	nurse.parts[CombatTypes.ARM_R].amputate()
	check(not _names(EnemyAI.available_attacks(nurse, battle.party)).has("Tajo"), "amputado, igual")


func test_sin_brazo_de_la_jeringa_no_pincha_ni_agarra() -> void:
	var battle: Battle = _battle()
	var nurse: Combatant = battle.enemies[0]
	_break(nurse, CombatTypes.ARM_L)
	var names: PackedStringArray = _names(EnemyAI.available_attacks(nurse, battle.party))
	check(not names.has("Pinchazo") and not names.has("Agarrar"), "sin la mano izquierda no pincha ni agarra")
	check(names.has("Tajo"), "pero sigue cortando")


func test_sin_piernas_se_arrastra() -> void:
	var battle: Battle = _battle()
	var nurse: Combatant = battle.enemies[0]
	var hero: Combatant = battle.protagonist()
	var chance_before: int = battle.preview_hit_chance(hero, nurse, CombatTypes.TORSO)
	_break(nurse, CombatTypes.LEG_L)
	nurse.parts[CombatTypes.LEG_R].amputate()
	check(nurse.is_crawling(), "con las dos piernas inútiles se arrastra")
	check_eq(nurse.effective_agility(), 0.0, "arrastrándose no esquiva")
	check(battle.preview_hit_chance(hero, nurse, CombatTypes.TORSO) > chance_before, "es más fácil de golpear")
	check(battle.flee_chance_all() > CombatRules.flee_chance(hero.effective_agility(), NURSE.agility), "y más fácil huir")
	var names: PackedStringArray = _names(EnemyAI.available_attacks(nurse, battle.party))
	check(names.has("Zarpazo") and names.has("Agarrar el tobillo"), "va a por los tobillos")
	check(not names.has("Tajo") and not names.has("Embestida") and not names.has("Agarrar"), "ya no ataca de pie")
	check(nurse.status_text().contains("Se arrastra"), "se ve en su estado")
	for i: int in 20:
		var intent: CombatAction = EnemyAI.choose_intent(nurse, battle.party, battle.rng)
		if intent.attack.display_name == "Zarpazo":
			check(intent.part_id == CombatTypes.LEG_L or intent.part_id == CombatTypes.LEG_R, "el zarpazo va a las piernas")


func test_agarra_y_luego_sierra_al_agarrado() -> void:
	var battle: Battle = _battle(7)
	var nurse: Combatant = battle.enemies[0]
	var hero: Combatant = battle.protagonist()
	hero.add_status(GRAB)
	var saws: int = 0
	for i: int in 40:
		nurse.cooldowns.clear()
		var intent: CombatAction = EnemyAI.choose_intent(nurse, battle.party, battle.rng)
		if intent.attack.display_name == "Serrar":
			saws += 1
			check(intent.target == hero, "sierra al que tiene agarrado")
			check(intent.part_id == CombatTypes.ARM_L or intent.part_id == CombatTypes.ARM_R, "apunta a un brazo")
	check(saws > 20, "con alguien agarrado casi siempre sierra (%d/40)" % saws)


func test_el_agarre_impide_huir_y_se_rompe() -> void:
	var battle: Battle = _battle(3)
	var hero: Combatant = battle.protagonist()
	var nurse: Combatant = battle.enemies[0]
	var free_chance: int = battle.preview_hit_chance(nurse, hero, CombatTypes.TORSO)
	battle._apply_status(hero, GRAB, nurse, CombatTypes.ARM_L)
	check(not hero.can_flee(), "agarrado no puede huir")
	check(battle.preview_hit_chance(nurse, hero, CombatTypes.TORSO) > free_chance, "agarrado es más fácil de golpear")
	check(battle.grabbed_by(hero) == nurse, "se sabe quién sujeta")
	# Romperle la mano que sujeta lo suelta.
	_break(nurse, CombatTypes.ARM_L)
	battle._release_grabs()
	check(not hero.has_status(&"agarre"), "si se le rompe el brazo, suelta")
	# Zafarse: con suficientes intentos, se suelta.
	battle._apply_status(hero, GRAB, nurse, &"")
	var freed: bool = false
	for i: int in 20:
		battle._break_free(hero)
		if not hero.has_status(&"agarre"):
			freed = true
			break
	check(freed, "zafarse acaba soltando")
	check(battle.break_free_chance(hero) >= 15, "probabilidad de zafarse con suelo")


func test_el_agarre_y_la_sedacion_duran_lo_suyo() -> void:
	var battle: Battle = _battle(5)
	var hero: Combatant = battle.protagonist()
	battle.begin_round()
	battle._apply_status(hero, SEDATION, battle.enemies[0], &"")
	check(hero.effective_agility() < PATIENT.agility, "sedado, más lento")
	check(hero.accuracy_modifier() < 0, "sedado, falla más")
	battle.intents.clear()
	battle.start_resolution([])
	while battle.step():
		pass
	check(hero.has_status(&"sedacion"), "dura más de una ronda")
	battle.begin_round()
	battle.intents.clear()
	battle.start_resolution([])
	while battle.step():
		pass
	check(not hero.has_status(&"sedacion"), "y se pasa")


func test_reacciona_al_perder_una_parte() -> void:
	var battle: Battle = _battle()
	var nurse: Combatant = battle.enemies[0]
	nurse.pending_reaction = true
	var intent: CombatAction = EnemyAI.choose_intent(nurse, battle.party, battle.rng)
	check_eq(intent.attack.display_name, "Chillido", "tras perder una parte, chilla")
	check(not nurse.pending_reaction, "la reacción se gasta")
	nurse.pending_reaction = true
	nurse.parts[CombatTypes.HEAD].state = CombatTypes.PartState.BROKEN
	intent = EnemyAI.choose_intent(nurse, battle.party, battle.rng)
	check(intent.attack.display_name != "Chillido", "sin cabeza útil no chilla")


func test_romper_una_parte_avisa_a_la_ia() -> void:
	var found: bool = false
	for seed_value: int in 60:
		var battle: Battle = _battle(seed_value)
		var nurse: Combatant = battle.enemies[0]
		nurse.parts[CombatTypes.ARM_R].integrity = 1
		battle._strike(battle.protagonist(), nurse, CombatTypes.ARM_R, "TUBO", 12, 100, CombatTypes.DamageType.BLUNT, 0)
		if nurse.parts[CombatTypes.ARM_R].state == CombatTypes.PartState.BROKEN:
			found = true
			check(nurse.pending_reaction, "la IA sabe que ha perdido una parte")
			break
	check(found, "un golpe rompe el brazo casi roto")


func test_el_tubo_arranca_el_brazo_roto_pero_no_otra_parte() -> void:
	var torn: bool = false
	for seed_value: int in 80:
		var battle: Battle = _battle(seed_value)
		var nurse: Combatant = battle.enemies[0]
		_break(nurse, CombatTypes.ARM_R)
		_break(nurse, CombatTypes.LEG_L)
		var info: Dictionary = battle._strike(battle.protagonist(), nurse, CombatTypes.ARM_R, "TUBO", 12, 100,
				CombatTypes.DamageType.BLUNT, 0)
		battle._strike(battle.protagonist(), nurse, CombatTypes.LEG_L, "TUBO", 12, 100, CombatTypes.DamageType.BLUNT, 0)
		check(not nurse.parts[CombatTypes.LEG_L].is_amputated(), "el contundente no amputa una pierna")
		if nurse.parts[CombatTypes.ARM_R].is_amputated():
			torn = true
			check(info["amputated"], "el golpe lo cuenta como amputación")
			check(nurse.bleeding > 0, "y sangra")
	check(torn, "a golpes se arranca el brazo de instrumental ya roto")


func test_decapitarlo_lo_mata() -> void:
	var killed: bool = false
	for seed_value: int in 120:
		var battle: Battle = _battle(seed_value, SCALPEL)
		var nurse: Combatant = battle.enemies[0]
		_break(nurse, CombatTypes.HEAD)
		battle._strike(battle.protagonist(), nurse, CombatTypes.HEAD, "BISTURÍ", 30, 100, CombatTypes.DamageType.CUT, 0)
		if nurse.parts[CombatTypes.HEAD].is_amputated():
			killed = true
			check(nurse.dead, "sin cabeza, muere")
			battle._check_outcome()
			check_eq(battle.outcome, Battle.Outcome.VICTORY, "y se gana el combate")
			break
	check(killed, "con un corte se le puede decapitar")


func test_pinchazo_resta_mente() -> void:
	var hit: bool = false
	for seed_value: int in 60:
		var battle: Battle = _battle(seed_value)
		var nurse: Combatant = battle.enemies[0]
		var hero: Combatant = battle.protagonist()
		var action: CombatAction = CombatAction.new()
		action.type = CombatTypes.ActionType.ENEMY_ATTACK
		action.actor = nurse
		action.target = hero
		for attack: EnemyAttackDef in NURSE.attacks:
			if attack.display_name == "Pinchazo":
				action.attack = attack
		action.part_id = CombatTypes.TORSO
		var mind: int = hero.mind
		battle._enemy_attack(action)
		if hero.body < PATIENT.body_max:
			hit = true
			check(hero.mind < mind, "el pinchazo resta Mente")
			break
	check(hit, "el pinchazo acierta alguna vez")


func test_la_amputacion_propia_sangra_y_pesa() -> void:
	for seed_value: int in 100:
		var battle: Battle = _battle(seed_value)
		var hero: Combatant = battle.protagonist()
		_break(hero, CombatTypes.ARM_R)
		battle._strike(battle.enemies[0], hero, CombatTypes.ARM_R, "SERRAR", 20, 100, CombatTypes.DamageType.CUT, 0)
		if hero.parts[CombatTypes.ARM_R].is_amputated():
			check(hero.bleeding >= Battle.AMPUTATION_BLEED, "una amputación sangra")
			check(hero.mind < PATIENT.mind_max, "y resta Mente")
			check_eq(hero.current_weapon().display_name, "Forcejear", "sin el brazo del tubo, solo forcejea")
			return
	check(false, "el serrado acaba amputando un brazo roto")


func test_estimacion_de_dano() -> void:
	var battle: Battle = _battle()
	var nurse: Combatant = battle.enemies[0]
	var hero: Combatant = battle.protagonist()
	var torso: Dictionary = battle.preview_damage(hero, nurse, CombatTypes.TORSO)
	var head: Dictionary = battle.preview_damage(hero, nurse, CombatTypes.HEAD)
	var range_torso: Vector2i = torso["body"]
	var range_head: Vector2i = head["body"]
	check(range_torso.x > 0 and range_torso.y >= range_torso.x, "rango de daño al torso")
	check(range_head.x > range_torso.x, "la cabeza duele más")
	check(battle.preview_hit_chance(hero, nurse, CombatTypes.HEAD) < battle.preview_hit_chance(hero, nurse, CombatTypes.TORSO),
		"pero es más difícil de acertar")


func test_recarga_del_agarre() -> void:
	var battle: Battle = _battle(11)
	var nurse: Combatant = battle.enemies[0]
	var grab: EnemyAttackDef = null
	for attack: EnemyAttackDef in NURSE.attacks:
		if attack.display_name == "Agarrar":
			grab = attack
	nurse.cooldowns[grab] = grab.cooldown + 1
	check(not _names(EnemyAI.available_attacks(nurse, battle.party)).has("Agarrar"), "en recarga no agarra")
	for i: int in grab.cooldown + 1:
		EnemyAI.tick_cooldowns(nurse)
	check(_names(EnemyAI.available_attacks(nurse, battle.party)).has("Agarrar"), "tras la recarga vuelve a poder")


func test_un_combate_entero_termina() -> void:
	for seed_value: int in 30:
		var battle: Battle = _battle(seed_value)
		var hero: Combatant = battle.protagonist()
		while battle.outcome == Battle.Outcome.ONGOING and battle.round_number < 60:
			battle.begin_round()
			var order: CombatAction = CombatAction.new()
			order.type = CombatTypes.ActionType.ATTACK
			order.actor = hero
			order.target = battle.enemies[0]
			order.part_id = CombatTypes.TORSO
			var orders: Array[CombatAction] = []
			if hero.is_active():
				orders.append(order)
			battle.start_resolution(orders)
			while battle.step():
				pass
		check(battle.outcome != Battle.Outcome.ONGOING, "el combate %d termina" % seed_value)


# --- puente mapa ↔ combate ---------------------------------------------------------------------------

func test_del_mapa_al_combate_y_de_vuelta() -> void:
	var character: CharacterState = CharacterState.new()
	character.vitals.body = 61
	character.vitals.mind = 44
	character.vitals.bleeding = true
	character.vitals.wounds = {CombatTypes.ARM_L: CombatTypes.PartState.WOUNDED}
	var encounter: EncounterDef = preload("res://data/enemies/encuentro_enfermero.tres")
	var battle: Battle = CombatBridge.build_battle(encounter, character, {}, 3)
	var hero: Combatant = battle.protagonist()
	check_eq(hero.body, 61, "el Cuerpo pasa al combate")
	check_eq(hero.mind, 44, "la Mente pasa al combate")
	check_eq(hero.bleeding, 1, "el sangrado pasa al combate")
	check_eq(hero.parts[CombatTypes.ARM_L].state, CombatTypes.PartState.WOUNDED, "las heridas pasan al combate")
	check_eq(hero.parts[CombatTypes.ARM_L].integrity, 15, "una parte herida empieza a la mitad")
	check_eq(hero.current_weapon().display_name, "Forcejear", "sin nada empuñado, forcejea")
	hero.body = 30
	hero.mind = 12
	hero.bleeding = 0
	hero.parts[CombatTypes.ARM_R].amputate()
	CombatBridge.to_vitals(hero, character.vitals)
	check_eq(character.vitals.body, 30, "el Cuerpo vuelve al mapa")
	check_eq(character.vitals.mind, 12, "la Mente vuelve al mapa")
	check(not character.vitals.bleeding, "el sangrado vuelve al mapa")
	check_eq(int(character.vitals.wounds.get(CombatTypes.ARM_R, 0)), CombatTypes.PartState.AMPUTATED, "la amputación queda")
	check_eq(int(character.vitals.wounds.get(CombatTypes.ARM_L, 0)), CombatTypes.PartState.WOUNDED, "la herida queda")
	var restored: Vitals = Vitals.from_dict(JSON.parse_string(JSON.stringify(character.vitals.to_dict())))
	check_eq(int(restored.wounds.get(CombatTypes.ARM_R, 0)), CombatTypes.PartState.AMPUTATED, "las heridas se guardan")


func test_pelea_con_el_arma_empunada() -> void:
	var character: CharacterState = CharacterState.new()
	character.custody.add_item(Registry.item(&"tubo_metal"))
	character.wield(character.custody.find_first(&"tubo_metal"))
	var encounter: EncounterDef = preload("res://data/enemies/encuentro_enfermero.tres")
	var battle: Battle = CombatBridge.build_battle(encounter, character)
	check_eq(battle.protagonist().current_weapon().display_name, PIPE.display_name, "pelea con el tubo empuñado")
	check(battle.can_flee, "de este combate se puede huir")
	check(not battle.item_user.is_null(), "usa los objetos de la custodia")


func test_el_enemigo_herido_vuelve_igual() -> void:
	var battle: Battle = _battle()
	var nurse: Combatant = battle.enemies[0]
	nurse.body = 47
	_break(nurse, CombatTypes.ARM_R)
	nurse.parts[CombatTypes.LEG_L].amputate()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(CombatBridge.enemy_state(nurse)))
	var again: Battle = _battle()
	CombatBridge.apply_enemy_state(again.enemies[0], saved)
	check_eq(again.enemies[0].body, 47, "vuelve con el mismo Cuerpo")
	check_eq(again.enemies[0].part_state(CombatTypes.ARM_R), CombatTypes.PartState.BROKEN, "con el brazo roto")
	check_eq(again.enemies[0].part_state(CombatTypes.LEG_L), CombatTypes.PartState.AMPUTATED, "y sin la pierna")
	check(CombatBridge.lost_parts(saved).has(CombatTypes.LEG_L), "se sabe qué partes perdió")


func test_objetos_en_combate_con_sus_efectos() -> void:
	var character: CharacterState = CharacterState.new()
	character.custody.add_item(Registry.item(&"venda"), 1)
	character.custody.add_item(Registry.item(&"pilas"), 1)
	var items: Array[ItemStack] = CombatBridge.combat_items(character)
	check_eq(items.size(), 1, "solo los objetos que curan")
	var encounter: EncounterDef = preload("res://data/enemies/encuentro_enfermero.tres")
	var battle: Battle = CombatBridge.build_battle(encounter, character, {}, 2)
	var hero: Combatant = battle.protagonist()
	hero.bleeding = 2
	var text: String = battle.item_user.call(hero, items[0])
	check(text != "", "la venda se usa: " + text)
	check_eq(hero.bleeding, 0, "la venda corta el sangrado")
	check(not character.custody.has(&"venda"), "y se gasta")
