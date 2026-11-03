extends SceneTree
## Simulación Monte Carlo del combate contra el enfermero con el código real de Battle y su API de
## opciones (las órdenes se hacen con `action_menu` + `make_order`, como en la interfaz).
## Uso: "$GODOT_BIN" --headless --path . -s tools/balance/sim_enfermero.gd [-- N [estrategia,estrategia…]]
## Con la variable de entorno SIM_LOG=1 imprime el registro de cada combate (úsalo con N pequeño).
## Protagonista como en el prólogo al coger el tubo (Cuerpo 82, Mente 70, sin sangrar).
## Estrategias del jugador:
## - torso: siempre al torso con el arma; nunca se cubre ni usa nada.
## - brazo: primero rompe el brazo de instrumental, luego al torso; nunca se cubre ni usa nada.
## - listo: lee el aviso. Se cubre de lo que le haría más daño, se suelta con un empujón, se levanta
##   cubriéndose, desarma, derriba con el golpe a la rodilla y remata; respira con la Mente baja.
##   Sin objetos.
## - listo-sin-rodilla: lo mismo sin el golpe a la rodilla (para medir lo que aporta).
## - listo+kit: lo mismo con lo que se suele llevar a esa altura (1 venda, 1 analgésico): trata el
##   sangrado que importa, cierra la herida del brazo del tubo y toma analgésicos si las heridas estorban.
## - torpe: golpea partes al azar sin mirar el aviso y a veces muerde (gasta Mente).
## Resultados en docs/design/enemigos/enfermero.md § Balance.

const ENEMY: String = "res://data/enemies/enfermero.tres"
const PARTY: String = "res://data/party/paciente_09.tres"
const PIPE: String = "res://data/weapons/pipe.tres"
const START_BODY: int = 82
const START_MIND: int = 70
const MAX_ROUNDS: int = 40
const KIT: Dictionary[StringName, int] = {&"venda": 1, &"analgesicos": 1}

var _uses: Dictionary[StringName, int] = {}
var _policy: String = ""
## Daño al Cuerpo del protagonista por origen (ataque enemigo o «sangrado»).
var _taken: Dictionary[String, int] = {}


func _init() -> void:
	var runs: int = 2000
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		runs = args[0].to_int()
	var policies: Array[String] = ["torso", "brazo", "torpe", "listo", "listo+kit"]
	if args.size() > 1:
		policies.assign(args[1].split(","))
	for policy: String in policies:
		_report(policy, runs)
	quit()


func _report(policy: String, runs: int) -> void:
	_uses.clear()
	_taken.clear()
	_policy = policy
	var wins: int = 0
	var rounds_total: int = 0
	var body_left: int = 0
	var amputated: int = 0
	var broken: int = 0
	var lost_mind: int = 0
	for i: int in runs:
		var battle: Battle = _battle(i, policy)
		if OS.get_environment("SIM_LOG") == "1":
			battle.logged.connect(func(text: String) -> void: print("    ", text))
		_play(battle, policy)
		var hero: Combatant = battle.protagonist()
		if battle.outcome == Battle.Outcome.VICTORY:
			wins += 1
			body_left += hero.body
			rounds_total += battle.round_number
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
	print("%-9s victoria %5.1f %% (Quiebre %4.1f %%)  rondas %4.1f  Cuerpo al ganar %4.1f  amputación %4.1f %%  algo roto %4.1f %%" % [
		policy, 100.0 * wins / runs, 100.0 * lost_mind / runs, float(rounds_total) / maxi(1, wins),
		float(body_left) / maxi(1, wins), 100.0 * amputated / runs, 100.0 * broken / runs])
	if not _uses.is_empty():
		var parts: PackedStringArray = []
		for id: StringName in _uses:
			parts.append("%s %.2f" % [id, float(_uses[id]) / runs])
		print("          usos por combate: " + ", ".join(parts))
	var taken: PackedStringArray = []
	for key: String in _taken:
		taken.append("%s %.1f" % [key, float(_taken[key]) / runs])
	print("          Cuerpo perdido por combate: " + ", ".join(taken))


