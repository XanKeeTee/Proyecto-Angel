extends TestCase
## El prólogo completo en la escena real: se puede terminar y todo es alcanzable andando.

const SCENE: String = "res://scenes/world/hospital/hospital.tscn"

var world: WorldController


func _setup() -> void:
	GameState.new_game()
	world = load(SCENE).instantiate()
	host.add_child(world)
	world.message.auto_advance = 0.01
	await host.get_tree().process_frame


func _teardown() -> void:
	world.queue_free()
	await host.get_tree().process_frame
	host.get_tree().paused = false


func _act(id: String, action: StringName = &"") -> InteractionResult:
	var it: Interactable = world.find_object(StringName(id))
	if it == null:
		failures.append("%s: no existe el objeto %s" % [current, id])
		return InteractionResult.new()
	if action == &"":
		var primary: Dictionary = it.primary_action(GameState.character)
		if primary.is_empty():
			failures.append("%s: %s no tiene acción" % [current, id])
			return InteractionResult.new()
		action = primary["id"]
	var result: InteractionResult = it.perform(action, GameState.character)
	await world.on_interacted(it, action, result)
	if result.special != &"" and result.special != WorldController.SAVE_SPECIAL:
		await world.on_special(result.special, it)
	return result


func _has(id: String) -> bool:
	return GameState.character.custody.has(StringName(id))


func test_se_puede_terminar() -> void:
	await _setup()
	await _act("mesita_09")
	check(_has("linterna"), "linterna en la mesita")
	check_eq(GameState.character.flashlight().charge, 35.0, "empieza con poca batería")
	check(GameState.character.custody.pockets.has(GameState.character.flashlight()), "la linterna va a un bolsillo")
	await _act("puerta_hab09")
	await _act("puerta_almacen")
	await _act("taquilla_almacen")
	check(_has("palanca"), "palanca")
	await _act("puerta_quirofano")
	check(world.find_object(&"puerta_quirofano").is_open, "la palanca abre el quirófano")
	check(not _has("palanca"), "la palanca se queda en la puerta")
	await _act("bandeja_quirofano")
	check(_has("destornillador"), "destornillador")
	await _act("puerta_hab11")
	await _act("cama_11")
	check(_has("llave_botiquin"), "llave pequeña en la cama de la 11")
	await _act("puerta_enfermeria")
	await _act("botiquin_enfermeria")
	check(_has("llave_archivo"), "llave del archivo")
	await _act("puerta_archivo")
	check(world.find_object(&"puerta_archivo").is_open, "archivo abierto")
	await _act("estanteria_archivo")
	await _act("escritorio_archivo")
	await _act("archivador_archivo_3")
	check(_has("fusible") and _has("llave_sotano"), "fusible y llave del sótano")
	check(GameState.character.custody.documents.has(&"expediente_09"), "expediente de la 09")
	await _act("puerta_escalera")
	check(world.find_object(&"puerta_escalera").is_open, "escalera abierta")
	await _act("b_puerta_taller")
	await _act("estanteria_taller")
	check(_has("valvula_averiada"), "válvula averiada")
	var c: Custody = GameState.character.custody
	c.combine(c.find_first(&"destornillador"), c.find_first(&"valvula_averiada"))
	check(_has("valvula_reparada"), "destornillador + válvula = válvula reparada")
	await _act("b_puerta_electrica")
	await _act("cuadro_electrico")
	await _act("cuadro_electrico", &"item:0")
	check(GameState.has_flag(&"panel_reparado"), "bornas apretadas")
	await _act("cuadro_electrico", &"item:1")
	check(GameState.has_flag(&"fusible_puesto"), "fusible colocado")
	await _act("b_puerta_calderas")
	await _act("generador", &"item:0")
	check(GameState.has_flag(&"valvula_puesta"), "válvula instalada")
	await _act("generador")
	check(GameState.has_flag(GameState.FLAG_POWER), "vuelve la luz")
	check(GameState.has_flag(&"pasillo_imposible"), "se abre el pasillo imposible")
	check((world.get_node("%Impossible") as TileMapLayer).visible, "el pasillo imposible se ve")
	await _teardown()


