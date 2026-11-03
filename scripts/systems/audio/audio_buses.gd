class_name AudioBuses
extends RefCounted
## Buses de audio del juego y sus efectos. Los crea `Settings` al arrancar (no hay
## default_bus_layout.tres: así la disposición está en un solo sitio y las pruebas la tienen).
##
##     Master  ← limitador suave
##     ├─ Sala  ← EQ de 6 bandas + reverberación (la acústica de la sala del jugador, `RoomAcoustics`)
##     │   ├─ Efectos                 (volumen «Efectos»)  ← pasos, puertas, golpes, voces del jugador…
##     │   │   ├─ Efectos lejos       ← paso bajo suave (sonidos a media distancia)
##     │   │   └─ Efectos muy lejos   ← paso bajo fuerte (sonidos lejanos)
##     │   └─ Ambiente eco            (volumen «Ambiente») ← sonidos sueltos del paisaje sonoro
##     │       ├─ Ambiente lejos      ← paso bajo suave
##     │       └─ Ambiente muy lejos  ← paso bajo fuerte
##     ├─ Ambiente  (volumen «Ambiente»)  ← bucles de fondo: ya traen su sala grabada, van secos
##     ├─ Música    (volumen «Música»)    ← sin eco
##     └─ Interfaz  (volumen «Interfaz»)  ← sin eco
##
## Cada bus manda a uno anterior en la lista (Godot mezcla de atrás adelante).
## `bus_for_distance` elige el bus de un sonido del mundo según lo lejos que esté de quien escucha.

const MASTER: StringName = &"Master"
const ROOM: StringName = &"Sala"
const AMBIENCE: StringName = &"Ambiente"
const AMBIENCE_ROOM: StringName = &"Ambiente eco"
const AMBIENCE_FAR: StringName = &"Ambiente lejos"
const AMBIENCE_FARTHEST: StringName = &"Ambiente muy lejos"
const MUSIC: StringName = &"Música"
const SFX: StringName = &"Efectos"
const SFX_FAR: StringName = &"Efectos lejos"
const SFX_FARTHEST: StringName = &"Efectos muy lejos"
const UI: StringName = &"Interfaz"

## [bus, destino] en el orden en que quedan tras Master.
const LAYOUT: Array[Array] = [
	[ROOM, MASTER],
	[AMBIENCE, MASTER],
	[AMBIENCE_ROOM, ROOM],
	[AMBIENCE_FAR, AMBIENCE_ROOM],
	[AMBIENCE_FARTHEST, AMBIENCE_ROOM],
	[MUSIC, MASTER],
	[SFX, ROOM],
	[SFX_FAR, SFX],
	[SFX_FARTHEST, SFX],
	[UI, MASTER],
]

## A partir de esta distancia (píxeles) a quien escucha, un sonido va por el bus «lejos».
const FAR_DISTANCE: float = 230.0
## Y a partir de esta, por el bus «muy lejos».
const FARTHEST_DISTANCE: float = 400.0
## Corte (Hz) del paso bajo de «lejos» y «muy lejos».
const FAR_CUTOFF_HZ: float = 3600.0
const FARTHEST_CUTOFF_HZ: float = 1500.0
## Lo lejano, además, un poco más bajo (dB): la atenuación por distancia de Godot es suave.
const FAR_GAIN_DB: float = -1.0
const FARTHEST_GAIN_DB: float = -2.5
## Techo del limitador del maestro (dB): nada puede saturar.
const LIMITER_CEILING_DB: float = -1.5

## Posición de cada efecto en el bus Sala.
const ROOM_EQ: int = 0
const ROOM_REVERB: int = 1


## Crea los buses que falten, los ordena, conecta sus envíos y les pone sus efectos.
static func ensure() -> void:
	for i: int in LAYOUT.size():
		var bus: StringName = LAYOUT[i][0]
		var at: int = i + 1
		var index: int = AudioServer.get_bus_index(bus)
		if index < 0:
			AudioServer.add_bus(at)
			AudioServer.set_bus_name(at, bus)
		elif index != at:
			AudioServer.move_bus(index, at)
	for entry: Array in LAYOUT:
		AudioServer.set_bus_send(AudioServer.get_bus_index(entry[0]), entry[1])
	_ensure_effects()


