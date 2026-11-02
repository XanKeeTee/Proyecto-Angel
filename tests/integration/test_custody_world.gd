extends TestCase
## Custodia y mundo: descartar deja el objeto en el suelo (y en el guardado), recogerlo lo devuelve
## con su estado, descartar desde la lista, la pestaña FABRICAR y las manos en EQUIPO.

const SCENE: String = "res://scenes/world/hospital/hospital.tscn"


func _spawn() -> WorldController:
	var w: WorldController = load(SCENE).instantiate()
	host.add_child(w)
	w.message.auto_advance = 0.01
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	return w


func _dropped(w: WorldController) -> Array[DroppedItem]:
	var result: Array[DroppedItem] = []
	for n: Node in w.find_children("*", "DroppedItem", true, false):
		var d: DroppedItem = n as DroppedItem
		if d.is_active():
			result.append(d)
	return result


func test_descartar_deja_el_objeto_en_el_suelo_y_se_guarda() -> void:
	GameState.new_game()
	var w: WorldController = await _spawn()
	w.player.position = Vector2(30 * 32 + 16, 15 * 32 + 16)
	var c: Custody = GameState.character.custody
	GameState.give_item(Registry.item(&"desinfectante"))
	GameState.give_item(Registry.item(&"llave_sotano"))
	var bottle: ItemStack = c.find_first(&"desinfectante")
	bottle.durability = 1
	check_eq(GameState.character.discard(c.find_first(&"llave_sotano")), "No. Podrías necesitarlo.", "la llave no se tira")
	check(GameState.character.discard(bottle).begins_with("Dejas"), "descarta el desinfectante")
	check(not c.has(&"desinfectante"), "sale de la custodia")
	var on_floor: Array[DroppedItem] = _dropped(w)
	check_eq(on_floor.size(), 1, "aparece en el suelo")
	if on_floor.is_empty():
		w.queue_free()
		return
	check(on_floor[0].position.distance_to(w.player.position) < 16.0, "a los pies del jugador")
	check_eq(CustodyWorldLink.saved_entries().size(), 1, "queda anotado para el guardado")
	# Guardar y cargar: sigue en el suelo.
	GameState.player_scene = SCENE
	GameState.player_position = w.player.position
	check(SaveSystem.save_game(7), "guarda")
	w.queue_free()
	await host.get_tree().process_frame
	GameState.new_game()
	check(SaveSystem.load_game(7), "carga")
	var w2: WorldController = await _spawn()
	var again: Array[DroppedItem] = _dropped(w2)
	check_eq(again.size(), 1, "tras cargar sigue en el suelo")
	if not again.is_empty():
		var d: DroppedItem = again[0]
		w2.player.place(d.base_cell() + Vector2i(0, 1), Vector2i.UP)
		check(w2.pick_target() == d, "se puede interactuar con él")
		var result: InteractionResult = d.perform(Interactable.ACT_TAKE, GameState.character)
		check(result.lines.is_empty() or not result.lines[0].begins_with("No te cabe"), "se recoge")
		var back: ItemStack = GameState.character.custody.find_first(&"desinfectante")
		check(back != null and back.durability == 1, "vuelve con el mismo desgaste")
		await host.get_tree().process_frame
		check(_dropped(w2).is_empty(), "ya no está en el suelo")
		check(CustodyWorldLink.saved_entries().is_empty(), "y se borra del guardado")
	SaveSystem.delete_save(7)
	w2.queue_free()
	await host.get_tree().process_frame


func test_descartar_desde_la_lista() -> void:
	GameState.new_game()
	var w: WorldController = await _spawn()
	var c: Custody = GameState.character.custody
	GameState.give_item(Registry.item(&"analgesicos"), 2)
	GameState.give_item(Registry.item(&"fusible"))
	w.custody_screen.open()
	var page: ItemsPage = w.custody_screen.items_page()
	page.select_stack(c.find_first(&"fusible"))
	_key(w.custody_screen, KEY_DELETE)
	check(c.has(&"fusible"), "el fusible (objeto principal) no se descarta")
	check(page.actions_for(c.find_first(&"fusible")).all(func(a: Dictionary) -> bool: return a["label"] != "Descartar"),
		"ni se ofrece")
	page.select_stack(c.find_first(&"analgesicos"))
	_key(w.custody_screen, KEY_DELETE)
	check(not c.has(&"analgesicos"), "Supr descarta los analgésicos")
	check_eq(_dropped(w).size(), 1, "y aparecen en el mundo")
	await w.custody_screen.close()
	w.queue_free()
	await host.get_tree().process_frame


func test_pestanas_fabricar_y_equipo() -> void:
	GameState.new_game()
	var w: WorldController = await _spawn()
	var c: Custody = GameState.character.custody
	GameState.give_item(Registry.item(&"bata_medico"))
	GameState.give_item(Registry.item(&"bisturi"))
	var screen: CustodyScreen = w.custody_screen
	screen.open()
	var page: ItemsPage = screen.items_page()
	check(page.select_stack(c.find_first(&"bata_medico")), "la bata está en Armaduras")
	check_eq(page.section, ItemDef.Section.ARMOR, "cambia a su categoría")
	_key(screen, KEY_T)
	check_eq(c.count(&"tela"), 3, "rasgar desde la lista da tela")
	screen._set_tab(CustodyScreen.Tab.CRAFT)
	check(screen._selected_recipe != null, "hay una receta elegida")
	screen._selected_recipe = null
	for r: RecipeDef in Crafting.known_recipes(c):
		if r.id == &"torniquete":
			screen._selected_recipe = r
	screen._do_craft()
	check(c.has(&"torniquete"), "fabricar desde la pestaña")
	screen._set_craft_mode(CustodyScreen.CraftMode.COMBINE)
	screen._set_tab(CustodyScreen.Tab.CHARACTER)
	var equip: EquipmentPage = screen.equipment_page()
	equip.select_slot(EquipmentPage.HAND_R)
	equip.equip_in_slot(c.find_first(&"bisturi"))
	check(GameState.character.wielded() != null and GameState.character.wielded().def.id == &"bisturi", "empuña desde EQUIPO")
	equip.select_slot(EquipmentPage.HAND_L)
	check(equip.candidates().has(c.find_first(&"bisturi")), "las armas aparecen también para la izquierda")
	equip.select_slot(EquipmentPage.HAND_R)
	equip.clear_selected()
	check(GameState.character.wielded() == null, "guardar el arma")
	await screen.close()
	w.queue_free()
	await host.get_tree().process_frame


func _key(screen: CustodyScreen, code: Key) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	screen._unhandled_input(ev)
