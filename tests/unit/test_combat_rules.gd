extends TestCase
## Reglas de profundidad del combate: tipos de daño por parte, sangrado por parte, empuñar según
## las heridas, habilidades, estados, tratar heridas en combate, IA del enfermero y la API de
## opciones con su vista previa. Lógica pura, sin escena.

const NURSE: CombatantDef = preload("res://data/enemies/enfermero.tres")
const PATIENT: CombatantDef = preload("res://data/party/paciente_09.tres")
const PIPE: WeaponDef = preload("res://data/weapons/pipe.tres")
const SCALPEL: WeaponDef = preload("res://data/weapons/scalpel.tres")
const BAR: WeaponDef = preload("res://data/weapons/iron_bar.tres")
const AWL: WeaponDef = preload("res://data/weapons/awl.tres")
const GRAB: CombatStatusDef = preload("res://data/statuses/agarre.tres")
const DOWN: CombatStatusDef = preload("res://data/statuses/derribado.tres")
const SEDATION: CombatStatusDef = preload("res://data/statuses/sedacion.tres")
const ANALGESIA: CombatStatusDef = preload("res://data/statuses/analgesia.tres")


func _battle(seed_value: int = 1, weapon: WeaponDef = PIPE, offhand: WeaponDef = null) -> Battle:
	var party: CombatantDef = PATIENT.duplicate()
	party.weapon = weapon
	party.offhand_weapon = offhand
	var party_defs: Array[CombatantDef] = [party]
	var enemy_defs: Array[CombatantDef] = [NURSE]
	return Battle.new(party_defs, enemy_defs, seed_value)


func _break(combatant: Combatant, id: StringName) -> void:
	var part: BodyPartState = combatant.parts[id]
	part.integrity = 0
	part.state = CombatTypes.PartState.BROKEN


func _wound(combatant: Combatant, id: StringName) -> void:
	var part: BodyPartState = combatant.parts[id]
	part.integrity = int(part.max_integrity / 2.0)
	part.state = CombatTypes.PartState.WOUNDED


func _option(battle: Battle, actor: Combatant, id: StringName) -> ActionOption:
	for option: ActionOption in battle.action_menu(actor):
		if option.id == id:
			return option
	return null


func _ids(battle: Battle, actor: Combatant) -> Array[StringName]:
	var result: Array[StringName] = []
	for option: ActionOption in battle.action_menu(actor):
		result.append(option.id)
	return result


func _skill_order(battle: Battle, id: StringName, part_id: StringName = &"") -> CombatAction:
	var hero: Combatant = battle.protagonist()
	var option: ActionOption = _option(battle, hero, id)
	return battle.make_order(hero, option, battle.enemies[0], part_id)


func _attack_named(name: String) -> EnemyAttackDef:
	for attack: EnemyAttackDef in NURSE.attacks:
		if attack.display_name == name:
			return attack
	return null


# --- tipos de daño ----------------------------------------------------------------------------------

func test_cada_tipo_de_dano_hace_lo_suyo_en_cada_parte() -> void:
	check(CombatRules.integrity_damage(10, CombatTypes.DamageType.BLUNT, CombatTypes.LEG_L) > 10,
		"el contundente rompe antes el hueso de una pierna")
	check(CombatRules.integrity_damage(10, CombatTypes.DamageType.PIERCE, CombatTypes.ARM_L) < 10,
		"el punzante apenas rompe un brazo")
	check_eq(CombatRules.armor_against(4, CombatTypes.DamageType.PIERCE), 2, "el punzante atraviesa media armadura")
	check_eq(CombatRules.armor_against(4, CombatTypes.DamageType.BLUNT), 4, "el contundente no")
	var cut_bled: int = 0
	var blunt_bled: int = 0
	var pierce_organ: int = 0
	for seed_value: int in 80:
		var battle: Battle = _battle(seed_value)
		var nurse: Combatant = battle.enemies[0]
		var hero: Combatant = battle.protagonist()
		battle._strike(hero, nurse, CombatTypes.LEG_L, "CORTE", 6, 100, CombatTypes.DamageType.CUT, 0)
		if nurse.parts[CombatTypes.LEG_L].bleeding > 0:
			cut_bled += 1
		battle._strike(hero, nurse, CombatTypes.ARM_L, "GOLPE", 6, 100, CombatTypes.DamageType.BLUNT, 0)
		if nurse.parts[CombatTypes.ARM_L].bleeding > 0:
			blunt_bled += 1
		var info: Dictionary = battle._strike(hero, nurse, CombatTypes.TORSO, "PUNZÓN", 6, 100,
				CombatTypes.DamageType.PIERCE, 0)
		if info["organ"]:
			pierce_organ += 1
			check(nurse.parts[CombatTypes.TORSO].bleeding > 0, "un órgano alcanzado sangra")
	check(cut_bled > 10, "el cortante hace sangrar la parte (%d/80)" % cut_bled)
	check_eq(blunt_bled, 0, "el contundente no hace sangrar")
	check(pierce_organ > 5, "el punzante alcanza órganos en el torso (%d/80)" % pierce_organ)


