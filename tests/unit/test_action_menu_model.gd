extends TestCase
## Puente de la interfaz con la API de opciones (`ActionMenuModel`): lo que enseña sale de las
## reglas de `Battle` tal cual; la interfaz solo añade reservas de objetos e iconos.

const PARTY: CombatantDef = preload("res://data/party/paciente_09.tres")
const ENEMY: CombatantDef = preload("res://data/enemies/enfermero.tres")
const PIPE: WeaponDef = preload("res://data/weapons/pipe.tres")


func test_las_opciones_son_las_de_las_reglas() -> void:
	var battle: Battle = _battle()
	var model: ActionMenuModel = ActionMenuModel.new(battle)
	var hero: Combatant = battle.protagonist()
	var mine: Array[ActionOption] = model.action_menu(hero)
	var rules: Array[ActionOption] = battle.action_menu(hero)
	check_eq(mine.size(), rules.size(), "las mismas opciones")
	for i: int in mine.size():
		check(mine[i].id == rules[i].id and mine[i].enabled == rules[i].enabled
			and mine[i].disabled_reason == rules[i].disabled_reason, "igual que las reglas: %s" % mine[i].id)
	var preview: ActionPreview = model.preview(hero, mine[0], battle.enemies[0], CombatTypes.ARM_R)
	var real: ActionPreview = battle.preview(hero, rules[0], battle.enemies[0], CombatTypes.ARM_R)
	check(preview.hit_chance == real.hit_chance and preview.damage_max == real.damage_max, "la vista previa, también")
	var targets: Array[TargetOption] = model.targets_for(hero, mine[0])
	check_eq(targets.size(), battle.targets_for(hero, rules[0]).size(), "y los objetivos")


func test_cada_opcion_tiene_su_icono() -> void:
	var battle: Battle = _battle()
	battle.supplies = {&"venda": 2, &"torniquete": 1, &"analgesicos": 1}
	var model: ActionMenuModel = ActionMenuModel.new(battle)
	var hero: Combatant = battle.protagonist()
	for option: ActionOption in model.action_menu(hero):
		check(model.icon_for(hero, option) != null, "icono para %s" % option.id)
		if option.category == ActionMenuModel.ATTACK:
			check_eq(model.icon_key_for(hero, option), &"pipe", "atacar con el tubo: el icono del tubo")
		if option.skill != null:
			check(ActionMenuModel.SKILL_ICONS.has(option.skill.id), "cada habilidad tiene su dibujo: %s" % option.skill.id)
	check_eq(ActionMenuModel.item_icon_key(&"torniquete"), &"tourniquet", "el torniquete, su cincha")
	check_eq(ActionMenuModel.item_icon_key(&"venda_esterilizada"), &"bandage", "las vendas, la venda")


func test_reservas_de_objetos() -> void:
	var battle: Battle = _battle()
	battle.supplies = {&"analgesicos": 1, &"venda": 2}
	var model: ActionMenuModel = ActionMenuModel.new(battle)
	var hero: Combatant = battle.protagonist()
	var pills: ActionOption = _option(model.action_menu(hero), &"item:analgesicos")
	check(pills != null, "hay analgésicos")
	var order: CombatAction = model.make_order(hero, pills, hero, &"")
	check_eq(order.type, CombatTypes.ActionType.ITEM, "orden de objeto")
	model.reserve(order)
	check(_option(model.action_menu(hero), &"item:analgesicos") == null, "reservados, no se ofrecen otra vez")
	model.release(order)
	check(_option(model.action_menu(hero), &"item:analgesicos") != null, "al volver atrás, sí")
	var bandage: ActionOption = _option(model.action_menu(hero), &"item:venda")
	check_eq(bandage.quantity, 2, "dos vendas")
	model.reserve(model.make_order(hero, bandage, hero, CombatTypes.ARM_L))
	check_eq(_option(model.action_menu(hero), &"item:venda").quantity, 1, "una reservada: queda una")
	model.clear_reservations()
	check_eq(_option(model.action_menu(hero), &"item:venda").quantity, 2, "ronda nueva: las dos")


func _option(options: Array[ActionOption], id: StringName) -> ActionOption:
	for option: ActionOption in options:
		if option.id == id:
			return option
	return null


func _battle() -> Battle:
	var party: CombatantDef = PARTY.duplicate()
	party.weapon = PIPE
	var battle: Battle = Battle.new([party] as Array[CombatantDef], [ENEMY] as Array[CombatantDef], 4)
	battle.begin_round()
	return battle
