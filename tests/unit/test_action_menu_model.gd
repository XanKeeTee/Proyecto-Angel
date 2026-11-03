extends TestCase
## Adaptador provisional de la API de opciones (`ActionMenuModel`): lo que enseña la interfaz sale
## de las reglas de `Battle`, sin inventar números.

const PARTY: CombatantDef = preload("res://data/party/paciente_09.tres")
const ENEMY: CombatantDef = preload("res://data/enemies/enfermero.tres")
const PIPE: WeaponDef = preload("res://data/weapons/pipe.tres")


func test_opciones_por_categoria() -> void:
	var battle: Battle = _battle()
	var model: ActionMenuModel = ActionMenuModel.new(battle)
	var hero: Combatant = battle.protagonist()
	var options: Array[ActionOption] = model.action_menu(hero)
	var attack: ActionOption = ActionMenuModel.of_category(options, ActionMenuModel.ATTACK)[0]
	check(attack.needs_target and attack.needs_part, "atacar pide objetivo y parte")
	check_eq(attack.icon_key, &"pipe", "el tubo, con su icono")
	var guard: ActionOption = ActionMenuModel.of_category(options, ActionMenuModel.GUARD)[0]
	check(guard.needs_part and not guard.needs_target, "la Guardia pide una parte propia")
	var breathe: ActionOption = ActionMenuModel.of_category(options, ActionMenuModel.SKILL)[0]
	check(not breathe.enabled and breathe.disabled_reason != "", "con la Mente entera, Respirar no, y dice por qué")
	hero.mind -= 30
	breathe = ActionMenuModel.of_category(model.action_menu(hero), ActionMenuModel.SKILL)[0]
	check(breathe.enabled, "con la Mente baja, sí")
	battle.can_flee = false
	var flee: ActionOption = ActionMenuModel.of_category(model.action_menu(hero), ActionMenuModel.OTHER)[0]
	check(not flee.enabled and flee.disabled_reason.contains("salida"), "sin huida, Huir está desactivado con motivo")


func test_objetivos_y_vista_previa_salen_de_las_reglas() -> void:
	var battle: Battle = _battle()
	var model: ActionMenuModel = ActionMenuModel.new(battle)
	var hero: Combatant = battle.protagonist()
	var enemy: Combatant = battle.enemies[0]
	var attack: ActionOption = model.action_menu(hero)[0]
	enemy.parts[CombatTypes.LEG_L].amputate()
	var targets: Array[TargetOption] = model.targets_for(hero, attack)
	check_eq(targets.size(), 1, "un enemigo")
	check_eq(targets[0].parts.size(), enemy.part_order.size(), "todas sus partes")
	for part: PartOption in targets[0].parts:
		if part.id == CombatTypes.LEG_L:
			check(not part.enabled and part.disabled_reason != "", "la amputada no se elige")
		else:
			check_eq(part.hit_chance, battle.preview_hit_chance(hero, enemy, part.id), "acierto de las reglas")
	var preview: ActionPreview = model.preview(hero, attack, enemy, CombatTypes.ARM_R)
	var damage: Vector2i = battle.preview_damage(hero, enemy, CombatTypes.ARM_R)["body"]
	check_eq(Vector2i(preview.damage_min, preview.damage_max), damage, "daño de las reglas")
	var sin_tajo: bool = false
	for line: String in preview.lines:
		sin_tajo = sin_tajo or line.contains("TAJO")
	check(sin_tajo, "dice qué ataque pierde si se rompe")
	# Brazo de instrumental roto: el tubo puede arrancarlo.
	enemy.parts[CombatTypes.ARM_R].worsen()
	enemy.parts[CombatTypes.ARM_R].worsen()
	preview = model.preview(hero, attack, enemy, CombatTypes.ARM_R)
	check(preview.amputation_chance > 0, "roto, se puede arrancar a golpes")
	preview = model.preview(hero, attack, enemy, CombatTypes.HEAD)
	check_eq(int(preview.status_chances.get(&"stun", 0)), ActionMenuModel.STUN_HEAD_BLUNT, "en la cabeza, puede aturdir")


func test_orden_y_reservas() -> void:
	var battle: Battle = _battle()
	battle.bandages = 1
	var model: ActionMenuModel = ActionMenuModel.new(battle)
	var hero: Combatant = battle.protagonist()
	var items: Array[ActionOption] = ActionMenuModel.of_category(model.action_menu(hero), ActionMenuModel.ITEM)
	check_eq(items.size(), 1, "una venda")
	var order: CombatAction = model.make_order(hero, items[0], null, &"")
	check_eq(order.type, CombatTypes.ActionType.ITEM, "orden de objeto")
	model.reserve(order)
	check(ActionMenuModel.of_category(model.action_menu(hero), ActionMenuModel.ITEM).is_empty(),
		"reservada, no se ofrece otra vez")
	model.release(order)
	check_eq(ActionMenuModel.of_category(model.action_menu(hero), ActionMenuModel.ITEM).size(), 1, "al volver atrás, sí")
	var guard: ActionOption = ActionMenuModel.of_category(model.action_menu(hero), ActionMenuModel.GUARD)[0]
	order = model.make_order(hero, guard, null, CombatTypes.ARM_L)
	check(order.type == CombatTypes.ActionType.GUARD and order.target == hero and order.part_id == CombatTypes.ARM_L,
		"la Guardia cubre una parte propia")


func _battle() -> Battle:
	var party: CombatantDef = PARTY.duplicate()
	party.weapon = PIPE
	var battle: Battle = Battle.new([party] as Array[CombatantDef], [ENEMY] as Array[CombatantDef], 4)
	battle.begin_round()
	return battle
