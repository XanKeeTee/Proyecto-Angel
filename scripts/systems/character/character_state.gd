class_name CharacterState
extends RefCounted
## Todo lo que pertenece a un protagonista: custodia, constantes y linterna.
## Preparado para los cinco protagonistas: GameState guarda uno por id.

var id: StringName = &"paciente_09"
var display_name: String = "Paciente 09"
var custody: Custody = Custody.new()
var vitals: Vitals = Vitals.new()
var flashlight_on: bool = false


## Linterna que lleva (en bandeja o bolsillo), o null.
func flashlight() -> ItemStack:
	return custody.find_first(&"linterna")


## Usa un objeto desde la custodia. Devuelve el texto para el jugador ("" = no se puede ahora).
func use_item(stack: ItemStack) -> String:
	if not stack.def.usable:
		return ""
	var texts: PackedStringArray = []
	var applied: bool = false
	for effect: ItemEffect in stack.def.use_effects:
		var text: String = effect.apply(stack, self)
		if text != "":
			applied = true
			if text != "·":
				texts.append(text)
	if not applied:
		return ""
	if stack.def.consumed_on_use:
		custody.consume(stack)
	return "\n".join(texts) if not texts.is_empty() else "·"


func to_dict() -> Dictionary:
	return {
		"id": String(id), "name": display_name, "custody": custody.to_dict(),
		"vitals": vitals.to_dict(), "flashlight_on": flashlight_on,
	}


static func from_dict(data: Dictionary) -> CharacterState:
	var c: CharacterState = CharacterState.new()
	c.id = StringName(data.get("id", "paciente_09"))
	c.display_name = data.get("name", c.display_name)
	c.custody = Custody.from_dict(data.get("custody", {}))
	c.vitals = Vitals.from_dict(data.get("vitals", {}))
	c.flashlight_on = bool(data.get("flashlight_on", false))
	return c
