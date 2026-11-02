class_name LootPlan
extends Resource
## Botín aleatorio de un mapa. Al empezar partida se tira una vez con una semilla que se guarda
## (al cargar sale lo mismo). Lo del camino principal no se toca: en los muebles del plan solo se
## quita el contenido «suelto» (lo que no es documento, ni objeto clave, ni está en `fixed_items`)
## y se sustituye por lo que salga. Ver LootRoller y docs/design/escenas/prologo.md («Botín»).
## Datos: data/loot/*.tres (generados por tools/data/build_prologue_data.gd).

## Muebles con botín aleatorio (su contenido suelto original se descarta).
@export var slots: Array[LootSlot] = []
## Repartos garantizados (pilas, vendas, ropa rara…), en orden.
@export var scatter: Array[LootScatter] = []
## Objetos que nunca se quitan de un mueble aunque esté en el plan (camino principal).
@export var fixed_items: Array[StringName] = []


## Si una entrada del contenido original se conserva.
func keeps(entry: LootEntry) -> bool:
	if entry.document != null or entry.item == null:
		return true
	return entry.item.key_item or fixed_items.has(entry.item.id)


func slot(object_id: StringName) -> LootSlot:
	for s: LootSlot in slots:
		if s.object_id == object_id:
			return s
	return null
