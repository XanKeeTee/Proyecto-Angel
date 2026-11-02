class_name Soundscape
extends Node2D
## Paisaje sonoro de un mapa, todo según `SoundscapeDef`:
## - tonos de sala que acompañan al jugador y se funden al cambiar de sala (habitación, pasillo,
##   alicatado, quirófano, sótano, morgue…) y el aire del edificio (zumbido con corriente, viento);
## - bucles posicionales suaves (fluorescentes, ventilación, relojes, goteos, tuberías, nevera de la
##   morgue, generador…);
## - sonidos sueltos al azar con enfriamiento (crujidos, puertas y pasos lejanos, ratas, rejillas…),
##   que suenan por el eco de la sala y, si son lejanos, más apagados (ver `AudioBuses`);
## - la acústica (eco y ecualización) de la sala donde está el jugador (`RoomAcoustics`).
## Se crea con una línea desde el `_ready` del mapa:
##     Soundscape.attach(self, preload("res://data/audio/hospital_soundscape.tres"), %Ambience)
## Depende del estado (corriente, zona del jugador). Entra poco a poco la primera vez que el
## jugador tiene el control. Convive con `HorrorDirector`: tras un susto calla los sueltos un
## rato y, mientras la entidad está presente, baja los bucles y no lanza sueltos.
## Si falta un WAV, su emisor existe pero no suena (y Sfx avisa por consola).

## Ganancia por debajo de la cual un bucle se para (ahorra mezcla).
const STOP_GAIN: float = 0.002
## Margen (píxeles) más allá de `max_distance` a partir del cual un bucle se para.
const RANGE_MARGIN: float = 48.0
## Si no hay sitio para un suelto, se reintenta tras estos segundos.
const RETRY: float = 6.0

var world: WorldController
var def: SoundscapeDef
## Ambiente de fondo del mapa (opcional): entra con el paisaje.
var bed: AudioStreamPlayer
## Emisores de bucle: AudioStreamPlayer2D con metadatos (ver `_add_emitter`).
var emitters: Array[AudioStreamPlayer2D] = []
## Reloj propio (solo avanza sin pausa).
var clock: float = 0.0

## Acústica de la sala del jugador (null si el mapa no tiene).
var acoustics: RoomAcoustics

var _horror: HorrorDirector
var _master: float = 0.0
var _started: bool = false
var _fading_out: bool = false
var _quiet_until: float = 0.0
var _last_shot: float = -1000.0
var _next_shot: Dictionary[AmbientSoundDef, float] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Crea el paisaje sonoro como hijo del mapa.
static func attach(world_controller: WorldController, soundscape: SoundscapeDef,
		bed_player: AudioStreamPlayer = null) -> Soundscape:
	var node: Soundscape = Soundscape.new()
	node.name = "Soundscape"
	node.world = world_controller
	node.def = soundscape
	node.bed = bed_player
	world_controller.add_child(node)
	return node


func _ready() -> void:
	_rng.randomize()
	_horror = world.get_node_or_null(^"HorrorDirector") as HorrorDirector
	if _horror != null:
		_horror.scare_played.connect(func(_s: ScareDef) -> void: _quiet_until = clock + def.quiet_after_scare)
	if bed != null:
		bed.volume_db = linear_to_db(0.0001)
	if def.acoustics != null:
		acoustics = RoomAcoustics.new(def.acoustics)
		if world.player != null:
			acoustics.update(0.0, _cell_of(world.player.position), true)
	for sound: AmbientSoundDef in def.sounds:
		if sound.kind != AmbientSoundDef.Kind.LOOP or sound.sounds.is_empty():
			continue
		if sound.placement == AmbientSoundDef.Placement.LISTENER:
			_add_emitter(sound, world.player.position if world.player != null else Vector2.ZERO, null)
			emitters[-1].set_meta(&"follow", true)
		elif sound.placement == AmbientSoundDef.Placement.LIGHTS:
			for node: Node in get_tree().get_nodes_in_group(PoweredLight.GROUP):
				var light: PoweredLight = node as PoweredLight
				if light.needs_power and not light.broken and sound.in_regions(_cell_of(to_local(light.global_position))):
					_add_emitter(sound, to_local(light.global_position), light)
		else:
			for cell: Vector2i in sound.cells:
				_add_emitter(sound, world.cell_center(cell), null)


func _process(delta: float) -> void:
	if world.player == null:
		return
	clock += delta
	var can_act: bool = _player_free()
	if not _started and can_act:
		_started = true
	var target_master: float = 0.0 if _fading_out or not _started else 1.0
	var rate: float = delta / maxf(def.fade_in if not _fading_out else 0.8, 0.01)
	_master = move_toward(_master, target_master, rate)
	if bed != null:
		bed.volume_db = def.bed_volume_db + linear_to_db(maxf(_master, 0.0001))
	var powered: bool = GameState.has_flag(GameState.FLAG_POWER)
	var cell: Vector2i = _cell_of(world.player.position)
	var stalker: bool = _horror != null and _horror.stalker != null and _horror.stalker.is_active()
	if acoustics != null:
		acoustics.update(delta, cell)
	_update_loops(delta, cell, powered, stalker)
	if can_act and not stalker and _master > 0.6 and clock >= _quiet_until and clock - _last_shot >= def.min_gap:
		_update_shots(cell, powered)


## Emisores (bucles) de un sonido del paisaje.
func emitters_of(id: StringName) -> Array[AudioStreamPlayer2D]:
	var result: Array[AudioStreamPlayer2D] = []
	for e: AudioStreamPlayer2D in emitters:
		if (e.get_meta(&"def") as AmbientSoundDef).id == id:
			result.append(e)
	return result


