class_name Crafting
extends RefCounted
## Fabricar y rasgar en la custodia. Solo lógica (sin escena): la usa la pestaña FABRICAR y se
## prueba en tests/unit/test_crafting.gd.
##
## - Recetas de fabricar (`RecipeDef` en modo CRAFT): varios ingredientes y herramientas.
##   Se descubren al llevar encima alguno de sus ingredientes (o desde el principio).
## - Las combinaciones de dos objetos aparecen en la lista cuando ya se han hecho una vez.
## - Rasgar: una prenda (no puesta) u otro objeto de tela se convierte en tiras de tela.


## Recetas que el jugador conoce, en el orden de `data/recipes/` (sin recargas de linterna).
static func known_recipes(custody: Custody) -> Array[RecipeDef]:
	discover(custody)
	var result: Array[RecipeDef] = []
	for recipe: RecipeDef in Registry.recipes():
		if recipe.mode == RecipeDef.Mode.RECHARGE:
			continue
		if recipe.known_from_start or custody.known_recipes.has(recipe.id):
			result.append(recipe)
	result.sort_custom(func(a: RecipeDef, b: RecipeDef) -> bool:
		return a.mode == RecipeDef.Mode.CRAFT and b.mode != RecipeDef.Mode.CRAFT or \
			(a.mode == b.mode and a.title() < b.title()))
	return result


## Recetas de fabricar que todavía no se conocen (para decir cuántas faltan).
static func unknown_count(custody: Custody) -> int:
	var n: int = 0
	for recipe: RecipeDef in Registry.recipes():
		if recipe.mode == RecipeDef.Mode.CRAFT and not recipe.known_from_start and not custody.known_recipes.has(recipe.id):
			n += 1
	return n


## Apunta como conocidas las recetas de fabricar de las que se lleva algún ingrediente.
## Devuelve las nuevas.
static func discover(custody: Custody) -> Array[RecipeDef]:
	var found: Array[RecipeDef] = []
	for recipe: RecipeDef in Registry.recipes():
		if recipe.mode != RecipeDef.Mode.CRAFT or custody.known_recipes.has(recipe.id):
			continue
		for ing: RecipeIngredient in recipe.ingredients:
			if not ing.tool and ing.item != null and custody.has(ing.item.id):
				custody.learn_recipe(recipe.id)
				found.append(recipe)
				break
	return found


## Unidades disponibles de un ingrediente (para herramientas con durabilidad: si queda algún uso).
static func available(custody: Custody, ing: RecipeIngredient) -> int:
	if ing.item == null:
		return 0
	return custody.count(ing.item.id)


## Lo que falta para hacer la receta: [{def, have, need, tool}] solo de lo que no llega.
static func missing(custody: Custody, recipe: RecipeDef) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ing: RecipeIngredient in recipe.ingredient_list():
		var have: int = available(custody, ing)
		if have < ing.amount:
			result.append({"def": ing.item, "have": have, "need": ing.amount, "tool": ing.tool})
	return result


static func can_craft(custody: Custody, recipe: RecipeDef) -> bool:
	return recipe.result != null and missing(custody, recipe).is_empty() and _fits_after(custody, recipe)


## Hace la receta: gasta ingredientes (y usos de herramientas) y da el resultado.
## Devuelve el texto para el jugador, o "" si no se puede (no se toca nada).
static func craft(custody: Custody, recipe: RecipeDef) -> String:
	if recipe.mode == RecipeDef.Mode.RECHARGE or recipe.result == null:
		return ""
	if not missing(custody, recipe).is_empty() or not _fits_after(custody, recipe):
		return ""
	_spend(custody, recipe)
	custody.add_item(recipe.result, recipe.result_quantity)
	custody.learn_recipe(recipe.id)
	return recipe.message if recipe.message != "" else "Fabricas: " + recipe.title() + "."


## Por qué no se puede fabricar ahora (texto corto), o "" si se puede.
static func blocker(custody: Custody, recipe: RecipeDef) -> String:
	var lack: Array[Dictionary] = missing(custody, recipe)
	if not lack.is_empty():
		var names: PackedStringArray = []
		for entry: Dictionary in lack:
			var def: ItemDef = entry["def"]
			names.append(def.display_name.to_lower() + ("" if entry["tool"] else " ×%d" % (int(entry["need"]) - int(entry["have"]))))
		return "Falta: " + ", ".join(names) + "."
	return ""


# --- rasgar ---------------------------------------------------------------------------------

## Se puede rasgar este montón ahora (no aplica a la ropa puesta: esa no está en la custodia).
static func can_tear(custody: Custody, stack: ItemStack) -> bool:
	return stack != null and custody.contains(stack) and stack.def.tear_yield() > 0 \
		and not stack.def.key_item and Registry.item(stack.def.tear_result_id()) != null


## Rasga una unidad del montón y da tiras de tela. Devuelve el texto para el jugador o "".
static func tear(custody: Custody, stack: ItemStack) -> String:
	if not can_tear(custody, stack):
		return ""
	var strip: ItemDef = Registry.item(stack.def.tear_result_id())
	var amount: int = stack.def.tear_yield()
	custody.consume(stack)
	custody.add_item(strip, amount)
	return "Rasgas %s en %d %s." % [stack.def.display_name.to_lower(), amount,
		"tira" if amount == 1 else "tiras"]


# --- interno ---------------------------------------------------------------------------------

static func _spend(custody: Custody, recipe: RecipeDef) -> void:
	for ing: RecipeIngredient in recipe.ingredient_list():
		if ing.tool:
			if ing.uses_durability:
				var tool_stack: ItemStack = custody.find_first(ing.item.id)
				if tool_stack != null:
					custody.consume(tool_stack, true)
			continue
		custody.take(ing.item.id, ing.amount)


## Ya no hay límite de espacio: el resultado siempre cabe si la receta tiene resultado.
static func _fits_after(_custody: Custody, recipe: RecipeDef) -> bool:
	return recipe.result != null
