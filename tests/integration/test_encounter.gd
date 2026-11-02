extends TestCase
## El combate contra el enfermero dentro del prólogo: el tubo fijo de la 12, la aparición al salir
## al pasillo, victoria (cuerpo en el mapa y en el guardado), huida (vuelve más tarde) y derrota.
## También la escena de combate en pantalla.

const SCENE: String = "res://scenes/world/hospital/hospital.tscn"
const CORRIDOR_CELL: Vector2i = Vector2i(12, 15)
const ROOM_CELL: Vector2i = Vector2i(12, 23)

var world: WorldController
var director: EncounterDirector
var battles: Array[Battle] = []


func _setup() -> void:
	GameState.new_game()
	world = load(SCENE).instantiate()
	host.add_child(world)
	world.message.auto_advance = 0.01
	await host.get_tree().process_frame
	director = world.get_node("EncounterDirector_enfermero") as EncounterDirector
	director.death_screen_enabled = false
	battles.clear()


func _teardown() -> void:
	world.queue_free()
	await host.get_tree().process_frame
	host.get_tree().paused = false


func _take_pipe() -> void:
	var pipe: Interactable = world.find_object(&"tubo_hab12")
	pipe.perform(Interactable.ACT_TAKE, GameState.character)


## Entra en una casilla como si el jugador la pisara.
func _enter(cell: Vector2i) -> void:
	world.player.place(cell, Vector2i.DOWN)
	world.player.cell_entered.emit(cell)


## Simula el combate sin interfaz y espera a que el mapa termine de resolverlo.
func _fight(runner: Callable) -> Battle.Outcome:
	director.battle_runner = func(battle: Battle) -> void:
		battles.append(battle)
		runner.call(battle)
	var result: Array = []
	director.resolved.connect(func(outcome: Battle.Outcome) -> void: result.append(outcome), CONNECT_ONE_SHOT)
	_enter(CORRIDOR_CELL)
	var waited: float = 0.0
	while result.is_empty() and waited < 20.0:
		await host.get_tree().create_timer(0.1).timeout
		waited += 0.1
	while director.is_running() and waited < 25.0:
		await host.get_tree().create_timer(0.1).timeout
		waited += 0.1
	return result[0] if not result.is_empty() else Battle.Outcome.ONGOING


func test_el_tubo_esta_fijo_en_la_12() -> void:
	await _setup()
	var pipe: Interactable = world.find_object(&"tubo_hab12")
	check(pipe != null and pipe.is_active(), "el tubo está en la habitación 12")
	check(Rect2i(9, 21, 7, 7).has_point(pipe.base_cell()), "dentro de la 12, junto a la 09")
	var found: bool = false
	for entry: LootEntry in pipe.contents:
		if entry.item != null and entry.item.id == &"tubo_metal":
			found = true
	check(found, "contiene el tubo de hierro")
	for rule: LootScatter in world.loot_plan.scatter:
		check(rule.item.id != &"tubo_metal", "el tubo ya no se reparte al azar")
	await _teardown()


func test_aparece_al_salir_con_el_tubo() -> void:
	await _setup()
	_enter(CORRIDOR_CELL)
	await host.get_tree().process_frame
	check(not director.is_running(), "sin el tubo no aparece")
	_take_pipe()
	check(GameState.has_flag(&"tubo_cogido"), "coger el tubo activa la bandera")
	var held: ItemStack = GameState.character.wielded()
	check(held != null and held.def.id == &"tubo_metal", "con la mano vacía, se empuña solo")
	_enter(ROOM_CELL)
	await host.get_tree().process_frame
	check(not director.is_running(), "dentro de la sala todavía no")
	var outcome: Battle.Outcome = await _fight(func(battle: Battle) -> void:
		check_eq(battle.protagonist().current_weapon().display_name, "Tubo de hierro", "pelea con el tubo")
		_win(battle))
	check_eq(outcome, Battle.Outcome.VICTORY, "en el pasillo empieza el combate")
	await _teardown()


func _win(battle: Battle) -> void:
	var hero: Combatant = battle.protagonist()
	var nurse: Combatant = battle.enemies[0]
	hero.body = 37
	hero.mind = 21
	hero.bleeding = 2
	hero.parts[CombatTypes.ARM_L].amputate()
	nurse.parts[CombatTypes.ARM_R].amputate()
	nurse.parts[CombatTypes.LEG_L].state = CombatTypes.PartState.BROKEN
	nurse.body = 0
	nurse.dead = true
	battle._check_outcome()


