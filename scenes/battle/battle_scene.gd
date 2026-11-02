class_name BattleScene
extends Control
## Combate por rondas con mutilaciones, a la manera de *Fear & Hunger*: fondo negro con un foco de
## luz cenital sobre el suelo; el enemigo, grande, de pie en la luz; el grupo **de espaldas** en
## primer plano; abajo, dos cajas (órdenes a la izquierda y una fila por miembro con Cuerpo y Mente
## a la derecha) y arriba una ventana de mensajes de 1-2 líneas. Solo presentación: las reglas
## están en `Battle`.
##
## Se puede abrir sola (prototipo: paciente 09 con el tubo contra el enfermero) o desde el mapa con
## `setup()` (lo hace EncounterDirector). Al terminar emite `battle_closed`.
##
## Controles: ratón o teclado (flechas + Intro; Esc vuelve atrás; Intro pasa los mensajes).
## Argumentos de depuración (después de "--"):
##   --autoplay=N          juega N rondas solo, atacando partes al azar
##   --screenshot=RUTA     guarda una captura (al terminar el autoplay, o al elegir órdenes) y cierra
##   --battle-pick=PARTE   abre la selección de parte apuntando a PARTE (para capturas)
##   --battle-maim=P,P     empieza con esas partes del enemigo amputadas (para capturas)
##   --battle-hurt=P:E     empieza con una parte del enemigo en un estado (1 Herida, 2 Rota)
##   --battle-wound=P:E    empieza con una parte propia en un estado (1 Herida, 2 Rota, 3 Amputada)
##   --battle-wounds       abre la ventanita de heridas del protagonista (para capturas)
##   --battle-seed=N       semilla fija
##   --battle-strike=PARTE para la captura: el protagonista arranca esa parte al enemigo
##   --battle-say=TEXTO    para la captura: enseña ese mensaje arriba («_» = espacio)
##   --battle-shot-delay=S segundos hasta la captura (0,6 por defecto)

signal battle_closed(outcome: Battle.Outcome)

const VIEW_SIZE: Vector2 = Vector2(640, 360)
## Pies del enemigo: en el centro del foco.
const ENEMY_FEET: Vector2 = Vector2(320, 250)
## Foco: elipse de luz en el suelo (centro y radios).
const LIGHT_CENTER: Vector2 = Vector2(320, 255)
const LIGHT_RADII: Vector2 = Vector2(200, 40)
## Pies del grupo, en primer plano y al borde de la luz.
const PARTY_FEET_Y: float = 306.0
const PARTY_SOLO_X: float = 226.0
const PARTY_SPACING: float = 128.0
## Cajas de abajo.
const BOX_Y: float = 255.0
const BOX_H: float = 100.0
const BOX_MARGIN: float = 6.0
const BOX_GAP: float = 4.0
const BOX_PAD: float = 5.0
const MENU_W: float = 118.0
const MENU_W_MAX: float = 212.0
const OPTION_H: float = 15.0
## Ventana de mensajes de arriba.
const MESSAGE_RECT: Rect2 = Rect2(6, 5, 628, 42)
const STEP_DELAY: float = 0.25
const AUTOPLAY_DELAY: float = 0.02
const IMPACT_ABERRATION: float = 2.6
## Viñeta del filtro mientras dura el combate: más suave, para que las cajas de abajo se lean.
const BATTLE_VIGNETTE: float = 0.3
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
## Colores de la ventana de mensajes.
const COLOR_ENEMY_LINE: Color = Color("d9c9b4")
const COLOR_SUMMARY: Color = Color("e8e1d3")

## Solo si se abre sola (sin setup()).
@export var party_defs: Array[CombatantDef] = [DEFAULT_PARTY]
@export var enemy_defs: Array[CombatantDef] = [DEFAULT_ENEMY]
## Semilla fija para repetir un combate. -1 = aleatoria.
@export var seed_value: int = -1

var battle: Battle
## Personaje del mapa (objetos de la custodia, arma y ropa). Opcional.
var character: CharacterState
## Imagen del lugar donde ocurre. Ya no se dibuja (el fondo es negro, como en la referencia); se
## conserva para no romper `setup()`.
var background_texture: Texture2D
## Música del combate (nombre de pista). Opcional.
var music_name: String = ""
## Filtro de imagen del mapa (desde EncounterDirector). Si falta, el combate crea el suyo.
var vhs: VhsOverlay
var debug: Dictionary[String, String] = {}

