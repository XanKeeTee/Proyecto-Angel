class_name Custody
extends RefCounted
## Sistema de Custodia: el inventario de La Novena Vigilia.
## - Objetos: una lista sin límite de espacio, ordenada por llegada y repartida en categorías
##   (`ItemDef.resolved_section`: Armas, Armaduras, Útiles, Medicina, Objetos principales, Otros).
##   Los objetos apilables van en un solo montón por tipo (los contaminados, aparte).
## - Atajos 1-5 (`pockets`): referencias a montones de la lista para usarlos sin abrir la custodia.
##   No son un contenedor aparte: lo que está en un atajo sigue en la lista.
## - Expediente personal: documentos.
## Solo lógica: la interfaz está en scenes/ui/custody/.

signal changed
signal document_added(doc: DocumentDef)

## Número de atajos (teclas 1-5).
const POCKETS: int = 5
## Versión del formato de guardado (1 = bandeja por casillas, 2 = lista).
const SAVE_VERSION: int = 2

## Montones, en el orden en que llegaron.
var items: Array[ItemStack] = []
## Atajos 1-5: montones de `items` (null = vacío).
var pockets: Array[ItemStack] = []
var documents: Array[StringName] = []
## Documentos ya abiertos alguna vez (para marcar los nuevos).
var documents_read: Array[StringName] = []
## Recetas descubiertas (por id): las de fabricar al llevar un ingrediente y las combinaciones al hacerlas.
var known_recipes: Array[StringName] = []


func _init() -> void:
	pockets.resize(POCKETS)


# --- lista -----------------------------------------------------------------------------------

## ¿Está este montón en la custodia?
func contains(stack: ItemStack) -> bool:
	return stack != null and items.has(stack)


## Saca un montón de la custodia (y de su atajo, si tenía).
func remove(stack: ItemStack) -> void:
	items.erase(stack)
	var i: int = pockets.find(stack)
	while i >= 0:
		pockets[i] = null
		i = pockets.find(stack)
	changed.emit()


## Saca un montón entero para dejarlo en el suelo. Los objetos clave y los principales no se
## pueden descartar. Devuelve true si se ha sacado.
func discard(stack: ItemStack) -> bool:
	if not contains(stack) or not stack.def.can_discard():
		return false
	remove(stack)
	return true


## Añade objetos. Los apilables se juntan con su montón (si coincide la contaminación); los demás
## entran de uno en uno, cada uno con su estado. `template` copia desgaste, carga y contaminación.
## Devuelve las unidades que no han cabido: siempre 0, porque ya no hay límite de espacio (se
## mantiene por compatibilidad con quien lo comprueba).
func add_item(item: ItemDef, amount: int = 1, template: ItemStack = null) -> int:
	if item == null or amount <= 0:
		return 0
	var contaminated: bool = template.contaminated if template != null else item.contaminated
	if item.is_stackable():
		for stack: ItemStack in items:
			if stack.def == item and stack.contaminated == contaminated:
				stack.quantity += amount
				changed.emit()
				return 0
		items.append(_new_stack(item, amount, template, contaminated))
	else:
		for i: int in amount:
			items.append(_new_stack(item, 1, template, contaminated))
	changed.emit()
	return 0


## Cuántas unidades caben ahora mismo: todas (no hay límite). Por compatibilidad.
func room_for(_item: ItemDef, amount: int) -> int:
	return amount


## Montones de una categoría, en orden de llegada.
func items_in(section: ItemDef.Section) -> Array[ItemStack]:
	var result: Array[ItemStack] = []
	for stack: ItemStack in items:
		if stack.def.resolved_section() == section:
			result.append(stack)
	return result


# --- atajos 1-5 --------------------------------------------------------------------------------

## Asigna un montón al atajo `index` (lo quita del que tuviera). Lo que había en ese atajo queda
## sin atajo, pero sigue en la custodia.
func to_pocket(stack: ItemStack, index: int) -> bool:
	if index < 0 or index >= POCKETS or not contains(stack):
		return false
	var old: int = pockets.find(stack)
	if old >= 0:
		pockets[old] = null
	pockets[index] = stack
	changed.emit()
	return true


