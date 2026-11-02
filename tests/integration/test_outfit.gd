extends TestCase
## Ropa por capas (ponerse, quitarse, guardar), física de la bata, apuntar y andar de espaldas,
## pantalla de equipo e iconos a medida.

const SCENE: String = "res://scenes/world/hospital/hospital.tscn"
const PLAYER: String = "res://scenes/world/player/player.tscn"


func _spawn_world() -> WorldController:
	var w: WorldController = load(SCENE).instantiate()
	host.add_child(w)
	w.message.auto_advance = 0.01
	await host.get_tree().process_frame
	return w


func test_ponerse_y_quitarse() -> void:
	GameState.new_game()
	var c: CharacterState = GameState.character
	check_eq(c.worn(ItemDef.EquipSlot.BODY).def.id, &"bata_paciente", "empieza con la bata de paciente")
	check(c.worn(ItemDef.EquipSlot.FEET) == null, "empieza descalzo")
	GameState.give_item(Registry.item(&"chaqueta_celador"))
	var jacket: ItemStack = c.custody.find_first(&"chaqueta_celador")
	check_eq(c.equip(jacket), "", "se pone la chaqueta")
	check_eq(c.worn(ItemDef.EquipSlot.BODY).def.id, &"chaqueta_celador", "lleva la chaqueta")
	check(not c.custody.has(&"chaqueta_celador"), "la chaqueta ya no ocupa la bandeja")
	check(c.custody.has(&"bata_paciente"), "la bata vuelve a la bandeja")
	check_eq(c.unequip(ItemDef.EquipSlot.BODY), "", "se la quita")
	check(c.worn(ItemDef.EquipSlot.BODY) == null and c.custody.has(&"chaqueta_celador"), "la chaqueta vuelve a la bandeja")
	GameState.give_item(Registry.item(&"pilas"))
	check(c.equip(c.custody.find_first(&"pilas")) != "", "las pilas no se pueden poner")


func test_quitarse_siempre_cabe() -> void:
	GameState.new_game()
	var c: CharacterState = GameState.character
	GameState.give_item(Registry.item(&"gorro_lana"))
	check_eq(c.equip(c.custody.find_first(&"gorro_lana")), "", "se pone el gorro")
	for i: int in 30:
		GameState.give_item(Registry.item(&"fusible"))
	check_eq(c.unequip(ItemDef.EquipSlot.HEAD), "", "con la custodia llena se lo quita igual")
	check(c.worn(ItemDef.EquipSlot.HEAD) == null and c.custody.has(&"gorro_lana"), "y vuelve a la lista")


func test_la_ropa_se_guarda() -> void:
	GameState.new_game()
	var c: CharacterState = GameState.character
	GameState.give_item(Registry.item(&"botas_goma"))
	c.equip(c.custody.find_first(&"botas_goma"))
	var copy: CharacterState = CharacterState.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check_eq(copy.worn(ItemDef.EquipSlot.FEET).def.id, &"botas_goma", "las botas siguen puestas al cargar")
	check_eq(copy.worn(ItemDef.EquipSlot.BODY).def.id, &"bata_paciente", "y la bata")


func test_capas_y_pisadas_en_el_mapa() -> void:
	GameState.new_game()
	var w: WorldController = await _spawn_world()
	var c: CharacterState = GameState.character
	var body: Sprite2D = w.player.get_node("Sprite2D/Body")
	check(body.visible and body.texture == c.worn(ItemDef.EquipSlot.BODY).def.wear_sheet, "se ve la bata puesta")
	for id: StringName in [&"botas_goma", &"gorro_quirurgico"]:
		GameState.give_item(Registry.item(id))
		c.equip(c.custody.find_first(id))
	w.apply_outfit()
	var feet: Sprite2D = w.player.get_node("Sprite2D/Feet")
	check(feet.visible and feet.texture == Registry.item(&"botas_goma").wear_sheet, "se ven las botas")
	check((w.player.get_node("Sprite2D/Head") as Sprite2D).visible, "se ve el gorro")
	check(not (w.player.get_node("Sprite2D/Legs") as Sprite2D).visible, "sin pantalón, la capa de piernas no se ve")
	check_eq(w.player.step_sound, "step_boot", "con botas suenan las pisadas de bota")
	await host.get_tree().process_frame
	check_eq(feet.frame, (w.player.get_node("Sprite2D") as Sprite2D).frame, "las capas usan el fotograma del cuerpo")
	w.queue_free()
	await host.get_tree().process_frame