var _embedded: bool = false
var _orders: Array[CombatAction] = []
var _member_index: int = -1
var _events: Array[Dictionary] = []
var _content: Control
var _stage: Node2D
var _enemy_views: Array[EnemyView] = []
var _enemy_marks: Array[EnemyMarks] = []
var _battlers: Array[PartyBattler] = []
var _blood: BloodFx
var _reticle: PartReticle
var _messages: MessageWindow
var _command_box: BattleFrame
var _party_box: BattleFrame
var _rows: Array[PartyRow] = []
var _wounds: WoundsPanel
var _menu_scroll: ScrollContainer
var _menu: VBoxContainer
var _impact: Label
var _impact_tween: Tween
var _floaters: Node2D
var _flash: ColorRect
var _vhs: VhsOverlay
var _vignette_before: float = -1.0
var _aberration_before: float = 0.0
var _noise_material: ShaderMaterial
var _music: MusicPlayer
var _shake_tween: Tween
var _theme: Theme
var _picking_enemy: Combatant
var _autoplay_rounds: int = 0
var _screenshot_path: String = ""
var _idle_timer: float = 5.0
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
	_build_party()
	_build_boxes()
	_build_messages()
	_build_overlays()
	battle.logged.connect(_on_logged)
	battle.impact.connect(_show_impact)
	battle.finished.connect(_on_finished)
	battle.action_started.connect(func(action: CombatAction) -> void: _events.append({"type": &"action", "action": action}))
	battle.struck.connect(func(info: Dictionary) -> void: _events.append({"type": &"struck", "info": info}))
	_vhs = vhs
	if _vhs == null and not _embedded:
		_vhs = VhsOverlay.new()
		add_child(_vhs)
	if _vhs != null:
		_vignette_before = float(_vhs.get_param(&"vignette_strength", 0.85))
		_aberration_before = float(_vhs.get_param(&"aberration_px", 0.0))
		_vhs.set_param(&"vignette_strength", BATTLE_VIGNETTE)
	_start_music()
	for enemy: Combatant in battle.enemies:
		if enemy.def.intro_text != "":
			_messages.push(enemy.def.intro_text, COLOR_ENEMY_LINE)
	_start_round()


func _exit_tree() -> void:
	if _vhs != null and is_instance_valid(_vhs) and _vignette_before >= 0.0:
		_vhs.set_param(&"vignette_strength", _vignette_before)
		_vhs.set_param(&"aberration_px", _aberration_before)


