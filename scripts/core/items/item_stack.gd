class_name ItemStack
extends RefCounted
## Un ejemplar concreto de un objeto en la custodia: cantidad, desgaste, carga y posición.

var def: ItemDef
var quantity: int = 1
var durability: int = 0
var charge: float = 0.0
var contaminated: bool = false
## Casilla superior izquierda en la bandeja (si está en la bandeja).
var cell: Vector2i = Vector2i.ZERO
var rotated: bool = false


static func create(item: ItemDef, amount: int = 1) -> ItemStack:
	var stack: ItemStack = ItemStack.new()
	stack.def = item
	stack.quantity = clampi(amount, 1, maxi(1, item.max_stack))
	stack.durability = item.max_durability
	stack.charge = item.max_charge
	stack.contaminated = item.contaminated
	return stack


func footprint() -> Vector2i:
	return def.footprint(rotated)


func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var fp: Vector2i = footprint()
	for y: int in fp.y:
		for x: int in fp.x:
			result.append(cell + Vector2i(x, y))
	return result


func can_merge(other: ItemStack) -> bool:
	return other != self and other.def == def and def.is_stackable() and contaminated == other.contaminated \
		and quantity < def.max_stack


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
		"contaminated": contaminated, "cell": [cell.x, cell.y], "rotated": rotated,
	}


static func from_dict(data: Dictionary) -> ItemStack:
	var item: ItemDef = Registry.item(StringName(data.get("id", "")))
	if item == null:
		return null
	var stack: ItemStack = ItemStack.create(item, int(data.get("quantity", 1)))
	stack.durability = int(data.get("durability", item.max_durability))
	stack.charge = float(data.get("charge", item.max_charge))
	stack.contaminated = bool(data.get("contaminated", item.contaminated))
	var c: Array = data.get("cell", [0, 0])
	stack.cell = Vector2i(int(c[0]), int(c[1]))
	stack.rotated = bool(data.get("rotated", false))
	return stack
