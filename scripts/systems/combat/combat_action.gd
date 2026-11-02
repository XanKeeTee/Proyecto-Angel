class_name CombatAction
extends RefCounted
## Una acción elegida para la ronda (del jugador o intención enemiga).

var type: CombatTypes.ActionType = CombatTypes.ActionType.ATTACK
var actor: Combatant
var target: Combatant
var part_id: StringName = &""
## Solo en acciones enemigas.
var attack: EnemyAttackDef
## El enemigo va a por un Caído.
var finishing: bool = false
var initiative: int = 0
## Objeto que se usa (ITEM con `Battle.item_user`); en el juego, un ItemStack de la custodia.
var item: Variant
