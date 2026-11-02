extends TestCase
## Movimiento del protagonista con 16 orientaciones: filas, paso según hacia dónde anda respecto
## a donde mira (de frente, de espaldas, de lado), giro con arrastre de pies, acciones de
## interacción, levantarse de la camilla, física de la bata y carga perezosa de la ropa.

const PLAYER: String = "res://scenes/world/player/player.tscn"
const SCENE: String = "res://scenes/world/hospital/hospital.tscn"


func _spawn() -> Player:
	var p: Player = load(PLAYER).instantiate()
	host.add_child(p)
	p.place(Vector2i(5, 5), Vector2i.DOWN)
	await host.get_tree().process_frame
	return p


func _column(p: Player) -> int:
	var sprite: Sprite2D = p.get_node("Sprite2D")
	return sprite.frame % sprite.hframes


func _in(column: int, anim: Vector2i) -> bool:
	return column >= anim.x and column < anim.x + anim.y


func test_filas_de_16_orientaciones() -> void:
	check_eq(Player.row_for_angle(PI / 2.0), 0, "abajo es la fila 0")
	check_eq(Player.row_for_angle(PI), 4, "izquierda es la fila 4")
	check_eq(Player.row_for_angle(-PI / 2.0), 8, "arriba es la fila 8")
	check_eq(Player.row_for_angle(0.0), 12, "derecha es la fila 12")
	check_eq(Player.row_for_angle(PI / 2.0 + deg_to_rad(22.5)), 1, "cada 22,5° hay una fila")
	check_eq(Player.row_for_angle(PI / 2.0 + deg_to_rad(10.0)), 0, "se redondea a la más cercana")
	for row: int in Player.DIRECTIONS:
		check_eq(Player.row_for_angle(Player.angle_of_row(row)), row, "ida y vuelta de la fila %d" % row)
	check_eq(Player.row_for_angle(PI, Player.ACTION_DIRECTIONS), 2, "las acciones usan 8 orientaciones")
	var p: Player = await _spawn()
	check_eq((p.get_node("Sprite2D") as Sprite2D).vframes, Player.DIRECTIONS, "la hoja de andar tiene 16 filas")
	p.queue_free()


func test_paso_segun_direccion() -> void:
	check_eq(Player.choose_gait(0.0), Player.Gait.FORWARD, "hacia donde mira: de frente")
	check_eq(Player.choose_gait(PI), Player.Gait.BACK, "al contrario: de espaldas")
	check_eq(Player.choose_gait(-PI / 2.0), Player.Gait.LEFT, "a -90°: hacia su izquierda")
	check_eq(Player.choose_gait(PI / 2.0), Player.Gait.RIGHT, "a +90°: hacia su derecha")
	check_eq(Player.choose_gait(deg_to_rad(40.0)), Player.Gait.FORWARD, "en diagonal hacia delante sigue de frente")
	# Mirando a la derecha y andando hacia arriba: paso lateral hacia su izquierda.
	GameState.new_game()
	var p: Player = await _spawn()
	p.input_enabled = true
	p.forced_aim = Vector2.RIGHT
	Input.action_press(InputActions.MOVE_UP)
	for i: int in 40:
		await host.get_tree().physics_frame
	await host.get_tree().process_frame
	check_eq(p.gait, Player.Gait.LEFT, "de lado hacia su izquierda")
	check(_in(_column(p), Player.ANIM_STRAFE_LEFT), "usa el paso lateral (columna %d)" % _column(p))
	check(absf(angle_difference(p.facing_angle, 0.0)) < 0.01, "sigue mirando a la derecha")
	var body_row: int = (p.get_node("Sprite2D") as Sprite2D).frame / Player.COLUMNS
	check(absi(body_row - Player.row_for_angle(0.0)) <= 1, "el cuerpo se gira como mucho una orientación (%d)" % body_row)
	Input.action_release(InputActions.MOVE_UP)
	# Hacia abajo: hacia su derecha.
	Input.action_press(InputActions.MOVE_DOWN)
	for i: int in 50:
		await host.get_tree().physics_frame
	await host.get_tree().process_frame
	check_eq(p.gait, Player.Gait.RIGHT, "de lado hacia su derecha")
	check(_in(_column(p), Player.ANIM_STRAFE_RIGHT), "usa el paso lateral derecho (columna %d)" % _column(p))
	Input.action_release(InputActions.MOVE_DOWN)
	p.forced_aim = Vector2.ZERO
	p.queue_free()


