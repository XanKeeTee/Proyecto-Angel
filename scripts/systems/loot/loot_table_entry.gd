class_name LootTableEntry
extends Resource
## Una línea de una tabla de botín: qué objeto, con qué peso y en qué cantidad.

@export var item: ItemDef
## Peso relativo frente a las otras entradas de la tabla.
@export var weight: float = 1.0
@export var min_quantity: int = 1
@export var max_quantity: int = 1
