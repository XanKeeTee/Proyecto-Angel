extends TestCase
## Correr con Shift: más rápido que andar, solo hacia delante, con transición suave, gasta
## aliento y se recupera; las acciones no se ven afectadas.

const PLAYER: String = "res://scenes/world/player/player.tscn"


func _spawn() -> Player:
	GameState.new_game()
	var p: Player = load(PLAYER).instantiate()
	host.add_child(p)
	p.place(Vector2i(5, 5), Vector2i.RIGHT)
	p.input_enabled = true
	p.forced_aim = Vector2.RIGHT
	await host.get_tree().process_frame
	return p


## Velocidad (px/s) tras `frames` fotogramas de física moviéndose hacia `action`.
func _speed_after(p: Player, action: StringName, frames: int) -> float:
	Input.action_press(action)
	for i: int in frames:
		await host.get_tree().physics_frame
	var speed: float = p.velocity.length()
	Input.action_release(action)
	return speed


func _release_all() -> void:
	for a: StringName in [InputActions.RUN, InputActions.MOVE_RIGHT, InputActions.MOVE_LEFT, InputActions.MOVE_UP]:
		Input.action_release(a)


func test_corre_mas_rapido_que_anda() -> void:
	var p: Player = await _spawn()
	var walk: float = await _speed_after(p, InputActions.MOVE_RIGHT, 40)
	p.stop()
	Input.action_press(InputActions.RUN)
	# Transición suave: al principio solo un poco más rápido.
	Input.action_press(InputActions.MOVE_RIGHT)
	for i: int in 6:
		await host.get_tree().physics_frame
	var early: float = p.run_amount()
	for i: int in 40:
		await host.get_tree().physics_frame
	var run: float = p.velocity.length()
	_release_all()
	check(early > 0.0 and early < 0.9, "empieza a correr poco a poco (%.2f)" % early)
	check(run > walk * 1.4 and run < walk * 1.65, "corre un poco más rápido (%.0f frente a %.0f px/s)" % [run, walk])
	check(p.breath_ratio() < 1.0, "correr gasta aliento")
	check_eq(p.gait, Player.Gait.FORWARD, "corre con el paso hacia delante")
	# Al soltar Shift vuelve a andar suavemente.
	Input.action_press(InputActions.MOVE_RIGHT)
	for i: int in 6:
		await host.get_tree().physics_frame
	check(p.run_amount() > 0.0 and p.run_amount() < 1.0, "deja de correr poco a poco")
	_release_all()
	p.queue_free()


func test_corre_en_diagonal_hacia_delante() -> void:
	var p: Player = await _spawn()
	Input.action_press(InputActions.RUN)
	Input.action_press(InputActions.MOVE_RIGHT)
	Input.action_press(InputActions.MOVE_UP)
	for i: int in 40:
		await host.get_tree().physics_frame
	check(p.run_amount() > 0.95, "a 45° de donde mira corre del todo (%.2f)" % p.run_amount())
	_release_all()
	p.queue_free()


func test_no_corre_de_espaldas_ni_de_lado() -> void:
	var p: Player = await _spawn()
	Input.action_press(InputActions.RUN)
	var back: float = await _speed_after(p, InputActions.MOVE_LEFT, 40)
	check_eq(p.run_amount(), 0.0, "de espaldas no corre")
	check(back <= Player.MAX_SPEED * Player.BACKWARD_SPEED + 1.0, "de espaldas va a paso de espaldas (%.0f)" % back)
	p.stop()
	var side: float = await _speed_after(p, InputActions.MOVE_UP, 40)
	check_eq(p.run_amount(), 0.0, "de lado no corre")
	check(side <= Player.MAX_SPEED * Player.STRAFE_SPEED + 1.0, "de lado va a paso lateral (%.0f)" % side)
	check_eq(p.breath_ratio(), 1.0, "sin correr no gasta aliento")
	_release_all()
	p.queue_free()


func test_el_aliento_se_agota_y_se_recupera() -> void:
	var p: Player = await _spawn()
	# Se le deja poco aliento para no esperar los segundos enteros.
	p.breath.amount = 0.12
	Input.action_press(InputActions.RUN)
	Input.action_press(InputActions.MOVE_RIGHT)
	for i: int in 90:
		await host.get_tree().physics_frame
	check(p.breath.winded, "se queda sin aliento")
	check(p.run_amount() < 0.05, "y deja de correr aunque siga pulsando Shift")
	check(p.velocity.length() < Player.MAX_SPEED * 1.05, "vuelve al paso de andar (%.0f)" % p.velocity.length())
	_release_all()
	for i: int in 150:  # unos 2,5 s parado
		await host.get_tree().physics_frame
	check(not p.breath.winded and p.breath.can_run(), "parado recupera el aliento")
	check(p.breath_ratio() > RunBreath.RECOVER_TO_RUN, "lo bastante para volver a correr")
	p.queue_free()


func test_la_accion_no_corre() -> void:
	var p: Player = await _spawn()
	Input.action_press(InputActions.RUN)
	Input.action_press(InputActions.MOVE_RIGHT)
	for i: int in 30:
		await host.get_tree().physics_frame
	_release_all()
	Input.action_press(InputActions.RUN)
	await p.play_action(&"reach_mid", p.position + Vector2(0, 60))
	check_eq(p.run_amount(), 0.0, "durante y tras una acción no corre")
	check(not p.is_busy(), "la acción termina")
	check_eq((p.get_node("Sprite2D") as Sprite2D).skew, 0.0, "sin inclinación tras la acción")
	_release_all()
	p.queue_free()
