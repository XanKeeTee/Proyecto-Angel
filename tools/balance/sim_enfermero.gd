extends SceneTree
## Simulación Monte Carlo del combate contra el enfermero con el código real de Battle.
## Uso: "$GODOT_BIN" --headless --path . -s tools/balance/sim_enfermero.gd [-- N]
## Protagonista como en el prólogo al coger el tubo (Cuerpo 82, Mente 70, sin sangrar).
## Estrategias del jugador:
## - torso: siempre al torso, nunca se cubre.
## - brazo: primero rompe el brazo de instrumental, luego al torso; nunca se cubre.
## - listo: lee el aviso (se cubre del serrado y de los tajos a la cabeza o al brazo del tubo
##   cuando va justo), rompe el brazo de instrumental y luego va a la cabeza o al torso.
## Resultados en docs/design/enemigos/enfermero.md § Balance.

const ENEMY: String = "res://data/enemies/enfermero.tres"
const PARTY: String = "res://data/party/paciente_09.tres"
const PIPE: String = "res://data/weapons/pipe.tres"
const START_BODY: int = 82
const START_MIND: int = 70
const MAX_ROUNDS: int = 40


func _init() -> void:
	var runs: int = 3000
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		runs = args[0].to_int()
	for policy: String in ["torso", "brazo", "listo"]:
		_report(policy, runs)
	quit()


func _report(policy: String, runs: int) -> void:
	var wins: int = 0
	var rounds_total: int = 0
	var body_left: int = 0
	var amputated: int = 0
	var broken: int = 0
	var mind_low: int = 0
	var lost_mind: int = 0
	for i: int in runs:
		var battle: Battle = _battle(i)
		var result: Dictionary = _play(battle, policy)
		var hero: Combatant = battle.protagonist()
		if battle.outcome == Battle.Outcome.VICTORY:
			wins += 1
			body_left += hero.body
			rounds_total += battle.round_number
			if hero.mind < 35:
				mind_low += 1
		elif hero.mind_broken and not hero.dead:
			lost_mind += 1
		for id: StringName in hero.part_order:
			if hero.parts[id].is_amputated():
				amputated += 1
				break
		for id: StringName in hero.part_order:
			if hero.parts[id].state == CombatTypes.PartState.BROKEN:
				broken += 1
				break
		if result.is_empty():
			pass
	print("%-6s victoria %5.1f %% (derrotas por Quiebre %4.1f %%)  rondas %4.1f  Cuerpo al ganar %4.1f  amputación %4.1f %%  algo roto %4.1f %%  Mente<35 al ganar %4.1f %%" % [
		policy, 100.0 * wins / runs, 100.0 * lost_mind / runs, float(rounds_total) / maxi(1, wins), float(body_left) / maxi(1, wins),
		100.0 * amputated / runs, 100.0 * broken / runs, 100.0 * mind_low / maxi(1, wins)])


func _battle(seed_value: int) -> Battle:
	var party: CombatantDef = (load(PARTY) as CombatantDef).duplicate()
	party.weapon = load(PIPE)
	var party_defs: Array[CombatantDef] = [party]
	var enemy_defs: Array[CombatantDef] = [load(ENEMY)]
	var battle: Battle = Battle.new(party_defs, enemy_defs, seed_value)
	battle.bandages = 0
	var hero: Combatant = battle.protagonist()
	hero.body = START_BODY
	hero.mind = START_MIND
	return battle


func _play(battle: Battle, policy: String) -> Dictionary:
	while battle.outcome == Battle.Outcome.ONGOING and battle.round_number < MAX_ROUNDS:
		battle.begin_round()
		var hero: Combatant = battle.protagonist()
		var orders: Array[CombatAction] = []
		if hero.is_active():
			orders.append(_order(battle, hero, policy))
		battle.start_resolution(orders)
		while battle.step():
			pass
	return {}


func _order(battle: Battle, hero: Combatant, policy: String) -> CombatAction:
	var enemy: Combatant = battle.enemies[0]
	var order: CombatAction = CombatAction.new()
	order.actor = hero
	order.target = enemy
	order.type = CombatTypes.ActionType.ATTACK
	var intent: CombatAction = battle.intents.get(enemy)
	if policy == "listo" and intent != null and intent.attack != null:
		var name: String = intent.attack.display_name
		var guard_it: bool = false
		if name == "Serrar":
			guard_it = true
		elif name == "Tajo" and intent.part_id == CombatTypes.HEAD and hero.body < 55:
			guard_it = true
		elif name == "Tajo" and intent.part_id == hero.def.dominant_arm \
				and hero.part_state(hero.def.dominant_arm) != CombatTypes.PartState.HEALTHY:
			guard_it = true
		if guard_it and intent.part_id != &"":
			order.type = CombatTypes.ActionType.GUARD
			order.target = hero
			order.part_id = intent.part_id
			return order
		if hero.mind < 30 and name != "Tajo":
			order.type = CombatTypes.ActionType.BREATHE
			return order
	match policy:
		"torso":
			order.part_id = CombatTypes.TORSO
		_:
			if not enemy.part_disabled(CombatTypes.ARM_R):
				order.part_id = CombatTypes.ARM_R
			else:
				order.part_id = CombatTypes.TORSO
	return order
