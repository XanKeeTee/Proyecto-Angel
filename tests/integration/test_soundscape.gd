extends TestCase
## Paisaje sonoro del hospital (Soundscape + data/audio/hospital_soundscape.tres) y música del
## menú: emisores según la sala y la corriente, entrada gradual, silencio tras un susto, y el
## título sin pistas de música no falla.

const SCENE: String = "res://scenes/world/hospital/hospital.tscn"
const TITLE: String = "res://scenes/ui/title/title_screen.tscn"
const CORRIDOR_CELL: Vector2i = Vector2i(30, 15)
const GENERATOR_ROOM_CELL: Vector2i = Vector2i(17, 54)
const BATHS_CELL: Vector2i = Vector2i(26, 24)

var world: WorldController
var scape: Soundscape


func _setup(cell: Vector2i, powered: bool) -> void:
	GameState.new_game()
	if powered:
		GameState.flags[GameState.FLAG_POWER] = true
	GameState.player_scene = SCENE
	GameState.player_position = Vector2(cell * 32) + Vector2(16, 16)
	GameState.player_facing = 0.0
	GameState.has_position = true
	world = load(SCENE).instantiate()
	host.add_child(world)
	world.message.auto_advance = 0.01
	scape = world.get_node(^"Soundscape") as Soundscape
	for i: int in 6:
		await host.get_tree().physics_frame


func _teardown() -> void:
	world.queue_free()
	await host.get_tree().process_frame
	GameState.new_game()


func _move_to(cell: Vector2i) -> void:
	world.player.position = Vector2(cell * 32) + Vector2(16, 16)
	await host.get_tree().process_frame


func _active(id: StringName) -> int:
	var n: int = 0
	var cell: Vector2i = Vector2i((world.player.position / 32.0).floor())
	var powered: bool = GameState.has_flag(GameState.FLAG_POWER)
	for e: AudioStreamPlayer2D in scape.emitters_of(id):
		if scape.is_emitter_active(e, cell, powered):
			n += 1
	return n


func test_crea_los_emisores_del_mapa() -> void:
	await _setup(CORRIDOR_CELL, false)
	check(scape != null, "el hospital crea el paisaje sonoro")
	var lights: int = 0
	for node: Node in host.get_tree().get_nodes_in_group(PoweredLight.GROUP):
		var light: PoweredLight = node as PoweredLight
		if light.needs_power and not light.broken:
			lights += 1
	check(lights > 0, "hay fluorescentes que funcionan")
	check_eq(scape.emitters_of(&"fluorescentes").size(), lights, "un zumbido por fluorescente que funciona")
	check_eq(scape.emitters_of(&"ventilacion").size(), 6, "rejillas de los dos pasillos")
	check_eq(scape.emitters_of(&"generador").size(), 1, "el generador")
	check_eq(scape.emitters_of(&"nevera_morgue").size(), 1, "la nevera de la morgue")
	for e: AudioStreamPlayer2D in scape.emitters:
		check_eq(e.bus, Settings.BUS_AMBIENCE, "los bucles van por el bus Ambiente")
	await _teardown()


func test_depende_de_la_corriente_y_de_la_sala() -> void:
	await _setup(CORRIDOR_CELL, false)
	check_eq(_active(&"ventilacion"), 0, "sin corriente no hay ventilación")
	check_eq(_active(&"fluorescentes"), 0, "sin corriente no zumban los fluorescentes")
	check_eq(_active(&"generador"), 0, "sin corriente no suena el generador")
	await _move_to(BATHS_CELL)
	check_eq(_active(&"goteo_banos"), 1, "en los baños gotea el grifo (sin corriente también)")
	await _move_to(CORRIDOR_CELL)
	check_eq(_active(&"goteo_banos"), 0, "fuera de los baños no")
	GameState.set_flag(GameState.FLAG_POWER)
	await host.get_tree().process_frame
	check(_active(&"ventilacion") >= 1, "con corriente, la ventilación del pasillo")
	check_eq(_active(&"generador"), 0, "el generador no se oye en la planta")
	# Los fluorescentes arrancan con retraso y parpadeos: se espera a que alguno zumbe.
	var humming: bool = false
	for i: int in 40:
		await host.get_tree().create_timer(0.1).timeout
		await _move_to(CORRIDOR_CELL)
		for e: AudioStreamPlayer2D in scape.emitters_of(&"fluorescentes"):
			world.player.position = e.position + Vector2(0, 40)
			if scape.is_emitter_active(e, Vector2i((world.player.position / 32.0).floor()), true):
				humming = true
				break
		if humming:
			break
	check(humming, "con corriente, junto a un fluorescente encendido se oye el zumbido")
	await _move_to(GENERATOR_ROOM_CELL)
	check_eq(_active(&"generador"), 1, "en el sótano, junto al generador, sí")
	check_eq(_active(&"ventilacion"), 0, "la ventilación de los pasillos no llega a la sala de calderas")
	check_eq(_active(&"nevera_morgue"), 0, "la nevera solo dentro de la morgue")
	await _teardown()