## Vacía un atajo (el objeto sigue en la custodia). Devuelve false si ya estaba vacío.
func from_pocket(index: int) -> bool:
	if index < 0 or index >= POCKETS or pockets[index] == null:
		return false
	pockets[index] = null
	changed.emit()
	return true


func swap_pockets(a: int, b: int) -> void:
	var tmp: ItemStack = pockets[a]
	pockets[a] = pockets[b]
	pockets[b] = tmp
	changed.emit()


## Atajo de un montón (0-4) o -1.
func pocket_of(stack: ItemStack) -> int:
	return pockets.find(stack) if stack != null else -1


# --- consultas ---------------------------------------------------------------------------

func count(id: StringName) -> int:
	var total: int = 0
	for stack: ItemStack in items:
		if stack.def.id == id:
			total += stack.quantity
	return total


func has(id: StringName) -> bool:
	return count(id) > 0


func find_first(id: StringName) -> ItemStack:
	for stack: ItemStack in items:
		if stack.def.id == id:
			return stack
	return null


## Gasta una unidad (o un uso de durabilidad) de `stack`. Lo retira si se acaba.
func consume(stack: ItemStack, uses_durability: bool = false) -> void:
	if uses_durability and stack.def.max_durability > 0:
		stack.durability -= 1
		if stack.durability <= 0:
			remove(stack)
		else:
			changed.emit()
		return
	stack.quantity -= 1
	if stack.quantity <= 0:
		remove(stack)
	else:
		changed.emit()


## Quita `amount` unidades de un objeto, de donde estén.
func take(id: StringName, amount: int = 1) -> bool:
	if count(id) < amount:
		return false
	var left: int = amount
	for stack: ItemStack in items.duplicate():
		if left <= 0:
			break
		if stack.def.id == id:
			var used: int = mini(left, stack.quantity)
			stack.quantity -= used
			left -= used
			if stack.quantity <= 0:
				remove(stack)
	changed.emit()
	return true


# --- combinación ------------------------------------------------------------------------

## Intenta combinar dos montones. Devuelve el texto para el jugador, o "" si no encajan.
func combine(a: ItemStack, b: ItemStack) -> String:
	if a == null or b == null or a == b:
		return ""
	var recipe: RecipeDef = Registry.find_recipe(a.def, b.def)
	if recipe == null:
		return ""
	var first: ItemStack = a if a.def == recipe.first else b
	var second: ItemStack = b if first == a else a
	match recipe.mode:
		RecipeDef.Mode.RECHARGE:
			var target: ItemStack = first if first.def.max_charge > 0.0 else second
			var source: ItemStack = second if target == first else first
			if target.charge >= target.def.max_charge - 0.5:
				return "Ya está cargada del todo."
			target.charge = minf(target.def.max_charge, target.charge + recipe.charge_amount)
			consume(source)
		RecipeDef.Mode.PRODUCE:
			if recipe.consume_first:
				consume(first, first.def.max_durability > 0)
			if recipe.consume_second:
				consume(second, second.def.max_durability > 0)
			add_item(recipe.result, recipe.result_quantity)
		RecipeDef.Mode.CRAFT:
			return ""
	learn_recipe(recipe.id)
	changed.emit()
	return recipe.message


## Apunta una receta como descubierta. Devuelve true si es nueva.
func learn_recipe(recipe_id: StringName) -> bool:
	if recipe_id == &"" or known_recipes.has(recipe_id):
		return false
	known_recipes.append(recipe_id)
	return true


# --- expediente ---------------------------------------------------------------------------

func add_document(id: StringName) -> bool:
	if documents.has(id):
		return false
	documents.append(id)
	var doc: DocumentDef = Registry.document(id)
	if doc != null:
		document_added.emit(doc)
	changed.emit()
	return true


