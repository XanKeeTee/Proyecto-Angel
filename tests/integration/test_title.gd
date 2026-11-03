extends TestCase
## Pantalla de título: menú completo, navegación con teclado/mando y paneles de Cargar y Créditos.

const SCENE: String = "res://scenes/ui/title/title_screen.tscn"

var _backup: Dictionary[int, String] = {}


## Guarda aparte las partidas de verdad (las pruebas borran y crean grabaciones).
func _stash_saves() -> void:
	_backup.clear()
	for slot: int in 3:
		if SaveSystem.has_save(slot):
			_backup[slot] = FileAccess.get_file_as_string(SaveSystem.slot_path(slot))
		SaveSystem.delete_save(slot)


func _restore_saves() -> void:
	for slot: int in 3:
		SaveSystem.delete_save(slot)
	for slot: int in _backup:
		var file: FileAccess = FileAccess.open(SaveSystem.slot_path(slot), FileAccess.WRITE)
		file.store_string(_backup[slot])
		file.close()


func _items(title: Node) -> PackedStringArray:
	var menu: VBoxContainer = title.get("_menu")
	var names: PackedStringArray = []
	for child: Node in menu.get_children():
		names.append((child as Button).text.trim_prefix("▸ "))
	return names


func _press(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await host.get_tree().process_frame
	var release: InputEventAction = InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await host.get_tree().process_frame


func test_menu_sin_partida_y_con_partida() -> void:
	_stash_saves()
	var title: Node = load(SCENE).instantiate()
	host.add_child(title)
	await host.get_tree().process_frame
	check_eq(_items(title), PackedStringArray(["Nueva partida", "Opciones", "Créditos", "Salir"]), "sin partida no hay Continuar ni Cargar")
	title.queue_free()
	await host.get_tree().process_frame
	GameState.new_game()
	SaveSystem.save_game()
	title = load(SCENE).instantiate()
	host.add_child(title)
	await host.get_tree().process_frame
	check_eq(_items(title), PackedStringArray(["Continuar", "Nueva partida", "Cargar", "Opciones", "Créditos", "Salir"]), "con partida, todo el menú")
	title.queue_free()
	await host.get_tree().process_frame
	_restore_saves()


func test_navegacion_y_paneles() -> void:
	_stash_saves()
	var title: Node = load(SCENE).instantiate()
	host.add_child(title)
	# Espera a que termine la entrada (la nieve se retira y el menú toma el foco).
	await host.get_tree().create_timer(1.3).timeout
	var menu: VBoxContainer = title.get("_menu")
	var first: Button = menu.get_child(0) as Button
	check(first.has_focus(), "el menú empieza con el foco en la primera entrada")
	check(first.text.begins_with("▸ "), "la entrada elegida lleva la marca")
	await _press(&"ui_down")
	var second: Button = menu.get_child(1) as Button
	check(second.has_focus(), "abajo pasa a la siguiente entrada")
	check(not first.text.begins_with("▸ "), "la anterior pierde la marca")
	# Créditos (tercera entrada sin partida): se abre el panel y Esc lo cierra.
	await _press(&"ui_down")
	await _press(&"ui_accept")
	var credits: TitlePanel = title.get("_credits_panel")
	check(credits.visible, "Intro en Créditos abre el panel")
	await _press(&"ui_cancel")
	check(not credits.visible, "Esc cierra el panel")
	check((menu.get_child(2) as Button).has_focus(), "el foco vuelve a Créditos")
	title.queue_free()
	await host.get_tree().process_frame
	_restore_saves()


func test_el_fondo_es_el_hospital_sin_guion_ni_estado() -> void:
	_stash_saves()
	GameState.new_game()
	var flags_before: int = GameState.flags.size()
	var objects_before: int = GameState.objects.size()
	var title: Node = load(SCENE).instantiate()
	host.add_child(title)
	await host.get_tree().create_timer(0.5).timeout
	var background: TitleBackground = title.get("_background")
	var viewport: SubViewport = null
	for node: Node in background.find_children("*", "SubViewport", true, false):
		viewport = node as SubViewport
	check(viewport != null, "el fondo va en un SubViewport")
	check(viewport.find_child("Stretcher09", true, false) != null, "con la Habitación 09 de verdad")
	check(viewport.find_children("*", "WorldController", true, false).is_empty(), "sin el guion del mapa")
	check(viewport.find_child("Player", true, false) == null, "sin jugador")
	check(viewport.find_child("HorrorDirector", true, false) == null, "sin el terror del juego")
	check(viewport.find_child("Ambience", true, false) == null, "sin el ambiente del juego")
	check_eq(GameState.flags.size(), flags_before, "no toca las banderas")
	check_eq(GameState.objects.size(), objects_before, "no toca el estado de los objetos")
	title.queue_free()
	await host.get_tree().process_frame
	_restore_saves()