func _battle(seed_value: int, policy: String) -> Battle:
	var party: CombatantDef = (load(PARTY) as CombatantDef).duplicate()
	party.weapon = load(PIPE)
	var party_defs: Array[CombatantDef] = [party]
	var enemy_defs: Array[CombatantDef] = [load(ENEMY)]
	var battle: Battle = Battle.new(party_defs, enemy_defs, seed_value)
	battle.bandages = 0
	if policy.contains("kit"):
		battle.supplies = KIT.duplicate()
	var hero: Combatant = battle.protagonist()
	hero.body = START_BODY
	hero.mind = START_MIND
	battle.struck.connect(func(info: Dictionary) -> void:
		if info["target"] == hero and info["hit"] and info["attacker"] != hero:
			var intent: CombatAction = battle.intents.get(info["attacker"])
			var key: String = intent.attack.display_name if intent != null and intent.attack != null else "?"
			_taken[key] = _taken.get(key, 0) + int(info["body_damage"]))
	battle.logged.connect(func(text: String) -> void:
		if text.begins_with(hero.display_name() + " se desangra"):
			_taken["sangrado"] = _taken.get("sangrado", 0) + text.get_slice("−", 1).to_int()
		elif text.begins_with(hero.display_name() + " se fuerza"):
			_taken["esfuerzo"] = _taken.get("esfuerzo", 0) + text.get_slice("−", 1).to_int())
	return battle


func _play(battle: Battle, policy: String) -> void:
	while battle.outcome == Battle.Outcome.ONGOING and battle.round_number < MAX_ROUNDS:
		battle.begin_round()
		var hero: Combatant = battle.protagonist()
		var orders: Array[CombatAction] = []
		if hero.is_active():
			var order: CombatAction = _order(battle, hero, policy)
			_count(order)
			orders.append(order)
		battle.start_resolution(orders)
		while battle.step():
			pass


func _count(order: CombatAction) -> void:
	var key: StringName = &""
	match order.type:
		CombatTypes.ActionType.SKILL:
			key = order.skill.id
		CombatTypes.ActionType.ITEM:
			key = StringName("objeto:" + String(order.treatment.id if order.treatment != null else &"?"))
		CombatTypes.ActionType.GUARD:
			key = &"guardia"
		CombatTypes.ActionType.BREAK_FREE:
			key = &"zafarse"
		_:
			return
	_uses[key] = _uses.get(key, 0) + 1


func _option(battle: Battle, hero: Combatant, id: StringName) -> ActionOption:
	for option: ActionOption in battle.action_menu(hero):
		if option.id == id and option.enabled:
			return option
	return null


func _order(battle: Battle, hero: Combatant, policy: String) -> CombatAction:
	var enemy: Combatant = battle.enemies[0]
	var attack: ActionOption = _option(battle, hero, &"attack")
	match policy:
		"torso":
			return _act(battle, hero, attack, enemy, CombatTypes.TORSO)
		"brazo":
			return _act(battle, hero, attack, enemy,
					CombatTypes.TORSO if enemy.part_disabled(CombatTypes.ARM_R) else CombatTypes.ARM_R)
		"torpe":
			var bite: ActionOption = _option(battle, hero, &"morder")
			var part: StringName = enemy.part_order[battle.rng.randi_range(0, enemy.part_order.size() - 1)]
			if bite != null and battle.rng.randf() < 0.3:
				return _act(battle, hero, bite, enemy, part)
			return _act(battle, hero, attack, enemy, part)
	return _smart(battle, hero, enemy, attack)


func _act(battle: Battle, hero: Combatant, option: ActionOption, target: Combatant, part_id: StringName) -> CombatAction:
	if option == null:
		option = battle.action_menu(hero)[0]
	return battle.make_order(hero, option, target, part_id)