func mark_read(id: StringName) -> void:
	if not documents_read.has(id):
		documents_read.append(id)


func is_unread(id: StringName) -> bool:
	return not documents_read.has(id)


# --- guardado -------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var item_data: Array = []
	for stack: ItemStack in items:
		item_data.append(stack.to_dict())
	var shortcut_data: Array = []
	for stack: ItemStack in pockets:
		shortcut_data.append(items.find(stack) if stack != null else -1)
	return {
		"version": SAVE_VERSION, "items": item_data, "shortcuts": shortcut_data,
		"documents": documents.map(func(d: StringName) -> String: return String(d)),
		"read": documents_read.map(func(d: StringName) -> String: return String(d)),
		"recipes": known_recipes.map(func(d: StringName) -> String: return String(d)),
	}


## Lee una custodia guardada. Admite el formato antiguo (bandeja por casillas + bolsillos): los
## objetos de la bandeja pasan a la lista en orden de lectura (fila a fila) y los de los bolsillos
## se añaden detrás y quedan en su atajo. Los montones iguales se juntan.
static func from_dict(data: Dictionary) -> Custody:
	var custody: Custody = Custody.new()
	if data.has("items"):
		for entry: Variant in data.get("items", []):
			custody._append_loaded(entry)
		var shortcuts: Array = data.get("shortcuts", [])
		for i: int in mini(POCKETS, shortcuts.size()):
			var index: int = int(shortcuts[i]) if shortcuts[i] != null else -1
			if index >= 0 and index < custody.items.size():
				custody.pockets[i] = custody.items[index]
	else:
		custody._load_legacy(data)
	for d: Variant in data.get("documents", []):
		custody.documents.append(StringName(d))
	for d: Variant in data.get("read", []):
		custody.documents_read.append(StringName(d))
	for r: Variant in data.get("recipes", []):
		custody.known_recipes.append(StringName(r))
	custody._merge_duplicates()
	return custody


## Partidas guardadas con la bandeja de casillas (formato 1).
func _load_legacy(data: Dictionary) -> void:
	var tray_entries: Array = []
	for entry: Variant in data.get("tray", []):
		if typeof(entry) == TYPE_DICTIONARY:
			tray_entries.append(entry)
	tray_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Array = a.get("cell", [0, 0])
		var cb: Array = b.get("cell", [0, 0])
		return int(ca[1]) < int(cb[1]) or (int(ca[1]) == int(cb[1]) and int(ca[0]) < int(cb[0])))
	for entry: Dictionary in tray_entries:
		_append_loaded(entry)
	var pocket_data: Array = data.get("pockets", [])
	for i: int in mini(POCKETS, pocket_data.size()):
		var stack: ItemStack = _append_loaded(pocket_data[i])
		if stack != null:
			pockets[i] = stack


func _append_loaded(entry: Variant) -> ItemStack:
	if typeof(entry) != TYPE_DICTIONARY:
		return null
	var stack: ItemStack = ItemStack.from_dict(entry)
	if stack != null:
		items.append(stack)
	return stack


## Junta los montones apilables repetidos (p. ej. dos de pilas de una partida antigua). El atajo
## que apuntaba a uno que desaparece pasa al que queda.
func _merge_duplicates() -> void:
	var i: int = 0
	while i < items.size():
		var keep: ItemStack = items[i]
		var j: int = i + 1
		while j < items.size():
			var other: ItemStack = items[j]
			if keep.can_merge(other):
				keep.quantity += other.quantity
				items.remove_at(j)
				var p: int = pockets.find(other)
				if p >= 0:
					pockets[p] = keep if not pockets.has(keep) else null
			else:
				j += 1
		i += 1


func _new_stack(item: ItemDef, amount: int, template: ItemStack, contaminated: bool) -> ItemStack:
	var stack: ItemStack = ItemStack.create(item, amount)
	if template != null:
		stack.durability = template.durability
		stack.charge = template.charge
	stack.contaminated = contaminated
	return stack
