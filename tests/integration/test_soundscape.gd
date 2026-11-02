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
