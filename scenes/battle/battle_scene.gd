class_name BattleScene
extends Control
## Combate por rondas con mutilaciones, a la manera de Fear & Hunger: el enemigo grande arriba en
## el centro, el grupo abajo (retrato, Cuerpo, Mente, partes y heridas), las órdenes abajo a la
## izquierda y el registro a la derecha. Solo presentación: las reglas están en `Battle`.
##
## Se puede abrir sola (prototipo: paciente 09 con el tubo contra el enfermero) o desde el mapa con
## `setup()` (lo hace EncounterDirector). Al terminar emite `battle_closed`.
##
## Controles: ratón o teclado (flechas + Intro; Esc vuelve atrás). F2: filtro VHS.
## Argumentos de depuración (después de "--"):
##   --autoplay=N          juega N rondas solo, atacando partes al azar
##   --screenshot=RUTA     guarda una captura (al terminar el autoplay, o al elegir órdenes) y cierra
##   --battle-pick=PARTE   abre la selección de parte apuntando a PARTE (para capturas)
##   --battle-maim=P,P     empieza con esas partes del enemigo amputadas (para capturas)
##   --battle-wound=P:E    empieza con una parte propia en un estado (1 Herida, 2 Rota, 3 Amputada)
##   --battle-seed=N       semilla fija
##   --battle-strike=PARTE para la captura: el protagonista arranca esa parte al enemigo
##   --battle-shot-delay=S segundos hasta la captura (0,6 por defecto)

signal battle_closed(outcome: Battle.Outcome)

const VIEW_SIZE: Vector2 = Vector2(640, 360)
const ENEMY_FEET: Vector2 = Vector2(320, 238)
const PANEL_Y: float = 246.0
const MENU_W: float = 152.0
const CARD_X: float = 162.0
const LOG_X: float = 440.0
const STEP_DELAY: float = 0.45
const AUTOPLAY_DELAY: float = 0.02
const IMPACT_ABERRATION: float = 2.6
const IDLE_SOUND_EVERY: Vector2 = Vector2(4.5, 8.0)
const DEFAULT_PARTY: CombatantDef = preload("res://data/party/paciente_09.tres")
const DEFAULT_ENEMY: CombatantDef = preload("res://data/enemies/enfermero.tres")
const DEFAULT_WEAPON: WeaponDef = preload("res://data/weapons/pipe.tres")
const NOISE_SHADER: Shader = preload("res://shaders/tape_noise.gdshader")
## Sonidos del combate (nombres de Sfx). Si falta el definitivo, se usa el provisional de la derecha.
const SOUND_FALLBACK: Dictionary[String, String] = {
	"combat_pipe_flesh": "metal_bang", "combat_pipe_bone": "metal_bang", "combat_bone_break": "metal_bang",
	"combat_amputation": "cloth_tear", "combat_scalpel_slash": "cloth_tear", "combat_saw": "cloth_tear",
	"combat_syringe": "glass", "combat_swing_miss": "cloth_rustle", "enfermero_breath": "entity_breath",
	"enfermero_growl": "entity_breath", "enfermero_scream": "entity_whisper", "enfermero_death": "heavy_drag",
	"enfermero_drag_steps": "heavy_drag", "combat_transition": "pa_static",
}
const ENEMY_CONDITION: Array[String] = ["Agonizando", "Malherido", "Herido", "Entero"]

## Solo si se abre sola (sin setup()).
@export var party_defs: Array[CombatantDef] = [DEFAULT_PARTY]
@export var enemy_defs: Array[CombatantDef] = [DEFAULT_ENEMY]
## Semilla fija para repetir un combate. -1 = aleatoria.
@export var seed_value: int = -1

var battle: Battle
## Personaje del mapa (objetos de la custodia y retrato). Opcional.
var character: CharacterState
## Imagen del lugar donde ocurre (se oscurece de fondo). Opcional.
var background_texture: Texture2D
## Música del combate (nombre de pista). Opcional.
var music_name: String = ""
var debug: Dictionary[String, String] = {}

var _embedded: bool = false
var _orders: Array[CombatAction] = []
var _member_index: int = -1
var _events: Array[Dictionary] = []
var _content: Control
var _stage: Node2D
var _enemy_views: Array[EnemyView] = []
var _blood: BloodFx
var _reticle: PartReticle
var _cards: Array[PartyCard] = []
var _menu: VBoxContainer
var _menu_title: Label
var _log: RichTextLabel
var _round_label: Label
var _impact: Label
var _impact_tween: Tween
var _floaters: Node2D
var _flash: ColorRect
var _intent_panel: Control
var _enemy_panel: Control
var _vhs: VhsOverlay
var _noise_material: ShaderMaterial
var _music: MusicPlayer
var _shake_tween: Tween
var _theme: Theme
var _picking_enemy: Combatant
var _autoplay_rounds: int = 0
var _screenshot_path: String = ""
var _idle_timer: float = 5.0
var _intent_flash: float = 0.0
var _closing: bool = false
## Hay un submenú abierto (Esc vuelve al principal).
var _submenu: bool = false


## Prepara el combate antes de añadir la escena al árbol (desde el mapa).
func setup(p_battle: Battle, p_character: CharacterState, p_background: Texture2D, p_music: String = "",
		p_debug: Dictionary[String, String] = {}) -> void:
	battle = p_battle
	character = p_character
	background_texture = p_background
	music_name = p_music
	debug = p_debug
	_embedded = true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _embedded:
		_parse_debug_args()
	_read_debug()
	if battle == null:
		battle = _prototype_battle()
	_apply_debug_state()
	_theme = _build_theme()
	theme = _theme
	_content = Control.new()
	_content.size = VIEW_SIZE
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_content)
	_build_background()
	_build_stage()
	_build_top()
	_build_bottom()
	_build_overlays()
	battle.logged.connect(_on_logged)
	battle.impact.connect(_show_impact)
	battle.finished.connect(_on_finished)
	battle.action_started.connect(func(action: CombatAction) -> void: _events.append({"type": &"action", "action": action}))
	battle.struck.connect(func(info: Dictionary) -> void: _events.append({"type": &"struck", "info": info}))
	if not _embedded:
		_vhs = VhsOverlay.new()
		add_child(_vhs)
	_start_music()
	for enemy: Combatant in battle.enemies:
		if enemy.def.intro_text != "":
			_on_logged(enemy.def.intro_text)
	_start_round()


