extends TestCase
## Interfaz del combate: placa de mensajes, menús construidos desde la API de opciones
## (`ActionMenuModel`), ficha de detalle con el motivo de lo desactivado, apuntar con el ratón y
## con la lámina, registro, fichas de paciente y figura del grupo de espaldas.


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
	check_eq(window.history.size(), 3, "todo queda en el historial")
	window.line_seconds = 10.0
	window.push("Larga espera.")
	await host.get_tree().process_frame
	window.skip()
	check(window.is_idle(), "Intro o clic lo pasa")
	window.queue_free()


func test_los_menus_se_construyen_desde_action_menu() -> void:
	var scene: BattleScene = _open_scene()
	await host.get_tree().process_frame
	var hero: Combatant = scene.battle.protagonist()
	var options: Array[ActionOption] = scene.battle.action_menu(hero)
	var labels: PackedStringArray = []
	for button: BattleOption in scene.menu_buttons():
		labels.append(button.text)
	check_eq(labels[0], "Atacar", "primero, Atacar")
	for category: StringName in [ActionMenuModel.ATTACK, ActionMenuModel.SKILL, ActionMenuModel.GUARD]:
		check(not ActionMenuModel.of_category(options, category).is_empty()
			and labels.has(ActionMenuModel.CATEGORY_LABELS[category]), "una entrada por categoría: %s" % category)
	for option: ActionOption in ActionMenuModel.of_category(options, ActionMenuModel.OTHER):
		check(labels.has(option.label), "las opciones sueltas van en el principal: %s" % option.label)
	for button: BattleOption in scene.menu_buttons():
		check(button.icon_texture != null, "cada orden lleva su icono: %s" % button.text)
	# Habilidades: las de las reglas para el arma que lleva, con su coste o motivo.
	scene.open_category(ActionMenuModel.SKILL)
	var skills: Array[ActionOption] = ActionMenuModel.of_category(options, ActionMenuModel.SKILL)
	check(skills.size() >= 3, "el tubo da varias habilidades")
	var buttons: Array[BattleOption] = scene.menu_buttons()
	check_eq(buttons.size(), skills.size() + 1, "el submenú lista las habilidades de las reglas y Atrás")
	for i: int in skills.size():
		check(buttons[i].option.id == skills[i].id and buttons[i].text == skills[i].label, "en orden: %s" % skills[i].id)
		check_eq(buttons[i].disabled, not skills[i].enabled, "apagada si las reglas la apagan: %s" % skills[i].id)
		check(buttons[i].icon_texture != null, "con su icono: %s" % skills[i].id)
		if skills[i].enabled and skills[i].value_text != "":
			check_eq(buttons[i].suffix, skills[i].value_text, "con su coste o efecto: %s" % skills[i].id)
	check_eq(scene.menu_options()[scene.menu_options().size() - 1], "Atrás", "se puede volver atrás")
	scene.queue_free()
	await host.get_tree().process_frame


func test_una_opcion_desactivada_muestra_su_motivo() -> void:
	var scene: BattleScene = _open_scene()
	await host.get_tree().process_frame
	scene.open_category(ActionMenuModel.SKILL)
	var off: BattleOption = null
	for button: BattleOption in scene.menu_buttons():
		if button.disabled and button.option != null:
			off = button
	check(off != null, "con el enemigo de pie, alguna habilidad está apagada (rematar)")
	if off == null:
		scene.queue_free()
		return
	await host.get_tree().process_frame
	off.grab_focus()
	await host.get_tree().process_frame
	var detail: PaperCard = scene.detail_card()
	check(detail.visible, "al señalarla sale la ficha de detalle")
	var text: String = "\n".join(detail.texts())
	check(off.option.disabled_reason != "" and text.contains(off.option.disabled_reason), "la ficha dice por qué no se puede")
	check(detail.stamp_texture != null, "con el sello de denegado")
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	off.gui_input.emit(event)
	await host.get_tree().process_frame
	check_eq(scene._orders.size(), 0, "pulsarla no da ninguna orden")
	scene.queue_free()
	await host.get_tree().process_frame


