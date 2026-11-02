class_name LootRoller
extends RefCounted
## Tira un LootPlan con una semilla: mismo plan y misma semilla, mismo resultado.
## Lógica pura (sin escena). La escena aplica el resultado con `to_entries`.

## Clave en GameState.objects donde se guarda la semilla (va con la partida).
const STATE_KEY: StringName = &"loot"
## Semilla que significa «sin botín aleatorio» (partidas guardadas antes de existir).
const LEGACY_SEED: int = -1


## Devuelve {object_id: [{item: ItemDef, quantity: int}]} con lo que hay en cada mueble.
static func roll(plan: LootPlan, seed_value: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var result: Dictionary = {}
	for s: LootSlot in plan.slots:
		result[s.object_id] = [] as Array[Dictionary]
	for rule: LootScatter in plan.scatter:
		if rule.item == null or rule.candidates.is_empty():
			continue
		if rng.randf() >= rule.chance:
			continue
		var pool: Array[StringName] = rule.candidates.duplicate()
		for i: int in rule.copies:
			if pool.is_empty():
				pool = rule.candidates.duplicate()
			var index: int = rng.randi_range(0, pool.size() - 1)
			var target: StringName = pool[index]
			pool.remove_at(index)
			var qty: int = rng.randi_range(mini(rule.min_quantity, rule.max_quantity), maxi(rule.min_quantity, rule.max_quantity))
			_add(result, target, rule.item, qty)
	for s: LootSlot in plan.slots:
		if s.table == null:
			continue
		for got: Dictionary in s.table.roll(rng):
			_add(result, s.object_id, got["item"], got["quantity"])
	return result


## Total de unidades de un objeto en un resultado de `roll` (para pruebas y balance).
static func total(result: Dictionary, item_id: StringName) -> int:
	var count: int = 0
	for id: Variant in result:
		for got: Dictionary in result[id]:
			if (got["item"] as ItemDef).id == item_id:
				count += int(got["quantity"])
	return count


## Pasa lo que toca a un mueble a entradas de su contenido.
static func to_entries(got: Array) -> Array[LootEntry]:
	var entries: Array[LootEntry] = []
	for g: Dictionary in got:
		var entry: LootEntry = LootEntry.new()
		entry.item = g["item"]
		entry.quantity = int(g["quantity"])
		entries.append(entry)
	return entries


## Semilla nueva al azar (no negativa).
static func new_seed() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return int(rng.randi() & 0x7fffffff)


static func _add(result: Dictionary, object_id: StringName, item: ItemDef, quantity: int) -> void:
	if quantity <= 0 or item == null:
		return
	if not result.has(object_id):
		result[object_id] = [] as Array[Dictionary]
	var list: Array = result[object_id]
	for got: Dictionary in list:
		if got["item"] == item:
			got["quantity"] = int(got["quantity"]) + quantity
			return
	list.append({"item": item, "quantity": quantity})
