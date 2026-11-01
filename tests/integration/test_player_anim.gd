extends TestCase
## Animación del protagonista (gestos, giros, luz desde la lente) y opciones de audio.

const PLAYER: String = "res://scenes/world/player/player.tscn"


func _spawn() -> Player:
	var p: Player = load(PLAYER).instantiate()
	host.add_child(p)
	p.place(Vector2i(5, 5), Vector2i.DOWN)
	await host.get_tree().process_frame
	return p


func _column(p: Player) -> int:
	return (p.get_node("Sprite2D") as Sprite2D).frame % Player.COLUMNS


func _row(p: Player) -> int:
	return (p.get_node("Sprite2D") as Sprite2D).frame / Player.COLUMNS


func test_gesto_en_reposo() -> void:
	var p: Player = await _spawn()
	var seen: Dictionary = {}
	for i: int in 30:
		await host.get_tree().process_frame
		seen[_column(p)] = true
	var breathing: int = 0
	for c: int in seen:
		if c < 8:
			breathing += 1
	check(breathing >= 1, "respira en reposo")
	p._idle_time = 100.0
	var fidget: bool = false
	for i: int in 40:
		await host.get_tree().process_frame
		var c: int = _column(p)
		if c >= Player.ANIM_FIDGET.x and c < Player.ANIM_FIDGET.x + Player.ANIM_FIDGET.y:
			fidget = true
	check(fidget, "tras un rato quieto hace su gesto")
	p.queue_free()


func test_giro_pasa_por_intermedias() -> void:
	var p: Player = await _spawn()
	check_eq(_row(p), 0, "empieza mirando abajo")
	p.face(Vector2i.UP)
	var rows: Array[int] = []
	for i: int in 30:
		await host.get_tree().process_frame
		if rows.is_empty() or rows[-1] != _row(p):
			rows.append(_row(p))
	check(rows.size() >= 4, "pasa por orientaciones intermedias (%s)" % str(rows))
	check_eq(rows[-1], 4, "acaba mirando arriba")
	p.queue_free()


func test_luz_sale_de_la_lente() -> void:
	var p: Player = await _spawn()
	p.set_holding_flashlight(true)
	p.set_light_on(true)
	for i: int in 30:
		await host.get_tree().process_frame
	var light: PointLight2D = p.get_node("Flashlight")
	var col: int = _column(p)
	var data: Variant = (p.lens_frames[_row(p)] as Array)[col]
	check(data != null, "el fotograma con linterna tiene posición de lente")
	if data != null:
		var lens: Vector2 = Vector2(float(data[0]), float(data[1]))
		check(light.position.distance_to(lens) < 2.5, "la luz está en la lente (%s / %s)" % [light.position, lens])
		check(lens.y < -15.0, "la lente está a la altura de la mano, no en los pies")
	p.queue_free()


func test_opciones_de_audio() -> void:
	var before: float = Settings.sfx
	for bus: StringName in [&"Ambiente", &"Efectos", &"Interfaz"]:
		check(AudioServer.get_bus_index(bus) >= 0, "existe el canal " + bus)
	Settings.sfx = 0.25
	Settings.apply()
	var db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Efectos"))
	check(absf(db - linear_to_db(0.25)) < 0.1, "el volumen de efectos se aplica al canal")
	Settings.sfx = before
	Settings.apply()