func test_tratar_una_parte_con_una_venda() -> void:
	var scene: BattleScene = _open_scene({&"venda": 2, &"analgesicos": 1})
	await host.get_tree().process_frame
	var hero: Combatant = scene.battle.protagonist()
	hero.add_bleed(CombatTypes.ARM_L, 2)
	scene._show_main_menu()
	scene.open_category(ActionMenuModel.ITEM)
	var bandage: BattleOption = null
	for button: BattleOption in scene.menu_buttons():
		if button.option != null and button.option.id == &"item:venda":
			bandage = button
	check(bandage != null and not bandage.disabled, "la venda se puede usar (el brazo sangra)")
	check(bandage.suffix.contains("2"), "con la cantidad")
	bandage.pressed.emit()
	check_eq(scene.phase(), BattleScene.Phase.AIM, "se elige dónde: la lámina del propio cuerpo")
	check(scene.body_diagram().visible, "con la lámina")
	var arm: BattleOption = scene._button_for_part(CombatTypes.ARM_L)
	check(arm != null and not arm.disabled and arm.suffix.contains("sangra"), "el brazo que sangra, elegible")
	var head: BattleOption = scene._button_for_part(CombatTypes.HEAD)
	check(head != null and head.disabled, "la cabeza sana, no")
	scene.aim_at_part(CombatTypes.ARM_L)
	check(scene.part_card().visible and "\n".join(scene.part_card().texts()).length() > 0, "la ficha del tratamiento")
	scene.confirm_aim()
	check_eq(scene._orders.size(), 1, "orden dada")
	check(scene._orders[0].type == CombatTypes.ActionType.ITEM and scene._orders[0].part_id == CombatTypes.ARM_L
		and scene._orders[0].treatment != null, "vendar el brazo izquierdo")
	scene.queue_free()
	await host.get_tree().process_frame


func test_derribado_solo_puede_levantarse() -> void:
	var party: CombatantDef = (BattleScene.DEFAULT_PARTY as CombatantDef).duplicate()
	party.weapon = BattleScene.DEFAULT_WEAPON
	var battle: Battle = Battle.new([party] as Array[CombatantDef], [BattleScene.DEFAULT_ENEMY] as Array[CombatantDef], 5)
	battle.protagonist().add_status(CombatCatalog.status(CombatTypes.STATUS_DOWN))
	var scene: BattleScene = BattleScene.new()
	scene.setup(battle, null, null)
	host.add_child(scene)
	await host.get_tree().process_frame
	var buttons: Array[BattleOption] = scene.menu_buttons()
	check(buttons[0].option != null and buttons[0].option.action_type == CombatTypes.ActionType.RECOVER,
		"lo primero, levantarse")
	check(not buttons[0].disabled, "y se puede")
	var icons: Array[Dictionary] = BattleFrame.status_icons(battle.protagonist())
	var down_icon: bool = false
	for icon: Dictionary in icons:
		down_icon = down_icon or BattleSkin.status_key(icon["kind"]) == &"down"
	check(down_icon, "la ficha enseña el icono de derribado")
	check(BattleSkin.status_icon(CombatTypes.STATUS_DOWN) != null, "que existe")
	check(scene.party_battlers()[0].combatant.is_down(), "la figura está en el suelo")
	scene.queue_free()
	await host.get_tree().process_frame


func test_la_nota_sigue_a_la_intencion() -> void:
	var scene: BattleScene = _open_scene()
	await host.get_tree().process_frame
	var enemy: Combatant = scene.battle.enemies[0]
	var before: String = scene.intent_note().text()
	scene.battle.intents.erase(enemy)
	scene.battle.intent_changed.emit(enemy)
	check(scene.intent_note().text() != before or before == "", "la nota se reescribe cuando cambia la intención")
	check_eq(scene.party_cards()[0].threat_part, &"", "y ya no hay parte amenazada")
	scene.queue_free()
	await host.get_tree().process_frame