func test_entra_poco_a_poco_y_calla_tras_un_susto() -> void:
	await _setup(CORRIDOR_CELL, true)
	var bed: AudioStreamPlayer = world.get_node(^"%Ambience") as AudioStreamPlayer
	check(bed.volume_db < -40.0, "el ambiente empieza casi en silencio (%.1f dB)" % bed.volume_db)
	await host.get_tree().create_timer(1.0).timeout
	var after: float = bed.volume_db
	check(after > -60.0 and after < scape.def.bed_volume_db - 1.0, "y sube despacio (%.1f dB)" % after)
	var director: HorrorDirector = world.get_node(^"HorrorDirector") as HorrorDirector
	director.scare_played.emit(director.profile.scares[0])
	check(scape.get("_quiet_until") > scape.clock + scape.def.quiet_after_scare - 0.5, "tras un susto, silencio de sueltos")
	await _teardown()


func test_el_titulo_sin_musica_no_falla() -> void:
	check(AudioServer.get_bus_index(Settings.BUS_MUSIC) >= 0, "existe el bus Música")
	var missing: PackedStringArray = MusicPlayer.available(PackedStringArray(["no_existe_esta_pista"]))
	check(missing.is_empty(), "una pista que no existe no está disponible")
	check(MusicPlayer.track("no_existe_esta_pista") == null, "y no se carga")
	var title: Node = load(TITLE).instantiate()
	host.add_child(title)
	await host.get_tree().create_timer(0.3).timeout
	var music: MusicPlayer = title.get("_music")
	check(music != null, "el título crea su reproductor de música")
	check_eq(music.bus, Settings.BUS_MUSIC, "por el bus Música")
	var any: bool = not MusicPlayer.available((title.get_script() as Script).get_script_constant_map()["MENU_TRACKS"]).is_empty()
	check_eq(music.playing, any, "suena solo si hay alguna pista")
	await music.fade_out(0.05)
	check(not music.playing, "el fundido de salida la para")
	title.queue_free()
	await host.get_tree().process_frame


# --- segunda capa: tonos de sala, acústica (eco) y distancia -----------------------------------

const MORGUE_CELL: Vector2i = Vector2i(5, 54)
const BASEMENT_CORRIDOR_CELL: Vector2i = Vector2i(20, 45)
const STAIRS_CELL: Vector2i = Vector2i(61, 7)


func _reverb() -> AudioEffectReverb:
	return AudioBuses.room_reverb()


## Deja que la acústica termine la transición (varios segundos de golpe).
func _settle_acoustics() -> void:
	for i: int in 10:
		scape.acoustics.update(1.0, Vector2i((world.player.position / 32.0).floor()))


func test_buses_eco_y_distancia() -> void:
	for entry: Array in AudioBuses.LAYOUT:
		var i: int = AudioServer.get_bus_index(entry[0])
		check(i > 0, "existe el bus %s" % entry[0])
		check_eq(AudioServer.get_bus_send(i), entry[1], "%s manda a %s" % [entry[0], entry[1]])
		check(AudioServer.get_bus_index(entry[1]) < i, "%s manda a un bus anterior" % entry[0])
	check_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(Settings.BUS_SFX)), AudioBuses.ROOM,
		"los efectos del mundo (pasos, puertas, golpes, voces) pasan por la sala")
	check_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(Settings.BUS_UI)), AudioBuses.MASTER,
		"la interfaz, sin eco")
	check_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(Settings.BUS_MUSIC)), AudioBuses.MASTER,
		"la música, sin eco")
	check(_reverb() != null and AudioBuses.room_eq() != null, "la sala tiene reverberación y ecualización")
	check_eq(AudioBuses.bus_for_distance(AudioBuses.SFX, 40.0), AudioBuses.SFX, "cerca: sin filtro")
	check_eq(AudioBuses.bus_for_distance(AudioBuses.SFX, 300.0), AudioBuses.SFX_FAR, "a media distancia: apagado")
	check_eq(AudioBuses.bus_for_distance(AudioBuses.SFX, 600.0), AudioBuses.SFX_FARTHEST, "lejos: más apagado")
	check_eq(AudioBuses.bus_for_distance(AudioBuses.AMBIENCE_ROOM, 600.0), AudioBuses.AMBIENCE_FARTHEST,
		"igual con los sueltos del ambiente")
	check_eq(AudioBuses.bus_for_distance(AudioBuses.UI, 600.0), AudioBuses.UI, "la interfaz no tiene distancia")
	var far: AudioEffectLowPassFilter = AudioServer.get_bus_effect(AudioServer.get_bus_index(AudioBuses.SFX_FARTHEST), 0)
	check(far != null and far.cutoff_hz < 2000.0, "lo muy lejano pasa por un paso bajo")
	# Opción «Eco».
	var was: bool = Settings.echo
	Settings.echo = false
	Settings.apply()
	check(not AudioBuses.is_echo_enabled(), "con el eco apagado no hay reverberación")
	Settings.echo = true
	Settings.apply()
	check(AudioBuses.is_echo_enabled(), "y vuelve al encenderlo")
	Settings.echo = was
	Settings.apply()


