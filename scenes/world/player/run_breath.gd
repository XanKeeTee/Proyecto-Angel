class_name RunBreath
extends RefCounted
## Aliento para correr del protagonista (lógica pura, sin nodos).
## Recién operado y con puntos en la espalda: corre poco y se ahoga pronto. Con el aliento
## lleno aguanta unos 4 s de carrera; se recupera andando (despacio) o parado (más deprisa),
## tras una pausa corta. Si se agota, no vuelve a correr hasta recuperar una parte.
## El estado del Cuerpo y el sangrado lo empeoran todo: se gasta antes, se recupera peor y
## la carrera es menos rápida.

## Se ha quedado sin aliento (para la respiración agitada).
signal exhausted

## Aliento que se gasta por segundo corriendo del todo (1 = lleno): ~4 s de carrera.
const DRAIN_PER_SECOND: float = 0.24
## Recuperación por segundo andando y parado.
const RECOVER_WALKING: float = 0.09
const RECOVER_STILL: float = 0.22
## Segundos sin correr antes de empezar a recuperarse.
const RECOVER_DELAY: float = 0.7
## Tras agotarse, aliento mínimo para volver a correr.
const RECOVER_TO_RUN: float = 0.35
## Velocidad de carrera respecto a la de andar, con el Cuerpo bien y con el Cuerpo al mínimo.
const RUN_SPEED_FIT: float = 1.5
const RUN_SPEED_HURT: float = 1.2
## Cuánto más se gasta con el Cuerpo al mínimo, y cuánto peor se recupera.
const DRAIN_HURT: float = 2.0
const RECOVER_HURT: float = 0.5
## Con sangrado: gasta más, recupera peor y corre algo menos.
const DRAIN_BLEEDING: float = 1.5
const RECOVER_BLEEDING: float = 0.7
const SPEED_BLEEDING: float = 0.92
## Cuerpo (proporción 0..1) a partir del cual está "en forma" y al que está "al mínimo".
const BODY_FIT: float = 0.7
const BODY_HURT: float = 0.2
## Por debajo de esta intensidad de carrera no se considera que corre.
const RUN_EPSILON: float = 0.05

## Aliento actual (0..1).
var amount: float = 1.0
## Agotado: no puede correr hasta recuperar RECOVER_TO_RUN.
var winded: bool = false
## Forma física según el Cuerpo (1 = bien, 0 = al mínimo).
var condition: float = 1.0
var bleeding: bool = false

var _rest_time: float = 0.0


## Ajusta la forma física: `body_ratio` es el Cuerpo entre 0 y 1.
func set_condition(body_ratio: float, is_bleeding: bool) -> void:
	condition = clampf((body_ratio - BODY_HURT) / (BODY_FIT - BODY_HURT), 0.0, 1.0)
	bleeding = is_bleeding


## Si ahora mismo puede correr.
func can_run() -> bool:
	return not winded and amount > 0.0


## Velocidad de carrera respecto a la de andar.
func speed_multiplier() -> float:
	return lerpf(RUN_SPEED_HURT, RUN_SPEED_FIT, condition) * (SPEED_BLEEDING if bleeding else 1.0)


## Avanza el tiempo. `running` es la intensidad de la carrera (0..1, con la transición);
## `moving`, si se está desplazando (andando se recupera más despacio que parado).
func tick(delta: float, running: float, moving: bool) -> void:
	if running > RUN_EPSILON:
		_rest_time = 0.0
		if amount <= 0.0:
			return
		amount -= DRAIN_PER_SECOND * _drain_scale() * running * delta
		if amount <= 0.0:
			amount = 0.0
			winded = true
			exhausted.emit()
		return
	_rest_time += delta
	if _rest_time < RECOVER_DELAY or amount >= 1.0:
		return
	var rate: float = RECOVER_WALKING if moving else RECOVER_STILL
	amount = minf(1.0, amount + rate * _recover_scale() * delta)
	if winded and amount >= RECOVER_TO_RUN:
		winded = false


## Lleno de nuevo (al cargar partida o tras una escena).
func reset() -> void:
	amount = 1.0
	winded = false
	_rest_time = 0.0


func _drain_scale() -> float:
	return lerpf(DRAIN_HURT, 1.0, condition) * (DRAIN_BLEEDING if bleeding else 1.0)


func _recover_scale() -> float:
	return lerpf(RECOVER_HURT, 1.0, condition) * (RECOVER_BLEEDING if bleeding else 1.0)
