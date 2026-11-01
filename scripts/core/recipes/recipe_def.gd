class_name RecipeDef
extends Resource
## Combinación de dos objetos de la custodia. Un `.tres` por receta en `data/recipes/`.
## El orden de `first` y `second` no importa.

enum Mode {
	PRODUCE,  ## Crea `result` (y gasta lo indicado).
	RECHARGE,  ## Suma carga al objeto que la tenga (p. ej. pilas + linterna).
}

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


func matches(a: ItemDef, b: ItemDef) -> bool:
	return (a == first and b == second) or (a == second and b == first)