func test_la_bata_se_balancea() -> void:
	var p: Player = load(PLAYER).instantiate()
	host.add_child(p)
	await host.get_tree().process_frame
	p.set_outfit_layer(&"body", Registry.item(&"bata_paciente").wear_sheet, 1.0)
	var dt: float = 1.0 / 60.0
	p.velocity = Vector2(Player.MAX_SPEED, 0.0)
	for i: int in 60:
		p._update_cloth(dt)
	check(p.cloth_offset().x < -1.0, "al andar a la derecha el bajo se queda atrás (%s)" % p.cloth_offset())
	var mat: ShaderMaterial = (p.get_node("Sprite2D/Body") as Sprite2D).material
	check((mat.get_shader_parameter(&"sway") as Vector2).distance_to(p.cloth_offset()) < 0.01, "el shader recibe el balanceo")
	p.velocity = Vector2.ZERO
	var overshoot: float = -INF
	for i: int in 30:
		p._update_cloth(dt)
		overshoot = maxf(overshoot, p.cloth_offset().x)
	check(overshoot > 0.2, "al frenar sigue de largo (%.2f)" % overshoot)
	for i: int in 240:
		p._update_cloth(dt)
	check(p.cloth_offset().length() < 0.1, "y vuelve a reposar")
	p.queue_free()


func test_apunta_y_anda_de_espaldas() -> void:
	GameState.new_game()
	var w: WorldController = await _spawn_world()
	var p: Player = w.player
	p.place(Vector2i(30, 15), Vector2i.DOWN)
	p.input_enabled = true
	p.forced_aim = Vector2.RIGHT
	Input.action_press(InputActions.MOVE_LEFT)
	for i: int in 40:
		await host.get_tree().physics_frame
	Input.action_release(InputActions.MOVE_LEFT)
	check(absf(angle_difference(p.facing_angle, 0.0)) < 0.01, "mira hacia donde apunta, no hacia donde anda")
	check(p.velocity.x < -10.0, "se mueve hacia la izquierda")
	check(absf(p.velocity.x) <= Player.MAX_SPEED * Player.BACKWARD_SPEED + 0.5, "de espaldas va más despacio")
	check_eq(p.gait, Player.Gait.BACK, "anda de espaldas con su propio paso")
	var column: int = (p.get_node("Sprite2D") as Sprite2D).frame % Player.COLUMNS
	check(column >= Player.ANIM_BACK.x and column < Player.ANIM_BACK.x + Player.ANIM_BACK.y,
		"usa la animación de andar de espaldas (columna %d)" % column)
	p.forced_aim = Vector2.ZERO
	w.queue_free()
	await host.get_tree().process_frame


func test_pantalla_de_equipo() -> void:
	GameState.new_game()
	var w: WorldController = await _spawn_world()
	GameState.give_item(Registry.item(&"pantalon_pijama"))
	w.custody_screen.open(CustodyScreen.Tab.CHARACTER)
	await host.get_tree().process_frame
	var page: EquipmentPage = w.custody_screen.equipment_page()
	check(page.visible, "se ve la página de equipo")
	check(page.item_in(ItemDef.EquipSlot.BODY).def.id == &"bata_paciente", "la ranura de cuerpo tiene la bata")
	page.select_slot(ItemDef.EquipSlot.LEGS)
	check_eq(page.candidates().size(), 1, "el pantalón aparece en la lista de la ranura de piernas")
	page.equip_in_slot(page.candidates()[0])
	check_eq(GameState.character.worn(ItemDef.EquipSlot.LEGS).def.id, &"pantalon_pijama", "se pone el pantalón desde la lista")
	w.custody_screen.close()
	await w.custody_screen.closed
	await host.get_tree().process_frame
	check((w.player.get_node("Sprite2D/Legs") as Sprite2D).visible, "al cerrar, el personaje lo lleva puesto")
	w.queue_free()
	await host.get_tree().process_frame


func test_iconos_a_medida() -> void:
	for item: ItemDef in Registry.all_items():
		if item.icon == null:
			continue  # objetos antiguos del prototipo de combate, sin icono
		var expected: Vector2 = Vector2(item.size * ItemDef.ICON_CELL - Vector2i(4, 4))
		check_eq(item.icon.get_size(), expected, "icono de " + item.id)
		if item.is_wearable():
			check(item.wear_sheet != null, "la prenda %s tiene hoja" % item.id)
