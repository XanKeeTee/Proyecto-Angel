class_name ItemStack
extends RefCounted
## Un ejemplar concreto de un objeto en la custodia: cantidad, desgaste, carga y contaminación.
## (La custodia es una lista por categorías: los montones ya no tienen casilla ni giro.)

var def: ItemDef
var quantity: int = 1
var durability: int = 0
var charge: float = 0.0
var contaminated: bool = false


## Crea un montón. Los objetos que no se apilan son siempre de una unidad.
static func create(item: ItemDef, amount: int = 1) -> ItemStack:
	var stack: ItemStack = ItemStack.new()
	stack.def = item
	stack.quantity = maxi(1, amount) if item.is_stackable() else 1
	stack.durability = item.max_durability
	stack.charge = item.max_charge
	stack.contaminated = item.contaminated
	return stack


## ¿Se pueden juntar en un mismo montón? (mismo objeto apilable y misma contaminación).
func can_merge(other: ItemStack) -> bool:
	return other != null and other != self and other.def == def and def.is_stackable() \
		and contaminated == other.contaminated


## Estado legible: "Contaminado", "Gastado", "Carga 40 %"…
func status_text() -> String:
	var parts: PackedStringArray = []
	if def.max_charge > 0.0:
		parts.append("Carga %d %%" % roundi(charge / def.max_charge * 100.0))
	if def.max_durability > 0:
		var ratio: float = float(durability) / def.max_durability
		parts.append("Desgastado" if ratio < 0.4 else ("Usado" if ratio < 1.0 else "En buen estado"))
	if contaminated:
		parts.append("Contaminado")
	return " · ".join(parts)


func to_dict() -> Dictionary:
	return {
		"id": String(def.id), "quantity": quantity, "durability": durability, "charge": charge,
		"contaminated": contaminated,
	}


## Lee un montón guardado (también los de la bandeja antigua: su casilla y giro se ignoran).
static func from_dict(data: Dictionary) -> ItemStack:
	var item: ItemDef = Registry.item(StringName(data.get("id", "")))
	if item == null:
		return null
	var stack: ItemStack = ItemStack.create(item, int(data.get("quantity", 1)))
	stack.durability = int(data.get("durability", item.max_durability))
	stack.charge = float(data.get("charge", item.max_charge))
	stack.contaminated = bool(data.get("contaminated", item.contaminated))
	return stack
