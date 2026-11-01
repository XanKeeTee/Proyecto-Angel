class_name Custody
extends RefCounted
## Sistema de Custodia: el inventario de La Novena Vigilia.
## - Bandeja de custodia: cuadrícula de 5x4 donde los objetos ocupan varias casillas,
##   se pueden girar, apilar y recolocar.
## - Bolsillos: 5 huecos de acceso rápido, independientes de la bandeja (un montón por hueco).
## - Expediente personal: documentos (no ocupan sitio).
## Solo lógica: la interfaz está en scenes/ui/custody/.

signal changed
signal document_added(doc: DocumentDef)

const TRAY_SIZE: Vector2i = Vector2i(5, 4)
const POCKETS: int = 5

var tray: Array[ItemStack] = []
var pockets: Array[ItemStack] = []
var documents: Array[StringName] = []
## Documentos ya abiertos alguna vez (para marcar los nuevos).
var documents_read: Array[StringName] = []


func _init() -> void:
	pockets.resize(POCKETS)


# --- bandeja ------------------------------------------------------------------------

func stack_at(cell: Vector2i) -> ItemStack:
	for stack: ItemStack in tray:
		if stack.cells().has(cell):
			return stack
	return null


func is_inside(cell: Vector2i, footprint: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x + footprint.x <= TRAY_SIZE.x and cell.y + footprint.y <= TRAY_SIZE.y


## ¿Cabe `footprint` en `cell` sin pisar nada (salvo `ignore`)?
func can_place(footprint: Vector2i, cell: Vector2i, ignore: ItemStack = null) -> bool:
	if not is_inside(cell, footprint):
		return false
	for other: ItemStack in tray:
		if other == ignore:
			continue
		var r1: Rect2i = Rect2i(cell, footprint)
		var r2: Rect2i = Rect2i(other.cell, other.footprint())
		if r1.intersects(r2):
			return false
	return true


## Primer hueco libre (de arriba a abajo, de izquierda a derecha), probando también girado.
## Devuelve [celda, girado] o [] si no cabe.
func find_space(item: ItemDef, ignore: ItemStack = null) -> Array:
	for rotated: bool in [false, true]:
		if rotated and item.size.x == item.size.y:
			continue
		var fp: Vector2i = item.footprint(rotated)
		for y: int in TRAY_SIZE.y:
			for x: int in TRAY_SIZE.x:
				if can_place(fp, Vector2i(x, y), ignore):
					return [Vector2i(x, y), rotated]
	return []


## Mueve (o gira) un montón de la bandeja. Si cae sobre un montón igual, los junta.
func move(stack: ItemStack, cell: Vector2i, rotated: bool) -> bool:
	var target: ItemStack = stack_at(cell)
	if target != null and target != stack and target.def == stack.def and target.can_merge(stack):
		_merge_into(stack, target)
		return true
	if not can_place(stack.def.footprint(rotated), cell, stack):
		return false
	stack.cell = cell
	stack.rotated = rotated
	changed.emit()
	return true


func remove(stack: ItemStack) -> void:
	tray.erase(stack)
	var i: int = pockets.find(stack)
	if i >= 0:
		pockets[i] = null
	changed.emit()


## Añade objetos: primero completa montones, luego bolsillos vacíos no (solo bandeja).
## Devuelve las unidades que no han cabido.
func add_item(item: ItemDef, amount: int = 1, template: ItemStack = null) -> int:
	var left: int = amount
	if item.is_stackable():
		for stack: ItemStack in _all_stacks():
			if left <= 0:
				break
			if stack.def == item and stack.quantity < item.max_stack and (template == null or stack.contaminated == template.contaminated):
				var moved: int = mini(left, item.max_stack - stack.quantity)
				stack.quantity += moved
				left -= moved
	while left > 0:
		var space: Array = find_space(item)
		if space.is_empty():
			break
		var stack: ItemStack = ItemStack.create(item, mini(left, maxi(1, item.max_stack)))
		if template != null:
			stack.durability = template.durability
			stack.charge = template.charge
			stack.contaminated = template.contaminated
		stack.cell = space[0]
		stack.rotated = space[1]
		tray.append(stack)
		left -= stack.quantity
	if left < amount:
		changed.emit()
	return left


## Cuántas unidades caben ahora mismo (para avisar antes de recoger).
func room_for(item: ItemDef, amount: int) -> int:
	var probe: Custody = Custody.from_dict(to_dict())
	return amount - probe.add_item(item, amount)


# --- bolsillos ------------------------------------------------------------------------

## Pasa un montón de la bandeja a un bolsillo. Si el bolsillo está ocupado, intercambia.
func to_pocket(stack: ItemStack, index: int) -> bool:
	if index < 0 or index >= POCKETS or not tray.has(stack):
		return false
	var current: ItemStack = pockets[index]
	tray.erase(stack)
	pockets[index] = stack
	if current != null:
		var space: Array = find_space(current.def)
		if space.is_empty():
			# No cabe lo que había: se deshace.
			pockets[index] = current
			tray.append(stack)
			return false
		current.cell = space[0]
		current.rotated = space[1]
		tray.append(current)
	changed.emit()
	return true


## Devuelve el contenido de un bolsillo a la bandeja (en `cell` o en el primer hueco).
func from_pocket(index: int, cell: Vector2i = Vector2i(-1, -1), rotated: bool = false) -> bool:
	var stack: ItemStack = pockets[index]
	if stack == null:
		return false
	if cell.x < 0:
		var space: Array = find_space(stack.def)
		if space.is_empty():
			return false
		cell = space[0]
		rotated = space[1]
	elif not can_place(stack.def.footprint(rotated), cell):
		return false
	pockets[index] = null
	stack.cell = cell
	stack.rotated = rotated
	tray.append(stack)
	changed.emit()
	return true


func swap_pockets(a: int, b: int) -> void:
	var tmp: ItemStack = pockets[a]
	pockets[a] = pockets[b]
	pockets[b] = tmp
	changed.emit()


# --- consultas ---------------------------------------------------------------------------

func count(id: StringName) -> int:
	var total: int = 0
	for stack: ItemStack in _all_stacks():
		if stack.def.id == id:
			total += stack.quantity
	return total


func has(id: StringName) -> bool:
	return count(id) > 0


func find_first(id: StringName) -> ItemStack:
	for stack: ItemStack in _all_stacks():
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
	for stack: ItemStack in _all_stacks():
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


func occupied_cells() -> int:
	var total: int = 0
	for stack: ItemStack in tray:
		total += stack.footprint().x * stack.footprint().y
	return total


# --- combinación ------------------------------------------------------------------------

## Intenta combinar dos montones. Devuelve el texto para el jugador, o "" si no encajan.
func combine(a: ItemStack, b: ItemStack) -> String:
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
			# El resultado hereda la contaminación si cualquiera la tenía y la receta no la limpia.
			if recipe.consume_first:
				consume(first, first.def.max_durability > 0)
			if recipe.consume_second:
				consume(second, second.def.max_durability > 0)
			var leftover: int = add_item(recipe.result, recipe.result_quantity)
			if leftover > 0:
				return recipe.message + "\n(No queda sitio en la bandeja: lo sostienes un momento y lo dejas caer.)"
	changed.emit()
	return recipe.message


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
	var tray_data: Array = []
	for stack: ItemStack in tray:
		tray_data.append(stack.to_dict())
	var pocket_data: Array = []
	for stack: ItemStack in pockets:
		pocket_data.append(stack.to_dict() if stack != null else null)
	return {
		"tray": tray_data, "pockets": pocket_data,
		"documents": documents.map(func(d: StringName) -> String: return String(d)),
		"read": documents_read.map(func(d: StringName) -> String: return String(d)),
	}


static func from_dict(data: Dictionary) -> Custody:
	var custody: Custody = Custody.new()
	for entry: Variant in data.get("tray", []):
		var stack: ItemStack = ItemStack.from_dict(entry)
		if stack != null:
			custody.tray.append(stack)
	var pocket_data: Array = data.get("pockets", [])
	for i: int in mini(POCKETS, pocket_data.size()):
		if pocket_data[i] != null:
			custody.pockets[i] = ItemStack.from_dict(pocket_data[i])
	for d: Variant in data.get("documents", []):
		custody.documents.append(StringName(d))
	for d: Variant in data.get("read", []):
		custody.documents_read.append(StringName(d))
	return custody


func _all_stacks() -> Array[ItemStack]:
	var result: Array[ItemStack] = []
	for stack: ItemStack in pockets:
		if stack != null:
			result.append(stack)
	result.append_array(tray)
	return result


func _merge_into(source: ItemStack, target: ItemStack) -> void:
	var moved: int = mini(source.quantity, target.def.max_stack - target.quantity)
	target.quantity += moved
	source.quantity -= moved
	if source.quantity <= 0:
		remove(source)
	changed.emit()