func test_victoria_deja_el_cuerpo_y_se_guarda() -> void:
	await _setup()
	_take_pipe()
	var outcome: Battle.Outcome = await _fight(_win)
	check_eq(outcome, Battle.Outcome.VICTORY, "victoria")
	var vitals: Vitals = GameState.character.vitals
	check_eq(vitals.body, 37, "el Cuerpo del combate vuelve al mapa")
	check_eq(vitals.mind, 21, "la Mente también")
	check(vitals.bleeding, "sale sangrando")
	check_eq(int(vitals.wounds.get(CombatTypes.ARM_L, 0)), CombatTypes.PartState.AMPUTATED, "y sin el brazo")
	var state: Dictionary = director.state()
	check_eq(state.get("state", ""), EncounterDirector.STATE_DEAD, "se recuerda que murió")
	var corpse: Interactable = director.corpse()
	check(corpse != null and corpse.is_active(), "el cuerpo queda en el mapa")
	check(not corpse.blocks, "y no corta el pasillo")
	check(corpse.examine_text != "", "se puede examinar")
	check(world.find_object(&"enfermero_cadaver") == corpse, "es un objeto del mapa")
	# Guardar y cargar: el cuerpo sigue ahí, sin el brazo que perdió.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	world.queue_free()
	await host.get_tree().process_frame
	GameState.from_dict(saved)
	GameState.has_position = false
	world = load(SCENE).instantiate()
	host.add_child(world)
	world.message.auto_advance = 0.01
	await host.get_tree().process_frame
	director = world.get_node("EncounterDirector_enfermero") as EncounterDirector
	var again: Interactable = director.corpse()
	check(again != null, "tras cargar, el cuerpo sigue")
	var view: EnemyView = again.find_children("*", "EnemyView", true, false)[0] as EnemyView
	check(view.is_dead(), "tendido")
	check_eq(view.part_state(CombatTypes.ARM_R), CombatTypes.PartState.AMPUTATED, "sin el brazo de instrumental")
	check(again.position.distance_to(Vector2(float(state["x"]), float(state["y"]))) < 32.0, "donde cayó")
	_enter(CORRIDOR_CELL)
	await host.get_tree().process_frame
	check(not director.is_running(), "muerto, no vuelve")
	await _teardown()


func test_huida_y_vuelve_mas_tarde() -> void:
	await _setup()
	_take_pipe()
	var outcome: Battle.Outcome = await _fight(func(battle: Battle) -> void:
		battle.enemies[0].parts[CombatTypes.ARM_R].state = CombatTypes.PartState.BROKEN
		battle.enemies[0].body = 50
		battle.protagonist().fled = true
		battle._check_outcome())
	check_eq(outcome, Battle.Outcome.PARTY_FLED, "huida")
	check_eq(director.state().get("state", ""), EncounterDirector.STATE_FLED, "se recuerda que huiste")
	_enter(CORRIDOR_CELL + Vector2i(3, 0))
	await host.get_tree().process_frame
	check(not director.is_running(), "no vuelve en el acto")
	# Más tarde, al volver al pasillo desde otra sala, reaparece con las heridas que tenía.
	GameState.play_time += 200.0
	_enter(ROOM_CELL)
	var again: Battle.Outcome = await _fight(func(battle: Battle) -> void:
		check_eq(battle.enemies[0].body, 50, "vuelve con el Cuerpo que le quedaba")
		check_eq(battle.enemies[0].part_state(CombatTypes.ARM_R), CombatTypes.PartState.BROKEN, "y con el brazo roto")
		_win(battle))
	check_eq(again, Battle.Outcome.VICTORY, "vuelve a aparecer y se le puede vencer")
	await _teardown()


func test_derrota() -> void:
	await _setup()
	_take_pipe()
	var outcome: Battle.Outcome = await _fight(func(battle: Battle) -> void:
		battle._kill(battle.protagonist())
		battle._check_outcome())
	check_eq(outcome, Battle.Outcome.GAME_OVER, "si muere el protagonista, fin de la partida")
	check(director.state().get("state", "") != EncounterDirector.STATE_DEAD, "el enfermero no queda muerto")
	await _teardown()


