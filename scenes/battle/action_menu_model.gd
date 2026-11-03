class_name ActionMenuModel
extends RefCounted
## Puente entre la interfaz del combate y la API de opciones de las reglas (`Battle.action_menu`,
## `targets_for`, `preview`, `make_order`; ver docs/tech/interfaz-combate.md). No decide reglas:
## pide a `Battle` lo que se puede hacer y le añade lo que solo necesita la interfaz:
##
## - **Reservas**: un objeto que ya ha elegido otro miembro esta ronda no se ofrece otra vez (o se
##   ofrece con una unidad menos).
## - **Iconos**: traduce el `icon_key` de cada opción («attack», «skill_empujon», «item_venda»,
##   «treat_torniquete»…) a una imagen del arte de la interfaz; el de atacar sale del arma empuñada.

const ATTACK: StringName = BattleMenu.CATEGORY_ATTACK
const SKILL: StringName = BattleMenu.CATEGORY_SKILL
const GUARD: StringName = BattleMenu.CATEGORY_GUARD
const ITEM: StringName = BattleMenu.CATEGORY_ITEM
const OTHER: StringName = BattleMenu.CATEGORY_OTHER
## Orden de las categorías en el menú principal.
const CATEGORIES: Array[StringName] = [ATTACK, SKILL, GUARD, ITEM, OTHER]
const CATEGORY_LABELS: Dictionary[StringName, String] = {
	ATTACK: "Atacar", SKILL: "Habilidades", GUARD: "Guardia", ITEM: "Objetos", OTHER: "Otras",
}
const CATEGORY_ICONS: Dictionary[StringName, StringName] = {
	ATTACK: &"attack", SKILL: &"skill", GUARD: &"guard", ITEM: &"item", OTHER: &"door",
}
## Icono de la interfaz para cada habilidad (por id).
const SKILL_ICONS: Dictionary[StringName, StringName] = {
	&"golpe_rodilla": &"kick", &"barrido": &"sweep", &"empujon": &"push", &"rematar": &"finish",
	&"forcejear": &"grapple", &"morder": &"bite", &"clavar": &"stab", &"respirar": &"lungs", &"breathe": &"lungs",
}
## Icono de la interfaz para las claves sueltas de las reglas.
const KEY_ICONS: Dictionary[StringName, StringName] = {
	&"guard": &"guard", &"recover": &"recover", &"break_free": &"break_free", &"flee_solo": &"flee_solo",
	&"flee": &"door", &"bandage": &"bandage",
}

var battle: Battle
## Personaje del mapa (para el arma empuñada). Opcional.
var character: CharacterState
## Objetos ya elegidos por otros miembros esta ronda (cuántas veces cada uno).
var _reserved: Dictionary = {}


func _init(p_battle: Battle, p_character: CharacterState = null) -> void:
	battle = p_battle
	character = p_character


## Lo que puede hacer `actor` ahora mismo (las reglas), sin lo que ya está reservado esta ronda.
func action_menu(actor: Combatant) -> Array[ActionOption]:
	var result: Array[ActionOption] = []
	for option: ActionOption in battle.action_menu(actor):
		if option.category == ITEM:
			if option.quantity <= 0:
				option.quantity = _quantity_from_text(option)
			var key: Variant = _item_key(option)
			var used: int = int(_reserved.get(key, 0))
			if used > 0:
				var left: int = option.quantity - used
				if left <= 0:
					continue
				option.quantity = left
				option.value_text = "×%d" % left if left > 1 else ""
		result.append(option)
	return result


func targets_for(actor: Combatant, option: ActionOption) -> Array[TargetOption]:
	return battle.targets_for(actor, option)


func preview(actor: Combatant, option: ActionOption, target: Combatant, part_id: StringName) -> ActionPreview:
	return battle.preview(actor, option, target, part_id)


func make_order(actor: Combatant, option: ActionOption, target: Combatant, part_id: StringName) -> CombatAction:
	var order: CombatAction = battle.make_order(actor, option, target, part_id)
	order.set_meta(&"menu_key", _item_key(option))
	return order


