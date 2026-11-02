class_name LootScatter
extends Resource
## Reparto garantizado: `copies` ejemplares de un objeto en muebles distintos elegidos al azar
## entre `candidates` (por `object_id`). Con `chance` < 1 puede no aparecer en toda la partida
## (la ropa rara). Así el total del mapa está controlado y solo cambia dónde está.

@export var item: ItemDef
## Probabilidad (0..1) de que la regla se aplique en esta partida.
@export_range(0.0, 1.0) var chance: float = 1.0
## Cuántos ejemplares se reparten (cada uno en un mueble distinto si hay bastantes).
@export var copies: int = 1
@export var min_quantity: int = 1
@export var max_quantity: int = 1
@export var candidates: Array[StringName] = []
