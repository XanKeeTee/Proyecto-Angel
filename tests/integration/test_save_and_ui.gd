extends TestCase
## Guardar y cargar en la escena real, y humo de la interfaz (custodia, inspector, pausa, título).

const SCENE: String = "res://scenes/world/hospital/hospital.tscn"


func _spawn() -> WorldController:
	var w: WorldController = load(SCENE).instantiate()
	host.add_child(w)
	w.message.auto_advance = 0.01
	await host.get_tree().process_frame
	return w


func test_cargar_restaura_el_mundo() -> void:
	GameState.new_game()
	var w: WorldController = await _spawn()
	var drawer: Interactable = w.find_object(&"mesita_09")
	drawer.perform(Interactable.ACT_OPEN, GameState.character)
	w.set_scenery_visible("CorpseGurney", false)
	w.set_scenery_visible("EmptyGurney", true)
	w.move_scenery("Bed08", Vector2(64, 64))
	GameState.set_flag(&"pasillo_imposible")
	w.player.position = Vector2(30 * 32 + 16, 15 * 32 + 16)
	GameState.player_scene = SCENE
	GameState.player_position = w.player.position
	check(SaveSystem.save_game(8), "guarda")
	w.queue_free()
	await host.get_tree().process_frame
	GameState.new_game()
	check(SaveSystem.load_game(8), "carga")
	var w2: WorldController = await _spawn()
	check_eq(w2.player.cell, Vector2i(30, 15), "posición del jugador")
	check(w2.find_object(&"mesita_09").is_open, "el cajón sigue abierto")
	check(GameState.character.custody.has(&"linterna"), "la linterna sigue en la custodia")
	check(not w2.find_object(&"cadaver_quirofano").is_active(), "el cadáver sigue sin estar")
	check(w2.find_object(&"camilla_vacia_quirofano").is_active(), "la camilla vacía sigue a la vista")
	check_eq((w2.find_child("Bed08", true, false) as Node2D).position, Vector2(10 * 32 + 16 + 64, 6 * 32 + 16 + 64), "la cama de la 08 sigue movida")
	check((w2.get_node("%Impossible") as TileMapLayer).visible, "el pasillo imposible sigue abierto")
	SaveSystem.delete_save(8)
	w2.queue_free()
	await host.get_tree().process_frame


func test_interfaz_custodia() -> void:
	GameState.new_game()
	var w: WorldController = await _spawn()
	var c: Custody = GameState.character.custody
	for id: String in ["linterna", "palanca", "venda", "desinfectante", "valvula_averiada"]:
		GameState.give_item(Registry.item(StringName(id)))
	GameState.give_document(Registry.document(&"expediente_09"))
	w.custody_screen.open()
	check(w.custody_screen.is_open() and host.get_tree().paused, "abre y pausa")
	var tray: TrayView = w.custody_screen.find_children("*", "TrayView", true, false)[0]
	var lever: ItemStack = c.find_first(&"palanca")
	tray.set_cursor(lever.cell)
	tray.pick_or_drop()
	tray.set_cursor(Vector2i(4, 1))
	tray.pick_or_drop()
	check_eq(lever.cell, Vector2i(4, 1), "arrastrar y soltar mueve la palanca")
	tray.set_cursor(c.find_first(&"venda").cell)
	tray.pick_or_drop()
	tray.set_cursor(c.find_first(&"desinfectante").cell)
	tray.pick_or_drop()
	check(c.has(&"venda_esterilizada"), "soltar venda sobre desinfectante combina")
	tray.set_cursor(c.find_first(&"linterna").cell)
	tray.pick_or_drop()
	tray.set_cursor(Vector2i(0, TrayView.POCKET_ROW))
	tray.pick_or_drop()
	check(c.pockets[0] != null and c.pockets[0].def.id == &"linterna", "arrastrar al bolsillo 1")
	w.custody_screen._set_tab(CustodyScreen.Tab.DOSSIER)
	w.custody_screen._show_document(&"expediente_09")
	check(not c.is_unread(&"expediente_09"), "leer marca el documento")
	await w.custody_screen.close()
	check(not host.get_tree().paused, "cerrar quita la pausa")
	var stack: ItemStack = c.find_first(&"valvula_averiada")
	w.inspector.show_item(stack.def.display_name, stack.def.description, stack.def.inspect_sheet, stack.def.inspect_views, stack.def.icon)
	w.inspector._step(1)
	w.inspector.close()
	host.get_tree().paused = false
	w.pause_menu.open()
	w.pause_menu.close()
	check(not host.get_tree().paused, "pausa abre y cierra")
	w.queue_free()
	await host.get_tree().process_frame
	var title: Node = load("res://scenes/ui/title/title_screen.tscn").instantiate()
	host.add_child(title)
	await host.get_tree().process_frame
	check(title.get_child_count() > 0, "el título se construye")
	title.queue_free()
	await host.get_tree().process_frame