## Reserva lo que gasta una orden ya elegida (objetos), para no ofrecerlo otra vez esta ronda.
func reserve(order: CombatAction) -> void:
	if order.type != CombatTypes.ActionType.ITEM:
		return
	var key: Variant = order.get_meta(&"menu_key", order.item)
	_reserved[key] = int(_reserved.get(key, 0)) + 1


## Deshace la reserva de una orden (al volver atrás).
func release(order: CombatAction) -> void:
	if order.type != CombatTypes.ActionType.ITEM:
		return
	var key: Variant = order.get_meta(&"menu_key", order.item)
	_reserved[key] = int(_reserved.get(key, 0)) - 1
	if int(_reserved[key]) <= 0:
		_reserved.erase(key)


## Se empieza una ronda nueva: no hay nada reservado.
func clear_reservations() -> void:
	_reserved.clear()


## Opciones de una categoría.
static func of_category(options: Array[ActionOption], category: StringName) -> Array[ActionOption]:
	var result: Array[ActionOption] = []
	for option: ActionOption in options:
		if option.category == category:
			result.append(option)
	return result


## Imagen de una opción: el icono del objeto si lo tiene; si no, la clave traducida al arte de la
## interfaz (atacar → el arma con que se ataca).
func icon_for(actor: Combatant, option: ActionOption) -> Texture2D:
	var stack: ItemStack = option.item if option.item is ItemStack else null
	if stack != null and stack.def.icon != null:
		return stack.def.icon
	if option.item is StringName or option.item is String:
		var def: ItemDef = Registry.item(StringName(option.item))
		if def != null and def.icon != null:
			return def.icon
	return BattleSkin.order_icon(icon_key_for(actor, option))


## Clave del arte de la interfaz para una opción.
func icon_key_for(actor: Combatant, option: ActionOption) -> StringName:
	if option.category == ATTACK:
		var grip: WeaponGrip = actor.offhand_grip() if option.use_offhand else actor.grip()
		if grip == null or grip.unarmed:
			return &"fist"
		return weapon_icon_key(grip.weapon)
	if option.skill != null:
		return SKILL_ICONS.get(option.skill.id, SKILL_ICONS.get(option.skill.icon_key, &"skill"))
	if option.treatment != null or option.category == ITEM:
		var id: StringName = Battle.item_id(option.item)
		if option.treatment != null:
			id = option.treatment.id
		return item_icon_key(id if id != &"" else option.id)
	return KEY_ICONS.get(option.icon_key, KEY_ICONS.get(option.id, &"item"))


## Clave del icono de un arma.
static func weapon_icon_key(weapon: WeaponDef) -> StringName:
	if weapon == null or weapon == Combatant.unarmed_weapon():
		return &"fist"
	match weapon.damage_type:
		CombatTypes.DamageType.CUT, CombatTypes.DamageType.PIERCE:
			return &"blade"
	return &"pipe"


## Clave del icono de un objeto o tratamiento por su id (vendas, torniquete, pastillas, jeringas…).
static func item_icon_key(item_id: StringName) -> StringName:
	var id: String = String(item_id)
	if id.contains("torniquete"):
		return &"tourniquet"
	if id.contains("venda") or id.contains("vendar") or id.contains("tela") or id == "bandage":
		return &"bandage"
	if id.contains("jeringa") or id.contains("sedante") or id.contains("ampolla"):
		return &"syringe"
	if id.contains("analges") or id.contains("pastill"):
		return &"pills"
	return &"item"


## Clave de reserva de una opción de objeto (el ItemStack o el id del objeto).
func _item_key(option: ActionOption) -> Variant:
	if option.item is Object:
		return option.item
	if option.item != null:
		return StringName(option.item)
	return option.id


static func _quantity_from_text(option: ActionOption) -> int:
	if option.value_text.begins_with("×"):
		return option.value_text.substr(1).to_int()
	return 1