func _process(delta: float) -> void:
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_idle_timer = randf_range(IDLE_SOUND_EVERY.x, IDLE_SOUND_EVERY.y)
		for enemy: Combatant in battle.enemies:
			if enemy.is_active() and enemy.def.sound_idle != "":
				_sound(enemy.def.sound_idle, -14.0)
	if _intent_flash > 0.0:
		_intent_flash = maxf(0.0, _intent_flash - delta * 1.6)
		_intent_panel.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _member_index >= 0:
		get_viewport().set_input_as_handled()
		if _submenu:
			_show_main_menu()
		elif not _orders.is_empty():
			_go_back()


# --- flujo de la ronda -----------------------------------------------------------------------

func _start_round() -> void:
	battle.begin_round()
	_orders.clear()
	_member_index = -1
	_refresh()
	_telegraph()
	if _autoplay_rounds > 0:
		_autoplay_rounds -= 1
		_autoplay_orders()
		_resolve()
		return
	_next_member()
	# Depuración (capturas desde el mapa): abre la selección de parte apuntando a una.
	if _embedded and debug.has("battle-pick") and battle.round_number == 1 and _member_index >= 0:
		var enemy: Combatant = _present_enemies()[0]
		_show_part_menu(enemy)
		_aim_at(enemy, StringName(debug["battle-pick"]))
	if _screenshot_path != "" and _autoplay_rounds == 0 and not debug.has("autoplay"):
		_take_screenshot_and_quit()


## Aviso del enemigo: anima la preparación del golpe y suena.
func _telegraph() -> void:
	_intent_flash = 1.0
	for index: int in battle.enemies.size():
		var enemy: Combatant = battle.enemies[index]
		var intent: CombatAction = battle.intents.get(enemy)
		if intent == null or not enemy.is_active():
			continue
		_enemy_views[index].play(&"windup")
		if intent.attack != null and intent.attack.sound_windup != "":
			_sound(intent.attack.sound_windup, -6.0)


func _next_member() -> void:
	_member_index += 1
	while _member_index < battle.party.size() and not battle.party[_member_index].is_active():
		_member_index += 1
	if _member_index >= battle.party.size():
		_resolve()
		return
	_show_main_menu()


func _resolve() -> void:
	_member_index = -1
	_picking_enemy = null
	_reticle.visible = false
	_set_menu_title("…")
	_submenu = false
	_clear_menu()
	_events.clear()
	battle.start_resolution(_orders)
	_refresh()
	var fast: bool = _autoplay_rounds > 0 or debug.has("autoplay")
	while battle.step():
		await _play_events(fast)
		_refresh()
		await _wait(AUTOPLAY_DELAY if fast else STEP_DELAY)
	await _play_events(fast)
	_refresh()
	if battle.outcome == Battle.Outcome.ONGOING:
		await _wait(AUTOPLAY_DELAY if fast else STEP_DELAY)
		_start_round()
	elif _screenshot_path != "":
		_take_screenshot_and_quit()
	elif _embedded:
		_close_after(battle.outcome)
	else:
		_show_end_menu()


func _current() -> Combatant:
	return battle.party[_member_index]


func _add_order(type: CombatTypes.ActionType, target: Combatant = null, part_id: StringName = &"",
		item: Variant = null) -> void:
	var order: CombatAction = CombatAction.new()
	order.type = type
	order.actor = _current()
	order.target = target if target != null else _current()
	order.part_id = part_id
	order.item = item
	_orders.append(order)
	_clear_highlights()
	_next_member()


func _go_back() -> void:
	var last: CombatAction = _orders.pop_back()
	_member_index = battle.party.find(last.actor)
	_show_main_menu()


# --- menús ---------------------------------------------------------------------------------------

func _show_main_menu() -> void:
	var member: Combatant = _current()
	_picking_enemy = null
	_submenu = false
	_reticle.visible = false
	_clear_highlights()
	_refresh()
	_set_menu_title("%s — ¿qué haces?" % member.display_name() if battle.party.size() > 1 else "¿Qué haces?")
	_clear_menu()
	var targets: Array[Combatant] = _present_enemies()
	_add_button("Atacar · %s" % member.current_weapon().display_name,
			_show_part_menu.bind(targets[0]) if targets.size() == 1 else _show_enemy_menu, not targets.is_empty())
	_add_button("Guardia", _show_guard_menu)
	var items: int = _item_count()
	_add_button("Objeto (%d)" % items, _show_item_menu, items > 0 and member.can_use_items())
	_add_button("Respirar  +%d Mente" % (Battle.BREATHE_BASE + member.def.willpower),
			_add_order.bind(CombatTypes.ActionType.BREATHE))
	if member.breakable_status() != null:
		_add_button("Zafarse  %d%%" % battle.break_free_chance(member), _add_order.bind(CombatTypes.ActionType.BREAK_FREE))
	if battle.party.size() > 1:
		_add_button("Huir solo  %d%%" % battle.flee_chance_solo(member),
				_add_order.bind(CombatTypes.ActionType.FLEE_SOLO), battle.can_flee and member.can_flee())
	_add_button("Huir  %d%%" % battle.flee_chance_all(), _add_order.bind(CombatTypes.ActionType.FLEE_ALL),
			battle.can_flee and member.can_flee())
	if not _orders.is_empty():
		_add_button("« Atrás", _go_back)
	_focus_first()


