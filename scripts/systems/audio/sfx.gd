class_name Sfx
extends RefCounted
## Sonidos: efectos posicionales y de interfaz. Los WAV están en assets/audio/sfx/<nombre>.wav.
## Si falta un archivo no pasa nada (se avisa una vez por consola).

const DIR: String = "res://assets/audio/sfx/"

static var _cache: Dictionary[String, AudioStream] = {}
static var _missing: Dictionary[String, bool] = {}


static func stream(sound_name: String) -> AudioStream:
	if sound_name == "":
		return null
	if _cache.has(sound_name):
		return _cache[sound_name]
	var path: String = DIR + sound_name + ".wav"
	if not ResourceLoader.exists(path):
		if not _missing.has(sound_name):
			_missing[sound_name] = true
			push_warning("Sonido que falta: " + path)
		return null
	var s: AudioStream = load(path)
	_cache[sound_name] = s
	return s


## Sonido en un punto del mundo (se oye más o menos según la distancia).
static func at(parent: Node, sound: Variant, position: Vector2, volume_db: float = 0.0, pitch_jitter: float = 0.06,
		max_distance: float = 900.0) -> AudioStreamPlayer2D:
	var s: AudioStream = sound if sound is AudioStream else stream(String(sound))
	if s == null or parent == null:
		return null
	var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	player.stream = s
	player.position = position
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.attenuation = 1.6
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.bus = &"Efectos"
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player


## Sonido sin posición (interfaz, megafonía).
static func ui(parent: Node, sound: Variant, volume_db: float = 0.0) -> AudioStreamPlayer:
	var s: AudioStream = sound if sound is AudioStream else stream(String(sound))
	if s == null or parent == null:
		return null
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = s
	player.volume_db = volume_db
	player.bus = &"Interfaz"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player