func _process(delta: float) -> void:
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_idle_timer = randf_range(IDLE_SOUND_EVERY.x, IDLE_SOUND_EVERY.y)
		for enemy: Combatant in battle.enemies:
			if enemy.is_active() and enemy.def.sound_idle != "":
				_sound(enemy.def.sound_idle, -14.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _member_index >= 0:
		get_viewport().set_input_as_handled()
		if _wounds.visible and _wounds.pinned:
			_wounds.close()
		elif _submenu:
			_show_main_menu()
		elif not _orders.is_empty():
			_go_back()


# --- acceso (pruebas y depuración) -----------------------------------------------------------------

## Ventana de mensajes de arriba.
func message_window() -> MessageWindow:
	return _messages


## Caja de órdenes (abajo a la izquierda).
func command_box() -> BattleFrame:
	return _command_box


## Caja del grupo (abajo a la derecha).
func party_box() -> BattleFrame:
	return _party_box


## Filas del grupo, una por miembro.
func party_rows() -> Array[PartyRow]:
	return _rows


## Figuras del grupo de espaldas.
func party_battlers() -> Array[PartyBattler]:
	return _battlers


## Ventanita de heridas propias.
func wounds_panel() -> WoundsPanel:
	return _wounds


## Textos de las opciones que hay ahora en la caja de órdenes.
func menu_options() -> PackedStringArray:
	var result: PackedStringArray = []
	for child: Node in _menu.get_children():
		var option: BattleOption = child as BattleOption
		if option != null and not option.is_queued_for_deletion():
			result.append(option.text + ("  " + option.suffix if option.suffix != "" else ""))
	return result


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


## Aviso del enemigo: anima la preparación del golpe, suena y lo cuenta arriba.
func _telegraph() -> void:
	for index: int in battle.enemies.size():
		var enemy: Combatant = battle.enemies[index]
		var intent: CombatAction = battle.intents.get(enemy)
		if intent == null or not enemy.is_active():
			continue
		_enemy_views[index].play(&"windup")
		if intent.attack != null and intent.attack.sound_windup != "":
			_sound(intent.attack.sound_windup, -6.0)
	_messages.set_sticky(_intent_lines())


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
	_submenu = false
	_wounds.close()
	_clear_menu()
	_set_menu_width(MENU_W)
	_messages.set_sticky([])
	_events.clear()
	battle.start_resolution(_orders)
	_refresh()
	var fast: bool = _autoplay_rounds > 0 or debug.has("autoplay")
	while battle.step():
		await _play_events(fast)
		_refresh()
		await _wait_messages(fast)
		await _wait(AUTOPLAY_DELAY if fast else STEP_DELAY)
	await _play_events(fast)
	_refresh()
	await _wait_messages(fast)
	if not is_inside_tree():
		return
	if battle.outcome == Battle.Outcome.ONGOING:
		await _wait(AUTOPLAY_DELAY if fast else STEP_DELAY)
		_start_round()
	elif _screenshot_path != "":
		_take_screenshot_and_quit()
	elif _embedded:
		_close_after(battle.outcome)
	else:
		_show_end_menu()


## Espera a que la ventana de mensajes haya contado todo (en rápido no espera).
func _wait_messages(fast: bool) -> void:
	if fast:
		return
	while is_inside_tree() and not _messages.is_idle():
		await get_tree().process_frame


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
	_messages.set_sticky(_intent_lines())
	_clear_menu()
	_set_menu_width(MENU_W)
	var targets: Array[Combatant] = _present_enemies()
	_add_option("Atacar", _show_part_menu.bind(targets[0]) if targets.size() == 1 else _show_enemy_menu,
		not targets.is_empty())
	_add_option("Habilidades", _show_skill_menu)
	_add_option("Guardia", _show_guard_menu)
	var items: int = _item_count()
	_add_option("Objeto", _show_item_menu, items > 0 and member.can_use_items(), str(items))
	if member.breakable_status() != null:
		_add_option("Zafarse", _add_order.bind(CombatTypes.ActionType.BREAK_FREE), true,
			"%d%%" % battle.break_free_chance(member))
	if battle.party.size() > 1:
		_add_option("Huir solo", _add_order.bind(CombatTypes.ActionType.FLEE_SOLO),
			battle.can_flee and member.can_flee(), "%d%%" % battle.flee_chance_solo(member))
	_add_option("Huir", _add_order.bind(CombatTypes.ActionType.FLEE_ALL), battle.can_flee and member.can_flee(),
		"%d%%" % battle.flee_chance_all())
	if not _orders.is_empty():
		_add_option("Atrás", _go_back)
	_focus_first()


func _show_enemy_menu() -> void:
	_submenu = true
	_clear_menu()
	for enemy: Combatant in _present_enemies():
		_add_option(enemy.display_name(), _show_part_menu.bind(enemy))
	_add_option("Atrás", _show_main_menu)
	_fit_menu_width()
	_focus_first()


## Al atacar, la caja de órdenes lista las partes del enemigo con su probabilidad de acierto.
func _show_part_menu(enemy: Combatant) -> void:
	_picking_enemy = enemy
	_submenu = true
	_clear_menu()
	var first: Button = null
	var wanted: StringName = StringName(debug.get("battle-pick", ""))
	for id: StringName in enemy.part_order:
		var part: BodyPartState = enemy.parts[id]
		var chance: String = "—" if part.is_amputated() else "%d%%" % battle.preview_hit_chance(_current(), enemy, id)
		var option: BattleOption = _add_option(part.def.display_name,
			_add_order.bind(CombatTypes.ActionType.ATTACK, enemy, id), not part.is_amputated(), chance)
		option.focus_entered.connect(_aim_at.bind(enemy, id))
		if not part.is_amputated() and (first == null or id == wanted):
			first = option
	_add_option("Atrás", _show_main_menu)
	_fit_menu_width()
	if first != null:
		_grab_focus_later(first)


## Habilidades: por ahora, Respirar (recupera Mente).
func _show_skill_menu() -> void:
	var member: Combatant = _current()
	_submenu = true
	_clear_menu()
	_add_option("Respirar", _add_order.bind(CombatTypes.ActionType.BREATHE), member.def.has_mind,
		"+%d Mente" % (Battle.BREATHE_BASE + member.def.willpower))
	_add_option("Atrás", _show_main_menu)
	_fit_menu_width()
	_focus_first()


func _show_guard_menu() -> void:
	var member: Combatant = _current()
	_submenu = true
	_clear_menu()
	for id: StringName in member.part_order:
		var part: BodyPartState = member.parts[id]
		var option: BattleOption = _add_option(part.def.display_name,
			_add_order.bind(CombatTypes.ActionType.GUARD, member, id), not part.is_amputated(),
			"" if part.state == CombatTypes.PartState.HEALTHY else CombatTypes.PART_STATE_NAMES[part.state])
		option.focus_entered.connect(_guard_highlight.bind(member, id))
	_add_option("Atrás", _show_main_menu)
	_fit_menu_width()
	_focus_first()


func _show_item_menu() -> void:
	_submenu = true
	_clear_menu()
	if character != null:
		var used: Array[Variant] = []
		for order: CombatAction in _orders:
			used.append(order.item)
		for stack: ItemStack in CombatBridge.combat_items(character):
			if used.has(stack):
				continue
			_add_option(stack.def.display_name, _add_order.bind(CombatTypes.ActionType.ITEM, _current(), &"", stack),
				true, "×%d" % stack.quantity if stack.quantity > 1 else "")
	else:
		for member: Combatant in battle.party:
			if member.is_present():
				_add_option("Venda a %s" % member.display_name(), _add_order.bind(CombatTypes.ActionType.ITEM, member))
	_add_option("Atrás", _show_main_menu)
	_fit_menu_width()
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
	_clear_menu()
	_add_option("Repetir", get_tree().reload_current_scene)
	_add_option("Salir", get_tree().quit)
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

## Marca la parte, discretamente, sobre el propio enemigo y cuenta arriba su acierto y daño estimado.
func _aim_at(enemy: Combatant, part_id: StringName) -> void:
	var index: int = battle.enemies.find(enemy)
	if index < 0:
		return
	var view: EnemyView = _enemy_views[index]
	view.highlight_part = part_id
	var part: BodyPartState = enemy.parts[part_id]
	_reticle.point_at(view.position + view.anchor(part_id), PackedStringArray())
	if _member_index < 0:
		return
	var first: String = part.def.display_name
	if part.is_amputated():
		_messages.set_sticky([{"text": "%s: ya no está." % first, "color": UiStyle.ASH}])
		return
	var chance: int = battle.preview_hit_chance(_current(), enemy, part_id)
	var damage: Dictionary = battle.preview_damage(_current(), enemy, part_id)
	var range_body: Vector2i = damage["body"]
	var state: String = CombatTypes.PART_STATE_NAMES[part.state]
	var line: String = "%s (%s) · acierto %d %% · daño %d–%d" % [first, state.to_lower(), chance, range_body.x,
		range_body.y]
	var lines: Array[Dictionary] = [{"text": line, "color": UiStyle.BONE}]
	var hint: String = _part_hint(enemy, part)
	if hint != "":
		lines.append({"text": hint, "color": BattleFrame.LABEL_BLUE})
	_messages.set_sticky(lines)


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
	if index >= 0 and index < _rows.size():
		_open_wounds(_rows[index], part_id)


func _clear_highlights() -> void:
	for view: EnemyView in _enemy_views:
		view.highlight_part = &""
	if _reticle != null:
		_reticle.visible = false
	if _wounds != null and not _wounds.pinned:
		_wounds.close()


## Ratón sobre el escenario: apunta a la parte más cercana; clic para golpear.
func _on_stage_input(event: InputEvent) -> void:
	if _picking_enemy == null:
		return
	var motion: InputEventMouse = event as InputEventMouse
	if motion == null:
		return
	var index: int = battle.enemies.find(_picking_enemy)
	var view: EnemyView = _enemy_views[index]
	var point: Vector2 = motion.position + Vector2(_stage_input_offset())
	var best: StringName = &""
	var best_d: float = 34.0
	for id: StringName in _picking_enemy.part_order:
		if _picking_enemy.parts[id].is_amputated():
			continue
		var d: float = (view.position + view.anchor(id)).distance_to(point)
		if d < best_d:
			best_d = d
			best = id
	if best == &"":
		return
	var option: BattleOption = _option_for_part(best)
	if option != null and not option.has_focus():
		option.grab_focus()
	else:
		_aim_at(_picking_enemy, best)
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_add_order(CombatTypes.ActionType.ATTACK, _picking_enemy, best)


func _stage_input_offset() -> Vector2i:
	return Vector2i(int(MESSAGE_RECT.position.x), int(MESSAGE_RECT.end.y))


func _option_for_part(part_id: StringName) -> BattleOption:
	if _picking_enemy == null:
		return null
	var index: int = _picking_enemy.part_order.find(part_id)
	if index < 0 or index >= _menu.get_child_count():
		return null
	return _menu.get_child(index) as BattleOption


# --- heridas propias -------------------------------------------------------------------------------

func _on_row_details(row: PartyRow, show: bool, pinned: bool) -> void:
	if show:
		_open_wounds(row, &"")
		if pinned:
			_wounds.pinned = not _wounds.pinned or _wounds.combatant != row.combatant
	elif not _wounds.pinned:
		_wounds.close()


func _open_wounds(row: PartyRow, part_id: StringName) -> void:
	var pinned: bool = _wounds.pinned
	_wounds.show_for(row.combatant, Vector2(_party_box.position.x + BOX_PAD, BOX_Y - 2.0), part_id)
	_wounds.pinned = pinned


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
			_lunge(_enemy_views[index], 1.05)
		if not fast:
			await _wait(0.22)
	elif action.type == CombatTypes.ActionType.ATTACK:
		var index: int = battle.party.find(action.actor)
		if index >= 0 and index < _battlers.size():
			_battlers[index].bump()
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
			sway.tween_property(view, "position:x", _enemy_home(index).x, 0.16)
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
		var battler: PartyBattler = _battlers[index] if index >= 0 and index < _battlers.size() else null
		var row: PartyRow = _rows[index] if index >= 0 and index < _rows.size() else null
		var anchor: Vector2 = battler.chest() if battler != null else Vector2(320, BOX_Y - 20.0)
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
			if battler != null:
				battler.hurt(1.6 if info["amputated"] else 1.0)
			if row != null:
				row.hurt(1.0)
			if amount > 0:
				_blood.burst(anchor, 40 if info["amputated"] else 6 + mini(amount, 20), Vector2.UP,
						220.0 if info["amputated"] else 150.0)
				_float_text(anchor + Vector2(0, -12), "−%d" % amount, UiStyle.BLOOD.lightened(0.3))
			if int(info["mind_damage"]) > 0:
				_float_text(anchor + Vector2(40, -12), "−%d Mente" % int(info["mind_damage"]), BattleFrame.LABEL_BLUE)
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
	# El número de ronda no se cuenta arriba (no aparece en la referencia), pero queda en el historial.
	if text.begins_with("—"):
		_messages.history.append(text)
		return
	var color: Color = UiStyle.BONE
	for enemy: Combatant in battle.enemies:
		if text.begins_with(enemy.display_name()):
			color = COLOR_ENEMY_LINE
	_messages.push(text, color)


func _on_finished(outcome: Battle.Outcome, summary: String) -> void:
	_messages.push(summary, COLOR_SUMMARY)
	_refresh()
	if _music != null:
		_music.fade_out(2.0)
	if outcome != Battle.Outcome.ONGOING:
		_messages.set_sticky([])


func _close_after(outcome: Battle.Outcome) -> void:
	if _closing:
		return
	_closing = true
	await _wait(1.6 if outcome == Battle.Outcome.VICTORY else 1.0)
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
				IMPACT_ABERRATION, _aberration_before, 0.6)


