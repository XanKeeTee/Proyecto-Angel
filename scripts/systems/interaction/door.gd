class_name Door
extends Interactable
## Puerta del mapa. Cambia sus tiles al abrirse o cerrarse (los tiles abiertos no tienen
## colisión) y, si se indica, lleva al otro lado de un muro alto con un fundido.
##
## Las puertas de la pared norte de una sala (3 casillas de alto) llevan a la sala de arriba:
## la casilla base es la parte baja de la puerta; `warp_front_to` es adónde llegas al cruzarla.
## Desde el otro lado se entra por el hueco del muro (`back_cell`), que lleva a `warp_back_to`.

## Casillas de tile que cambian, relativas a la base, con su tile cerrado y abierto (coordenadas de atlas).
@export var tile_cells: Array[Vector2i] = []
@export var closed_tiles: Array[Vector2i] = []
@export var open_tiles: Array[Vector2i] = []
## Capa de tiles donde están (la escena la asigna).
@export var tile_layer: TileMapLayer
@export var tile_source: int = 0

@export_group("Paso al otro lado")
## Si es >= 0, entrar en la casilla base estando abierta lleva a esta casilla.
@export var warp_front_to: Vector2i = Vector2i(-1, -1)
@export var warp_front_facing: Vector2i = Vector2i.UP
## Casilla (relativa) del hueco por el otro lado y adónde lleva.
@export var back_cell: Vector2i = Vector2i(0, -999)
@export var warp_back_to: Vector2i = Vector2i(-1, -1)
@export var warp_back_facing: Vector2i = Vector2i.DOWN


func _ready() -> void:
	openable = true
	kind = Kind.CONTAINER
	super._ready()


## Destino si el jugador entra en `cell`: [celda, dirección] o [].
func warp_for(cell: Vector2i) -> Array:
	if not is_open:
		return []
	if cell == base_cell() and warp_front_to.x >= 0:
		return [warp_front_to, warp_front_facing]
	if back_cell.y != -999 and cell == base_cell() + back_cell and warp_back_to.x >= 0:
		return [warp_back_to, warp_back_facing]
	return []


func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = super.cells()
	if back_cell.y != -999 and not result.has(base_cell() + back_cell):
		result.append(base_cell() + back_cell)
	return result


func _container_actions(actions: Array[Dictionary], character: CharacterState) -> void:
	if is_locked:
		if key_item != null and character.custody.has(key_item.id):
			actions.append({"id": ACT_UNLOCK, "label": "Abrir con " + key_item.display_name.to_lower()})
		else:
			actions.append({"id": ACT_OPEN, "label": "Abrir"})
	elif not is_open:
		actions.append({"id": ACT_OPEN, "label": "Abrir"})
	else:
		actions.append({"id": ACT_CLOSE, "label": "Cerrar"})


func _open(result: InteractionResult, character: CharacterState) -> void:
	if is_locked or not _flags_ok([requires_flag]):
		super._open(result, character)
		return
	is_open = true
	result.sound = sound_open
	result.add(search_text)
	_set_flag(flag_on_open)


func _apply_visuals() -> void:
	super._apply_visuals()
	if tile_layer == null:
		return
	var tiles: Array[Vector2i] = open_tiles if is_open else closed_tiles
	for i: int in mini(tile_cells.size(), tiles.size()):
		tile_layer.set_cell(base_cell() + tile_cells[i], tile_source, tiles[i])