func test_contundente_en_la_cabeza_aturde_y_en_la_pierna_derriba() -> void:
	var stunned: bool = false
	var downed: bool = false
	for seed_value: int in 80:
		var battle: Battle = _battle(seed_value)
		var nurse: Combatant = battle.enemies[0]
		battle._strike(battle.protagonist(), nurse, CombatTypes.HEAD, "TUBO", 3, 100, CombatTypes.DamageType.BLUNT, 0)
		stunned = stunned or nurse.has_status(CombatTypes.STATUS_STUN)
		nurse.parts[CombatTypes.LEG_R].integrity = 1
		var info: Dictionary = battle._strike(battle.protagonist(), nurse, CombatTypes.LEG_R, "TUBO", 12, 100,
				CombatTypes.DamageType.BLUNT, 0)
		if info["knocked_down"]:
			downed = true
			check(nurse.has_status(CombatTypes.STATUS_DOWN) and nurse.is_down(), "romper la pierna lo tira al suelo")
	check(stunned, "un golpe contundente en la cabeza puede aturdir")
	check(downed, "romper una pierna a golpes puede derribar")


# --- sangrado por parte ------------------------------------------------------------------------------

func test_el_sangrado_va_por_partes_y_un_munon_no_coagula() -> void:
	var battle: Battle = _battle(4)
	var hero: Combatant = battle.protagonist()
	hero.add_bleed(CombatTypes.ARM_L, 2)
	hero.add_bleed(CombatTypes.LEG_R, 1)
	check_eq(hero.bleeding, 3, "el total suma las partes")
	check_eq(hero.bleeding_parts().size(), 2, "dos partes sangran")
	var body: int = hero.body
	battle._bleed_out(hero)
	check_eq(hero.body, body - 3 * Battle.BLEED_PER_STACK, "cada acumulación resta Cuerpo al final de la ronda")
	hero.bleeding = 0
	check_eq(hero.bleeding, 0, "asignar 0 lo corta todo")
	hero.parts[CombatTypes.ARM_R].amputate()
	hero.parts[CombatTypes.ARM_R].add_bleed(2)
	for i: int in 8:
		hero.body = 100
		battle._bleed_out(hero)
	check_eq(hero.parts[CombatTypes.ARM_R].bleeding, 2, "un muñón no deja de sangrar sin tratarlo")
	hero.add_bleed(CombatTypes.LEG_L, 1)
	for i: int in 12:
		hero.body = 100
		battle._bleed_out(hero)
	check_eq(hero.parts[CombatTypes.LEG_L].bleeding, 0, "una herida pequeña acaba coagulando")
	var entries: Array[Dictionary] = hero.status_entries()
	var shown: bool = false
	for entry: Dictionary in entries:
		if entry["id"] == CombatTypes.STATUS_BLEED and entry["part_id"] == CombatTypes.ARM_R:
			shown = true
	check(shown, "la interfaz ve el sangrado de cada parte")


# --- mutilaciones del protagonista ---------------------------------------------------------------------

func test_brazo_roto_pasa_el_arma_a_la_otra_mano() -> void:
	var battle: Battle = _battle()
	var hero: Combatant = battle.protagonist()
	var healthy: Dictionary = battle.preview_damage(hero, battle.enemies[0], CombatTypes.TORSO)
	_wound(hero, hero.def.dominant_arm)
	var grip: WeaponGrip = hero.grip()
	check(grip.accuracy_mod < 0 and grip.power_mult < 1.0, "con el brazo herido pega peor")
	_break(hero, hero.def.dominant_arm)
	grip = hero.grip()
	check_eq(grip.weapon, PIPE, "con el brazo roto sigue con el tubo…")
	check_eq(grip.hand, hero.off_arm(), "…en la otra mano")
	check_eq(grip.accuracy_mod, Combatant.CLUMSY_HAND_ACCURACY, "mano torpe: falla más")
	var clumsy: Dictionary = battle.preview_damage(hero, battle.enemies[0], CombatTypes.TORSO)
	check((clumsy["body"] as Vector2i).y < (healthy["body"] as Vector2i).y, "y hace menos daño")
	hero.parts[hero.def.dominant_arm].amputate()
	check(hero.grip().unarmed, "si pierde el brazo, el arma se cae: forcejea")