func test_apuntar_con_el_raton_sobre_una_parte_la_selecciona() -> void:
	var scene: BattleScene = _open_scene()
	await host.get_tree().process_frame
	var enemy: Combatant = scene.battle.enemies[0]
	scene.open_category(ActionMenuModel.ATTACK)
	await host.get_tree().process_frame
	check_eq(scene.phase(), BattleScene.Phase.AIM, "Atacar va directo a apuntar")
	check(scene.body_diagram().visible, "con la lámina anatómica")
	check(scene.part_card().visible, "y la ficha de la parte")
	var view: EnemyView = scene.enemy_views()[0]
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = view.position + view.anchor(CombatTypes.ARM_L) - scene._stage_input_rect().position
	scene._on_stage_input(motion)
	check_eq(scene.aimed_part(), CombatTypes.ARM_L, "el ratón sobre el brazo lo señala")
	check_eq(view.focus_part, CombatTypes.ARM_L, "el enemigo se oscurece salvo esa parte")
	check_eq(scene.body_diagram().selected, CombatTypes.ARM_L, "y la lámina la marca")
	var card: String = "\n".join(scene.part_card().texts())
	check(card.contains(enemy.parts[CombatTypes.ARM_L].def.display_name), "la ficha es de esa parte")
	check(card.contains("ACIERTO") and card.contains("DAÑO"), "con acierto y daño estimado")
	# Sobre la lámina también se elige.
	var diagram: BodyDiagram = scene.body_diagram()
	check_eq(diagram.part_at(diagram.part_center(CombatTypes.HEAD)), CombatTypes.HEAD, "la lámina sabe dónde está la cabeza")
	# Con las flechas (el menú) se cambia de parte.
	scene.aim_at_part(CombatTypes.TORSO)
	check_eq(view.focus_part, CombatTypes.TORSO, "las flechas mueven el foco")
	# Clic: se autoriza la orden.
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = motion.position
	scene._on_stage_input(click)
	check_eq(scene._orders.size(), 1, "el clic da la orden")
	check_eq(scene._orders[0].part_id, CombatTypes.ARM_L, "a la parte de debajo del ratón")
	check_eq(scene._orders[0].type, CombatTypes.ActionType.ATTACK, "de atacar")
	scene.queue_free()
	await host.get_tree().process_frame


func test_partes_amputadas_no_se_eligen() -> void:
	var scene: BattleScene = _open_scene()
	await host.get_tree().process_frame
	var enemy: Combatant = scene.battle.enemies[0]
	enemy.parts[CombatTypes.ARM_R].amputate()
	scene.open_category(ActionMenuModel.ATTACK)
	var button: BattleOption = scene._button_for_part(CombatTypes.ARM_R)
	check(button != null and button.disabled, "una parte amputada no se puede elegir")
	check_eq(button.suffix, "—", "y no da acierto")
	var diagram: BodyDiagram = scene.body_diagram()
	check_eq(diagram.part_at(diagram.part_center(CombatTypes.ARM_R)), &"", "ni en la lámina")
	check(scene.command_box().size.x > BattleScene.MENU_W, "la caja se ensancha para los nombres largos")
	scene._show_main_menu()
	check(is_equal_approx(scene.command_box().size.x, BattleScene.MENU_W), "al volver, estrecha otra vez")
	scene.queue_free()
	await host.get_tree().process_frame


func test_el_registro_guarda_las_lineas() -> void:
	var scene: BattleScene = _open_scene()
	await host.get_tree().process_frame
	var log: BattleLog = scene.battle_log()
	check(log.lines().has("— RONDA 1 —"), "la ronda abre un grupo en el registro")
	scene.battle.logged.emit("Una línea de prueba.")
	check(log.lines().has("Una línea de prueba."), "lo que cuenta el combate queda en el registro")
	check(not log.is_open, "cerrado de entrada")
	var tab: InputEventKey = InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	scene._unhandled_input(tab)
	check(log.is_open, "Tab lo abre")
	for i: int in 40:
		log.add("Relleno %d." % i)
	log.scroll_by(5)
	check_eq(log.scroll, 5, "se recorre hacia atrás")
	log.add("Nueva.")
	check_eq(log.scroll, 0, "una línea nueva vuelve al final")
	scene._input(tab)
	check(not log.is_open, "y se cierra")
	scene.queue_free()
	await host.get_tree().process_frame


