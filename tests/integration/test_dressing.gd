extends TestCase
## El decorado no interactivo (tools/levels/hospital_dressing.gd) en la escena real:
## no tapa puertas ni objetos, todo sigue siendo alcanzable andando, nada queda fuera
## del suelo y los contenedores enseñan su interior vacío solo cuando están abiertos.

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


func _dressing_cells() -> Dictionary:
	var cells: Dictionary = {}
	for node: Node in host.get_tree().get_nodes_in_group(&"dressing"):
		if node.has_meta(&"cells"):
			for c: Vector2i in node.get_meta(&"cells"):
				cells[c] = String(node.name)
	return cells


func test_hay_decorado_y_no_pisa_objetos() -> void:
	await _setup()
	var dressing: Array[Node] = host.get_tree().get_nodes_in_group(&"dressing")
	check(dressing.size() > 80, "hay decorado en las salas (%d)" % dressing.size())
	var map: TileMapLayer = world.get_node("%Map")
	var cells: Dictionary = _dressing_cells()
	for node: Node in world.find_children("*", "Interactable", true, false):
		var it: Interactable = node as Interactable
		for off: Vector2i in it.footprint:
			check(not cells.has(it.base_cell() + off), "%s comparte casilla con %s" % [it.object_id, cells.get(it.base_cell() + off, "")])
	for c: Vector2i in cells:
		var data: TileData = map.get_cell_tile_data(c)
		check(data != null and not data.get_custom_data("solid"), "%s está fuera del suelo en %s" % [cells[c], c])
	await _teardown()


func test_todo_alcanzable_con_decorado() -> void:
	await _setup()
	for node: Node in world.find_children("*", "Door", true, false):
		(node as Door).force_state(true, false)
	await host.get_tree().process_frame
	var map: TileMapLayer = world.get_node("%Map")
	var blocked: Dictionary = _dressing_cells()
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
			if data == null or data.get_custom_data("solid"):
				continue
			seen[n] = true
			queue.append(n)
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
	check(unreachable.is_empty(), "objetos inalcanzables con el decorado: " + ", ".join(unreachable))
	for door: Door in doors:
		var base: Vector2i = Vector2i(floori(door.position.x / 32.0), floori(door.position.y / 32.0))
		check(seen.has(door.warp_front_to) or seen.has(door.warp_back_to) or seen.has(base + Vector2i(0, 1)),
			"se llega a la puerta " + String(door.object_id))
	await _teardown()


func test_cajon_vacio_solo_abierto() -> void:
	await _setup()
	var mesita: Interactable = world.find_object(&"mesita_08")
	check(mesita.frame_empty == 2, "la mesita tiene fotograma de vacío")
	var sprite: Sprite2D = mesita.get_node(^"Sprite2D")
	check_eq(sprite.frame, 0, "cerrada")
	var result: InteractionResult = mesita.perform(&"open", GameState.character)
	await world.on_interacted(mesita, &"open", result)
	result = mesita.perform(&"search", GameState.character)
	await world.on_interacted(mesita, &"search", result)
	check_eq(sprite.frame, 2, "abierta y vacía enseña el cajón vacío")
	result = mesita.perform(&"close", GameState.character)
	await world.on_interacted(mesita, &"close", result)
	check_eq(sprite.frame, 0, "cerrada otra vez vuelve al fotograma cerrado")
	await _teardown()


## Las puertas de las salas al sur del pasillo solo enseñan su remate desde el pasillo: el
## remate es el hueco visto desde arriba y la linterna lo alumbra (la puerta cerrada solo
## tapa la luz con el canto sur), y delante hay desgaste del suelo en vez de sombra de pared.
func test_puertas_se_adivinan_desde_el_otro_lado() -> void:
	await _setup()
	var doorway: Dictionary = {}
	for node: Node in world.find_children("doorway_*", "Sprite2D", true, false):
		var s: Sprite2D = node as Sprite2D
		doorway[Vector2i((s.global_position / 32.0).floor())] = s.rotation
	var lower: int = 0
	for node: Node in world.find_children("*", "Door", true, false):
		var door: Door = node as Door
		if door.always_open:
			continue
		var base: Vector2i = door.base_cell()
		check(doorway.has(base + Vector2i(0, 1)), "%s: desgaste del suelo al pie de la puerta" % door.object_id)
		check(doorway.has(base + Vector2i(0, -4)), "%s: desgaste del suelo al otro lado del remate" % door.object_id)
		var poly: PackedVector2Array = (door.get_node("Occluder") as LightOccluder2D).occluder.polygon
		var top: float = INF
		var bottom: float = -INF
		for p: Vector2 in poly:
			top = minf(top, p.y)
			bottom = maxf(bottom, p.y)
		check(bottom - top <= 8.0, "%s: la puerta cerrada solo tapa la luz con el canto del remate" % door.object_id)
		check_eq(bottom, -2.5 * 32.0, "%s: el canto tapa en el borde sur del remate" % door.object_id)
		if String(door.object_id) in ["puerta_hab09", "puerta_hab12", "puerta_almacen", "puerta_banos", "puerta_control",
				"puerta_quirofano", "puerta_recepcion", "b_puerta_morgue", "b_puerta_calderas", "b_puerta_taller"]:
			lower += 1
	check_eq(lower, 10, "las diez puertas al sur de los pasillos")
	await _teardown()