func test_todo_es_alcanzable() -> void:
	await _setup()
	# Abrir todas las puertas (como al final de una partida) y revelar el pasillo.
	for node: Node in world.find_children("*", "Door", true, false):
		var door: Door = node as Door
		door.force_state(true, false)
	GameState.set_flag(&"pasillo_imposible")
	await host.get_tree().process_frame
	var map: TileMapLayer = world.get_node("%Map")
	var impossible: TileMapLayer = world.get_node("%Impossible")
	var blocked: Dictionary = {}
	for node: Node in world.find_children("*", "Interactable", true, false):
		var it: Interactable = node as Interactable
		if it.blocks and it.is_active():
			for off: Vector2i in it.footprint:
				blocked[it.base_cell() + off] = true
	var doors: Array[Door] = []
	for node: Node in world.find_children("*", "Door", true, false):
		doors.append(node as Door)
	var start: Vector2i = Vector2i(3, 23)
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		var next: Array[Vector2i] = []
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			next.append(cell + d)
		for door: Door in doors:
			var warp: Array = door.warp_for(cell)
			if not warp.is_empty():
				next.append(warp[0])
		for n: Vector2i in next:
			if seen.has(n) or blocked.has(n):
				continue
			var data: TileData = map.get_cell_tile_data(n)
			if data == null:
				data = impossible.get_cell_tile_data(n)
			if data == null or data.get_custom_data("solid"):
				continue
			seen[n] = true
			queue.append(n)
	check(seen.has(Vector2i(-18, 15)), "se llega al final del pasillo imposible")
	check(seen.has(Vector2i(4, 34)), "se llega al sótano")
	var important: Array[String] = ["mesita_09", "taquilla_almacen", "bandeja_quirofano", "cama_11", "botiquin_enfermeria",
		"estanteria_archivo", "escritorio_archivo", "archivador_archivo_3", "estanteria_taller", "cuadro_electrico", "generador",
		"grabadora_control", "grabadora_sotano", "telefono_control", "plano_recepcion"]
	for id: String in important:
		var it: Interactable = world.find_object(StringName(id))
		var reachable: bool = false
		for c: Vector2i in it.cells():
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if seen.has(c + d):
					reachable = true
		check(reachable, "se puede llegar a " + id)
	# Todos los objetos con contenido, al menos alcanzables.
	var unreachable: PackedStringArray = []
	for node: Node in world.find_children("*", "Interactable", true, false):
		var it: Interactable = node as Interactable
		if not it.is_active():
			continue
		var ok: bool = false
		for c: Vector2i in it.cells():
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.ZERO]:
				if seen.has(c + d):
					ok = true
		if not ok:
			unreachable.append(String(it.object_id))
	check(unreachable.is_empty(), "objetos inalcanzables: " + ", ".join(unreachable))
	await _teardown()


## Mantiene pulsada una acción de movimiento hasta llegar a la fila `row` (o agotar el tiempo).
func _walk(action: StringName, row: int, seconds: float) -> void:
	Input.action_press(action)
	var waited: float = 0.0
	while waited < seconds and world.player.cell.y != row:
		await host.get_tree().physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second
	Input.action_release(action)
	for i: int in 6:
		await host.get_tree().physics_frame


func test_puertas_se_cruzan_andando() -> void:
	await _setup()
	var door: Door = world.find_object(&"puerta_hab09") as Door
	var body: CollisionObject2D = door.get_node("Body") as CollisionObject2D
	var occluder: LightOccluder2D = door.get_node("Occluder") as LightOccluder2D
	check(not door.is_open and body.process_mode != Node.PROCESS_MODE_DISABLED and occluder.visible, "cerrada: choca y tapa la luz")
	var frame: Sprite2D = door.get_node("Sprite2D") as Sprite2D
	check_eq(frame.global_position.y, float((door.base_cell().y + 1) * 32), "el marco se ordena por el pie del muro")
	world.player.place(Vector2i(4, 21), Vector2i.UP)
	world.player.input_enabled = true
	await _walk(InputActions.MOVE_UP, 16, 1.5)
	check_eq(world.player.cell.y, 21, "con la puerta cerrada no se pasa")
	door.perform(Interactable.ACT_OPEN, GameState.character)
	check(body.process_mode == Node.PROCESS_MODE_DISABLED and not occluder.visible, "abierta: ni choca ni tapa la luz")
	await _walk(InputActions.MOVE_UP, 16, 4.0)
	check_eq(world.player.cell, Vector2i(4, 16), "se cruza andando hasta el pasillo, sin fundido")
	await _walk(InputActions.MOVE_DOWN, 22, 4.0)
	check_eq(world.player.cell, Vector2i(4, 22), "y se vuelve andando a la habitación")
	# Si se cierra sola con el jugador dentro del hueco, sale hacia el lado más cercano.
	world.player.place(Vector2i(4, 19), Vector2i.UP)
	check(world.actions_for(door).all(func(a: Dictionary) -> bool: return a["id"] != Interactable.ACT_CLOSE), "no se ofrece cerrar desde dentro")
	door.force_state(false)
	check(not door.passage_cells().has(world.player.cell), "una puerta que se cierra no atrapa al jugador")
	await _teardown()


