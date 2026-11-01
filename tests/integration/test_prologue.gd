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
