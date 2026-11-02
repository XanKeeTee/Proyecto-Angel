extends TestCase
## Interacción con el entorno y persistencia del estado de los objetos.


func _item(id: String) -> ItemDef:
	return Registry.item(StringName(id))


func _fresh() -> CharacterState:
	GameState.new_game()
	return GameState.character


func _spawn(node: Interactable) -> Interactable:
	host.add_child(node)
	return node


func _loot(id: String, amount: int = 1) -> LootEntry:
	var entry: LootEntry = LootEntry.new()
	entry.item = _item(id)
	entry.quantity = amount
	return entry


func _drawer(id: String) -> Interactable:
	var drawer: Interactable = Interactable.new()
	drawer.object_id = StringName(id)
	drawer.display_name = "Cajón"
	drawer.kind = Interactable.Kind.CONTAINER
	drawer.openable = true
	drawer.contents = [_loot("pilas", 2)]
	return drawer


func _ids(actions: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	for a: Dictionary in actions:
		result.append(a["id"])
	return result


func test_cajon_abrir_coger_y_queda_abierto() -> void:
	var ch: CharacterState = _fresh()
	var drawer: Interactable = _spawn(_drawer("t_cajon"))
	check_eq(drawer.state_name(), "Cerrado", "empieza cerrado")
	check_eq(drawer.primary_action(ch)["id"], Interactable.ACT_OPEN, "acción principal: abrir")
	drawer.perform(Interactable.ACT_OPEN, ch)
	check_eq(ch.custody.count(&"pilas"), 2, "coge las pilas al abrir")
	check(drawer.is_open and drawer.is_empty(), "queda abierto y vacío")
	check_eq(drawer.state_name(), "Vacío", "estado vacío")
	check_eq(drawer.primary_action(ch)["id"], Interactable.ACT_CLOSE, "ahora se puede cerrar")
	drawer.queue_free()
	# Recrear el mismo objeto (como al volver a la sala o cargar): conserva su estado.
	var again: Interactable = _spawn(_drawer("t_cajon"))
	check(again.is_open and again.is_empty(), "al recrearlo sigue abierto y vacío")
	again.perform(Interactable.ACT_OPEN, ch)
	check_eq(ch.custody.count(&"pilas"), 2, "las pilas no reaparecen")
	again.queue_free()


func test_cerrado_con_llave() -> void:
	var ch: CharacterState = _fresh()
	var box: Interactable = _drawer("t_botiquin")
	box.start_locked = true
	box.key_item = _item("llave_botiquin")
	_spawn(box)
	var r: InteractionResult = box.perform(Interactable.ACT_OPEN, ch)
	check(box.is_locked, "sin llave sigue bloqueado")
	check(r.lines.size() > 0, "explica que está cerrado")
	ch.custody.add_item(_item("llave_botiquin"))
	check_eq(box.primary_action(ch)["id"], Interactable.ACT_UNLOCK, "con llave ofrece abrir con ella")
	box.perform(Interactable.ACT_UNLOCK, ch)
	check(not box.is_locked and box.is_open, "abierto")
	check(not ch.custody.has(&"llave_botiquin"), "la llave se queda puesta")
	check_eq(ch.custody.count(&"pilas"), 2, "y coge el contenido")
	box.queue_free()


func test_con_mucho_encima_se_coge_igual() -> void:
	# Sin límite de espacio (lista al estilo de Fear & Hunger): registrar siempre lo coge todo.
	var ch: CharacterState = _fresh()
	for i: int in 10:
		ch.custody.add_item(_item("valvula_averiada"))
	var bin: Interactable = Interactable.new()
	bin.object_id = &"t_papelera"
	bin.kind = Interactable.Kind.CONTAINER
	bin.contents = [_loot("venda_sucia")]
	_spawn(bin)
	bin.perform(Interactable.ACT_SEARCH, ch)
	check(bin.is_empty() and ch.custody.has(&"venda_sucia"), "se coge")
	bin.queue_free()


func test_recoger_objeto_suelto() -> void:
	var ch: CharacterState = _fresh()
	var lamp: Interactable = Interactable.new()
	lamp.object_id = &"t_linterna"
	lamp.kind = Interactable.Kind.PICKUP
	lamp.contents = [_loot("linterna")]
	_spawn(lamp)
	lamp.perform(Interactable.ACT_TAKE, ch)
	check(ch.custody.has(&"linterna"), "recogida")
	check(not lamp.visible, "desaparece del mundo")
	check(lamp.get_actions(ch).is_empty(), "ya no ofrece acciones")
	lamp.queue_free()


func test_leer_documento() -> void:
	var ch: CharacterState = _fresh()
	var doc: DocumentDef = DocumentDef.new()
	doc.id = &"t_doc"
	doc.title = "Prueba"
	var note: Interactable = Interactable.new()
	note.object_id = &"t_nota"
	note.kind = Interactable.Kind.READABLE
	note.document = doc
	_spawn(note)
	var r: InteractionResult = note.perform(Interactable.ACT_READ, ch)
	check(r.read_document == doc, "abre el lector")
	check(ch.custody.documents.has(&"t_doc"), "pasa al expediente")
	check(ch.custody.items.is_empty(), "no es un objeto de la lista")
	note.queue_free()


func test_usar_objeto_sobre_el_mundo() -> void:
	var ch: CharacterState = _fresh()
	ch.custody.add_item(_item("palanca"))
	var door: Interactable = _drawer("t_atascada")
	door.start_locked = true
	var use: ItemUse = ItemUse.new()
	use.item = _item("palanca")
	use.opens = true
	use.uses_durability = true
	use.sets_flag = &"t_forzada"
	door.item_uses = [use]
	_spawn(door)
	check_eq(String(door.primary_action(ch)["id"]), "item:0", "ofrece forzar con la palanca")
	door.perform(&"item:0", ch)
	check(door.is_open, "abierta")
	check(GameState.has_flag(&"t_forzada"), "activa la bandera")
	check_eq(ch.custody.find_first(&"palanca").durability, 5, "la palanca se desgasta")
	door.queue_free()


func test_requiere_bandera() -> void:
	var ch: CharacterState = _fresh()
	var lever: Interactable = Interactable.new()
	lever.object_id = &"t_palanca_luz"
	lever.kind = Interactable.Kind.DEVICE
	lever.requires_flag = &"t_corriente"
	lever.blocked_text = "No pasa nada."
	lever.device_text = "Clac."
	_spawn(lever)
	var r: InteractionResult = lever.perform(Interactable.ACT_DEVICE, ch)
	check(r.lines.has("No pasa nada."), "sin corriente no funciona")
	GameState.set_flag(&"t_corriente")
	r = lever.perform(Interactable.ACT_DEVICE, ch)
	check(r.lines.has("Clac."), "con corriente sí")
	lever.queue_free()


func test_guardar_y_cargar_partida() -> void:
	var ch: CharacterState = _fresh()
	var drawer: Interactable = _spawn(_drawer("t_guardado"))
	drawer.perform(Interactable.ACT_OPEN, ch)
	GameState.set_flag(&"t_evento")
	GameState.player_scene = "res://x.tscn"
	GameState.player_position = Vector2(100, 200)
	ch.vitals.set_bleeding(true)
	check(SaveSystem.save_game(9), "guarda")
	GameState.new_game()
	check(not GameState.has_flag(&"t_evento"), "partida nueva limpia")
	check(SaveSystem.load_game(9), "carga")
	check(GameState.has_flag(&"t_evento"), "bandera recuperada")
	check_eq(GameState.character.custody.count(&"pilas"), 2, "inventario recuperado")
	check(GameState.character.vitals.bleeding, "sangrado recuperado")
	check_eq(GameState.player_position, Vector2(100, 200), "posición recuperada")
	check(GameState.object_state(&"t_guardado").get("open", false), "cajón abierto recuperado")
	SaveSystem.delete_save(9)
	drawer.queue_free()
