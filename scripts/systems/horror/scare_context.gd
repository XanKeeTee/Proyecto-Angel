class_name ScareContext
extends RefCounted
## Foto de la situación del jugador que usan `ScareDef.fits` y `ScarePlanner`.
## La rellena `HorrorDirector`; en las pruebas se crea a mano.

## Segundos de juego (reloj del director).
var now: float = 0.0
## Casilla del jugador.
var cell: Vector2i = Vector2i.ZERO
var flashlight_on: bool = false
## 0 con la Mente alta, 1 con la Mente muy baja.
var unease: float = 0.0
## Banderas activas (normalmente `GameState.flags`).
var flags: Dictionary[StringName, bool] = {}


func has_flag(flag: StringName) -> bool:
	return flags.get(flag, false)
