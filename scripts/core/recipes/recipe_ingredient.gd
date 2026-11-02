class_name RecipeIngredient
extends Resource
## Un ingrediente de una receta de fabricar (`RecipeDef` en modo CRAFT).

@export var item: ItemDef
@export var amount: int = 1
## Herramienta: hace falta tenerla, pero no se gasta (salvo `uses_durability`).
@export var tool: bool = false
## Si es herramienta con durabilidad, gasta un uso.
@export var uses_durability: bool = false


static func create(def: ItemDef, count: int = 1, is_tool: bool = false, wear: bool = false) -> RecipeIngredient:
	var ing: RecipeIngredient = RecipeIngredient.new()
	ing.item = def
	ing.amount = count
	ing.tool = is_tool
	ing.uses_durability = wear
	return ing