## Estrategia sensata: lee la intención, se cubre o se suelta, trata lo que sangra de verdad,
## desarma, derriba y remata.
func _smart(battle: Battle, hero: Combatant, enemy: Combatant, attack: ActionOption) -> CombatAction:
	var intent: CombatAction = battle.intents.get(enemy)
	var name: String = intent.attack.display_name if intent != null and intent.attack != null else ""
	var guard: ActionOption = _option(battle, hero, &"guard")
	# En el suelo: encogerse sobre lo que va a golpear, o levantarse.
	if hero.pending_skip() != null:
		if guard != null and intent != null and intent.target == hero and intent.part_id != &"":
			return _act(battle, hero, guard, hero, intent.part_id)
		return _act(battle, hero, _option(battle, hero, &"recover"), hero, &"")
	# Agarrado y viene el serrado: empujón (rápido, suelta y le quita el golpe) o cubrir el brazo.
	if name == "Serrar":
		var push: ActionOption = _option(battle, hero, &"empujon")
		if push != null and battle.preview(hero, push, enemy, CombatTypes.TORSO).act_first_chance >= 60:
			return _act(battle, hero, push, enemy, CombatTypes.TORSO)
		return _act(battle, hero, guard, hero, intent.part_id)
	# Sangrado que de verdad cuesta: tratarlo.
	var bleeding: Dictionary[StringName, int] = hero.bleeding_parts()
	for id: StringName in bleeding:
		if bleeding[id] >= 2 or hero.parts[id].is_disabled() or id == CombatTypes.TORSO:
			for item_id: StringName in [&"item:torniquete", &"item:venda"]:
				var treat: ActionOption = _option(battle, hero, item_id)
				if treat != null and battle.treatment_part_reason(treat.treatment, hero, id) == "":
					return _act(battle, hero, treat, hero, id)
	# Tajo peligroso: a la cabeza con poco Cuerpo, o al brazo del tubo ya herido.
	if name == "Tajo" and intent.target == hero and (
			(intent.part_id == CombatTypes.HEAD and hero.body < 55)
			or (intent.part_id == hero.def.dominant_arm and hero.part_state(hero.def.dominant_arm) != CombatTypes.PartState.HEALTHY)):
		return _act(battle, hero, guard, hero, intent.part_id)
	# Una venda cierra la herida del brazo del tubo (quita su penalizador).
	var bandage: ActionOption = _option(battle, hero, &"item:venda")
	if bandage != null and hero.part_state(hero.def.dominant_arm) == CombatTypes.PartState.WOUNDED:
		return _act(battle, hero, bandage, hero, hero.def.dominant_arm)
	# Analgésicos si las heridas ya estorban.
	var pills: ActionOption = _option(battle, hero, &"item:analgesicos")
	if pills != null and (hero.part_state(CombatTypes.HEAD) != CombatTypes.PartState.HEALTHY
			or hero.part_state(CombatTypes.TORSO) == CombatTypes.PartState.BROKEN
			or hero.part_state(hero.def.dominant_arm) == CombatTypes.PartState.WOUNDED):
		return _act(battle, hero, pills, hero, &"")

	# En el suelo: rematar a la cabeza (si se puede pagar).
	var finish: ActionOption = _option(battle, hero, &"rematar")
	if finish != null:
		return _act(battle, hero, finish, enemy, CombatTypes.HEAD)
	if hero.mind < 30 and name != "Tajo":
		var breathe: ActionOption = _option(battle, hero, &"respirar")
		if breathe != null:
			return _act(battle, hero, breathe, null, &"")
	# Desarmar primero.
	if not enemy.part_disabled(CombatTypes.ARM_R):
		return _act(battle, hero, attack, enemy, CombatTypes.ARM_R)
	# Luego, a las piernas: derribar para rematar.
	var knee: ActionOption = _option(battle, hero, &"golpe_rodilla") if not _policy.contains("sin-rodilla") else null
	if knee != null and not enemy.is_down():
		var leg: StringName = CombatTypes.LEG_L
		if enemy.part_disabled(CombatTypes.LEG_L) or enemy.part_state(CombatTypes.LEG_R) != CombatTypes.PartState.HEALTHY:
			leg = CombatTypes.LEG_R
		if not enemy.part_disabled(leg):
			return _act(battle, hero, knee, enemy, leg)
	return _act(battle, hero, attack, enemy, CombatTypes.TORSO)
