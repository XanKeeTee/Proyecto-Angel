class_name LootTable
extends Resource
## Tabla de botín de un tipo de mueble (cajón de mesita, taquilla, papelera…): probabilidad de
## que esté vacío y, si no, cuántas tiradas y qué puede salir en cada una (por peso).

@export var id: StringName = &""
## Probabilidad (0..1) de que no haya nada de esta tabla.
@export_range(0.0, 1.0) var empty_chance: float = 0.6
@export var min_rolls: int = 1
@export var max_rolls: int = 1
@export var entries: Array[LootTableEntry] = []


## Tira la tabla con `rng`. Devuelve [{item, quantity}].
func roll(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if entries.is_empty() or rng.randf() < empty_chance:
		return result
	var total: float = 0.0
	for entry: LootTableEntry in entries:
		total += maxf(0.0, entry.weight)
	if total <= 0.0:
		return result
	var rolls: int = rng.randi_range(mini(min_rolls, max_rolls), maxi(min_rolls, max_rolls))
	for i: int in rolls:
		var pick: float = rng.randf() * total
		for entry: LootTableEntry in entries:
			pick -= maxf(0.0, entry.weight)
			if pick < 0.0:
				var qty: int = rng.randi_range(mini(entry.min_quantity, entry.max_quantity), maxi(entry.min_quantity, entry.max_quantity))
				if entry.item != null and qty > 0:
					result.append({"item": entry.item, "quantity": qty})
				break
	return result