func test_aviso_del_enemigo_y_parte_amenazada() -> void:
	var scene: BattleScene = _open_scene()
	await host.get_tree().process_frame
	var enemy: Combatant = scene.battle.enemies[0]
	var intent: CombatAction = scene.battle.intents.get(enemy)
	check(intent != null, "el enemigo prepara algo")
	check(scene.intent_note().visible and scene.intent_note().text().contains("prepara"), "la nota dice qué prepara")
	var card: PatientCard = scene.party_cards()[0]
	if intent.attack.visibility == CombatTypes.Visibility.FULL and intent.part_id != &"":
		check_eq(card.threat_part, intent.part_id, "la ficha del paciente señala la parte amenazada")
	check(scene.turn_strip().names().size() == 2, "la tira de turno lista a los dos")
	scene.queue_free()
	await host.get_tree().process_frame


func test_fichas_de_paciente_hasta_cuatro() -> void:
	var defs: Array[CombatantDef] = []
	for i: int in 4:
		var def: CombatantDef = (BattleScene.DEFAULT_PARTY as CombatantDef).duplicate()
		def.weapon = BattleScene.DEFAULT_WEAPON
		def.is_protagonist = i == 0
		defs.append(def)
	var scene: BattleScene = BattleScene.new()
	scene.setup(Battle.new(defs, [BattleScene.DEFAULT_ENEMY] as Array[CombatantDef], 2), null, null)
	host.add_child(scene)
	await host.get_tree().process_frame
	var cards: Array[PatientCard] = scene.party_cards()
	check_eq(cards.size(), 4, "una ficha por miembro")
	for i: int in cards.size():
		check(cards[i].get_rect().end.x <= BattleScene.VIEW_SIZE.x, "dentro de la pantalla")
		if i > 0:
			check(cards[i].position.x >= cards[i - 1].get_rect().end.x, "sin pisarse")
		check(cards[i].compact(), "estrechas: sin foto")
	check(cards[0].selected, "la del que elige, resaltada")
	scene.queue_free()
	await host.get_tree().process_frame


func test_ficha_de_paciente_reacciona_al_golpe() -> void:
	var scene: BattleScene = _open_scene()
	await host.get_tree().process_frame
	var card: PatientCard = scene.party_cards()[0]
	var zones: Dictionary[StringName, Rect2] = card.layout()
	check(zones.has(&"body") and zones.has(&"mind") and zones.has(&"wounds") and zones.has(&"weapon"),
		"Cuerpo, Mente, mapa de heridas y arma")
	check(zones.has(&"photo"), "ancha: con la foto")
	check(card.weapon_icon != null, "con el icono del arma empuñada")
	var hero: Combatant = scene.battle.protagonist()
	var before: float = card._body_shown
	hero.body -= 30
	card.hurt(1.0)
	await host.get_tree().create_timer(0.1).timeout
	check(card._body_shown < before and card._body_shown > hero.body, "el líquido baja despacio")
	check(card._body_ghost > card._body_shown, "dejando rastro")
	check(not card._stains.is_empty(), "y la ficha se mancha")
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


func _open_scene(supplies: Dictionary[StringName, int] = {}) -> BattleScene:
	var scene: BattleScene = BattleScene.new()
	var party: CombatantDef = (BattleScene.DEFAULT_PARTY as CombatantDef).duplicate()
	party.weapon = BattleScene.DEFAULT_WEAPON
	var battle: Battle = Battle.new([party] as Array[CombatantDef], [BattleScene.DEFAULT_ENEMY] as Array[CombatantDef], 5)
	battle.supplies = supplies
	scene.setup(battle, null, null)
	host.add_child(scene)
	return scene