func test_dos_manos_y_mano_izquierda() -> void:
	var battle: Battle = _battle(1, BAR)
	var hero: Combatant = battle.protagonist()
	check_eq(hero.current_weapon(), BAR, "la barra con los dos brazos")
	_break(hero, hero.off_arm())
	check(hero.grip().unarmed, "con un brazo roto no puede con un arma de dos manos")
	var dual: Battle = _battle(1, PIPE, SCALPEL)
	var other: Combatant = dual.protagonist()
	var attacks: int = 0
	for option: ActionOption in dual.action_menu(other):
		if option.category == BattleMenu.CATEGORY_ATTACK:
			attacks += 1
	check_eq(attacks, 2, "con un arma en cada mano, dos formas de atacar")
	check(_option(dual, other, &"attack_offhand").use_offhand, "una con la izquierda")
	_break(other, other.def.dominant_arm)
	check_eq(other.current_weapon(), SCALPEL, "con el brazo bueno roto, pelea con el bisturí de la izquierda")


func test_pierna_rota_cuesta_huir_y_cabeza_herida_resta_mente() -> void:
	var battle: Battle = _battle()
	var hero: Combatant = battle.protagonist()
	var before: int = battle.flee_chance_all()
	_break(hero, CombatTypes.LEG_L)
	check(battle.flee_chance_all() <= before - Combatant.FLEE_DISABLED_LEG, "con una pierna rota, huir es mucho peor")
	check(hero.effective_agility() < PATIENT.agility, "y esquiva menos")
	_wound(hero, CombatTypes.HEAD)
	check(hero.accuracy_modifier() <= -10, "la cabeza herida resta acierto")
	var mind: int = hero.mind
	battle._wound_strain(hero)
	check(hero.mind < mind, "y Mente cada ronda")
	hero.add_status(ANALGESIA)
	mind = hero.mind
	battle._wound_strain(hero)
	check_eq(hero.mind, mind, "con analgésicos la cabeza no zumba")
	check(hero.accuracy_modifier() > -10, "ni resta acierto")


# --- habilidades -------------------------------------------------------------------------------------

func test_las_habilidades_dependen_del_arma() -> void:
	var with_pipe: Battle = _battle(1, PIPE)
	var ids: Array[StringName] = _ids(with_pipe, with_pipe.protagonist())
	for id: StringName in [&"golpe_rodilla", &"barrido", &"empujon", &"rematar", &"forcejear", &"morder", &"respirar"]:
		check(ids.has(id), "con el tubo: " + String(id))
	check(not ids.has(&"clavar"), "con el tubo no se clava")
	check(not _option(with_pipe, with_pipe.protagonist(), &"rematar").enabled, "rematar solo si está en el suelo")
	var with_scalpel: Battle = _battle(1, SCALPEL)
	ids = _ids(with_scalpel, with_scalpel.protagonist())
	check(ids.has(&"clavar") and ids.has(&"forcejear") and ids.has(&"morder"), "con el bisturí: clavar, forcejear, morder")
	check(not ids.has(&"golpe_rodilla") and not ids.has(&"barrido") and not ids.has(&"empujon"), "sin técnicas de arma larga")
	var with_bar: Battle = _battle(1, BAR)
	ids = _ids(with_bar, with_bar.protagonist())
	check(ids.has(&"barrido") and not ids.has(&"forcejear"), "con la barra a dos manos no hay mano libre")
	var bare: Battle = _battle(1, null)
	ids = _ids(bare, bare.protagonist())
	check(ids.has(&"forcejear") and ids.has(&"morder") and not ids.has(&"golpe_rodilla"), "sin arma: forcejear y morder")
	var respirar: ActionOption = _option(bare, bare.protagonist(), &"respirar")
	check(respirar.enabled and not respirar.needs_target, "respirar no necesita objetivo")


func test_las_heridas_bloquean_habilidades_con_su_motivo() -> void:
	var battle: Battle = _battle()
	var hero: Combatant = battle.protagonist()
	_break(hero, hero.off_arm())
	var push: ActionOption = _option(battle, hero, &"empujon")
	check(not push.enabled and push.disabled_reason.contains("dos brazos"), "empujar pide los dos brazos: " + push.disabled_reason)
	_break(hero, CombatTypes.HEAD)
	var bite: ActionOption = _option(battle, hero, &"morder")
	check(not bite.enabled, "con la cabeza rota no muerde")
	hero.mind = 3
	check(not _option(battle, hero, &"rematar").enabled, "sin Mente no hay remate")