func test_pantalla_de_combate() -> void:
	GameState.new_game()
	var character: CharacterState = GameState.character
	character.custody.add_item(Registry.item(&"tubo_metal"))
	character.wield(character.custody.find_first(&"tubo_metal"))
	var battle: Battle = CombatBridge.build_battle(preload("res://data/enemies/encuentro_enfermero.tres"), character, {}, 9)
	var scene: BattleScene = BattleScene.new()
	scene.setup(battle, character, null)
	host.add_child(scene)
	await host.get_tree().process_frame
	check_eq(battle.round_number, 1, "empieza la primera ronda")
	check(battle.intent_text(battle.enemies[0]) != "", "el enemigo avisa de lo que va a hacer")
	check(battle.intent_telegraph(battle.enemies[0]) != "", "con un aviso legible")
	var views: Array[Node] = scene.find_children("*", "EnemyView", true, false)
	check_eq(views.size(), 1, "el enemigo está en pantalla")
	var view: EnemyView = views[0] as EnemyView
	check(view.position.y < BattleScene.BOX_Y and absf(view.position.x - 320.0) < 1.0, "en el centro, sobre las cajas")
	# El grupo, de espaldas y en primer plano: más abajo que el enemigo.
	var battlers: Array[PartyBattler] = scene.party_battlers()
	check_eq(battlers.size(), 1, "el protagonista está en el escenario")
	check(not battlers[0].textures.is_empty(), "con su imagen de espaldas")
	check(battlers[0].position.y > view.position.y, "delante del enemigo y más abajo")
	# Abajo, dos cajas: órdenes a la izquierda (estrecha) y el grupo a la derecha (ancha).
	var commands: BattleFrame = scene.command_box()
	var party: BattleFrame = scene.party_box()
	check(commands != null and party != null, "las dos cajas existen")
	check(commands.position.y >= 240.0 and party.position.y >= 240.0, "abajo")
	check(commands.position.x < party.position.x and commands.size.x < party.size.x, "órdenes a la izquierda, más estrecha")
	var options: PackedStringArray = scene.menu_options()
	check(options.size() >= 4 and options[0] == "Atacar", "las órdenes empiezan por Atacar")
	check(options.has("Guardia") and options.has("Habilidades"), "con Guardia y Habilidades")
	# Una fila por miembro con Cuerpo y Mente.
	var rows: Array[PartyRow] = scene.party_rows()
	check_eq(rows.size(), 1, "una fila por miembro")
	check(rows[0].selected, "el que elige, resaltado")
	var columns: Dictionary[StringName, Vector2] = rows[0].columns()
	check(columns.has(&"body") and columns.has(&"mind"), "la fila tiene Cuerpo y Mente")
	check(columns[&"body"].y > 40.0 and columns[&"mind"].y > 40.0, "con sitio para la barra y el número")
	check(rows[0].weapon_icon != null, "con el icono del arma empuñada")
	# Arriba, la ventana de mensajes con el aviso del enemigo.
	var messages: MessageWindow = scene.message_window()
	check(messages.position.y < 20.0 and messages.size.x > 600.0, "ventana de mensajes arriba, a todo lo ancho")
	var waited_msg: float = 0.0
	while not messages.is_idle() and waited_msg < 5.0:
		messages.skip()
		await host.get_tree().process_frame
		waited_msg += 0.02
	await host.get_tree().process_frame
	check(messages.visible_text().contains("prepara"), "cuenta lo que prepara el enemigo")
	# Atacar: la caja de órdenes lista las partes con su acierto y la parte se marca sobre el enemigo.
	scene._show_part_menu(battle.enemies[0])
	options = scene.menu_options()
	check(options[0].begins_with(battle.enemies[0].parts[battle.enemies[0].part_order[0]].def.display_name),
		"al atacar se listan las partes")
	check(options[0].ends_with("%"), "con su probabilidad de acierto")
	scene._aim_at(battle.enemies[0], CombatTypes.ARM_R)
	var reticle: PartReticle = scene.find_children("*", "PartReticle", true, false)[0] as PartReticle
	check(reticle.visible and reticle.lines.is_empty(), "se marca la parte, sin ficha")
	check(reticle.position.distance_to(view.position + view.anchor(CombatTypes.ARM_R)) < 1.5, "sobre la propia parte")
	check(messages.visible_text().contains("acierto") and messages.visible_text().contains("daño"),
		"arriba, el acierto y el daño estimado")
	# Golpear el brazo y resolver la ronda (mensajes rápidos).
	messages.line_seconds = 0.02
	messages.per_char = 0.0
	scene._add_order(CombatTypes.ActionType.ATTACK, battle.enemies[0], CombatTypes.ARM_R)
	var waited: float = 0.0
	while battle.round_number < 2 and battle.outcome == Battle.Outcome.ONGOING and waited < 12.0:
		await host.get_tree().create_timer(0.1).timeout
		waited += 0.1
	check(battle.round_number >= 2 or battle.outcome != Battle.Outcome.ONGOING, "la ronda se resuelve en pantalla")
	check("\n".join(messages.history).contains("RONDA 1"), "el historial cuenta lo que pasa")
	check(messages.history.size() >= 3, "con varias líneas")
	# Una amputación se ve en el sprite.
	battle.enemies[0].parts[CombatTypes.LEG_R].amputate()
	scene._refresh()
	check_eq(view.part_state(CombatTypes.LEG_R), CombatTypes.PartState.AMPUTATED, "la vista oculta la parte amputada")
	var marks: EnemyMarks = scene.find_children("*", "EnemyMarks", true, false)[0] as EnemyMarks
	var amputated_mark: bool = false
	for mark: Dictionary in marks.marks():
		if mark["part"] == CombatTypes.LEG_R and mark["kind"] == BattleFrame.ICON_AMPUTATED:
			amputated_mark = true
	check(amputated_mark, "un icono de amputada junto a la pierna")
	# Las heridas propias, en una ventanita al pasar por la fila.
	battle.protagonist().parts[CombatTypes.ARM_L].worsen()
	scene._on_row_details(rows[0], true, false)
	var wounds: WoundsPanel = scene.wounds_panel()
	check(wounds.visible, "al pasar por la fila se ven las heridas")
	check(wounds.lines().has("%s: Herida" % battle.protagonist().parts[CombatTypes.ARM_L].def.display_name),
		"con la parte herida")
	scene._on_row_details(rows[0], false, false)
	check(not wounds.visible, "y se cierran al salir")
	scene.queue_free()
	await host.get_tree().process_frame
	GameState.new_game()


