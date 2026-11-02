class_name AcousticSpaceDef
extends Resource
## Acústica de un tipo de sala (habitación alicatada, pasillo largo, quirófano, escalera de
## hormigón, sótano, morgue…): parámetros de la reverberación y de la ecualización del bus «Sala»
## mientras el jugador está en alguna de sus `regions`. Lo aplica `RoomAcoustics`.
## La mezcla es moderada a propósito: que se note un poco de eco, sin embarrar.

## Número de parámetros de `to_params` (8 de reverberación + 6 bandas de EQ).
const PARAM_COUNT: int = 14

@export var id: StringName = &""
## Zonas (en casillas) de este espacio. La primera que contenga al jugador manda.
@export var regions: Array[Rect2i] = []

@export_group("Reverberación")
## Tamaño de la sala (0..1): cuánto dura la cola.
@export_range(0.0, 1.0) var room_size: float = 0.3
## Amortiguación de los agudos de la cola (0..1): alto = paredes blandas (madera, papel, tela).
@export_range(0.0, 1.0) var damping: float = 0.5
## Anchura estéreo de la cola (0..1).
@export_range(0.0, 1.0) var spread: float = 0.6
## Paso alto de la cola (0..1): quita graves al eco para que no retumbe.
@export_range(0.0, 1.0) var hipass: float = 0.2
## Señal reverberada (0..1). Moderada: 0,08-0,28.
@export_range(0.0, 1.0) var wet: float = 0.15
## Señal directa (0..1).
@export_range(0.0, 1.0) var dry: float = 1.0
## Retardo de la primera reflexión (ms): pasillos y salas grandes, más.
@export_range(0.0, 500.0) var predelay_msec: float = 15.0
## Realimentación del retardo (0..0,98): un eco que rebota (pasillo largo, escalera).
@export_range(0.0, 0.98) var predelay_feedback: float = 0.2

@export_group("Ecualización")
## Ganancia (dB) de las 6 bandas del bus Sala: 32, 100, 320, 1000, 3200 y 10000 Hz.
## Suave: ±4 dB como mucho (alicatado y acero, más brillo; hormigón grande, más grave).
@export var eq_db: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])


## Si `cell` está en alguna de sus zonas.
func contains(cell: Vector2i) -> bool:
	for r: Rect2i in regions:
		if r.has_point(cell):
			return true
	return false


## Todos los parámetros en orden fijo (para mezclar dos espacios en las transiciones).
func to_params() -> PackedFloat32Array:
	var p: PackedFloat32Array = PackedFloat32Array([room_size, damping, spread, hipass, wet, dry, predelay_msec,
		predelay_feedback])
	for i: int in 6:
		p.append(eq_db[i] if i < eq_db.size() else 0.0)
	return p


## Espacio sin sala: sin cola y con la EQ plana (título, combate fuera de un mapa…).
static func neutral() -> AcousticSpaceDef:
	var space: AcousticSpaceDef = AcousticSpaceDef.new()
	space.id = &"neutral"
	space.wet = 0.0
	space.predelay_feedback = 0.0
	return space