func test_golpe_a_la_rodilla_derriba_y_luego_se_remata() -> void:
	var downed: Battle = null
	for seed_value: int in 120:
		var battle: Battle = _battle(seed_value)
		_wound(battle.enemies[0], CombatTypes.LEG_L)
		var order: CombatAction = _skill_order(battle, &"golpe_rodilla", CombatTypes.LEG_L)
		var body: int = battle.protagonist().body
		battle._execute(order)
		check_eq(battle.protagonist().body, body - order.skill.cost_body, "cuesta Cuerpo")
		check(battle.protagonist().skill_cooldowns.has(&"golpe_rodilla"), "tiene recarga")
		if battle.enemies[0].has_status(CombatTypes.STATUS_DOWN):
			downed = battle
			break
	check(downed != null, "el golpe a la rodilla acaba derribando")
	if downed == null:
		return
	var hero: Combatant = downed.protagonist()
	var nurse: Combatant = downed.enemies[0]
	var finish: ActionOption = _option(downed, hero, &"rematar")
	check(finish.enabled, "derribado, se le puede rematar")
	var targets: Array[TargetOption] = downed.targets_for(hero, finish)
	var parts: Array[StringName] = []
	for part: PartOption in targets[0].parts:
		if part.enabled:
			parts.append(part.id)
	check(parts.has(CombatTypes.HEAD) and parts.has(CombatTypes.TORSO) and parts.size() == 2, "rematar: cabeza o torso")
	var mind: int = hero.mind
	var body: int = nurse.body
	downed._execute(downed.make_order(hero, finish, nurse, CombatTypes.HEAD))
	check(hero.mind < mind, "rematar cuesta Mente")
	check(nurse.body < body or nurse.dead or nurse.body == body, "el remate se resuelve")


func test_empujon_suelta_y_hace_perder_el_golpe() -> void:
	var pushed: bool = false
	for seed_value: int in 40:
		var battle: Battle = _battle(seed_value)
		var hero: Combatant = battle.protagonist()
		var nurse: Combatant = battle.enemies[0]
		battle._apply_status(hero, GRAB, nurse, CombatTypes.ARM_L)
		battle._execute(_skill_order(battle, &"empujon"))
		if not nurse.has_status(CombatTypes.STATUS_PUSHED):
			continue
		pushed = true
		check(not hero.has_status(&"agarre"), "apartarlo te suelta")
		check(nurse.pending_skip() != null, "pierde su siguiente acción")
		var intent: CombatAction = CombatAction.new()
		intent.type = CombatTypes.ActionType.ENEMY_ATTACK
		intent.actor = nurse
		intent.target = hero
		intent.attack = _attack_named("Tajo")
		intent.part_id = CombatTypes.TORSO
		var body: int = hero.body
		battle._execute(intent)
		check_eq(hero.body, body, "el tajo que preparaba se pierde")
		check(nurse.pending_skip() == null, "y solo una vez")
		break
	check(pushed, "el empujón entra")


func test_forcejear_morder_y_clavar() -> void:
	var held: bool = false
	for seed_value: int in 40:
		var battle: Battle = _battle(seed_value, SCALPEL)
		var hero: Combatant = battle.protagonist()
		var nurse: Combatant = battle.enemies[0]
		battle._apply_status(hero, GRAB, nurse, CombatTypes.ARM_L)
		battle._execute(_skill_order(battle, &"forcejear", CombatTypes.ARM_L))
		if nurse.has_status(&"agarre"):
			held = true
			check(not hero.has_status(&"agarre"), "forcejear le da la vuelta al agarre")
			check(battle.grabbed_by(nurse) == hero, "ahora le sujetas tú")
			var bite: ActionOption = _option(battle, hero, &"morder")
			var loose: ActionOption = _option(_battle(seed_value), _battle(seed_value).protagonist(), &"morder")
			var close: int = battle.targets_for(hero, bite)[0].parts[1].hit_chance
			var far_battle: Battle = _battle(seed_value)
			var far: int = far_battle.targets_for(far_battle.protagonist(), loose)[0].parts[1].hit_chance
			check(close > far, "cuerpo a cuerpo se muerde mejor (%d > %d)" % [close, far])
			break
	check(held, "forcejear acaba sujetándole")
	var stabbed: bool = false
	for seed_value: int in 40:
		var battle: Battle = _battle(seed_value, AWL)
		battle._execute(_skill_order(battle, &"clavar", CombatTypes.TORSO))
		if battle.enemies[0].parts[CombatTypes.TORSO].bleeding > 0:
			stabbed = true
			break
	check(stabbed, "clavar hace sangrar")


func test_respirar_como_habilidad() -> void:
	var battle: Battle = _battle()
	var hero: Combatant = battle.protagonist()
	hero.mind = 30
	battle._execute(_skill_order(battle, &"respirar"))
	check_eq(hero.mind, 30 + Battle.BREATHE_BASE + PATIENT.willpower, "respirar recupera 10 + VOL")


# --- estados -------------------------------------------------------------------------------------------

