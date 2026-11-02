class_name CharacterState
extends RefCounted
## Todo lo que pertenece a un protagonista: custodia, constantes, linterna y ropa puesta.
## Preparado para los cinco protagonistas: GameState guarda uno por id.

## Ha cambiado la ropa puesta.
signal outfit_changed

## Ropa con la que empieza (ranura -> id de objeto).
const START_OUTFIT: Dictionary[int, StringName] = {ItemDef.EquipSlot.BODY: &"bata_paciente"}

var id: StringName = &"paciente_09"
var display_name: String = "Paciente 09"
var custody: Custody = Custody.new()
var vitals: Vitals = Vitals.new()
var flashlight_on: bool = false
## Ropa puesta: ranura (ItemDef.EquipSlot) -> ItemStack. No ocupa sitio en la bandeja.
var equipment: Dictionary[int, ItemStack] = {}


func _init() -> void:
	for slot: int in START_OUTFIT:
		var def: ItemDef = Registry.item(START_OUTFIT[slot])
		if def != null:
			equipment[slot] = ItemStack.create(def, 1)


## Lo que lleva puesto en una ranura, o null.
func worn(slot: ItemDef.EquipSlot) -> ItemStack:
	return equipment.get(slot)


## Se pone una prenda de la custodia. Lo que llevaba en esa ranura vuelve a la bandeja.
## Devuelve el texto para el jugador; "" si se ha puesto.
func equip(stack: ItemStack) -> String:
	if stack == null or not stack.def.is_wearable():
		return "Eso no se puede poner."
	var slot: int = stack.def.equip_slot
	var old: ItemStack = equipment.get(slot)
	custody.remove(stack)
	if old != null and custody.add_item(old.def, 1, old) > 0:
		# No cabe lo que se quita: se deshace el cambio.
		custody.add_item(stack.def, 1, stack)
		return "No hay sitio en la bandeja para guardar " + old.def.display_name.to_lower() + "."
	equipment[slot] = ItemStack.create(stack.def, 1)
	outfit_changed.emit()
	return ""


## Se quita lo que lleva en una ranura y lo guarda en la bandeja. "" si se ha podido.
func unequip(slot: ItemDef.EquipSlot) -> String:
	var old: ItemStack = equipment.get(slot)
	if old == null:
		return "No llevas nada ahí."
	if custody.add_item(old.def, 1, old) > 0:
		return "No hay sitio en la bandeja."
	equipment.erase(slot)
	outfit_changed.emit()
	return ""


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
	EventBus.item_used.emit(stack.def)
	if stack.def.consumed_on_use:
		custody.consume(stack)
	return "\n".join(texts) if not texts.is_empty() else "·"


func to_dict() -> Dictionary:
	return {
		"id": String(id), "name": display_name, "custody": custody.to_dict(),
		"vitals": vitals.to_dict(), "flashlight_on": flashlight_on, "equipment": _equipment_to_dict(),
	}


static func from_dict(data: Dictionary) -> CharacterState:
	var c: CharacterState = CharacterState.new()
	c.id = StringName(data.get("id", "paciente_09"))
	c.display_name = data.get("name", c.display_name)
	c.custody = Custody.from_dict(data.get("custody", {}))
	c.vitals = Vitals.from_dict(data.get("vitals", {}))
	c.flashlight_on = bool(data.get("flashlight_on", false))
	if data.has("equipment"):
		c.equipment.clear()
		var worn_data: Dictionary = data["equipment"]
		for key: String in worn_data:
			var def: ItemDef = Registry.item(StringName(worn_data[key]))
			if def != null:
				c.equipment[key.to_int()] = ItemStack.create(def, 1)
	return c


func _equipment_to_dict() -> Dictionary:
	var result: Dictionary = {}
	for slot: int in equipment:
		result[str(slot)] = String(equipment[slot].def.id)
	return result
