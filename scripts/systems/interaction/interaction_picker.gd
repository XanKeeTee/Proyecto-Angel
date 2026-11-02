class_name InteractionPicker
extends RefCounted
## Elige con qué objeto se interactúa: el más cercano a los pies del protagonista y más
## alineado con hacia dónde mira. No depende de la escena (se prueba sin nodos visuales).
##
## Para cada casilla de interacción del objeto se mide la distancia desde los pies hasta el
## punto más cercano de la casilla y el ángulo entre la mirada y el centro de la casilla.
## Puntuación = distancia + ángulo (en grados) × ANGLE_WEIGHT; gana la más baja.

## Distancia máxima (píxeles) de los pies al borde de la casilla.
const REACH: float = 26.0
## Ángulo máximo con la mirada (grados). Pegado al objeto (< CLOSE) vale cualquier ángulo.
const MAX_ANGLE: float = 80.0
const CLOSE: float = 4.0
const ANGLE_WEIGHT: float = 0.35
const TILE_SIZE: int = 32


## Puntuación de una casilla (INF si no está al alcance).
static func score_cell(cell: Vector2i, feet: Vector2, facing_angle: float) -> float:
	var rect: Rect2 = Rect2(Vector2(cell * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
	var nearest: Vector2 = feet.clamp(rect.position, rect.end)
	var distance: float = feet.distance_to(nearest)
	if distance > REACH:
		return INF
	var to_center: Vector2 = rect.get_center() - feet
	var angle: float = 0.0
	if to_center.length() > 1.0:
		angle = absf(rad_to_deg(Vector2.from_angle(facing_angle).angle_to(to_center)))
	if angle > MAX_ANGLE and distance > CLOSE:
		return INF
	return distance + angle * ANGLE_WEIGHT


## Puntuación de un objeto (la mejor de sus casillas).
static func score(it: Interactable, feet: Vector2, facing_angle: float) -> float:
	var best: float = INF
	for cell: Vector2i in it.cells():
		best = minf(best, score_cell(cell, feet, facing_angle))
	return best


## El mejor objeto activo de la lista, o null.
static func pick(candidates: Array, feet: Vector2, facing_angle: float) -> Interactable:
	var best: Interactable = null
	var best_score: float = INF
	for node: Variant in candidates:
		var it: Interactable = node as Interactable
		if it == null or not it.is_active():
			continue
		var s: float = score(it, feet, facing_angle)
		if s < best_score:
			best_score = s
			best = it
	return best