func test_derribado_pierde_la_accion_en_levantarse() -> void:
	var battle: Battle = _battle(2)
	var hero: Combatant = battle.protagonist()
	battle.begin_round()
	battle._apply_status(hero, DOWN, null, &"")
	var menu: Array[ActionOption] = battle.action_menu(hero)
	check_eq(menu[0].id, &"recover", "lo primero: levantarse")
	check_eq(menu[0].label, "Levantarse", "con su nombre")
	for option: ActionOption in menu:
		if option.category == BattleMenu.CATEGORY_GUARD:
			check(option.enabled, "en el suelo aún puede encogerse")
		elif option.id != &"recover":
			check(not option.enabled and option.disabled_reason != "", "%s bloqueada en el suelo" % option.label)
	check(battle.preview_hit_chance(battle.enemies[0], hero, CombatTypes.TORSO) > 0, "le aciertan")
	battle.intents.clear()
	var attack: CombatAction = battle.make_order(hero, _option(battle, hero, &"attack"), battle.enemies[0], CombatTypes.TORSO)
	var body: int = battle.enemies[0].body
	battle.start_resolution([attack] as Array[CombatAction])
	while battle.step():
		pass
	check_eq(battle.enemies[0].body, body, "derribado, su ataque se pierde")
	check(not hero.has_status(CombatTypes.STATUS_DOWN), "y al acabar la ronda ya está de pie")


func test_aturdido_es_un_estado_de_datos() -> void:
	var battle: Battle = _battle()
	var hero: Combatant = battle.protagonist()
	hero.stunned = 1
	check(hero.has_status(CombatTypes.STATUS_STUN), "aturdir aplica el estado")
	check_eq(hero.stunned, 1, "y se lee como antes")
	check(hero.pending_skip() != null, "pierde la siguiente acción")


func test_aterrado_por_la_mente_y_la_sedacion_lo_embota() -> void:
	var battle: Battle = _battle()
	var hero: Combatant = battle.protagonist()
	var added: Array[StringName] = []
	battle.status_added.connect(func(_who: Combatant, id: StringName) -> void: added.append(id))
	hero.mind = 20
	battle.begin_round()
	check(hero.has_status(CombatTypes.STATUS_TERROR), "con la Mente por debajo del 25 %, aterrado")
	check(added.has(CombatTypes.STATUS_TERROR), "la interfaz se entera")
	hero.add_status(SEDATION)
	check(hero.is_suppressed(CombatTypes.STATUS_TERROR), "la sedación embota el terror")
	hero.remove_status(CombatTypes.STATUS_SEDATION)
	battle._breathe(hero, 30)
	check(not hero.has_status(CombatTypes.STATUS_TERROR), "al recuperar Mente se pasa")


# --- tratar heridas ------------------------------------------------------------------------------------

func test_torniquete_y_venda_por_partes() -> void:
	var battle: Battle = _battle(3)
	battle.supplies = {&"torniquete": 1, &"venda": 1}
	var hero: Combatant = battle.protagonist()
	var tourniquet: ActionOption = _option(battle, hero, &"item:torniquete")
	check(tourniquet != null and not tourniquet.enabled, "sin nada que sangre, el torniquete no sirve")
	hero.parts[CombatTypes.ARM_L].amputate()
	hero.parts[CombatTypes.ARM_L].add_bleed(2)
	hero.add_bleed(CombatTypes.TORSO, 1)
	tourniquet = _option(battle, hero, &"item:torniquete")
	check(tourniquet.enabled and tourniquet.needs_part, "con un muñón que sangra, sí")
	var targets: Array[TargetOption] = battle.targets_for(hero, tourniquet)
	for part: PartOption in targets[0].parts:
		check(part.enabled == (part.id == CombatTypes.ARM_L), "torniquete solo en la extremidad que sangra: %s" % part.id)
	var preview: ActionPreview = battle.preview(hero, tourniquet, hero, CombatTypes.ARM_L)
	check(not preview.lines.is_empty(), "la vista previa dice lo que hace")
	battle._execute(battle.make_order(hero, tourniquet, hero, CombatTypes.ARM_L))
	check_eq(hero.parts[CombatTypes.ARM_L].bleeding, 0, "el muñón deja de sangrar")
	check(hero.parts[CombatTypes.ARM_L].sealed, "y ya no sangrará más")
	check_eq(int(battle.supplies[&"torniquete"]), 0, "se gasta")
	_wound(hero, CombatTypes.LEG_R)
	var bandage: ActionOption = _option(battle, hero, &"item:venda")
	battle._execute(battle.make_order(hero, bandage, hero, CombatTypes.LEG_R))
	check_eq(hero.parts[CombatTypes.LEG_R].state, CombatTypes.PartState.HEALTHY, "una venda cierra una herida")
	check_eq(hero.parts[CombatTypes.TORSO].bleeding, 1, "y no toca lo que sangra en otra parte")