# --- refresco --------------------------------------------------------------------------------------

func _refresh() -> void:
	for index: int in battle.enemies.size():
		_enemy_views[index].sync_parts(battle.enemies[index])
	for index: int in _rows.size():
		_rows[index].selected = index == _member_index
		_rows[index].refresh()
	for battler: PartyBattler in _battlers:
		battler.queue_redraw()
	if _wounds.visible:
		_wounds.queue_redraw()


## Aviso de lo que prepara el enemigo, para la ventana de arriba: «El enfermero prepara TAJO →
## brazo der.» y, debajo, el gesto que lo delata.
func _intent_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for enemy: Combatant in battle.enemies:
		var what: String = battle.intent_text(enemy)
		if what == "":
			continue
		var enemy_name: String = enemy.display_name()
		if what == "??? → ???":
			lines.append({"text": "No ves qué prepara %s." % enemy_name, "color": COLOR_ENEMY_LINE})
			continue
		# Con un solo personaje sobra «de PACIENTE 09».
		if battle.party.size() == 1:
			what = what.replace(" de " + battle.party[0].display_name(), "")
		var bits: PackedStringArray = what.split(" → ")
		var where: String = bits[1] if bits.size() > 1 else ""
		var tail: String = (" → " + where) if where != "" else ""
		if not tail.ends_with("."):
			tail += "."
		var plain: String = "%s prepara %s%s" % [enemy_name, bits[0], tail]
		var rich: String = "%s prepara [color=#%s]%s[/color]%s" % [enemy_name, UiStyle.AMBER.to_html(false), bits[0], tail]
		lines.append({"text": plain, "bbcode": rich, "color": COLOR_ENEMY_LINE})
		var telegraph: String = battle.intent_telegraph(enemy)
		if telegraph != "" and battle.enemies.size() == 1:
			lines.append({"text": telegraph, "color": UiStyle.BONE_DIM})
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


