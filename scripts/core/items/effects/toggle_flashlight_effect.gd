class_name ToggleFlashlightEffect
extends ItemEffect
## Enciende o apaga la linterna. No consume el objeto (marcar `consumed_on_use = false`).


func can_apply(stack: ItemStack, _character: CharacterState) -> bool:
	return stack.charge > 0.0


func apply(stack: ItemStack, character: CharacterState) -> String:
	if stack.charge <= 0.0:
		return ""
	character.flashlight_on = not character.flashlight_on
	return "·"  # sin texto: el clic y la luz bastan
