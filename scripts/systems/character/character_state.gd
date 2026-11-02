class_name CharacterState
extends RefCounted
## Todo lo que pertenece a un protagonista: custodia, constantes, linterna, ropa puesta y arma en la mano.
## Preparado para los cinco protagonistas: GameState guarda uno por id.

## Ha cambiado la ropa puesta.
signal outfit_changed
## Ha cambiado el arma empuñada (null = manos vacías).
signal weapon_changed(stack: ItemStack)

## Ropa con la que empieza (ranura -> id de objeto).
const START_OUTFIT: Dictionary[int, StringName] = {ItemDef.EquipSlot.BODY: &"bata_paciente"}

var id: StringName = &"paciente_09"
var display_name: String = "Paciente 09"
var custody: Custody = Custody.new()
var vitals: Vitals = Vitals.new()
var flashlight_on: bool = false
## Ropa puesta: ranura (ItemDef.EquipSlot) -> ItemStack. No ocupa sitio en la bandeja.
var equipment: Dictionary[int, ItemStack] = {}
## Arma empuñada. A diferencia de la ropa, **sigue en la custodia** (bandeja o bolsillo) y ocupa
## su sitio: así una palanca empuñada se puede seguir usando en una puerta. Si sale de la
## custodia (se descarta, se gasta, se queda encajada), la mano queda vacía sola.
var _weapon: ItemStack


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


## Arma empuñada, o null.
func wielded() -> ItemStack:
	if _weapon != null and not custody.contains(_weapon):
		_weapon = null
		weapon_changed.emit(null)
	return _weapon


## Empuña un arma de la custodia. Devuelve el texto para el jugador; "" si se ha empuñado.
func wield(stack: ItemStack) -> String:
	if stack == null or not stack.def.is_weapon():
		return "Eso no sirve como arma."
	if not custody.contains(stack):
		return "Tiene que estar en la custodia."
	_weapon = stack
	weapon_changed.emit(stack)
	return ""


## Deja de empuñar el arma (sigue en la custodia).
func unwield() -> void:
	if _weapon == null:
		return
	_weapon = null
	weapon_changed.emit(null)


## Deja un montón en el suelo. Devuelve el texto para el jugador. Si se ha podido, avisa con
## `EventBus.item_discarded` (el mundo lo pone a los pies del jugador).
func discard(stack: ItemStack) -> String:
	if stack == null:
		return ""
	if not stack.def.can_discard():
		return "No. Podrías necesitarlo."
	if stack == _weapon:
		unwield()
	if not custody.discard(stack):
		return ""
	_emit(&"item_discarded", stack)
	return "Dejas %s en el suelo." % _stack_label(stack)


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
	_emit(&"item_used", stack.def)
	if stack.def.consumed_on_use:
		custody.consume(stack)
	return "\n".join(texts) if not texts.is_empty() else "·"


func to_dict() -> Dictionary:
	return {
		"id": String(id), "name": display_name, "custody": custody.to_dict(),
		"vitals": vitals.to_dict(), "flashlight_on": flashlight_on, "equipment": _equipment_to_dict(),
		"weapon": _weapon_to_dict(),
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
	c._weapon = c._find_weapon(data.get("weapon", {}))
	return c


func _equipment_to_dict() -> Dictionary:
	var result: Dictionary = {}
	for slot: int in equipment:
		result[str(slot)] = String(equipment[slot].def.id)
	return result


## Dónde está el arma empuñada: id del objeto y bolsillo o casilla.
func _weapon_to_dict() -> Dictionary:
	var stack: ItemStack = wielded()
	if stack == null:
		return {}
	return {"id": String(stack.def.id), "pocket": custody.pockets.find(stack), "cell": [stack.cell.x, stack.cell.y]}


func _find_weapon(data: Variant) -> ItemStack:
	if typeof(data) != TYPE_DICTIONARY or (data as Dictionary).is_empty():
		return null
	var d: Dictionary = data
	var item_id: StringName = StringName(d.get("id", ""))
	var pocket: int = int(d.get("pocket", -1))
	if pocket >= 0 and pocket < Custody.POCKETS:
		var p: ItemStack = custody.pockets[pocket]
		if p != null and p.def.id == item_id:
			return p
	var c: Array = d.get("cell", [-1, -1])
	var at: ItemStack = custody.stack_at(Vector2i(int(c[0]), int(c[1])))
	if at != null and at.def.id == item_id:
		return at
	return custody.find_first(item_id)


## Nombre en minúsculas, con la cantidad si hay varias (para los textos).
static func _stack_label(stack: ItemStack) -> String:
	var name: String = stack.def.display_name.to_lower()
	if stack.quantity > 1:
		return "%s ×%d" % [name, stack.quantity]
	return name


## Emite una señal de EventBus sin nombrar el autoload, para que este script también compile en
## las herramientas que se ejecutan con -s (sin autoloads), como tools/data/build_items.gd.
func _emit(signal_name: StringName, value: Variant) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var bus: Node = tree.root.get_node_or_null(^"EventBus") if tree != null else null
	if bus != null:
		bus.emit_signal(signal_name, value)