func test_giro_parado_arrastra_los_pies() -> void:
	var p: Player = await _spawn()
	p.face(Vector2i.UP)
	var shuffled: bool = false
	for i: int in 50:
		await host.get_tree().create_timer(0.025).timeout
		if _in(_column(p), Player.ANIM_TURN):
			shuffled = true
	check(shuffled, "al darse la vuelta parado arrastra los pies")
	check_eq((p.get_node("Sprite2D") as Sprite2D).frame / Player.COLUMNS, 8, "y acaba mirando arriba")
	p.queue_free()


func test_accion_desconocida_no_se_cuelga() -> void:
	var p: Player = await _spawn()
	var start: int = Time.get_ticks_msec()
	await p.play_action(&"bailar_claque", p.position + Vector2(0, 30))
	check(Time.get_ticks_msec() - start < 100, "vuelve enseguida")
	check(not p.is_busy(), "no se queda ocupado")
	p.queue_free()


func test_accion_reproduce_y_vuelve() -> void:
	var p: Player = await _spawn()
	var seen_action: bool = false
	var done: Array[bool] = [false]
	var run: Callable = func() -> void:
		await p.play_action(&"reach_low", p.position + Vector2(32, 0))
		done[0] = true
	run.call()
	var sprite: Sprite2D = p.get_node("Sprite2D")
	for i: int in 100:
		await host.get_tree().create_timer(0.025).timeout
		if p.is_busy() and sprite.vframes == Player.ACTION_DIRECTIONS:
			seen_action = true
		if done[0]:
			break
	check(seen_action, "usa la hoja de acciones")
	check(done[0], "la acción termina")
	check_eq(sprite.vframes, Player.DIRECTIONS, "vuelve a la hoja de andar")
	check(absf(angle_difference(p.facing_angle, 0.0)) < 0.01, "se ha girado hacia el objeto")
	# Con linterna, la luz sale de la lente también durante la acción.
	p.set_holding_flashlight(true)
	p.set_light_on(true)
	done[0] = false
	var lens_ok: bool = true
	var run2: Callable = func() -> void:
		await p.play_action(&"valve", p.position + Vector2(0, -32))
		done[0] = true
	run2.call()
	for i: int in 100:
		await host.get_tree().create_timer(0.025).timeout
		if p.is_busy() and sprite.vframes == Player.ACTION_DIRECTIONS and p._frame_data(&"lens") == null:
			lens_ok = false
		if done[0]:
			break
	check(done[0] and lens_ok, "con linterna cada fotograma de la acción sabe dónde está la lente")
	p.queue_free()


func test_levantarse_termina() -> void:
	var p: Player = await _spawn()
	var bed: Vector2 = Vector2(80, 752)
	p.prepare_get_up(bed)
	p.visible = false
	var done: Array[bool] = [false]
	var run: Callable = func() -> void:
		await p.play_get_up(bed)
		done[0] = true
	run.call()
	var sprite: Sprite2D = p.get_node("Sprite2D")
	await host.get_tree().process_frame
	check(p.visible and p.is_busy(), "se ve mientras se levanta")
	check_eq(sprite.vframes, 1, "usa la hoja de levantarse")
	check(sprite.hframes >= 40, "con al menos 40 fotogramas (%d)" % sprite.hframes)
	for i: int in 400:
		await host.get_tree().create_timer(0.025).timeout
		if done[0]:
			break
	check(done[0], "termina")
	check(not p.is_busy(), "y devuelve el control")
	check_eq(sprite.vframes, Player.DIRECTIONS, "vuelve a la hoja de andar")
	check_eq(sprite.position, Vector2.ZERO, "el dibujo vuelve a los pies")
	check(p.position.x - bed.x >= 18.0, "acaba de pie fuera de la camilla (%s)" % p.position)
	check_eq(Player.row_for_angle(p.facing_angle), 12, "mirando a la derecha")
	p.queue_free()


