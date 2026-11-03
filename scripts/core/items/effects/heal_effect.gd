class_name HealEffect
extends ItemEffect
## Recupera Cuerpo y/o Mente y, si se indica, detiene el sangrado.
## Si el ejemplar está contaminado, aplica la penalización en lugar de parte de la mejora.

@export var body: int = 0
@export var mind: int = 0
@export var stops_bleeding: bool = false
## Solo se puede usar si hay sangrado (vendas: no se malgastan).
@export var requires_bleeding: bool = false
## Pérdida de Cuerpo y Mente si el ejemplar está contaminado.
@export var contaminated_penalty: int = 6
@export_multiline var message: String = ""
@export_multiline var contaminated_message: String = ""


func can_apply(_stack: ItemStack, character: CharacterState) -> bool:
	var v: Vitals = character.vitals
	if requires_bleeding and not v.bleeding:
		return false
	return (stops_bleeding and v.bleeding) or (body > 0 and v.body < Vitals.MAX) or (mind > 0 and v.mind < Vitals.MAX)


func apply(stack: ItemStack, character: CharacterState) -> String:
	if not can_apply(stack, character):
		return ""
	var v: Vitals = character.vitals
	if stops_bleeding:
		v.set_bleeding(false)
	if stack.contaminated:
		v.change_body(-contaminated_penalty)
		v.change_mind(-contaminated_penalty)
		return contaminated_message if contaminated_message != "" else message
	v.change_body(body)
	v.change_mind(mind)
	return message
