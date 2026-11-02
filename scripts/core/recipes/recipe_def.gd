class_name RecipeDef
extends Resource
## Receta de la custodia. Un `.tres` por receta en `data/recipes/`.
## - PRODUCE y RECHARGE son **combinaciones** de dos objetos (`first` y `second`; el orden no importa):
##   se hacen soltando uno encima de otro, con C, o desde la pestaña FABRICAR › Combinar.
## - CRAFT es una receta de **fabricar** con varios ingredientes (`ingredients`) desde FABRICAR › Fabricar.

enum Mode {
	PRODUCE,  ## Crea `result` (y gasta lo indicado).
	RECHARGE,  ## Suma carga al objeto que la tenga (p. ej. pilas + linterna).
	CRAFT,  ## Varios ingredientes (y herramientas) dan `result`.
}

## Identificador estable (para recordar las recetas descubiertas en el guardado).
@export var id: StringName = &""
## Nombre en la lista de recetas (vacío = el del resultado).
@export var display_name: String = ""
@export var first: ItemDef
@export var second: ItemDef
@export var mode: Mode = Mode.PRODUCE
@export var result: ItemDef
@export var result_quantity: int = 1
## Qué se gasta: una unidad (o un uso de durabilidad, si tiene) de cada uno.
@export var consume_first: bool = true
@export var consume_second: bool = true
## Para RECHARGE: carga que se suma.
@export var charge_amount: float = 50.0
@export_multiline var message: String = ""
## Sonido al hacerla (vacío = el genérico de fabricar).
@export var sound: String = ""

@export_group("Fabricar")
## Para CRAFT: ingredientes y herramientas.
@export var ingredients: Array[RecipeIngredient] = []
## Se conoce desde el principio. Si no, se descubre al llevar encima alguno de sus ingredientes.
@export var known_from_start: bool = false


## Para combinaciones: ¿encajan estos dos objetos?
func matches(a: ItemDef, b: ItemDef) -> bool:
	if mode == Mode.CRAFT:
		return false
	return (a == first and b == second) or (a == second and b == first)


func is_combination() -> bool:
	return mode != Mode.CRAFT


func title() -> String:
	if display_name != "":
		return display_name
	return result.display_name if result != null else String(id)


## Ingredientes como lista, también para las combinaciones (para mostrarlas en FABRICAR).
func ingredient_list() -> Array[RecipeIngredient]:
	if mode == Mode.CRAFT:
		return ingredients
	var list: Array[RecipeIngredient] = []
	for pair: Array in [[first, consume_first], [second, consume_second]]:
		var def: ItemDef = pair[0]
		if def == null:
			continue
		# Lo que tiene durabilidad (desinfectante, destornillador) gasta un uso, como herramienta.
		var wears: bool = bool(pair[1]) and def.max_durability > 0
		list.append(RecipeIngredient.create(def, 1, not bool(pair[1]) or wears, wears))
	return list