func test_analgesicos_y_sedante_en_combate() -> void:
	var battle: Battle = _battle()
	battle.supplies = {&"analgesicos": 1, &"sedante": 1}
	var hero: Combatant = battle.protagonist()
	_break(hero, CombatTypes.TORSO)
	battle._execute(battle.make_order(hero, _option(battle, hero, &"item:analgesicos"), hero, &""))
	check(hero.has_status(CombatTypes.STATUS_ANALGESIA), "los analgésicos dan analgesia")
	var body: int = hero.body
	var breathe: CombatAction = battle.make_order(hero, _option(battle, hero, &"respirar"), null, &"")
	battle._execute(breathe)
	check_eq(hero.body, body, "con analgesia el torso roto no cuesta")
	hero.mind = 15
	battle._refresh_terror(hero)
	battle._execute(battle.make_order(hero, _option(battle, hero, &"item:sedante"), hero, &""))
	check(hero.mind > 15, "el sedante devuelve Mente")
	check(not hero.has_status(CombatTypes.STATUS_TERROR), "y quita el terror")
	check(hero.has_status(CombatTypes.STATUS_SEDATION), "pero seda")


func test_puente_mano_izquierda_y_tratamientos_de_la_custodia() -> void:
	var character: CharacterState = CharacterState.new()
	character.custody.add_item(Registry.item(&"tubo_metal"))
	character.custody.add_item(Registry.item(&"bisturi"))
	character.custody.add_item(Registry.item(&"torniquete"), 1)
	character.custody.add_item(Registry.item(&"venda_sucia"), 1)
	character.wield(character.custody.find_first(&"tubo_metal"))
	check_eq(character.wield_offhand(character.custody.find_first(&"bisturi")), "", "bisturí en la izquierda")
	var encounter: EncounterDef = preload("res://data/enemies/encuentro_enfermero.tres")
	var battle: Battle = CombatBridge.build_battle(encounter, character, {}, 5)
	var hero: Combatant = battle.protagonist()
	check_eq(hero.def.offhand_weapon, SCALPEL, "la mano izquierda pasa al combate")
	check(_option(battle, hero, &"clavar") != null, "con el bisturí en la izquierda se puede clavar")
	hero.add_bleed(CombatTypes.LEG_L, 2)
	var dirty: ActionOption = _option(battle, hero, &"item:venda_sucia")
	check(dirty != null and dirty.enabled and dirty.treatment != null, "la venda usada trata por partes")
	var preview: ActionPreview = battle.preview(hero, dirty, hero, CombatTypes.LEG_L)
	check(not preview.risk_lines.is_empty(), "avisa de que está sucia")
	var mind: int = hero.mind
	battle._execute(battle.make_order(hero, dirty, hero, CombatTypes.LEG_L))
	check_eq(hero.parts[CombatTypes.LEG_L].bleeding, 0, "corta el sangrado de la pierna")
	check(hero.mind < mind, "pero la tela sucia se paga")
	check(not character.custody.has(&"venda_sucia"), "y se gasta de la custodia")
	hero.parts[CombatTypes.ARM_L].amputate()
	hero.parts[CombatTypes.ARM_L].add_bleed(2)
	CombatBridge.to_vitals(hero, character.vitals)
	check(character.vitals.bleeding, "si algo sangra, sale sangrando al mapa")
	check_eq(int(character.vitals.wounds.get(CombatTypes.ARM_L, 0)), CombatTypes.PartState.AMPUTATED, "con el muñón")


# --- IA -------------------------------------------------------------------------------------------------

func test_la_ia_va_a_por_la_herida_que_sangra() -> void:
	var battle: Battle = _battle(9)
	var nurse: Combatant = battle.enemies[0]
	var hero: Combatant = battle.protagonist()
	hero.add_bleed(CombatTypes.LEG_R, 1)
	var on_wound: int = 0
	var cuts: int = 0
	var reasons: PackedStringArray = []
	for i: int in 60:
		nurse.cooldowns.clear()
		var intent: CombatAction = EnemyAI.choose_intent(nurse, battle.party, battle.rng)
		if intent.attack.display_name == "Tajo":
			cuts += 1
			if intent.part_id == CombatTypes.LEG_R:
				on_wound += 1
		if intent.reason != "":
			reasons.append(intent.reason)
	check(on_wound * 2 > cuts, "los tajos van sobre todo a la pierna que sangra (%d/%d)" % [on_wound, cuts])
	check(reasons.has("Huele tu sangre"), "y se lee por qué")


