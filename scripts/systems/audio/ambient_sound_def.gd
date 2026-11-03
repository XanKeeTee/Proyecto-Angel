class_name AmbientSoundDef
extends Resource
## Un sonido del paisaje sonoro de un mapa (ver `SoundscapeDef` y `Soundscape`):
## - LOOP: un bucle suave en uno o varios puntos fijos (o junto a cada luz con corriente), o un
##   tono de sala que acompaña al jugador mientras esté en sus zonas (LISTENER).
## - ONE_SHOT: un sonido suelto que salta al azar, con enfriamiento, cerca del jugador.
## Depende del estado: corriente sí/no y zona (sala, planta o sótano) donde está el jugador.
## Los sonidos son WAV de assets/audio/sfx/ (de Freesound; ver tools/audio/sound_manifest.json).

enum Kind { LOOP, ONE_SHOT }
## Cuándo suena según la corriente del edificio (GameState.FLAG_POWER).
enum Power { ANY, ON, OFF }
## Dónde están los emisores.
enum Placement {
	CELLS,          ## En las casillas de `cells`.
	LIGHTS,         ## Junto a cada luz del edificio que necesita corriente y no está rota (solo LOOP).
	AROUND_PLAYER,  ## Suelto: en una dirección al azar, a `distance` píxeles del jugador.
	LISTENER,       ## Bucle sin posición: va con el jugador (tono de sala, aire del edificio).
}

@export var id: StringName = &""
@export var kind: Kind = Kind.LOOP
## Nombres de los sonidos (sin .wav). LOOP usa el primero; ONE_SHOT, uno al azar.
@export var sounds: PackedStringArray = []
@export var power: Power = Power.ANY
## Zonas (en casillas) donde tiene que estar el jugador para que suene. Vacío = en todo el mapa.
## Con LIGHTS, además, solo las luces de dentro de estas zonas.
@export var regions: Array[Rect2i] = []
@export var placement: Placement = Placement.CELLS
@export var cells: Array[Vector2i] = []

@export_group("Volumen y distancia")
## Volumen del emisor (dB), antes del bus «Ambiente». Bajo: es fondo.
@export var volume_db: float = -14.0
## A partir de esta distancia (píxeles) ya no se oye.
@export var max_distance: float = 260.0
@export var attenuation: float = 1.8
@export var pitch_jitter: float = 0.05
## Bucles: segundos del fundido al entrar o salir de su zona (< 0 = el `loop_fade` del paisaje).
## Los tonos de sala, más largos: así el cambio de sala es un fundido cruzado.
@export var fade: float = -1.0

@export_group("Sueltos")
## Segundos entre dos veces [mín, máx].
@export var cooldown: Vector2 = Vector2(45.0, 100.0)
## Espera antes de la primera vez desde que el sonido puede sonar [mín, máx].
@export var first_delay: Vector2 = Vector2(8.0, 30.0)
## AROUND_PLAYER: distancia al jugador [mín, máx] en píxeles.
@export var distance: Vector2 = Vector2(120.0, 260.0)


## Si puede sonar con el jugador en `cell` y la corriente `powered`.
func fits(cell: Vector2i, powered: bool) -> bool:
	if power == Power.ON and not powered:
		return false
	if power == Power.OFF and powered:
		return false
	return in_regions(cell)


func in_regions(cell: Vector2i) -> bool:
	if regions.is_empty():
		return true
	for r: Rect2i in regions:
		if r.has_point(cell):
			return true
	return false