func _show_enemy_menu() -> void:
	_set_menu_title("¿A quién?")
	_submenu = true
	_clear_menu()
	for enemy: Combatant in _present_enemies():
		_add_button(enemy.display_name(), _show_part_menu.bind(enemy))
	_add_button("« Atrás", _show_main_menu)
	_focus_first()


func _show_part_menu(enemy: Combatant) -> void:
	_picking_enemy = enemy
	_set_menu_title("¿Dónde golpeas?   Esc: atrás")
	_submenu = true
	_clear_menu()
	var first: Button = null
	var wanted: StringName = StringName(debug.get("battle-pick", ""))
	for id: StringName in enemy.part_order:
		var part: BodyPartState = enemy.parts[id]
		var text: String = "%s  —" % part.def.display_name
		if not part.is_amputated():
			text = "%s  %d%%" % [part.def.display_name, battle.preview_hit_chance(_current(), enemy, id)]
		var button: Button = _add_button(text, _add_order.bind(CombatTypes.ActionType.ATTACK, enemy, id),
				not part.is_amputated())
		button.focus_entered.connect(_aim_at.bind(enemy, id))
		button.mouse_entered.connect(_aim_at.bind(enemy, id))
		if not part.is_amputated() and (first == null or id == wanted):
			first = button
	if enemy.part_order.size() < 6:
		_add_button("« Atrás", _show_main_menu)
	if first != null:
		var focus_first: Button = first
		(func() -> void:
			if is_instance_valid(focus_first) and focus_first.is_inside_tree():
				focus_first.grab_focus()).call_deferred()


func _show_guard_menu() -> void:
	var member: Combatant = _current()
	_set_menu_title("¿Qué te cubres?   Esc: atrás")
	_submenu = true
	_clear_menu()
	for id: StringName in member.part_order:
		var part: BodyPartState = member.parts[id]
		var button: Button = _add_button("Cubrir %s" % part.def.display_name.to_lower(),
				_add_order.bind(CombatTypes.ActionType.GUARD, member, id), not part.is_amputated())
		button.focus_entered.connect(_guard_highlight.bind(member, id))
		button.mouse_entered.connect(_guard_highlight.bind(member, id))
	if member.part_order.size() < 6:
		_add_button("« Atrás", _show_main_menu)
	_focus_first()


func _show_item_menu() -> void:
	_set_menu_title("¿Qué usas?   Esc: atrás")
	_submenu = true
	_clear_menu()
	if character != null:
		var used: Array[Variant] = []
		for order: CombatAction in _orders:
			used.append(order.item)
		for stack: ItemStack in CombatBridge.combat_items(character):
			if used.has(stack):
				continue
			var label: String = stack.def.display_name + (" ×%d" % stack.quantity if stack.quantity > 1 else "")
			_add_button(label, _add_order.bind(CombatTypes.ActionType.ITEM, _current(), &"", stack))
	else:
		for member: Combatant in battle.party:
			if member.is_present():
				_add_button("Venda a %s" % member.display_name(), _add_order.bind(CombatTypes.ActionType.ITEM, member))
	_add_button("« Atrás", _show_main_menu)
	_focus_first()


func _item_count() -> int:
	if character != null:
		var count: int = CombatBridge.combat_items(character).size()
		for order: CombatAction in _orders:
			if order.type == CombatTypes.ActionType.ITEM:
				count -= 1
		return maxi(0, count)
	var used: int = 0
	for order: CombatAction in _orders:
		if order.type == CombatTypes.ActionType.ITEM:
			used += 1
	return battle.bandages - used


func _show_end_menu() -> void:
	_set_menu_title("FIN DEL COMBATE")
	_clear_menu()
	_add_button("Repetir combate", get_tree().reload_current_scene)
	_add_button("Salir", get_tree().quit)
	_focus_first()


func _autoplay_orders() -> void:
	for member: Combatant in battle.party:
		if not member.is_active():
			continue
		var targets: Array[Combatant] = _present_enemies()
		if targets.is_empty():
			return
		var target: Combatant = targets[battle.rng.randi_range(0, targets.size() - 1)]
		var order: CombatAction = CombatAction.new()
		order.type = CombatTypes.ActionType.ATTACK
		order.actor = member
		order.target = target
		order.part_id = target.part_order[battle.rng.randi_range(0, target.part_order.size() - 1)]
		_orders.append(order)


func _present_enemies() -> Array[Combatant]:
	var result: Array[Combatant] = []
	for enemy: Combatant in battle.enemies:
		if enemy.is_present():
			result.append(enemy)
	return result


# --- apuntar ---------------------------------------------------------------------------------------

## Señala la parte sobre el propio sprite con su acierto y el daño estimado.
func _aim_at(enemy: Combatant, part_id: StringName) -> void:
	var index: int = battle.enemies.find(enemy)
	if index < 0:
		return
	var view: EnemyView = _enemy_views[index]
	view.highlight_part = part_id
	var part: BodyPartState = enemy.parts[part_id]
	var lines: PackedStringArray = [part.def.display_name.to_upper()]
	if part.is_amputated():
		lines.append("Ya no está.")
	else:
		var chance: int = battle.preview_hit_chance(_current(), enemy, part_id)
		var damage: Dictionary = battle.preview_damage(_current(), enemy, part_id)
		var range_body: Vector2i = damage["body"]
		lines.append("Acierto %d %%" % chance)
		lines.append("Daño %d–%d" % [range_body.x, range_body.y])
		lines.append("Estado: %s" % CombatTypes.PART_STATE_NAMES[part.state])
		var hint: String = _part_hint(enemy, part)
		if hint != "":
			lines.append(hint)
	var point: Vector2 = view.position + view.anchor(part_id)
	_reticle.panel_at = Vector2(10, 150)
	_reticle.point_at(point, lines)