## Tema de las opciones: texto blanco hueso; la seleccionada, con una franja clara y marco fino.
func _build_theme() -> Theme:
	var built: Theme = Theme.new()
	built.default_font = UiStyle.ui()
	built.default_font_size = UiStyle.SIZE_TEXT
	var normal: StyleBoxEmpty = StyleBoxEmpty.new()
	normal.content_margin_left = 7
	normal.content_margin_right = 6
	var band: StyleBoxFlat = StyleBoxFlat.new()
	band.bg_color = BattleFrame.BAND
	band.border_color = BattleFrame.BAND_BORDER
	band.set_border_width_all(1)
	band.content_margin_left = 7
	band.content_margin_right = 6
	built.set_stylebox("normal", "Button", normal)
	built.set_stylebox("hover", "Button", normal)
	built.set_stylebox("pressed", "Button", band)
	built.set_stylebox("focus", "Button", band)
	built.set_stylebox("disabled", "Button", normal)
	built.set_color("font_color", "Button", UiStyle.BONE)
	built.set_color("font_hover_color", "Button", UiStyle.BONE)
	built.set_color("font_focus_color", "Button", Color.WHITE)
	built.set_color("font_pressed_color", "Button", Color.WHITE)
	built.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	built.set_color("font_disabled_color", "Button", Color(UiStyle.ASH, 0.75))
	built.set_color("font_color", "Label", UiStyle.BONE)
	return built


