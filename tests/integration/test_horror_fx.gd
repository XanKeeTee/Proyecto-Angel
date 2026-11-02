extends TestCase
## Terror ambiental y efectos de estado en el hospital real: la entidad se deshace con el haz,
## no aparece con el control bloqueado, y el overlay de estado reacciona al sangrado y a la venda.

const SCENE: String = "res://scenes/world/hospital/hospital.tscn"
## Una casilla del pasillo largo de la planta, lejos de luces y puertas.
const CORRIDOR_CELL: Vector2i = Vector2i(30, 15)

var world: WorldController
var director: HorrorDirector


## Arranca el hospital como si se cargara una partida en el pasillo (sin la secuencia inicial).
func _setup() -> void:
	GameState.new_game()
	GameState.player_scene = SCENE
	GameState.player_position = Vector2(CORRIDOR_CELL * 32) + Vector2(16, 16)
	GameState.player_facing = 0.0
	GameState.has_position = true
	world = load(SCENE).instantiate()
	host.add_child(world)
	world.message.auto_advance = 0.01
	director = world.get_node(^"HorrorDirector") as HorrorDirector
	for i: int in 6:
		await host.get_tree().physics_frame
	world.player.forced_aim = Vector2.RIGHT


func _teardown() -> void:
	world.queue_free()
	await host.get_tree().process_frame
	host.get_tree().paused = false
	GameState.new_game()


func _frames(n: int) -> void:
	for i: int in n:
		await host.get_tree().process_frame


func _light_on() -> void:
	var lamp: ItemDef = Registry.item(&"linterna")
	GameState.give_item(lamp)
	GameState.character.flashlight().charge = 100.0
	GameState.character.flashlight_on = true
	await _frames(3)


func test_la_entidad_se_deshace_con_la_linterna() -> void:
	await _setup()
	check(director != null, "el hospital crea el director de terror")
	check(world.player.input_enabled, "el jugador tiene el control")
	await _light_on()
	check(world.player.has_flashlight_on(), "linterna encendida")
	var reasons: Array[StringName] = []
	director.stalker_vanished.connect(func(r: StringName) -> void: reasons.append(r))
	# Aparece a la espalda (a la izquierda): el haz apunta a la derecha y no la toca.
	var behind: Vector2 = world.player.position + Vector2(-100, 0)
	director.stalker.appear(behind, [world.player.position], 30.0)
	await _frames(10)
	check(director.stalker.is_solid(), "a la espalda, fuera del haz, sigue ahí")
	# Se gira hacia ella: el haz la toca y se deshace.
	world.player.forced_aim = Vector2.LEFT
	world.player.facing_angle = PI
	await _frames(4)
	check(director.stalker.state == Stalker.State.DISSOLVING or reasons.has(&"light"), "el haz la deshace")
	await host.get_tree().create_timer(Stalker.DISSOLVE_TIME + 0.2).timeout
	check(not director.stalker.is_active(), "ya no está")
	check(reasons.has(&"light"), "se ha ido por la luz")
	await _teardown()


func test_la_entidad_no_aparece_con_el_control_bloqueado() -> void:
	await _setup()
	var profile: HorrorProfile = director.profile.duplicate()
	profile.stalker_first_delay = 0.0
	profile.stalker_walk_time = 0.0
	profile.stalker_chance = Vector2(1000.0, 1000.0)
	profile.gap_calm = Vector2(0.0, 0.0)
	director.profile = profile
	director.planner.schedule(director.clock, 0.0)
	var scares: Array[ScareDef] = []
	director.scare_played.connect(func(s: ScareDef) -> void: scares.append(s))
	world.lock()
	var clock_before: float = director.clock
	# Mientras está bloqueado, aunque «camine» (velocidad) no pasa nada y el reloj no avanza.
	for i: int in 30:
		world.player.velocity = Vector2(70, 0)
		world.player.position += Vector2(2, 0)
		await host.get_tree().process_frame
	check(not director.can_act(), "con el control bloqueado no puede actuar")
	check(not director.stalker.is_active(), "la entidad no aparece")
	check(scares.is_empty(), "no salta ningún susto")
	check_eq(director.clock, clock_before, "el reloj del terror no avanza")
	# Con un texto en pantalla tampoco.
	world.unlock()
	await _frames(3)
	world.message.auto_advance = 0.0
	world.message.show_lines(PackedStringArray(["Prueba."]))
	await _frames(2)
	check(not director.can_act(), "con un texto abierto no puede actuar")
	await host.get_tree().create_timer(0.3).timeout
	await _teardown()