## Pista corta de lo que conseguiría golpear ahí.
func _part_hint(enemy: Combatant, part: BodyPartState) -> String:
	var weapon: WeaponDef = _current().current_weapon()
	var blunt: bool = weapon.damage_type == CombatTypes.DamageType.BLUNT
	if part.state == CombatTypes.PartState.BROKEN:
		if blunt and part.def.severable_by_blunt:
			return "Se puede arrancar."
		if weapon.damage_type == CombatTypes.DamageType.CUT and part.def.amputable:
			return "Se puede cortar."
		return "Ya está rota."
	for attack: EnemyAttackDef in enemy.def.attacks:
		if attack.required_part == part.def.id and not attack.reaction:
			return "Si se rompe: sin %s." % attack.display_name.to_lower()
	if part.def.id == CombatTypes.HEAD and blunt:
		return "Puede aturdir."
	return ""


func _guard_highlight(member: Combatant, part_id: StringName) -> void:
	var index: int = battle.party.find(member)
	if index >= 0 and index < _cards.size():
		_cards[index].highlight(part_id)


func _clear_highlights() -> void:
	for view: EnemyView in _enemy_views:
		view.highlight_part = &""
	for card: PartyCard in _cards:
		card.highlight(&"")
	if _reticle != null:
		_reticle.visible = false


## Ratón sobre el escenario: apunta a la parte más cercana; clic para golpear.
func _on_stage_input(event: InputEvent) -> void:
	if _picking_enemy == null:
		return
	var motion: InputEventMouse = event as InputEventMouse
	if motion == null:
		return
	var index: int = battle.enemies.find(_picking_enemy)
	var view: EnemyView = _enemy_views[index]
	var best: StringName = &""
	var best_d: float = 34.0
	for id: StringName in _picking_enemy.part_order:
		if _picking_enemy.parts[id].is_amputated():
			continue
		var d: float = (view.position + view.anchor(id)).distance_to(motion.position)
		if d < best_d:
			best_d = d
			best = id
	if best == &"":
		return
	_aim_at(_picking_enemy, best)
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_add_order(CombatTypes.ActionType.ATTACK, _picking_enemy, best)


# --- reproducción de lo que pasa ---------------------------------------------------------------------

func _play_events(fast: bool) -> void:
	while not _events.is_empty():
		var event: Dictionary = _events.pop_front()
		if event["type"] == &"action":
			await _play_action(event["action"], fast)
		else:
			await _play_strike(event["info"], fast)


func _play_action(action: CombatAction, fast: bool) -> void:
	if action.actor.is_enemy:
		var index: int = battle.enemies.find(action.actor)
		if index >= 0 and action.attack != null:
			_enemy_views[index].play(action.attack.anim)
			_lunge(_enemy_views[index], 1.07)
		if not fast:
			await _wait(0.22)
	elif action.type == CombatTypes.ActionType.ATTACK:
		var index: int = battle.party.find(action.actor)
		if index >= 0 and index < _cards.size():
			_cards[index].bump()
		if not fast:
			await _wait(0.12)


func _play_strike(info: Dictionary, fast: bool) -> void:
	var target: Combatant = info["target"]
	var hit: bool = info["hit"]
	var part_id: StringName = info["part_id"]
	var attacker: Combatant = info["attacker"]
	if target == null:
		return
	if target.is_enemy:
		var index: int = battle.enemies.find(target)
		var view: EnemyView = _enemy_views[index]
		var point: Vector2 = view.position + view.anchor(part_id if part_id != &"" else CombatTypes.TORSO)
		if not hit:
			_sound("combat_swing_miss", -6.0)
			_float_text(point, "FALLO", UiStyle.ASH)
			var sway: Tween = create_tween()
			sway.tween_property(view, "position:x", view.position.x + 10.0, 0.08)
			sway.tween_property(view, "position:x", ENEMY_FEET.x, 0.16)
		else:
			view.flash()
			view.sync_parts(target)
			var heavy: bool = info["broke"] or info["amputated"]
			view.play(&"stagger" if heavy else &"hit")
			_blood.burst(point, 50 if info["amputated"] else (22 if heavy else 9),
					(point - ENEMY_FEET - Vector2(0, -120)).normalized(), 190.0 if info["amputated"] else 140.0)
			_sound(_impact_sound(info), -2.0)
			if heavy and target.def.sound_hurt != "" and not target.dead:
				_sound(target.def.sound_hurt, -4.0)
			_float_text(point, "−%d" % int(info["body_damage"]), UiStyle.BONE)
			if info["critical"]:
				_float_text(point + Vector2(0, -16), "CRÍTICO", UiStyle.AMBER)
			_shake(6.0 if info["amputated"] else (3.5 if heavy else 2.0))
			if target.dead:
				await _enemy_death(target, view)
	else:
		var index: int = battle.party.find(target)
		var card: PartyCard = _cards[index] if index >= 0 and index < _cards.size() else null
		var anchor: Vector2 = card.home + Vector2(card.size.x * 0.5, 4.0) if card != null else Vector2(320, PANEL_Y)
		if not hit:
			_sound("combat_swing_miss", -6.0)
			_float_text(anchor + Vector2(0, -10), "ESQUIVAS", UiStyle.ASH)
		else:
			var amount: int = info["body_damage"]
			var attack_sound: String = ""
			var intent_attack: EnemyAttackDef = _attack_of(attacker)
			if intent_attack != null:
				attack_sound = intent_attack.sound_hit
			if info["amputated"]:
				_sound("combat_amputation", 0.0)
			elif attack_sound != "":
				_sound(attack_sound, -2.0)
			if card != null:
				card.hurt(1.6 if info["amputated"] else 1.0)
			if amount > 0:
				_blood.burst(anchor, 40 if info["amputated"] else 6 + mini(amount, 20), Vector2.UP,
						220.0 if info["amputated"] else 150.0)
				_float_text(anchor + Vector2(0, -12), "−%d" % amount, UiStyle.BLOOD.lightened(0.3))
			if int(info["mind_damage"]) > 0:
				_float_text(anchor + Vector2(40, -12), "−%d Mente" % int(info["mind_damage"]), Color("8c9ad8"))
			_red_flash(0.55 if info["amputated"] else 0.3)
			_shake(9.0 if info["amputated"] else 4.0 + amount * 0.15)
	_refresh()
	if not fast:
		await _wait(0.32)