func test_vista_por_capas_oculta_lo_amputado() -> void:
	var sprites: EnemySpriteDef = EnemySpriteDef.new()
	sprites.frame = Vector2i(20, 30)
	sprites.origin = Vector2i(10, 28)
	for layer: String in ["body", "head", "arm_l", "arm_r", "leg_l", "leg_r", "stump_arm_r"]:
		var image: Image = Image.create(80, 30, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		sprites.layers[StringName(layer)] = ImageTexture.create_from_image(image)
	sprites.order = [&"leg_l", &"leg_r", &"body", &"arm_l", &"head", &"arm_r", &"stump_arm_r"]
	sprites.anims = {&"idle": [0, 2, 4.0, 1], &"attack": [2, 2, 8.0, 0], &"death": [2, 2, 8.0, 0]}
	sprites.anchors = {&"arm_r": Vector2(4, 12)}
	var view: EnemyView = EnemyView.new()
	host.add_child(view)
	view.setup_sprites(sprites)
	var arm: Sprite2D = view.get_node("Layer_arm_r") as Sprite2D
	var stump: Sprite2D = view.get_node("Layer_stump_arm_r") as Sprite2D
	check(arm.visible and not stump.visible, "entero: brazo sí, muñón no")
	check_eq(arm.hframes, 4, "rejilla leída de la hoja")
	view.set_part_state(CombatTypes.ARM_R, CombatTypes.PartState.AMPUTATED)
	check(not arm.visible and stump.visible, "amputado: se oculta el brazo y se ve el muñón")
	check_eq(view.anchor(CombatTypes.ARM_R), Vector2(-6, -16), "ancla relativa a los pies")
	view.play(&"attack")
	check_eq(arm.frame, 2, "la animación usa su fotograma")
	view.show_dead()
	check(view.is_dead(), "muere y se queda")
	var meta: EnemySpriteDef = EnemySpriteDef.from_meta({"frame": [20, 30], "layers": {"body": "res://no/existe.png"}})
	check(meta == null, "sin hojas reales, marcador provisional")
	view.queue_free()
