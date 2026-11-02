class_name SoundscapeDef
extends Resource
## Paisaje sonoro de un mapa: la lista de bucles y sonidos sueltos (`AmbientSoundDef`) y cómo
## entran y conviven con el terror. Se guarda en data/audio/<mapa>_soundscape.tres y lo usa
## `Soundscape`. Diseño y lista de sonidos: docs/tech/sonidos.md.

@export var sounds: Array[AmbientSoundDef] = []

@export_group("Mezcla")
## Volumen (dB) del ambiente de fondo del mapa (%Ambience), si se le pasa a `Soundscape`.
@export var bed_volume_db: float = -4.0
## Entrada gradual (s) de todo el paisaje la primera vez que el jugador tiene el control
## (tras el despertar o al cargar).
@export var fade_in: float = 9.0
## Fundido (s) de cada bucle al entrar o salir de su zona o al cambiar la corriente.
@export var loop_fade: float = 1.6

@export_group("Convivencia con el terror")
## Silencio de los sonidos sueltos tras un susto del director de terror (s).
@export var quiet_after_scare: float = 16.0
## Separación mínima entre dos sonidos sueltos cualesquiera (s).
@export var min_gap: float = 9.0
## Bajada (dB) de los bucles mientras la entidad está presente.
@export var stalker_duck_db: float = -9.0