## Ataque que está ejecutando un enemigo (su intención de esta ronda).
func _attack_of(enemy: Combatant) -> EnemyAttackDef:
	var intent: CombatAction = battle.intents.get(enemy)
	return intent.attack if intent != null else null


func _impact_sound(info: Dictionary) -> String:
	if info["amputated"]:
		return "combat_amputation"
	if info["broke"]:
		return "combat_bone_break"
	match int(info["damage_type"]):
		CombatTypes.DamageType.CUT:
			return "combat_scalpel_slash"
		CombatTypes.DamageType.PIERCE:
			return "combat_syringe"
	var part_id: StringName = info["part_id"]
	return "combat_pipe_bone" if part_id == CombatTypes.HEAD or part_id.begins_with("arm") else "combat_pipe_flesh"


func _enemy_death(enemy: Combatant, view: EnemyView) -> void:
	view.play(&"death")
	if enemy.def.sound_death != "":
		_sound(enemy.def.sound_death, 0.0)
	_blood.burst(view.position + view.anchor(CombatTypes.TORSO), 30, Vector2.ZERO, 160.0)
	_shake(5.0)
	await _wait(view.anim_length(&"death"))


func _lunge(view: EnemyView, amount: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(view, "scale", Vector2(amount, amount), 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "scale", Vector2.ONE, 0.2)


func _shake(strength: float) -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = create_tween()
	for i: int in 6:
		var falloff: float = 1.0 - i / 6.0
		_shake_tween.tween_property(_content, "position",
				Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * falloff, 0.035)
	_shake_tween.tween_property(_content, "position", Vector2.ZERO, 0.04)


func _red_flash(alpha: float) -> void:
	_flash.color = Color(0.55, 0.02, 0.02, alpha)
	var tween: Tween = create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.5)
	if _vhs != null:
		_vhs.glitch(0.35, 0.35)


