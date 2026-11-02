class_name RoomAcoustics
extends RefCounted
## Lleva la acústica del bus «Sala» (reverberación + EQ, ver `AudioBuses`) a la del espacio donde
## está el jugador (`AcousticsDef`), con una transición suave al cambiar de sala.
## Lo actualiza `Soundscape` cada fotograma; al salir del mapa vuelve al neutro (sin eco), así el
## título y lo que no tenga mapa suenan secos.
## Lógica sin nodos: se puede probar llamando a `update` con casillas.

var def: AcousticsDef
## Espacio al que se va (o en el que se está).
var target: AcousticSpaceDef
## Parámetros aplicados ahora mismo (`AcousticSpaceDef.to_params`).
var current: PackedFloat32Array


func _init(acoustics: AcousticsDef) -> void:
	def = acoustics
	current = AcousticSpaceDef.neutral().to_params()


## Avanza la transición hacia el espacio de `cell` y lo aplica al bus. `snap` = sin transición
## (al entrar en el mapa o al cargar).
func update(delta: float, cell: Vector2i, snap: bool = false) -> void:
	if def == null:
		return
	target = def.space_at(cell)
	var goal: PackedFloat32Array = target.to_params()
	var t: float = 1.0 if snap else clampf(delta / maxf(def.transition, 0.01) * 3.0, 0.0, 1.0)
	for i: int in current.size():
		# Aproximación exponencial: a ~95 % en `transition` segundos, sin saltos.
		current[i] = lerpf(current[i], goal[i], t)
		if absf(current[i] - goal[i]) < 0.0005:
			current[i] = goal[i]
	apply(current)


## Pone unos parámetros en el bus Sala (si existe).
static func apply(params: PackedFloat32Array) -> void:
	var reverb: AudioEffectReverb = AudioBuses.room_reverb()
	if reverb != null:
		reverb.room_size = params[0]
		reverb.damping = params[1]
		reverb.spread = params[2]
		reverb.hipass = params[3]
		reverb.wet = params[4]
		reverb.dry = params[5]
		reverb.predelay_msec = params[6]
		reverb.predelay_feedback = params[7]
	var eq: AudioEffectEQ6 = AudioBuses.room_eq()
	if eq != null:
		for band: int in 6:
			eq.set_band_gain_db(band, params[8 + band])


## Sin sala: sin cola y EQ plana.
static func reset() -> void:
	apply(AcousticSpaceDef.neutral().to_params())
