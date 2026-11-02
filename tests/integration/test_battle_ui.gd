extends TestCase
## Presentación del combate a la manera de Fear & Hunger: ventana de mensajes de arriba, menú de
## órdenes, partes amputadas al apuntar y figura del grupo de espaldas.


func test_ventana_de_mensajes_de_dos_lineas() -> void:
	var window: MessageWindow = MessageWindow.new()
	window.size = BattleScene.MESSAGE_RECT.size
	host.add_child(window)
	window.line_seconds = 0.05
	window.per_char = 0.0
	window.set_sticky([{"text": "El enfermero prepara TAJO.", "color": UiStyle.BONE}])
	await host.get_tree().process_frame
	check(window.visible_text().contains("prepara"), "sin mensajes, se ve el aviso fijo")
	for i: int in 3:
		window.push("Línea %d." % i)
	await host.get_tree().process_frame
	check_eq(window.visible_text(), "Línea 0.", "un mensaje nuevo quita el aviso y se ve el primero")
	check(not window.is_idle(), "aún queda por contar")
	var waited: float = 0.0
	while not window.is_idle() and waited < 2.0:
		await host.get_tree().process_frame
		waited += 0.016
	check(window.is_idle(), "los mensajes pasan solos")
	var shown: PackedStringArray = window.visible_text().split("\n")
	check(shown.size() <= MessageWindow.MAX_LINES, "como mucho dos líneas a la vez")
	check_eq(shown[shown.size() - 1], "Línea 2.", "la última abajo")
	await host.get_tree().process_frame
	check(window.visible_text().contains("prepara"), "al acabar vuelve el aviso")
	check_eq(window.history.size(), 3, "todo queda en el historial")
	window.line_seconds = 10.0
	window.push("Larga espera.")
	await host.get_tree().process_frame
	window.skip()
	check(window.is_idle(), "Intro o clic lo pasa")
	window.queue_free()


func test_menu_habilidades_y_partes_amputadas() -> void:
	var scene: BattleScene = _open_scene()
	await host.get_tree().process_frame
	var enemy: Combatant = scene.battle.enemies[0]
	scene._show_skill_menu()
	check(scene.menu_options()[0].begins_with("Respirar"), "Habilidades: Respirar")
	enemy.parts[CombatTypes.ARM_R].amputate()
	scene._show_part_menu(enemy)
	var index: int = enemy.part_order.find(CombatTypes.ARM_R)
	var option: BattleOption = scene._menu.get_child(index) as BattleOption
	check(option.disabled, "una parte amputada no se puede elegir")
	check_eq(option.suffix, "—", "y no da acierto")
	check(scene.menu_options()[scene.menu_options().size() - 1] == "Atrás", "se puede volver atrás")
	check(scene.command_box().size.x > BattleScene.MENU_W, "la caja se ensancha para los nombres largos")
	check(is_equal_approx(scene.command_box().get_rect().end.x + BattleScene.BOX_GAP, scene.party_box().position.x),
		"y la del grupo cede el sitio")
	scene._show_main_menu()
	check(is_equal_approx(scene.command_box().size.x, BattleScene.MENU_W), "al volver, estrecha otra vez")
	scene.queue_free()
	await host.get_tree().process_frame


func test_grupo_de_espaldas_provisional() -> void:
	var layers: Array[Texture2D] = PartyBattler.map_back_layers()
	check_eq(layers.size(), 1, "sin custodia, solo el cuerpo")
	var atlas: AtlasTexture = layers[0] as AtlasTexture
	check(atlas != null, "un fotograma de la hoja del mapa")
	check_eq(atlas.region.position.y, PartyBattler.MAP_BACK_ROW * PartyBattler.MAP_FRAME.y, "la fila de espaldas")
	var battler: PartyBattler = PartyBattler.new()
	host.add_child(battler)
	battler.setup(null)
	check_eq(battler.draw_scale, 2.0, "ampliado ×2")
	check_eq(battler.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "sin suavizar")
	battler.queue_free()


func _open_scene() -> BattleScene:
	var scene: BattleScene = BattleScene.new()
	var party: CombatantDef = (BattleScene.DEFAULT_PARTY as CombatantDef).duplicate()
	party.weapon = BattleScene.DEFAULT_WEAPON
	var battle: Battle = Battle.new([party] as Array[CombatantDef], [BattleScene.DEFAULT_ENEMY] as Array[CombatantDef], 5)
	scene.setup(battle, null, null)
	host.add_child(scene)
	return scene