func _float_text(point: Vector2, text: String, color: Color) -> void:
	var label: Label = UiStyle.label(text, UiStyle.SIZE_LARGE, color, UiStyle.ui_bold())
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.position = point + Vector2(-30, -20)
	label.size = Vector2(60, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floaters.add_child(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 22.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.35)
	tween.tween_callback(label.queue_free)


# --- señales de Battle ------------------------------------------------------------------------------

func _on_logged(text: String) -> void:
	if text.begins_with("—"):
		_log.append_text("[color=#d0a24a]%s[/color]\n" % text)
	else:
		_log.append_text(text + "\n")


func _on_finished(outcome: Battle.Outcome, summary: String) -> void:
	_log.append_text("[color=#e8e1d3]%s[/color]\n" % summary)
	_refresh()
	if _music != null:
		_music.fade_out(2.0)
	if outcome == Battle.Outcome.VICTORY:
		_set_menu_title("")


func _close_after(outcome: Battle.Outcome) -> void:
	if _closing:
		return
	_closing = true
	await _wait(1.6 if outcome == Battle.Outcome.VICTORY else 1.0)
	_set_menu_title("")
	_clear_menu()
	battle_closed.emit(outcome)


func _show_impact(text: String) -> void:
	_impact.text = text
	if _impact_tween != null:
		_impact_tween.kill()
	_impact.modulate.a = 1.0
	_impact.scale = Vector2(1.15, 1.15)
	_impact_tween = create_tween()
	_impact_tween.tween_property(_impact, "scale", Vector2.ONE, 0.2)
	_impact_tween.tween_interval(0.4)
	_impact_tween.tween_property(_impact, "modulate:a", 0.0, 0.6)
	if _vhs != null:
		_vhs.set_param(&"aberration_px", IMPACT_ABERRATION)
		_impact_tween.parallel().tween_method(func(v: float) -> void: _vhs.set_param(&"aberration_px", v),
				IMPACT_ABERRATION, 1.0, 0.6)


# --- refresco --------------------------------------------------------------------------------------

func _refresh() -> void:
	_round_label.text = "RONDA %d" % battle.round_number
	for index: int in battle.enemies.size():
		_enemy_views[index].sync_parts(battle.enemies[index])
	for index: int in _cards.size():
		_cards[index].selected = index == _member_index
		_cards[index].refresh()
	_intent_panel.queue_redraw()
	_enemy_panel.queue_redraw()


func _enemy_condition(enemy: Combatant) -> String:
	if enemy.dead:
		return "Muerto"
	var ratio: float = float(enemy.body) / enemy.def.body_max
	return ENEMY_CONDITION[clampi(int(ratio * 4.0 - 0.001), 0, 3)]


func _draw_intent_panel() -> void:
	var enemy: Combatant = battle.enemies[0] if not battle.enemies.is_empty() else null
	if enemy == null or not enemy.is_active():
		return
	var what: String = battle.intent_text(enemy)
	if what == "":
		return
	# Con un solo personaje sobra «de PACIENTE 09»; el objetivo va en su propia línea.
	if battle.party.size() == 1:
		what = what.replace(" de " + battle.party[0].display_name(), "").replace(" → " + battle.party[0].display_name(), "")
	var bits: PackedStringArray = what.split(" → ")
	var telegraph: String = battle.intent_telegraph(enemy)
	var font: Font = UiStyle.ui()
	var bold: Font = UiStyle.ui_bold()
	var width: float = _intent_panel.size.x
	var lines: PackedStringArray = _wrap(telegraph, font, UiStyle.SIZE_SMALL - 1, width - 12.0)
	var target_line: String = ("→ " + bits[1]) if bits.size() > 1 else ""
	var top: float = 46.0 if target_line != "" else 34.0
	var height: float = top + lines.size() * 12.0 + 2.0
	var glow: float = _intent_flash
	_intent_panel.draw_rect(Rect2(Vector2.ZERO, Vector2(width, height)), Color(0.05, 0.03, 0.02, 0.86))
	_intent_panel.draw_rect(Rect2(Vector2.ZERO, Vector2(width, height)), UiStyle.AMBER.lerp(Color.WHITE, glow * 0.5), false, 1.0 + glow)
	_intent_panel.draw_string(font, Vector2(6, 12), "PREPARA", HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.SIZE_SMALL - 1, UiStyle.ASH)
	_intent_panel.draw_string(bold, Vector2(6, 28), bits[0], HORIZONTAL_ALIGNMENT_LEFT, width - 12.0, UiStyle.SIZE_LARGE,
		UiStyle.AMBER.lerp(Color.WHITE, glow * 0.4))
	if target_line != "":
		_intent_panel.draw_string(bold, Vector2(6, 41), target_line, HORIZONTAL_ALIGNMENT_LEFT, width - 12.0,
			UiStyle.SIZE_SMALL, UiStyle.BONE)
	for i: int in lines.size():
		_intent_panel.draw_string(font, Vector2(6, top + 10 + i * 12), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1,
			UiStyle.SIZE_SMALL - 1, UiStyle.BONE_DIM)


func _draw_enemy_panel() -> void:
	var mono: Font = UiStyle.mono()
	var bold: Font = UiStyle.ui_bold()
	var y: float = 0.0
	for enemy: Combatant in battle.enemies:
		_enemy_panel.draw_string(bold, Vector2(0, y + 12), enemy.display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1,
			UiStyle.SIZE_TEXT, UiStyle.BONE)
		_enemy_panel.draw_string(mono, Vector2(0, y + 25), _enemy_condition(enemy), HORIZONTAL_ALIGNMENT_LEFT, -1,
			UiStyle.MONO_SMALL, UiStyle.BLOOD.lightened(0.3))
		var status: String = enemy.status_text()
		var line: float = y + 38.0
		if status != "" and not enemy.dead:
			_enemy_panel.draw_string(mono, Vector2(0, line), status, HORIZONTAL_ALIGNMENT_LEFT, 140, UiStyle.MONO_SMALL - 1,
				UiStyle.AMBER)
			line += 12.0
		for id: StringName in enemy.part_order:
			var part: BodyPartState = enemy.parts[id]
			var color: Color = [UiStyle.BONE_DIM, UiStyle.AMBER, UiStyle.BLOOD.lightened(0.2), UiStyle.ASH][part.state]
			_enemy_panel.draw_rect(Rect2(Vector2(0, line - 6), Vector2(4, 4)), color)
			_enemy_panel.draw_string(mono, Vector2(8, line), "%s · %s" % [part.def.display_name, CombatTypes.PART_STATE_NAMES[part.state]],
				HORIZONTAL_ALIGNMENT_LEFT, 190, UiStyle.MONO_SMALL - 1, color)
			line += 11.0
		y = line + 8.0


func _wrap(text: String, font: Font, font_size: int, width: float) -> PackedStringArray:
	var lines: PackedStringArray = []
	var current: String = ""
	for word: String in text.split(" ", false):
		var attempt: String = word if current == "" else current + " " + word
		if font.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and current != "":
			lines.append(current)
			current = word
		else:
			current = attempt
	if current != "":
		lines.append(current)
	return lines


# --- construcción ----------------------------------------------------------------------------------

func _prototype_battle() -> Battle:
	var defs: Array[CombatantDef] = []
	for def: CombatantDef in party_defs:
		var copy: CombatantDef = def.duplicate()
		if copy.weapon == null:
			copy.weapon = DEFAULT_WEAPON
		defs.append(copy)
	var seed_number: int = int(debug["battle-seed"]) if debug.has("battle-seed") else seed_value
	var built: Battle = Battle.new(defs, enemy_defs, seed_number)
	built.bandages = 1
	return built


func _build_theme() -> Theme:
	var built: Theme = Theme.new()
	built.default_font = UiStyle.ui()
	built.default_font_size = UiStyle.SIZE_SMALL
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.06, 0.08, 0.92)
	normal.border_color = Color(0.22, 0.22, 0.25)
	normal.set_border_width_all(1)
	normal.content_margin_left = 6
	normal.content_margin_right = 4
	normal.content_margin_top = 1
	normal.content_margin_bottom = 1
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.13, 0.1, 0.07, 0.95)
	hover.border_color = UiStyle.AMBER
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.04, 0.04, 0.05, 0.8)
	built.set_stylebox("normal", "Button", normal)
	built.set_stylebox("hover", "Button", hover)
	built.set_stylebox("pressed", "Button", hover)
	built.set_stylebox("focus", "Button", hover)
	built.set_stylebox("disabled", "Button", disabled)
	built.set_color("font_color", "Button", UiStyle.BONE_DIM)
	built.set_color("font_hover_color", "Button", UiStyle.AMBER)
	built.set_color("font_focus_color", "Button", UiStyle.AMBER)
	built.set_color("font_pressed_color", "Button", UiStyle.AMBER)
	built.set_color("font_disabled_color", "Button", Color(UiStyle.ASH, 0.6))
	built.set_color("font_color", "Label", UiStyle.BONE)
	built.set_color("default_color", "RichTextLabel", UiStyle.BONE_DIM)
	return built