func test_botin_fijo_y_semilla_guardada() -> void:
	await _setup()
	var state: Dictionary = GameState.object_state(LootRoller.STATE_KEY)
	check(state.has("seed") and int(state["seed"]) >= 0, "la semilla se guarda en la partida")
	var expect: Dictionary = {"mesita_09": "linterna", "taquilla_almacen": "palanca", "bandeja_quirofano": "destornillador",
		"cama_11": "llave_botiquin", "botiquin_enfermeria": "llave_archivo", "estanteria_archivo": "fusible",
		"escritorio_archivo": "llave_sotano", "estanteria_taller": "valvula_averiada"}
	for id: String in expect:
		var found: bool = false
		for e: LootEntry in world.find_object(StringName(id)).contents:
			if e.item != null and e.item.id == StringName(expect[id]):
				found = true
		check(found, "%s sigue teniendo %s" % [id, expect[id]])
	var bed: Interactable = world.find_object(&"cama_09")
	for e: LootEntry in bed.contents:
		check(e.document != null, "debajo de tu cama ya no hay ropa fija")
	# Misma semilla al recargar: mismo contenido.
	var before: PackedStringArray = _contents(["taquilla_07", "carro_lavanderia_2", "mesita_12"])
	world.queue_free()
	await host.get_tree().process_frame
	world = load(SCENE).instantiate()
	host.add_child(world)
	await host.get_tree().process_frame
	check_eq(_contents(["taquilla_07", "carro_lavanderia_2", "mesita_12"]), before, "al volver a cargar el mapa sale el mismo botín")
	check(world.find_object(&"mesita_09").has_node("Glint"), "la mesita de la linterna destella")
	var sprite: Sprite2D = world.find_object(&"cama_09").get_node("Sprite2D") as Sprite2D
	check(is_equal_approx(sprite.global_position.y, world.find_object(&"cama_09").position.y - 32 - 12), "la cama se ordena por el borde de atrás")
	await _teardown()


func test_gestos_por_tipo_de_objeto() -> void:
	await _setup()
	var expect: Array = [
		["mesita_09", Interactable.ACT_OPEN, Interactable.ANIM_REACH_LOW],
		["taquilla_almacen", Interactable.ACT_OPEN, Interactable.ANIM_REACH_MID],
		["estanteria_archivo", Interactable.ACT_SEARCH, Interactable.ANIM_REACH_HIGH],
		["estanteria_taller", Interactable.ACT_SEARCH, Interactable.ANIM_REACH_LOW],
		["parte_control", Interactable.ACT_READ, Interactable.ANIM_PICKUP],
		["puerta_hab09", Interactable.ACT_OPEN, Interactable.ANIM_REACH_MID],
		["puerta_archivo", Interactable.ACT_UNLOCK, Interactable.ANIM_KEY],
		["puerta_quirofano", &"item:0", Interactable.ANIM_PRY],
		["generador", Interactable.ACT_DEVICE, Interactable.ANIM_LEVER],
		["generador", &"item:0", Interactable.ANIM_VALVE],
		["cuadro_electrico", &"item:1", Interactable.ANIM_REACH_MID],
		["mesita_09", Interactable.ACT_EXAMINE, &""],
	]
	for row: Array in expect:
		check_eq(world.find_object(StringName(row[0])).anim_for(row[1]), row[2], "gesto de %s · %s" % [row[0], row[1]])
	await _teardown()


## Con un protagonista que tiene `play_action` (contrato con el agente del personaje), el cambio
## de estado llega cuando la mano toca el objeto, no antes.
func test_el_cambio_llega_al_tocar() -> void:
	GameState.new_game()
	world = load(SCENE).instantiate()
	var fake: GDScript = GDScript.new()
	fake.source_code = "extends \"res://scenes/world/player/player.gd\"\nsignal action_contact\nvar gestures: Array = []\n" \
		+ "func play_action(action: StringName, _target: Vector2) -> void:\n\tgestures.append(action)\n" \
		+ "\tawait get_tree().create_timer(0.3).timeout\n\taction_contact.emit()\n\tawait get_tree().create_timer(0.3).timeout\n"
	fake.reload()
	var player: Node = world.find_child("Player", true, false)
	player.set_script(fake)
	host.add_child(world)
	world.message.auto_advance = 0.01
	await host.get_tree().process_frame
	var drawer: Interactable = world.find_object(&"mesita_09")
	world.player.place(Vector2i(3, 23), Vector2i.UP)
	var run: Callable = func() -> void: await world._perform(drawer, Interactable.ACT_OPEN)
	run.call()
	await host.get_tree().create_timer(0.15).timeout
	check(not drawer.is_open, "antes de tocar, el cajón sigue cerrado")
	await host.get_tree().create_timer(0.3).timeout
	check(drawer.is_open, "al tocar, se abre")
	check_eq(world.player.get("gestures"), [&"reach_low"], "gesto de cajón bajo")
	await host.get_tree().create_timer(1.0).timeout
	await _teardown()


func _contents(ids: Array) -> PackedStringArray:
	var result: PackedStringArray = []
	for id: String in ids:
		for e: LootEntry in world.find_object(StringName(id)).contents:
			result.append("%s:%s" % [id, e.item.id if e.item != null else &"doc"])
	return result