## Si un emisor debería sonar ahora (zona, corriente, luz encendida y distancia).
func is_emitter_active(e: AudioStreamPlayer2D, cell: Vector2i, powered: bool) -> bool:
	var sound: AmbientSoundDef = e.get_meta(&"def")
	if not sound.fits(cell, powered):
		return false
	if e.has_meta(&"light"):
		var light: Variant = e.get_meta(&"light")
		if not is_instance_valid(light) or not (light as PoweredLight).enabled:
			return false
	return e.position.distance_to(world.player.position) <= sound.max_distance + RANGE_MARGIN


## Fundido de salida de todo (final del mapa).
func fade_out() -> void:
	_fading_out = true


func _exit_tree() -> void:
	# Fuera del mapa no hay sala: el título y lo demás suenan secos.
	if acoustics != null:
		RoomAcoustics.reset()


func _add_emitter(sound: AmbientSoundDef, pos: Vector2, light: PoweredLight) -> void:
	var e: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	e.name = "%s_%d" % [sound.id, emitters.size()]
	e.position = pos
	e.max_distance = sound.max_distance
	e.attenuation = sound.attenuation
	e.bus = Settings.BUS_AMBIENCE
	e.volume_db = linear_to_db(0.0001)
	e.pitch_scale = 1.0 + _rng.randf_range(-sound.pitch_jitter, sound.pitch_jitter)
	var stream: AudioStream = Sfx.stream(sound.sounds[0])
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	if wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	e.stream = stream
	e.set_meta(&"def", sound)
	e.set_meta(&"gain", 0.0)
	if light != null:
		e.set_meta(&"light", light)
	add_child(e)
	emitters.append(e)


func _update_loops(delta: float, cell: Vector2i, powered: bool, stalker: bool) -> void:
	var duck: float = def.stalker_duck_db if stalker else 0.0
	for e: AudioStreamPlayer2D in emitters:
		var sound: AmbientSoundDef = e.get_meta(&"def")
		var step: float = delta / maxf(sound.fade if sound.fade >= 0.0 else def.loop_fade, 0.01)
		if e.has_meta(&"follow"):
			e.position = world.player.position
		var target: float = 1.0 if is_emitter_active(e, cell, powered) else 0.0
		# Las luces que parpadean cortan el zumbido de golpe, como el tubo.
		var fast: bool = e.has_meta(&"light")
		var gain: float = move_toward(float(e.get_meta(&"gain")), target, step * (6.0 if fast else 1.0))
		e.set_meta(&"gain", gain)
		var level: float = gain * _master
		if level <= STOP_GAIN:
			if e.playing:
				e.stop()
			continue
		e.volume_db = sound.volume_db + duck + linear_to_db(level)
		if not e.playing and e.stream != null:
			# Cada emisor empieza en un punto distinto del bucle (no suenan en fase).
			e.play(_rng.randf() * maxf(e.stream.get_length() - 0.1, 0.0))


func _update_shots(cell: Vector2i, powered: bool) -> void:
	var order: Array[AmbientSoundDef] = []
	for sound: AmbientSoundDef in def.sounds:
		if sound.kind == AmbientSoundDef.Kind.ONE_SHOT and not sound.sounds.is_empty():
			order.append(sound)
	order.shuffle()
	for sound: AmbientSoundDef in order:
		if not sound.fits(cell, powered):
			_next_shot.erase(sound)
			continue
		if not _next_shot.has(sound):
			_next_shot[sound] = clock + _rng.randf_range(sound.first_delay.x, sound.first_delay.y)
			continue
		if clock < _next_shot[sound]:
			continue
		var where: Variant = _shot_position(sound)
		if where == null:
			_next_shot[sound] = clock + RETRY
			continue
		_play_shot(sound, where as Vector2)
		_next_shot[sound] = clock + _rng.randf_range(sound.cooldown.x, sound.cooldown.y)
		_last_shot = clock
		return


## Punto donde suena un suelto (null si no hay ninguno a distancia).
func _shot_position(sound: AmbientSoundDef) -> Variant:
	var origin: Vector2 = world.player.position
	if sound.placement == AmbientSoundDef.Placement.CELLS and not sound.cells.is_empty():
		var near: Array[Vector2] = []
		for c: Vector2i in sound.cells:
			var p: Vector2 = world.cell_center(c)
			if p.distance_to(origin) <= sound.max_distance * 0.85:
				near.append(p)
		return near[_rng.randi() % near.size()] if not near.is_empty() else null
	var dir: Vector2 = Vector2.from_angle(_rng.randf() * TAU)
	# AROUND_PLAYER y LISTENER (en un suelto no tiene sentido ir pegado al jugador).
	return origin + dir * _rng.randf_range(sound.distance.x, sound.distance.y)


func _play_shot(sound: AmbientSoundDef, pos: Vector2) -> void:
	var stream: AudioStream = Sfx.stream(sound.sounds[_rng.randi() % sound.sounds.size()])
	if stream == null:
		return
	var p: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	p.stream = stream
	p.position = pos
	p.max_distance = sound.max_distance
	p.attenuation = sound.attenuation
	p.volume_db = sound.volume_db + linear_to_db(maxf(_master, 0.0001))
	p.pitch_scale = 1.0 + _rng.randf_range(-sound.pitch_jitter, sound.pitch_jitter)
	# Los sueltos suenan en la sala (eco) y, si están lejos, más apagados.
	p.bus = AudioBuses.bus_for_distance(AudioBuses.AMBIENCE_ROOM, pos.distance_to(world.player.position))
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _player_free() -> bool:
	var player: Player = world.player
	if not player.input_enabled or not player.visible:
		return false
	return world.message == null or not world.message.is_open()


func _cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / WorldController.TILE_SIZE), floori(pos.y / WorldController.TILE_SIZE))