## Fondo: el lugar donde ocurre, oscurecido, con un cono de luz sobre el enemigo.
func _build_background() -> void:
	var base: ColorRect = ColorRect.new()
	base.color = Color("060608")
	base.size = VIEW_SIZE
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(base)
	if background_texture != null:
		var picture: TextureRect = TextureRect.new()
		picture.texture = background_texture
		picture.size = VIEW_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.modulate = Color(0.34, 0.31, 0.32)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(picture)
	var shade: Control = Control.new()
	shade.size = VIEW_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.draw.connect(_draw_backdrop.bind(shade))
	_content.add_child(shade)


func _draw_backdrop(canvas: Control) -> void:
	var has_picture: bool = background_texture != null
	if not has_picture:
		# Pasillo genérico: suelo de baldosa en perspectiva hacia el fondo.
		for i: int in 14:
			var y: float = 150.0 + pow(i / 13.0, 1.7) * 100.0
			canvas.draw_line(Vector2(0, y), Vector2(VIEW_SIZE.x, y), Color(0.12, 0.12, 0.13, 0.6), 1.0)
		for i: int in 17:
			var x: float = (i - 8) * 80.0
			canvas.draw_line(Vector2(ENEMY_FEET.x + x * 0.15, 150), Vector2(ENEMY_FEET.x + x, 250), Color(0.12, 0.12, 0.13, 0.6), 1.0)
	# Cono de luz desde arriba sobre el enemigo y oscuridad alrededor.
	var cone: PackedVector2Array = [Vector2(ENEMY_FEET.x - 26, 0), Vector2(ENEMY_FEET.x + 26, 0),
		Vector2(ENEMY_FEET.x + 130, ENEMY_FEET.y + 10), Vector2(ENEMY_FEET.x - 130, ENEMY_FEET.y + 10)]
	canvas.draw_colored_polygon(cone, Color(0.75, 0.8, 0.72, 0.05))
	for ring: int in 6:
		var r: Vector2 = Vector2(150 - ring * 20, 18 - ring * 2)
		_ellipse(canvas, ENEMY_FEET + Vector2(0, 4), r, Color(0.7, 0.75, 0.7, 0.025))
	for i: int in 24:
		var t: float = i / 23.0
		canvas.draw_rect(Rect2(0, i * 4, VIEW_SIZE.x, 4), Color(0, 0, 0, 0.55 * (1.0 - t)))
	canvas.draw_rect(Rect2(0, 0, 70, VIEW_SIZE.y), Color(0, 0, 0, 0.35))
	canvas.draw_rect(Rect2(VIEW_SIZE.x - 70, 0, 70, VIEW_SIZE.y), Color(0, 0, 0, 0.35))


func _ellipse(canvas: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = []
	for i: int in 24:
		var a: float = TAU * i / 24.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	canvas.draw_colored_polygon(points, color)


func _build_stage() -> void:
	_stage = Node2D.new()
	_stage.name = "Stage"
	_content.add_child(_stage)
	var count: int = battle.enemies.size()
	for index: int in count:
		var view: EnemyView = EnemyView.new()
		view.position = ENEMY_FEET + Vector2((index - (count - 1) / 2.0) * 180.0, 0)
		view.setup(battle.enemies[index].def)
		view.sync_parts(battle.enemies[index])
		_stage.add_child(view)
		_enemy_views.append(view)
	_blood = BloodFx.new()
	_blood.floor_y = ENEMY_FEET.y + 6.0
	_stage.add_child(_blood)
	_reticle = PartReticle.new()
	_reticle.font = UiStyle.mono()
	_reticle.visible = false
	_stage.add_child(_reticle)
	var input: Control = Control.new()
	input.position = Vector2(80, 0)
	input.size = Vector2(480, PANEL_Y)
	input.mouse_filter = Control.MOUSE_FILTER_PASS
	input.gui_input.connect(_on_stage_input)
	_content.add_child(input)


func _build_top() -> void:
	_round_label = UiStyle.label("", UiStyle.MONO_SMALL, UiStyle.ASH, UiStyle.mono())
	_round_label.position = Vector2(8, 4)
	_content.add_child(_round_label)
	_enemy_panel = Control.new()
	_enemy_panel.position = Vector2(10, 20)
	_enemy_panel.size = Vector2(200, 140)
	_enemy_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_panel.draw.connect(_draw_enemy_panel)
	_content.add_child(_enemy_panel)
	_intent_panel = Control.new()
	_intent_panel.position = Vector2(452, 20)
	_intent_panel.size = Vector2(180, 100)
	_intent_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent_panel.draw.connect(_draw_intent_panel)
	_content.add_child(_intent_panel)


func _build_bottom() -> void:
	var panel: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.03, 0.95)
	style.border_color = Color(0.3, 0.29, 0.33)
	style.border_width_top = 1
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(0, PANEL_Y)
	panel.size = Vector2(VIEW_SIZE.x, VIEW_SIZE.y - PANEL_Y)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(panel)
	_menu_title = UiStyle.label("", UiStyle.SIZE_SMALL - 1, UiStyle.AMBER)
	_menu_title.position = Vector2(6, PANEL_Y + 2)
	_menu_title.size = Vector2(MENU_W, 13)
	_menu_title.clip_text = true
	_content.add_child(_menu_title)
	_menu = VBoxContainer.new()
	_menu.position = Vector2(6, PANEL_Y + 16)
	_menu.size = Vector2(MENU_W, VIEW_SIZE.y - PANEL_Y - 18)
	_menu.add_theme_constant_override("separation", 0)
	_content.add_child(_menu)
	var x: float = CARD_X
	for member: Combatant in battle.party:
		var card: PartyCard = PartyCard.new()
		card.position = Vector2(x, PANEL_Y + 7)
		card.home = card.position
		card.setup(member, character if member.def.is_protagonist else null)
		_content.add_child(card)
		_cards.append(card)
		x += 92.0 if battle.party.size() > 1 else 0.0
		if battle.party.size() > 1:
			card.size = Vector2(88, 100)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.position = Vector2(LOG_X, PANEL_Y + 4)
	_log.size = Vector2(VIEW_SIZE.x - LOG_X - 6, VIEW_SIZE.y - PANEL_Y - 8)
	_log.add_theme_font_override("normal_font", UiStyle.mono())
	_log.add_theme_font_size_override("normal_font_size", UiStyle.MONO_SMALL - 1)
	_log.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_child(_log)


