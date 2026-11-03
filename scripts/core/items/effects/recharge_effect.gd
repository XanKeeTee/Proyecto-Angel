class_name RechargeEffect
extends ItemEffect
## Recarga la linterna que lleve el personaje (pilas usadas directamente).

@export var amount: float = 50.0
@export var target_item: StringName = &"linterna"
@export_multiline var message: String = ""
@export_multiline var full_message: String = "La linterna ya está cargada."


func can_apply(_stack: ItemStack, character: CharacterState) -> bool:
	var target: ItemStack = character.custody.find_first(target_item)
	return target != null and target.charge < target.def.max_charge - 0.5


func apply(stack: ItemStack, character: CharacterState) -> String:
	if not can_apply(stack, character):
		return ""
	var target: ItemStack = character.custody.find_first(target_item)
	target.charge = minf(target.def.max_charge, target.charge + amount)
	return message