func test_la_sala_cambia_la_reverberacion() -> void:
	await _setup(BATHS_CELL, false)
	check(scape.acoustics != null, "el hospital tiene acústica")
	var tiled: AcousticSpaceDef = scape.def.acoustics.space_at(BATHS_CELL)
	check_eq(tiled.id, &"alicatado", "los baños son una sala alicatada")
	_settle_acoustics()
	check(is_equal_approx(_reverb().room_size, tiled.room_size), "en los baños, la sala de los baños")
	check(is_equal_approx(_reverb().damping, tiled.damping), "alicatado: los agudos rebotan")
	var wet_tiled: float = _reverb().wet
	check(wet_tiled > 0.05 and wet_tiled < 0.35, "eco moderado (%.2f)" % wet_tiled)
	# Al pasillo: transición suave, no salto.
	await _move_to(CORRIDOR_CELL)
	var corridor: AcousticSpaceDef = scape.def.acoustics.space_at(CORRIDOR_CELL)
	check_eq(corridor.id, &"pasillo", "el pasillo largo")
	scape.acoustics.update(0.05, CORRIDOR_CELL)
	var mid: float = _reverb().predelay_msec
	check(mid > tiled.predelay_msec and mid < corridor.predelay_msec, "la transición es gradual (%.1f ms)" % mid)
	_settle_acoustics()
	check(is_equal_approx(_reverb().predelay_msec, corridor.predelay_msec), "pasillo: primera reflexión tardía")
	check(_reverb().room_size > tiled.room_size, "el pasillo suena más grande que el baño")
	# El resto de espacios.
	var expected: Dictionary[Vector2i, StringName] = {
		MORGUE_CELL: &"morgue", GENERATOR_ROOM_CELL: &"sotano", BASEMENT_CORRIDOR_CELL: &"sotano",
		STAIRS_CELL: &"escalera", Vector2i(45, 24): &"quirofano", Vector2i(4, 7): &"habitacion",
		Vector2i(-10, 15): &"pasillo_imposible",
	}
	for cell: Vector2i in expected:
		check_eq(scape.def.acoustics.space_at(cell).id, expected[cell], "acústica de %s" % cell)
	await _move_to(MORGUE_CELL)
	_settle_acoustics()
	var eq: AudioEffectEQ6 = AudioBuses.room_eq()
	check(eq.get_band_gain_db(5) > 0.0, "la morgue (acero y azulejo) suena brillante")
	await _move_to(GENERATOR_ROOM_CELL)
	_settle_acoustics()
	check(eq.get_band_gain_db(5) < 0.0 and eq.get_band_gain_db(1) > 0.0, "el sótano grande, grave y apagado")
	check(_reverb().room_size > 0.7, "y con mucha cola")
	await _teardown()
	check(is_zero_approx(_reverb().wet), "al salir del mapa, sin eco")