## Fondo negro con un foco cenital: un haz tenue desde arriba y una elipse de luz en el suelo.
func _build_background() -> void:
	var base: ColorRect = ColorRect.new()
	base.color = Color("020203")
	base.size = VIEW_SIZE
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(base)
	var beam: Control = Control.new()
	beam.size = VIEW_SIZE
	beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beam.draw.connect(_draw_beam.bind(beam))
	_content.add_child(beam)
	# Elipse de luz en el suelo, que se difumina hacia fuera.
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	gradient.colors = PackedColorArray([Color(0.6, 0.59, 0.55, 0.8), Color(0.46, 0.45, 0.42, 0.58),
		Color(0.28, 0.27, 0.26, 0.2), Color(0.2, 0.2, 0.2, 0.0)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	var pool: TextureRect = TextureRect.new()
	pool.name = "Spotlight"
	pool.texture = texture
	pool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pool.stretch_mode = TextureRect.STRETCH_SCALE
	pool.position = LIGHT_CENTER - LIGHT_RADII
	pool.size = LIGHT_RADII * 2.0
	pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(pool)


## Haz de luz desde el techo hasta el suelo: más estrecho arriba, muy tenue.
func _draw_beam(canvas: Control) -> void:
	var top_half: float = 46.0
	var bottom: Vector2 = LIGHT_CENTER
	var bottom_half: float = LIGHT_RADII.x * 0.78
	var layers: int = 6
	for i: int in layers:
		var t: float = float(i) / layers
		var shrink: float = 1.0 - t * 0.75
		var points: PackedVector2Array = [Vector2(bottom.x - top_half * shrink, 0), Vector2(bottom.x + top_half * shrink, 0),
			Vector2(bottom.x + bottom_half * shrink, bottom.y), Vector2(bottom.x - bottom_half * shrink, bottom.y)]
		var colors: PackedColorArray = [Color(0.7, 0.7, 0.66, 0.012), Color(0.7, 0.7, 0.66, 0.012),
			Color(0.7, 0.7, 0.66, 0.04), Color(0.7, 0.7, 0.66, 0.04)]
		canvas.draw_polygon(points, colors)


func _enemy_home(index: int) -> Vector2:
	var count: int = battle.enemies.size()
	return ENEMY_FEET + Vector2((index - (count - 1) / 2.0) * 180.0, 0)


func _build_stage() -> void:
	_stage = Node2D.new()
	_stage.name = "Stage"
	_content.add_child(_stage)
	_blood = BloodFx.new()
	_blood.floor_y = ENEMY_FEET.y + 6.0
	_stage.add_child(_blood)
	for index: int in battle.enemies.size():
		var view: EnemyView = EnemyView.new()
		view.position = _enemy_home(index)
		view.setup(battle.enemies[index].def)
		view.sync_parts(battle.enemies[index])
		_stage.add_child(view)
		_enemy_views.append(view)
	for index: int in battle.enemies.size():
		var marks: EnemyMarks = EnemyMarks.new()
		marks.setup(_enemy_views[index], battle.enemies[index])
		_stage.add_child(marks)
		_enemy_marks.append(marks)
	_reticle = PartReticle.new()
	_reticle.font = UiStyle.mono()
	_reticle.visible = false
	_stage.add_child(_reticle)
	var input: Control = Control.new()
	input.position = Vector2(_stage_input_offset())
	input.size = Vector2(VIEW_SIZE.x - input.position.x * 2.0, BOX_Y - input.position.y)
	input.mouse_filter = Control.MOUSE_FILTER_PASS
	input.gui_input.connect(_on_stage_input)
	_content.add_child(input)


## El grupo, de espaldas, delante del enemigo y más abajo.
func _build_party() -> void:
	var count: int = battle.party.size()
	for index: int in count:
		var member: Combatant = battle.party[index]
		var battler: PartyBattler = PartyBattler.new()
		battler.name = "PartyBattler%d" % index
		var x: float = PARTY_SOLO_X if count == 1 else ENEMY_FEET.x + (index - (count - 1) / 2.0) * PARTY_SPACING
		battler.position = Vector2(x, PARTY_FEET_Y)
		battler.home = battler.position
		battler.setup(member, character if member.def.is_protagonist else null)
		_stage.add_child(battler)
		_battlers.append(battler)


func _build_boxes() -> void:
	_command_box = BattleFrame.new()
	_command_box.name = "CommandBox"
	_content.add_child(_command_box)
	_menu_scroll = ScrollContainer.new()
	_menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_menu_scroll.follow_focus = true
	_command_box.add_child(_menu_scroll)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 0)
	_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_scroll.add_child(_menu)
	_party_box = BattleFrame.new()
	_party_box.name = "PartyBox"
	_content.add_child(_party_box)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 1)
	rows.position = Vector2(BOX_PAD, BOX_PAD)
	_party_box.add_child(rows)
	for member: Combatant in battle.party:
		var row: PartyRow = PartyRow.new()
		row.setup(member, _weapon_icon(member))
		row.details_requested.connect(_on_row_details)
		rows.add_child(row)
		_rows.append(row)
	_wounds = WoundsPanel.new()
	_content.add_child(_wounds)
	_set_menu_width(MENU_W)