func test_no_aparece_en_una_sala_iluminada() -> void:
	await _setup()
	var lit: PoweredLight = null
	for node: Node in host.get_tree().get_nodes_in_group(PoweredLight.GROUP):
		var light: PoweredLight = node as PoweredLight
		if not light.broken and light.needs_power:
			lit = light
			break
	check(lit != null, "hay luces con corriente")
	check(not director.is_lit(lit.global_position), "sin corriente, la sala está a oscuras")
	GameState.set_flag(GameState.FLAG_POWER)
	# El fluorescente arranca con retraso y parpadeos al azar: se espera a verlo encendido.
	var seen_lit: bool = false
	for i: int in 50:
		await host.get_tree().create_timer(0.1).timeout
		if director.is_lit(lit.global_position):
			seen_lit = true
			break
	check(seen_lit, "con corriente, junto a la luz está iluminado")
	await _teardown()


func test_el_overlay_reacciona_al_sangrado_y_a_la_venda() -> void:
	await _setup()
	var fx: StatusFx = world.get_node(^"StatusFx") as StatusFx
	check(fx != null, "WorldController añade el overlay de estado")
	var vitals: Vitals = GameState.character.vitals
	check(fx.bleed_level() < 0.01, "sin sangrado no hay regueros")
	vitals.set_bleeding(true)
	vitals.change_body(-55)
	await host.get_tree().create_timer(1.2).timeout
	check(fx.bleed_level() > 0.5, "sangrando: regueros en pantalla (%.2f)" % fx.bleed_level())
	check(fx.hurt_level() > 0.4, "herido: viñeta (%.2f)" % fx.hurt_level())
	var hurt_before: float = fx.hurt_level()
	GameState.give_item(Registry.item(&"venda"))
	var stack: ItemStack = GameState.character.custody.find_first(&"venda")
	GameState.character.use_item(stack)
	check(not vitals.bleeding, "la venda corta el sangrado")
	check(fx.is_healing(), "la venda lanza la onda de cura")
	await host.get_tree().create_timer(0.4).timeout
	check(fx.bleed_level() < 0.35, "los regueros se retiran (%.2f)" % fx.bleed_level())
	check(fx.hurt_level() < hurt_before, "la viñeta se retira un poco")
	# Analgésicos: suavizado breve.
	GameState.give_item(Registry.item(&"analgesicos"))
	GameState.character.use_item(GameState.character.custody.find_first(&"analgesicos"))
	check(fx.calm_level() > 0.9, "los analgésicos suavizan la imagen")
	await _teardown()


func test_la_entidad_aparece_detras_en_el_camino_recorrido() -> void:
	await _setup()
	# El jugador anda hacia la derecha por el pasillo: queda un rastro a su espalda.
	for i: int in 50:
		world.player.position += Vector2(4, 0)
		await host.get_tree().process_frame
	check(director.try_spawn_stalker(), "hay sitio detrás para que aparezca")
	var stalker: Stalker = director.stalker
	check(stalker.is_active(), "ha aparecido")
	check(stalker.position.x < world.player.position.x - 90.0, "aparece a la espalda, a distancia")
	check(not director.is_wall(Vector2i((stalker.position / 32.0).floor())), "aparece sobre el suelo, no en una pared")
	check(not director.try_spawn_stalker(), "no aparece dos veces a la vez")
	# Si el jugador se queda quieto sin mirarla, lo alcanza: susurro, -Mente y se va.
	var mind_before: int = GameState.character.vitals.mind
	var reasons: Array[StringName] = []
	director.stalker_vanished.connect(func(r: StringName) -> void: reasons.append(r))
	await host.get_tree().create_timer(8.0).timeout
	check(reasons.has(&"reached"), "lo alcanza si no la mira")
	check(GameState.character.vitals.mind < mind_before, "alcanzarlo cuesta algo de Mente")
	check(GameState.character.vitals.body > 0, "nunca hace daño")
	await _teardown()