## Bus de un sonido del mundo según su distancia a quien escucha. `near` es el bus cercano
## (`SFX` o `AMBIENCE_ROOM`).
static func bus_for_distance(near: StringName, distance: float) -> StringName:
	var far: bool = distance >= FAR_DISTANCE
	var farthest: bool = distance >= FARTHEST_DISTANCE
	if near == AMBIENCE_ROOM:
		return AMBIENCE_FARTHEST if farthest else (AMBIENCE_FAR if far else AMBIENCE_ROOM)
	if near == SFX:
		return SFX_FARTHEST if farthest else (SFX_FAR if far else SFX)
	return near


## Distancia de un nodo 2D a quien escucha (el centro de la cámara; 0 si no hay cámara).
static func listener_distance(node: Node2D) -> float:
	if node == null or not node.is_inside_tree():
		return 0.0
	var camera: Camera2D = node.get_viewport().get_camera_2d()
	if camera == null:
		return 0.0
	return camera.get_screen_center_position().distance_to(node.global_position)


## La reverberación de la sala (null si aún no existen los buses).
static func room_reverb() -> AudioEffectReverb:
	var i: int = AudioServer.get_bus_index(ROOM)
	if i < 0 or AudioServer.get_bus_effect_count(i) <= ROOM_REVERB:
		return null
	return AudioServer.get_bus_effect(i, ROOM_REVERB) as AudioEffectReverb


## La ecualización de la sala (null si aún no existen los buses).
static func room_eq() -> AudioEffectEQ6:
	var i: int = AudioServer.get_bus_index(ROOM)
	if i < 0 or AudioServer.get_bus_effect_count(i) <= ROOM_EQ:
		return null
	return AudioServer.get_bus_effect(i, ROOM_EQ) as AudioEffectEQ6


## Enciende o apaga el eco (reverberación y ecualización de sala). El paso bajo de la distancia
## se queda: no es eco.
static func set_echo_enabled(enabled: bool) -> void:
	var i: int = AudioServer.get_bus_index(ROOM)
	if i < 0:
		return
	for effect: int in AudioServer.get_bus_effect_count(i):
		AudioServer.set_bus_effect_enabled(i, effect, enabled)


static func is_echo_enabled() -> bool:
	var i: int = AudioServer.get_bus_index(ROOM)
	return i >= 0 and AudioServer.get_bus_effect_count(i) > ROOM_REVERB \
		and AudioServer.is_bus_effect_enabled(i, ROOM_REVERB)


static func _ensure_effects() -> void:
	var master: int = AudioServer.get_bus_index(MASTER)
	if AudioServer.get_bus_effect_count(master) == 0:
		var limiter: AudioEffectHardLimiter = AudioEffectHardLimiter.new()
		limiter.ceiling_db = LIMITER_CEILING_DB
		AudioServer.add_bus_effect(master, limiter)
	var room: int = AudioServer.get_bus_index(ROOM)
	if AudioServer.get_bus_effect_count(room) == 0:
		AudioServer.add_bus_effect(room, AudioEffectEQ6.new(), ROOM_EQ)
		var reverb: AudioEffectReverb = AudioEffectReverb.new()
		# Sin sala hasta que el mapa diga dónde está el jugador (ver RoomAcoustics.reset).
		reverb.wet = 0.0
		reverb.dry = 1.0
		AudioServer.add_bus_effect(room, reverb, ROOM_REVERB)
	for pair: Array in [[SFX_FAR, FAR_CUTOFF_HZ, FAR_GAIN_DB], [SFX_FARTHEST, FARTHEST_CUTOFF_HZ, FARTHEST_GAIN_DB],
			[AMBIENCE_FAR, FAR_CUTOFF_HZ, FAR_GAIN_DB], [AMBIENCE_FARTHEST, FARTHEST_CUTOFF_HZ, FARTHEST_GAIN_DB]]:
		var i: int = AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_volume_db(i, pair[2])
		if AudioServer.get_bus_effect_count(i) == 0:
			var low_pass: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
			low_pass.cutoff_hz = pair[1]
			low_pass.resonance = 0.5
			AudioServer.add_bus_effect(i, low_pass)