## Coloca las dos cajas: la de órdenes con el ancho pedido y la del grupo con el resto.
func _set_menu_width(width: float) -> void:
	_command_box.position = Vector2(BOX_MARGIN, BOX_Y)
	_command_box.size = Vector2(width, BOX_H)
	_menu_scroll.position = Vector2(BOX_PAD, BOX_PAD)
	_menu_scroll.size = Vector2(width - BOX_PAD * 2.0, BOX_H - BOX_PAD * 2.0)
	_menu.custom_minimum_size = Vector2(width - BOX_PAD * 2.0, 0)
	var party_x: float = BOX_MARGIN + width + BOX_GAP
	_party_box.position = Vector2(party_x, BOX_Y)
	_party_box.size = Vector2(VIEW_SIZE.x - BOX_MARGIN - party_x, BOX_H)
	var rows: Control = _party_box.get_node("Rows") as Control
	var rows_width: float = _party_box.size.x - BOX_PAD * 2.0
	for row: PartyRow in _rows:
		row.custom_minimum_size = Vector2(rows_width, PartyRow.HEIGHT)
		row.size.x = rows_width
		row.queue_redraw()
	rows.size = Vector2(rows_width, 0)
	rows.reset_size()
	_command_box.queue_redraw()
	_party_box.queue_redraw()