func test_tonos_de_sala_segun_sala_y_corriente() -> void:
	await _setup(BATHS_CELL, false)
	check_eq(_active(&"tono_banos"), 1, "en los baños, su tono de sala")
	check_eq(_active(&"tono_pasillo"), 0, "y no el del pasillo")
	for e: AudioStreamPlayer2D in scape.emitters_of(&"tono_banos"):
		check_eq(e.bus, Settings.BUS_AMBIENCE, "los tonos de sala van por Ambiente, secos")
	await _move_to(CORRIDOR_CELL)
	check_eq(_active(&"tono_pasillo"), 1, "en el pasillo, el del pasillo")
	check_eq(_active(&"tono_banos"), 0, "el de los baños se va")
	await host.get_tree().process_frame
	check(scape.emitters_of(&"tono_pasillo")[0].position.distance_to(world.player.position) < 1.0,
		"el tono de sala va con el jugador")
	check_eq(_active(&"viento_edificio"), 1, "sin corriente, el viento contra el edificio")
	check_eq(_active(&"zumbido_edificio"), 0, "y el edificio no zumba")
	check_eq(_active(&"megafonia_siseo"), 0, "ni los altavoces")
	check_eq(_active(&"relojes"), 0, "lejos de los relojes, no se oyen")
	GameState.set_flag(GameState.FLAG_POWER)
	await host.get_tree().process_frame
	check_eq(_active(&"zumbido_edificio"), 1, "con corriente, el zumbido del edificio")
	check_eq(_active(&"viento_edificio"), 0, "el viento fuerte se va")
	check_eq(_active(&"viento_edificio_corriente"), 1, "queda uno más bajo, tapado por las máquinas")
	await _move_to(Vector2i(39, 6))
	check_eq(_active(&"tono_habitaciones"), 1, "en la enfermería, tono de habitación")
	check_eq(_active(&"relojes"), 1, "y el reloj de la pared")
	await _move_to(MORGUE_CELL)
	check_eq(_active(&"tono_morgue"), 1, "en la morgue, su sala fría")
	check_eq(_active(&"nevera_morgue"), 1, "y su nevera con corriente")
	check_eq(_active(&"tono_sotano"), 0, "no la del sótano")
	check_eq(_active(&"viento_edificio_corriente"), 0, "el viento no baja al sótano")
	await _move_to(Vector2i(24, 37))
	check_eq(_active(&"tono_sotano"), 1, "en la lavandería, el sótano")
	check_eq(_active(&"bomba_lavanderia"), 1, "la bomba de agua con corriente")
	check_eq(_active(&"goteo_sotano"), 1, "y el goteo en el charco")
	await _teardown()


func test_sueltos_variados_y_apagados_con_la_distancia() -> void:
	await _setup(CORRIDOR_CELL, false)
	var shots: int = 0
	for sound: AmbientSoundDef in scape.def.sounds:
		if sound.kind == AmbientSoundDef.Kind.ONE_SHOT:
			shots += 1
			check(sound.cooldown.x >= 10.0, "%s tiene enfriamiento" % sound.id)
	check(shots >= 25, "hay muchos sonidos sueltos distintos (%d)" % shots)
	check(scape.def.min_gap >= 3.0 and scape.def.min_gap <= 6.0, "más frecuentes, pero separados")
	var near_ids: PackedStringArray = []
	for sound: AmbientSoundDef in scape.def.sounds:
		if sound.kind == AmbientSoundDef.Kind.ONE_SHOT and sound.fits(CORRIDOR_CELL, false):
			near_ids.append(sound.id)
	check(near_ids.size() >= 6, "en el pasillo sin corriente pueden sonar varios (%s)" % ", ".join(near_ids))
	check(not near_ids.has("cebadores"), "sin corriente no hay cebadores")
	check(not near_ids.has("crujidos_sotano"), "ni crujidos del sótano en la planta")
	# Un suelto lejano suena por el eco y apagado; uno cercano, por el eco sin filtro.
	var drip: AmbientSoundDef = AmbientSoundDef.new()
	drip.kind = AmbientSoundDef.Kind.ONE_SHOT
	drip.sounds = PackedStringArray(["drip"])
	var before: int = scape.get_child_count()
	scape.call(&"_play_shot", drip, world.player.position + Vector2(500, 0))
	scape.call(&"_play_shot", drip, world.player.position + Vector2(30, 0))
	var players: Array[AudioStreamPlayer2D] = []
	for i: int in range(before, scape.get_child_count()):
		players.append(scape.get_child(i) as AudioStreamPlayer2D)
	check_eq(players.size(), 2, "suenan los dos")
	if players.size() == 2:
		check_eq(players[0].bus, AudioBuses.AMBIENCE_FARTHEST, "el lejano, apagado")
		check_eq(players[1].bus, AudioBuses.AMBIENCE_ROOM, "el cercano, con el eco de la sala")
	var camera: Camera2D = world.get_viewport().get_camera_2d()
	check(camera != null, "hay cámara (quien escucha)")
	var center: Vector2 = camera.get_screen_center_position() if camera != null else world.player.global_position
	var far_step: AudioStreamPlayer2D = Sfx.at(world, "drip", world.to_local(center + Vector2(520, 0)))
	var near_step: AudioStreamPlayer2D = Sfx.at(world, "drip", world.to_local(center))
	check_eq(far_step.bus, AudioBuses.SFX_FARTHEST, "un efecto lejano del mundo, apagado")
	check_eq(near_step.bus, AudioBuses.SFX, "uno cercano, por Efectos (y la sala)")
	await _teardown()