func test_la_ia_remata_al_derribado() -> void:
	var battle: Battle = _battle(11)
	var nurse: Combatant = battle.enemies[0]
	var hero: Combatant = battle.protagonist()
	battle._apply_status(hero, DOWN, null, &"")
	var finishing: int = 0
	for i: int in 30:
		nurse.cooldowns.clear()
		if EnemyAI.choose_intent(nurse, battle.party, battle.rng).attack.display_name == "Ensartar":
			finishing += 1
	check(finishing > 15, "en el suelo, casi siempre ensarta (%d/30)" % finishing)
	_break(nurse, CombatTypes.ARM_R)
	var stomps: int = 0
	for i: int in 30:
		nurse.cooldowns.clear()
		var intent: CombatAction = EnemyAI.choose_intent(nurse, battle.party, battle.rng)
		if intent.attack.display_name == "Pisotón":
			stomps += 1
	check(stomps > 12, "sin bisturíes, pisotea (%d/30)" % stomps)


func test_la_ia_cambia_de_tactica_al_perder_partes() -> void:
	var intact: Battle = _battle(13)
	var maimed: Battle = _battle(13)
	_break(maimed.enemies[0], CombatTypes.ARM_R)
	var counts: Array[int] = [0, 0]
	var index: int = 0
	for battle: Battle in [intact, maimed]:
		for i: int in 80:
			battle.enemies[0].cooldowns.clear()
			var intent: CombatAction = EnemyAI.choose_intent(battle.enemies[0], battle.party, battle.rng)
			if intent.attack.display_name == "Embestida":
				counts[index] += 1
		index += 1
	check(counts[1] > counts[0] * 2, "sin bisturíes embiste mucho más (%d → %d)" % [counts[0], counts[1]])
	var bonus: Dictionary = EnemyAI.attack_bonus(maimed.enemies[0], _attack_named("Embestida"), maimed.protagonist())
	check_eq(bonus["reason"], "Sin bisturíes, embiste", "con su razón legible")


func test_senales_de_intencion_y_orden_de_turno() -> void:
	var battle: Battle = _battle(6)
	var changed: Array[Combatant] = []
	var order_changes: Array[int] = [0]
	battle.intent_changed.connect(func(enemy: Combatant) -> void: changed.append(enemy))
	battle.turn_order_changed.connect(func() -> void: order_changes[0] += 1)
	battle.begin_round()
	check(changed.has(battle.enemies[0]), "al fijar la intención se avisa")
	var hero: Combatant = battle.protagonist()
	var order: CombatAction = battle.make_order(hero, _option(battle, hero, &"attack"), battle.enemies[0], CombatTypes.TORSO)
	battle.start_resolution([order] as Array[CombatAction])
	check(order_changes[0] > 0, "al ordenar la ronda se avisa")
	check_eq(battle.turn_order().size(), 2, "dos acciones en cola")
	battle.step()
	check_eq(battle.turn_order().size(), 1, "una menos tras actuar")
	var recover_battle: Battle = _battle(6)
	recover_battle._apply_status(recover_battle.enemies[0], DOWN, null, &"")
	recover_battle.begin_round()
	check(recover_battle.intent_text(recover_battle.enemies[0]).contains("PIERDE EL TURNO"),
		"un enemigo en el suelo enseña que pierde el turno")


# --- API de opciones y vista previa -------------------------------------------------------------------------