func test_la_bata_inicial_se_balancea() -> void:
	# Regresión: la bata de paciente apenas se movía porque el shader suponía el bajo a 12 px de
	# los pies (el de la bata de médico) y la bata corta acaba a ~16 px.
	GameState.new_game()
	var w: WorldController = load(SCENE).instantiate()
	host.add_child(w)
	w.message.auto_advance = 0.01
	await host.get_tree().process_frame
	var p: Player = w.player
	var gown: ItemDef = GameState.character.worn(ItemDef.EquipSlot.BODY).def
	check_eq(gown.id, &"bata_paciente", "empieza con la bata")
	var mat: ShaderMaterial = (p.get_node("Sprite2D/Body") as Sprite2D).material
	check_eq(float(mat.get_shader_parameter(&"hem")), gown.cloth_hem, "el shader usa el bajo de esta bata")
	var dt: float = 1.0 / 60.0
	p.velocity = Vector2(Player.MAX_SPEED, 0.0)
	var most: float = 0.0
	for i: int in 60:
		p._update_cloth(dt)
		most = maxf(most, absf(p.cloth_shift_at(&"body", gown.cloth_hem).x))
	check(most >= 1.8, "al andar, el bajo se queda atrás de forma visible (%.2f px)" % most)
	p.velocity = Vector2.ZERO
	var overshoot: float = 0.0
	for i: int in 40:
		p._update_cloth(dt)
		overshoot = maxf(overshoot, p.cloth_shift_at(&"body", gown.cloth_hem).x)
	check(overshoot >= 0.5, "al frenar sigue de largo (%.2f px)" % overshoot)
	# Las demás prendas largas también tienen su bajo.
	for id: StringName in [&"bata_medico", &"chaqueta_celador"]:
		var def: ItemDef = Registry.item(id)
		check(def.cloth_sway > 0.0 and def.cloth_hem > 0.0 and def.cloth_hem < def.cloth_waist, "%s se balancea" % id)
	w.queue_free()
	await host.get_tree().process_frame


func test_la_ropa_se_carga_al_ponerla() -> void:
	GameState.new_game()
	var w: WorldController = load(SCENE).instantiate()
	host.add_child(w)
	w.message.auto_advance = 0.01
	await host.get_tree().process_frame
	var coat: ItemDef = Registry.item(&"bata_medico")
	check(coat.wear_path != "", "la prenda guarda la ruta de su hoja")
	check(not ResourceLoader.has_cached(coat.wear_path), "la hoja de una prenda que no se lleva no está cargada")
	GameState.give_item(coat)
	var c: CharacterState = GameState.character
	c.equip(c.custody.find_first(&"bata_medico"))
	w.apply_outfit()
	check(ResourceLoader.has_cached(coat.wear_path), "al ponérsela se carga")
	c.unequip(ItemDef.EquipSlot.BODY)
	w.apply_outfit()
	await host.get_tree().process_frame
	check(not ResourceLoader.has_cached(coat.wear_path), "al quitársela se suelta")
	w.queue_free()
	await host.get_tree().process_frame


func test_arma_en_la_mano() -> void:
	var p: Player = await _spawn()
	var weapon: Sprite2D = p.get_node("Sprite2D/Weapon")
	check(not weapon.visible, "sin arma no se dibuja nada")
	var tex: Texture2D = load("res://assets/sprites/items/palanca.png") if ResourceLoader.exists("res://assets/sprites/items/palanca.png") else PlaceholderTexture2D.new()
	if tex is PlaceholderTexture2D:
		(tex as PlaceholderTexture2D).size = Vector2(40, 8)
	p.set_held_weapon(tex)
	await host.get_tree().process_frame
	check(weapon.visible, "con arma se dibuja")
	check(weapon.position.y < -8.0 and weapon.position.y > -40.0, "a la altura de la mano (%s)" % weapon.position)
	p.set_held_weapon(null)
	await host.get_tree().process_frame
	check(not weapon.visible, "al soltarla desaparece")
	p.queue_free()