## Ensancha la caja de órdenes si las opciones no caben (nombres de partes largos).
func _fit_menu_width() -> void:
	var font: Font = UiStyle.ui()
	var widest: float = 0.0
	for child: Node in _menu.get_children():
		var option: BattleOption = child as BattleOption
		if option == null or option.is_queued_for_deletion():
			continue
		var text_w: float = font.get_string_size(option.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.SIZE_TEXT).x
		var suffix_w: float = font.get_string_size(option.suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.SIZE_TEXT).x
		widest = maxf(widest, text_w + suffix_w + (16.0 if option.suffix != "" else 0.0))
	_set_menu_width(clampf(ceilf(widest + 13.0 + BOX_PAD * 2.0), MENU_W, MENU_W_MAX))


## Icono del arma empuñada: el del objeto que lleva en la mano o, sin custodia, el del objeto que
## corresponde a esa arma.
func _weapon_icon(member: Combatant) -> Texture2D:
	if member.def.weapon == null:
		return null
	if character != null and member.def.is_protagonist:
		var held: ItemStack = character.wielded()
		if held != null and held.def.icon != null:
			return held.def.icon
	for item: ItemDef in Registry.all_items():
		if item.weapon == member.def.weapon and item.icon != null:
			return item.icon
	return null


func _build_messages() -> void:
	_messages = MessageWindow.new()
	_messages.name = "MessageWindow"
	_messages.position = MESSAGE_RECT.position
	_messages.size = MESSAGE_RECT.size
	if debug.has("autoplay"):
		_messages.line_seconds = 0.0
		_messages.per_char = 0.0
	_content.add_child(_messages)


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
	_noise_material.set_shader_parameter(&"amount", 0.008)
	_noise_material.set_shader_parameter(&"streaks", 0.0)
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


func _clear_menu() -> void:
	for child: Node in _menu.get_children():
		_menu.remove_child(child)
		child.queue_free()


func _add_option(text: String, callback: Callable, enabled: bool = true, suffix: String = "") -> BattleOption:
	var option: BattleOption = BattleOption.new()
	option.text = text
	option.suffix = suffix
	option.disabled = not enabled
	option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	option.custom_minimum_size = Vector2(0, OPTION_H)
	option.clip_text = true
	option.focus_mode = Control.FOCUS_ALL
	option.pressed.connect(func() -> void:
		_sound("ui_accept", -10.0)
		callback.call())
	option.focus_entered.connect(func() -> void: _sound("ui_move", -16.0))
	option.mouse_entered.connect(func() -> void:
		if not option.disabled and not option.has_focus():
			option.grab_focus())
	_menu.add_child(option)
	return option


func _focus_first() -> void:
	for child: Node in _menu.get_children():
		var button: Button = child as Button
		if button != null and not button.disabled:
			_grab_focus_later(button)
			return


## Da el foco al botón en el siguiente fotograma, si para entonces sigue en el menú.
func _grab_focus_later(button: Button) -> void:
	_grab_focus_by_id.call_deferred(button.get_instance_id())


func _grab_focus_by_id(id: int) -> void:
	var button: Button = instance_from_id(id) as Button
	if button != null and button.is_inside_tree():
		button.grab_focus()


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
	if battle.enemies.is_empty():
		return
	var enemy: Combatant = battle.enemies[0]
	if debug.has("battle-maim"):
		for id: String in debug["battle-maim"].split(","):
			if enemy.parts.has(StringName(id)):
				enemy.parts[StringName(id)].amputate()
	if debug.has("battle-hurt"):
		for pair: String in debug["battle-hurt"].split(","):
			var bits: PackedStringArray = pair.split(":")
			if bits.size() == 2 and enemy.parts.has(StringName(bits[0])):
				var part: BodyPartState = enemy.parts[StringName(bits[0])]
				for i: int in clampi(bits[1].to_int(), 0, 2):
					part.worsen()
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
	if debug.has("battle-wounds") and not _rows.is_empty():
		_open_wounds(_rows[0], &"")
	if debug.has("battle-say"):
		_messages.clear()
		_messages.push(debug["battle-say"].replace("_", " "), COLOR_ENEMY_LINE)
	await _wait(float(debug.get("battle-shot-delay", "0.6")))
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_screenshot_path)
	print("Captura guardada en ", _screenshot_path)
	get_tree().quit()