func test_api_de_opciones_del_contrato() -> void:
	var battle: Battle = _battle(8)
	var hero: Combatant = battle.protagonist()
	var nurse: Combatant = battle.enemies[0]
	battle.begin_round()
	var menu: Array[ActionOption] = battle.action_menu(hero)
	var categories: Array[StringName] = []
	for option: ActionOption in menu:
		if not categories.has(option.category):
			categories.append(option.category)
		check(option.label != "" and option.id != &"" and option.icon_key != &"", "opción completa: %s" % option.id)
	for category: StringName in [&"attack", &"skill", &"guard", &"other"]:
		check(categories.has(category), "categoría " + String(category))
	var attack: ActionOption = _option(battle, hero, &"attack")
	check(attack.needs_target and attack.needs_part, "atacar pide objetivo y parte")
	nurse.parts[CombatTypes.LEG_L].amputate()
	var targets: Array[TargetOption] = battle.targets_for(hero, attack)
	check_eq(targets.size(), 1, "un enemigo")
	check(targets[0].combatant == nurse, "es el enfermero")
	for part: PartOption in targets[0].parts:
		if part.id == CombatTypes.LEG_L:
			check(not part.enabled and part.disabled_reason != "", "lo amputado no se elige")
		else:
			check_eq(part.hit_chance, battle.preview_hit_chance(hero, nurse, part.id), "acierto de %s" % part.id)
	var preview: ActionPreview = battle.preview(hero, attack, nurse, CombatTypes.ARM_R)
	var damage: Dictionary = battle.preview_damage(hero, nurse, CombatTypes.ARM_R)
	check_eq(preview.hit_chance, battle.preview_hit_chance(hero, nurse, CombatTypes.ARM_R), "acierto en la vista previa")
	check_eq(Vector2i(preview.damage_min, preview.damage_max), damage["body"] as Vector2i, "daño en la vista previa")
	check_eq(preview.damage_type, CombatTypes.DamageType.BLUNT, "tipo de daño")
	var joined: String = "\n".join(preview.lines)
	check(joined.contains("TAJO"), "dice qué pierde si se rompe: " + joined)
	var guard: ActionOption = _option(battle, hero, &"guard")
	var guard_targets: Array[TargetOption] = battle.targets_for(hero, guard)
	check(guard_targets.size() == 1 and guard_targets[0].combatant == hero, "la guardia es sobre uno mismo")
	var order: CombatAction = battle.make_order(hero, attack, nurse, CombatTypes.ARM_R)
	check(order.type == CombatTypes.ActionType.ATTACK and order.target == nurse and order.part_id == CombatTypes.ARM_R,
		"make_order da la orden")
	var intent: CombatAction = battle.intents.get(nurse)
	if intent != null and intent.target == hero and intent.attack != null \
			and intent.attack.damage_type != CombatTypes.DamageType.HORROR:
		check(not preview.risk_lines.is_empty(), "avisa del golpe que viene sin cubrir")
		var covered: ActionPreview = battle.preview(hero, guard, hero, intent.part_id)
		check("\n".join(covered.lines).contains(intent.attack.display_name.to_upper()), "la guardia dice qué para")


func test_vista_previa_de_amputar_y_romper() -> void:
	var cut: Battle = _battle(1, SCALPEL)
	var hero: Combatant = cut.protagonist()
	var nurse: Combatant = cut.enemies[0]
	_break(nurse, CombatTypes.ARM_L)
	var attack: ActionOption = _option(cut, hero, &"attack")
	check(cut.preview(hero, attack, nurse, CombatTypes.ARM_L).amputation_chance > 0, "el bisturí puede amputar lo roto")
	var blunt: Battle = _battle(1, PIPE)
	_break(blunt.enemies[0], CombatTypes.LEG_L)
	_break(blunt.enemies[0], CombatTypes.ARM_R)
	var pipe_attack: ActionOption = _option(blunt, blunt.protagonist(), &"attack")
	check_eq(blunt.preview(blunt.protagonist(), pipe_attack, blunt.enemies[0], CombatTypes.LEG_L).amputation_chance, 0,
		"el tubo no amputa una pierna")
	check(blunt.preview(blunt.protagonist(), pipe_attack, blunt.enemies[0], CombatTypes.ARM_R).amputation_chance > 0,
		"pero arranca el brazo de instrumental roto")
	var head: ActionPreview = blunt.preview(blunt.protagonist(), pipe_attack, blunt.enemies[0], CombatTypes.HEAD)
	check(int(head.status_chances.get(CombatTypes.STATUS_STUN, 0)) > 0, "en la cabeza, probabilidad de aturdir")
	var knee: ActionOption = _option(blunt, blunt.protagonist(), &"golpe_rodilla")
	var knee_preview: ActionPreview = blunt.preview(blunt.protagonist(), knee, blunt.enemies[0], CombatTypes.LEG_R)
	check(int(knee_preview.status_chances.get(CombatTypes.STATUS_DOWN, 0)) > 0, "la rodilla dice cuánto derriba")
	check(knee_preview.risk_lines.size() > 0, "y lo que cuesta")


## La probabilidad de romper que enseña la vista previa se parece a la real.
func test_la_vista_previa_es_honesta() -> void:
	var probe: Battle = _battle(1)
	var nurse_probe: Combatant = probe.enemies[0]
	nurse_probe.parts[CombatTypes.ARM_R].integrity = 20
	var option: ActionOption = _option(probe, probe.protagonist(), &"attack")
	var expected: int = probe.preview(probe.protagonist(), option, nurse_probe, CombatTypes.ARM_R).break_chance
	var broke: int = 0
	var runs: int = 400
	for seed_value: int in runs:
		var battle: Battle = _battle(seed_value + 1000)
		var nurse: Combatant = battle.enemies[0]
		nurse.parts[CombatTypes.ARM_R].integrity = 20
		var order: CombatAction = battle.make_order(battle.protagonist(), option, nurse, CombatTypes.ARM_R)
		battle._execute(order)
		if nurse.parts[CombatTypes.ARM_R].is_disabled():
			broke += 1
	var real: int = roundi(100.0 * broke / runs)
	check(absi(real - expected) <= 8 and expected > 10 and expected < 90, "romper: previsto %d %%, real %d %%" % [expected, real])