func _build_overlays() -> void:
	_floaters = Node2D.new()
	_content.add_child(_floaters)
	var settings: LabelSettings = LabelSettings.new()
	settings.font = UiStyle.pixel()
	settings.font_size = 26
	settings.font_color = UiStyle.BONE
	settings.outline_size = 5
	settings.outline_color = Color.BLACK
	_impact = Label.new()
	_impact.label_settings = settings
	_impact.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_impact.position = Vector2(0, 120)
	_impact.size = Vector2(VIEW_SIZE.x, 36)
	_impact.pivot_offset = Vector2(VIEW_SIZE.x / 2.0, 18)
	_impact.modulate.a = 0.0
	_impact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_impact)
	_flash = ColorRect.new()
	_flash.size = VIEW_SIZE
	_flash.color = Color(0, 0, 0, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_noise_material = ShaderMaterial.new()
	_noise_material.shader = NOISE_SHADER
	_noise_material.set_shader_parameter(&"amount", 0.06)
	_noise_material.set_shader_parameter(&"streaks", 0.4)
	var noise: ColorRect = ColorRect.new()
	noise.material = _noise_material
	noise.size = VIEW_SIZE
	noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(noise)


func _start_music() -> void:
	if music_name == "" or debug.has("screenshot"):
		return
	_music = MusicPlayer.new()
	add_child(_music)
	_music.play_any(PackedStringArray([music_name]), -6.0, 2.5)


func _set_menu_title(text: String) -> void:
	_menu_title.text = text


func _clear_menu() -> void:
	for child: Node in _menu.get_children():
		_menu.remove_child(child)
		child.queue_free()


func _add_button(text: String, callback: Callable, enabled: bool = true) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.disabled = not enabled
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(MENU_W, 14)
	button.clip_text = true
	button.pressed.connect(func() -> void:
		_sound("ui_accept", -10.0)
		callback.call())
	button.focus_entered.connect(func() -> void: _sound("ui_move", -16.0))
	_menu.add_child(button)
	return button


func _focus_first() -> void:
	for child: Node in _menu.get_children():
		var button: Button = child as Button
		if button != null and not button.disabled:
			button.grab_focus.call_deferred()
			return


## Sonido con su provisional si aún no está el definitivo (ver SOUND_FALLBACK).
func _sound(sound: String, volume_db: float) -> void:
	if sound == "":
		return
	var name: String = sound
	if not ResourceLoader.exists(Sfx.DIR + sound + ".wav") and SOUND_FALLBACK.has(sound):
		name = SOUND_FALLBACK[sound]
	if not ResourceLoader.exists(Sfx.DIR + name + ".wav"):
		return
	Sfx.ui(self, name, volume_db)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


# --- depuración ------------------------------------------------------------------------------------

func _parse_debug_args() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--"):
			var pair: PackedStringArray = argument.substr(2).split("=", true, 1)
			debug[pair[0]] = pair[1] if pair.size() > 1 else ""


func _read_debug() -> void:
	if debug.has("autoplay"):
		_autoplay_rounds = debug["autoplay"].to_int()
	if debug.has("screenshot"):
		_screenshot_path = debug["screenshot"]


func _apply_debug_state() -> void:
	if debug.has("battle-maim") and not battle.enemies.is_empty():
		for id: String in debug["battle-maim"].split(","):
			var enemy: Combatant = battle.enemies[0]
			if enemy.parts.has(StringName(id)):
				enemy.parts[StringName(id)].amputate()
	if debug.has("battle-wound"):
		for pair: String in debug["battle-wound"].split(","):
			var bits: PackedStringArray = pair.split(":")
			if bits.size() == 2:
				var wounds: Dictionary = {bits[0]: bits[1].to_int()}
				CombatBridge.apply_wounds(battle.protagonist(), wounds)


## Depuración: un golpe que amputa `part_id` al enemigo, con todo su efecto (para capturas).
func _debug_strike(part_id: StringName) -> void:
	var enemy: Combatant = battle.enemies[0]
	if not enemy.parts.has(part_id):
		return
	enemy.parts[part_id].integrity = 0
	enemy.parts[part_id].state = CombatTypes.PartState.BROKEN
	battle._amputate(enemy, enemy.parts[part_id])
	enemy.body = maxi(1, enemy.body - 14)
	_play_strike({"attacker": battle.protagonist(), "target": enemy, "part_id": part_id, "hit": true, "chance": 70,
		"part_damage": 14, "body_damage": 14, "critical": false, "guarded": false, "broke": false, "amputated": true,
		"damage_type": CombatTypes.DamageType.BLUNT, "mind_damage": 0, "status": &""}, true)


func _take_screenshot_and_quit() -> void:
	if debug.has("battle-strike"):
		_debug_strike(StringName(debug["battle-strike"]))
	elif debug.has("battle-pick") and _picking_enemy == null and _member_index >= 0:
		var enemy: Combatant = _present_enemies()[0]
		_show_part_menu(enemy)
		_aim_at(enemy, StringName(debug["battle-pick"]))
	await _wait(float(debug.get("battle-shot-delay", "0.6")))
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_screenshot_path)
	print("Captura guardada en ", _screenshot_path)
	get_tree().quit()
