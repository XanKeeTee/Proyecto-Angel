class_name Door
extends Interactable
## Puerta del mapa. Se cruza andando: el hueco del muro (remate + 3 tramos de pared) es suelo
## transitable y la puerta pone o quita su propia colisión y su oclusor de luz al cerrarse o
## abrirse. El marco, el dintel y la hoja son un sprite (hijo «Sprite2D») que se ordena por la
## línea del pie del muro: si el jugador está dentro del hueco, el marco se dibuja por encima.
##
## La casilla base es la parte baja de la puerta (el tramo de pared que toca el suelo del lado
## de delante). `footprint` cubre las cuatro casillas del hueco, de la base hacia arriba.
##
## Las escaleras usan el modo antiguo: siempre abiertas, sin colisión propia, y al pisar la
## casilla base llevan a otra planta (`warp_front_to`) con un fundido corto.

## Casillas de tile que cambian, relativas a la base, con su tile cerrado y abierto (coordenadas de
## atlas). Solo para pasos dibujados con tiles (escaleras); las puertas normales usan el sprite.
@export var tile_cells: Array[Vector2i] = []
@export var closed_tiles: Array[Vector2i] = []
@export var open_tiles: Array[Vector2i] = []
## Capa de tiles donde están (la escena la asigna).
@export var tile_layer: TileMapLayer
@export var tile_source: int = 0
## Siempre abierta y sin acciones (escaleras, pasos sin puerta).
@export var always_open: bool = false

@export_group("Paso al otro lado")
## Si es >= 0, entrar en la casilla base estando abierta lleva a esta casilla (escaleras).
@export var warp_front_to: Vector2i = Vector2i(-1, -1)
@export var warp_front_facing: Vector2i = Vector2i.UP
## Casilla (relativa) del hueco por el otro lado y adónde lleva (modo antiguo; sin uso en las
## puertas que se cruzan andando).
@export var back_cell: Vector2i = Vector2i(0, -999)
@export var warp_back_to: Vector2i = Vector2i(-1, -1)
@export var warp_back_facing: Vector2i = Vector2i.DOWN

@onready var _occluder: LightOccluder2D = get_node_or_null(^"Occluder") as LightOccluder2D


func _ready() -> void:
	openable = true
	kind = Kind.CONTAINER
	if always_open:
		start_open = true
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


## Casillas del hueco que se cruza andando (vacío en las escaleras).
func passage_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if warp_front_to.x >= 0:
		return result
	for offset: Vector2i in footprint:
		result.append(base_cell() + offset)
	return result


func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = super.cells()
	if back_cell.y != -999 and not result.has(base_cell() + back_cell):
		result.append(base_cell() + back_cell)
	return result


func _container_actions(actions: Array[Dictionary], character: CharacterState) -> void:
	if always_open:
		return
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
	var body: CollisionObject2D = get_node_or_null(^"Body") as CollisionObject2D
	if body != null:
		var solid: bool = visible and not is_open
		body.process_mode = Node.PROCESS_MODE_INHERIT if solid else Node.PROCESS_MODE_DISABLED
	if _occluder != null:
		_occluder.visible = visible and not is_open
	if tile_layer == null:
		return
	var tiles: Array[Vector2i] = open_tiles if is_open else closed_tiles
	for i: int in mini(tile_cells.size(), tiles.size()):
		tile_layer.set_cell(base_cell() + tile_cells[i], tile_source, tiles[i])
