class_name MusicPlayer
extends AudioStreamPlayer
## Música en bucle por el bus «Música», con fundido de entrada y de salida.
## Las pistas son OGG en assets/audio/music/<nombre>.ogg (las prepara tools/audio/freesound.py).
## Si no hay ninguna pista, no suena nada y no pasa nada.

const DIR: String = "res://assets/audio/music/"
const BUS: StringName = &"Música"
## Volumen al que se considera apagada.
const SILENT_DB: float = -60.0

## Volumen de destino (dB) cuando termina el fundido de entrada.
var target_db: float = 0.0
## Nombre de la pista que suena ("" si ninguna).
var track_name: String = ""

var _tween: Tween


func _init() -> void:
	bus = BUS
	volume_db = SILENT_DB


## Pista por nombre (null si no existe el archivo). Se carga en bucle.
static func track(music_name: String) -> AudioStream:
	var path: String = DIR + music_name + ".ogg"
	if music_name == "" or not ResourceLoader.exists(path):
		return null
	var res: AudioStream = load(path)
	var ogg: AudioStreamOggVorbis = res as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true
	return res


## Nombres de `names` que tienen archivo.
static func available(names: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = []
	for n: String in names:
		if ResourceLoader.exists(DIR + n + ".ogg"):
			result.append(n)
	return result


## Empieza una de las pistas disponibles (al azar) con fundido de entrada. Devuelve false si no
## hay ninguna.
func play_any(names: PackedStringArray, volume: float = 0.0, fade_in: float = 4.0) -> bool:
	var options: PackedStringArray = available(names)
	if options.is_empty():
		return false
	track_name = options[randi() % options.size()]
	stream = track(track_name)
	if stream == null:
		return false
	target_db = volume
	volume_db = SILENT_DB
	play()
	_fade_to(target_db, fade_in)
	return true


## Fundido de salida y parada. Se puede esperar con `await`.
func fade_out(seconds: float = 1.5) -> void:
	if not playing:
		return
	_fade_to(SILENT_DB, seconds)
	await _tween.finished
	stop()


func _fade_to(db: float, seconds: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", db, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT if db > volume_db else Tween.EASE_IN)
