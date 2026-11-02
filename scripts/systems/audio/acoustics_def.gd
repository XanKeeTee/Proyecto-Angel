class_name AcousticsDef
extends Resource
## Acústica de un mapa: la lista de espacios (`AcousticSpaceDef`) con sus zonas y el espacio por
## defecto. Se guarda en data/audio/<mapa>_acoustics.tres y la usa `RoomAcoustics` a través de
## `SoundscapeDef.acoustics`.

@export var spaces: Array[AcousticSpaceDef] = []
## Donde no hay ninguna zona (o null = sin eco).
@export var fallback: AcousticSpaceDef
## Segundos que tarda en pasar de la acústica de una sala a la de otra.
@export var transition: float = 1.2


## Espacio de la casilla `cell` (el primero que la contiene; si ninguno, `fallback` o el neutro).
func space_at(cell: Vector2i) -> AcousticSpaceDef:
	for space: AcousticSpaceDef in spaces:
		if space.contains(cell):
			return space
	return fallback if fallback != null else AcousticSpaceDef.neutral()
