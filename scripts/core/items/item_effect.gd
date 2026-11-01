class_name ItemEffect
extends Resource
## Efecto que produce un objeto al usarse. Las subclases están en `effects/`.
## `apply` devuelve el texto que verá el jugador, o "" si no se puede usar ahora
## (en ese caso el objeto no se consume).


func apply(_stack: ItemStack, _character: CharacterState) -> String:
	return ""


## Si el efecto tendría sentido ahora (para avisar antes de gastar el objeto).
func can_apply(_stack: ItemStack, _character: CharacterState) -> bool:
	return true
