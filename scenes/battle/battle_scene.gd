class_name BattleScene
extends Control
## Pantalla de combate. De *Fear & Hunger* se conserva solo la disposición: fondo negro con un foco
## cenital, el enemigo grande en el centro sobre la luz y el grupo **de espaldas** en primer plano.
## Todo lo demás es del hospital de 1987: cajas de chapa oxidada con remaches, fichas de papel
## clínico a máquina, cinta adhesiva, sellos de caucho y una lámina anatómica para apuntar.
##
## - Abajo a la izquierda, el **menú de órdenes** (`BattleOption` en un `BattleFrame`): categorías con
##   icono; al pasar por una, la **ficha de detalle** (`PaperCard`) cuenta qué hace, su coste, por
##   qué no se puede y la vista previa.
## - **Apuntar** es el acto central: el enemigo se oscurece salvo la parte señalada (contorno que
##   late), la **lámina** (`BodyDiagram`) a la izquierda y la **ficha de la parte** a la derecha
##   (estado, acierto, daño, qué se consigue y los riesgos). Se elige con flechas, con el ratón sobre
##   el enemigo o sobre la lámina; al confirmar cae el sello «AUTORIZADO».
## - Abajo a la derecha, una **ficha de paciente** (`PatientCard`) por miembro (hasta 4).
## - Arriba: la **nota de observación** (`IntentNote`) con lo que prepara el enemigo, la tira de
##   **turno** (`TurnStrip`) y la carpeta del **registro** (`BattleLog`). Al resolver, la placa de
##   mensajes (`MessageWindow`), números flotantes, sangre, iconos de estado y sellos de impacto.
##
## Solo presentación: las reglas están en `Battle`; las opciones llegan por `ActionMenuModel`
## (contrato de la API de opciones, docs/tech/interfaz-combate.md).
##
## Se puede abrir sola (prototipo: paciente 09 con el tubo contra el enfermero) o desde el mapa con
## `setup()` (lo hace EncounterDirector). Al terminar emite `battle_closed`.
##
## Controles: ratón, teclado o mando. Flechas + Intro; Esc (o clic derecho) vuelve atrás; Tab o
## Select abre el registro; Intro pasa los mensajes.
## Argumentos de depuración (después de "--"):
##   --autoplay=N          juega N rondas solo, atacando partes al azar
##   --screenshot=RUTA     guarda una captura (al terminar el autoplay, o al elegir órdenes) y cierra
##   --battle-menu=CAT     abre esa categoría (attack, skill, guard, item, other) para la captura
##   --battle-focus=N      señala la opción N del menú (enseña su ficha de detalle)
##   --battle-choose=ID    elige esa opción del menú abierto (p. ej. item:venda) para la captura
##   --battle-pick=PARTE   apunta a PARTE (lámina y ficha de la parte)
##   --battle-maim=P,P     empieza con esas partes del enemigo amputadas
##   --battle-hurt=P:E     empieza con una parte del enemigo en un estado (1 Herida, 2 Rota)
##   --battle-wound=P:E    empieza con una parte propia en un estado (1 Herida, 2 Rota, 3 Amputada)
##   --battle-wounds       abre la hoja de lesiones del protagonista
##   --battle-items        (sola) lleva vendas, torniquete, analgésicos y sedante
##   --battle-bleed=P:N    (sola) el protagonista sangra N por la parte P
##   --battle-status=ID    el protagonista empieza con ese estado (derribado, aturdido, aterrado…)
##   --battle-log          abre el registro para la captura
##   --battle-confirm      confirma la parte apuntada (sello «AUTORIZADO») justo antes de la captura
##   --battle-seed=N       semilla fija
##   --battle-strike=PARTE para la captura: el protagonista arranca esa parte al enemigo
##   --battle-say=TEXTO    para la captura: enseña ese mensaje arriba («_» = espacio)
##   --battle-shot-delay=S segundos hasta la captura (0,6 por defecto)

signal battle_closed(outcome: Battle.Outcome)

enum Phase { MAIN, SUBMENU, AIM, RESOLVE, END }

const VIEW_SIZE: Vector2 = Vector2(640, 360)
## Pies del enemigo: en el centro del foco.
const ENEMY_FEET: Vector2 = Vector2(320, 250)
## Foco: elipse de luz en el suelo (centro y radios).
const LIGHT_CENTER: Vector2 = Vector2(320, 255)
const LIGHT_RADII: Vector2 = Vector2(200, 40)
## Pies del grupo, en primer plano y al borde de la luz.
const PARTY_FEET_Y: float = 310.0
const PARTY_SOLO_X: float = 238.0
const PARTY_SPACING: float = 128.0
## Cajas de abajo.
const BOX_Y: float = 254.0
const BOX_H: float = 102.0
const BOX_MARGIN: float = 6.0
const BOX_GAP: float = 8.0
const MENU_W: float = 168.0
const MENU_W_MAX: float = 212.0
const OPTION_H: float = 13.0
## Placa de mensajes de arriba (al resolver).
const MESSAGE_RECT: Rect2 = Rect2(6, 4, 552, 46)
## Nota de observación (arriba a la izquierda).
const INTENT_AT: Vector2 = Vector2(8, 8)
## Ficha de detalle: ancho y esquina inferior izquierda (sale de detrás del menú).
const DETAIL_W: float = 186.0
const DETAIL_AT: Vector2 = Vector2(8, BOX_Y - 14)
## Ficha de la parte (a la derecha del enemigo) y lámina (a la izquierda).
const PART_CARD_AT: Vector2 = Vector2(444, 34)
const PART_CARD_W: float = 188.0
const DIAGRAM_AT: Vector2 = Vector2(10, 88)
## Tira de turno (encima de las fichas, a la derecha) y registro (arriba a la derecha).
const TURN_RECT: Rect2 = Rect2(250, 234, 384, 16)
const LOG_AT: Vector2 = Vector2(384, 2)
const STEP_DELAY: float = 0.25
const AUTOPLAY_DELAY: float = 0.02
const CONFIRM_DELAY: float = 0.38
const IMPACT_ABERRATION: float = 2.6
const IMPACT_AT: Vector2 = Vector2(320, 132)
## Viñeta del filtro mientras dura el combate: más suave, para que se lea la interfaz.
const BATTLE_VIGNETTE: float = 0.3
const IDLE_SOUND_EVERY: Vector2 = Vector2(4.5, 8.0)
const DEFAULT_PARTY: CombatantDef = preload("res://data/party/paciente_09.tres")
const DEFAULT_ENEMY: CombatantDef = preload("res://data/enemies/enfermero.tres")
const DEFAULT_WEAPON: WeaponDef = preload("res://data/weapons/pipe.tres")
const NOISE_SHADER: Shader = preload("res://shaders/tape_noise.gdshader")
## Objetos de la custodia con `--battle-items` (prototipo).
const DEBUG_ITEMS: Array[StringName] = [&"venda", &"torniquete", &"analgesicos", &"sedante"]
## Sonidos (nombres de Sfx). Si falta el definitivo, se usa el provisional de la derecha ("" = nada).
const SOUND_FALLBACK: Dictionary[String, String] = {
	"combat_pipe_flesh": "metal_bang", "combat_pipe_bone": "metal_bang", "combat_bone_break": "metal_bang",
	"combat_amputation": "cloth_tear", "combat_scalpel_slash": "cloth_tear", "combat_saw": "cloth_tear",
	"combat_syringe": "glass", "combat_swing_miss": "cloth_rustle", "enfermero_breath": "entity_breath",
	"enfermero_growl": "entity_breath", "enfermero_scream": "entity_whisper", "enfermero_death": "heavy_drag",
	"enfermero_drag_steps": "heavy_drag", "combat_transition": "pa_static",
	"ui_battle_move": "ui_move", "ui_battle_confirm": "ui_accept", "ui_battle_back": "ui_back",
	"ui_battle_denied": "ui_back", "ui_stamp": "ui_accept", "ui_paper_slide": "paper", "ui_folder": "paper",
	"ui_aim_part": "ui_move", "ui_typewriter": "",
}
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
## Imagen del lugar donde ocurre. No se dibuja (el fondo es negro); se conserva para `setup()`.
var background_texture: Texture2D
## Música del combate (nombre de pista). Opcional.
var music_name: String = ""
## Filtro de imagen del mapa (desde EncounterDirector). Si falta, el combate crea el suyo.
var vhs: VhsOverlay
var debug: Dictionary[String, String] = {}

var _embedded: bool = false
var _phase: Phase = Phase.MAIN
var _model: ActionMenuModel
var _orders: Array[CombatAction] = []
var _member_index: int = -1
var _events: Array[Dictionary] = []
## Lo que se está eligiendo: la opción, el objetivo y la parte.
var _aim_option: ActionOption
var _aim_target: TargetOption
var _aim_part: StringName = &""
var _busy: bool = false
var _content: Control
var _stage: Node2D
var _enemy_views: Array[EnemyView] = []
var _enemy_marks: Array[EnemyMarks] = []
var _battlers: Array[PartyBattler] = []
var _blood: BloodFx
var _messages: MessageWindow
var _command_box: BattleFrame
var _menu_scroll: ScrollContainer
var _menu: VBoxContainer
## Al resolver, la caja de órdenes imprime las últimas líneas del registro (teletipo).
var _report: Label
var _cards: Array[PatientCard] = []
var _wounds: WoundsPanel
var _detail: PaperCard
var _part_card: PaperCard
var _diagram: BodyDiagram
var _intent: IntentNote
var _turns: TurnStrip
var _log: BattleLog
var _floaters: Node2D
var _flash: ColorRect
var _vhs: VhsOverlay
var _vignette_before: float = -1.0
var _aberration_before: float = 0.0
var _noise_material: ShaderMaterial
var _music: MusicPlayer
var _shake_tween: Tween
var _theme: Theme
var _bleed_seen: Dictionary[Combatant, int] = {}
var _autoplay_rounds: int = 0
var _screenshot_path: String = ""
var _idle_timer: float = 5.0
var _closing: bool = false
var _cursor_set: bool = false


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
	_model = ActionMenuModel.new(battle, character)
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
	_build_papers()
	_build_messages()
	_build_overlays()
	battle.logged.connect(_on_logged)
	battle.impact.connect(_show_impact)
	battle.finished.connect(_on_finished)
	battle.action_started.connect(func(action: CombatAction) -> void: _events.append({"type": &"action", "action": action}))
	battle.struck.connect(func(info: Dictionary) -> void: _events.append({"type": &"struck", "info": info}))
	battle.intent_changed.connect(func(_enemy: Combatant) -> void: _update_intent())
	battle.turn_order_changed.connect(_on_turn_order_changed)
	battle.status_changed.connect(func(_who: Combatant) -> void: _refresh_marks())
	_vhs = vhs
	if _vhs == null and not _embedded:
		_vhs = VhsOverlay.new()
		add_child(_vhs)
	if _vhs != null:
		_vignette_before = float(_vhs.get_param(&"vignette_strength", 0.85))
		_aberration_before = float(_vhs.get_param(&"aberration_px", 0.0))
		_vhs.set_param(&"vignette_strength", BATTLE_VIGNETTE)
	_set_cursor(true)
	_start_music()
	for member: Combatant in battle.party:
		_bleed_seen[member] = member.bleeding
	for enemy: Combatant in battle.enemies:
		_bleed_seen[enemy] = enemy.bleeding
		if enemy.def.intro_text != "":
			_messages.push(enemy.def.intro_text, COLOR_ENEMY_LINE)
			_log.add(enemy.def.intro_text, BattleSkin.INK_SOFT)
	_start_round()


func _exit_tree() -> void:
	_set_cursor(false)
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
	# Durante las órdenes la placa de mensajes solo se ve mientras cuenta algo (la presentación).
	if _phase != Phase.RESOLVE and _phase != Phase.END and _messages.is_idle() and _messages.visible:
		_messages.clear()


## El registro abierto se queda las flechas (antes que el menú).
func _input(event: InputEvent) -> void:
	if _log == null or not _log.is_open:
		return
	if event.is_action_pressed(&"ui_up"):
		_log.scroll_by(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_down"):
		_log.scroll_by(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") or _is_log_key(event):
		_toggle_log()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _is_log_key(event):
		_toggle_log()
		get_viewport().set_input_as_handled()
		return
	var right_click: InputEventMouseButton = event as InputEventMouseButton
	var back: bool = event.is_action_pressed(&"ui_cancel") or (right_click != null and right_click.pressed
			and right_click.button_index == MOUSE_BUTTON_RIGHT)
	if not back or _member_index < 0 or _busy:
		return
	get_viewport().set_input_as_handled()
	if _wounds.visible and _wounds.pinned:
		_wounds.close()
	elif _phase == Phase.AIM or _phase == Phase.SUBMENU:
		_sound("ui_battle_back", -10.0)
		_show_main_menu()
	elif not _orders.is_empty():
		_sound("ui_battle_back", -10.0)
		_go_back()


# --- acceso (pruebas y depuración) -----------------------------------------------------------------

## Placa de mensajes de arriba.
func message_window() -> MessageWindow:
	return _messages


## Caja de órdenes (abajo a la izquierda).
func command_box() -> BattleFrame:
	return _command_box


## Fichas de paciente, una por miembro.
func party_cards() -> Array[PatientCard]:
	return _cards


## Figuras del grupo de espaldas.
func party_battlers() -> Array[PartyBattler]:
	return _battlers


## Hoja de lesiones propia.
func wounds_panel() -> WoundsPanel:
	return _wounds


## Ficha de detalle de la orden señalada.
func detail_card() -> PaperCard:
	return _detail


## Ficha de la parte apuntada.
func part_card() -> PaperCard:
	return _part_card


## Lámina anatómica para apuntar.
func body_diagram() -> BodyDiagram:
	return _diagram


## Nota de observación (lo que prepara el enemigo).
func intent_note() -> IntentNote:
	return _intent


func turn_strip() -> TurnStrip:
	return _turns


func battle_log() -> BattleLog:
	return _log


func enemy_views() -> Array[EnemyView]:
	return _enemy_views


func phase() -> Phase:
	return _phase


## Botones que hay ahora en el menú de órdenes.
func menu_buttons() -> Array[BattleOption]:
	var result: Array[BattleOption] = []
	for child: Node in _menu.get_children():
		var option: BattleOption = child as BattleOption
		if option != null and not option.is_queued_for_deletion():
			result.append(option)
	return result


## Textos de las opciones que hay ahora en el menú.
func menu_options() -> PackedStringArray:
	var result: PackedStringArray = []
	for option: BattleOption in menu_buttons():
		result.append(option.text + ("  " + option.suffix if option.suffix != "" else ""))
	return result


## Parte apuntada ahora (o &"").
func aimed_part() -> StringName:
	return _aim_part if _phase == Phase.AIM else &""


## Abre el menú de una categoría (&"attack" apunta directamente).
func open_category(category: StringName) -> void:
	_open_category(category)


## Apunta a una parte del objetivo actual (como si se señalara con las flechas).
func aim_at_part(part_id: StringName) -> void:
	var button: BattleOption = _button_for_part(part_id)
	if button != null:
		button.grab_focus()
	_aim_at_part(part_id)


## Confirma la parte apuntada (como Intro).
func confirm_aim() -> void:
	if _phase == Phase.AIM and _aim_part != &"":
		_confirm(_aim_option, _aim_target.combatant if _aim_target != null else null, _aim_part)


# --- flujo de la ronda -----------------------------------------------------------------------

func _start_round() -> void:
	battle.begin_round()
	_orders.clear()
	_model.clear_reservations()
	_member_index = -1
	_phase = Phase.MAIN
	_refresh()
	_telegraph()
	if _autoplay_rounds > 0:
		_autoplay_rounds -= 1
		_autoplay_orders()
		_resolve()
		return
	_next_member()
	# Depuración (capturas desde el mapa): apunta a una parte.
	if _embedded and debug.has("battle-pick") and battle.round_number == 1 and _member_index >= 0:
		_open_category(ActionMenuModel.ATTACK)
		aim_at_part(StringName(debug["battle-pick"]))
	if _screenshot_path != "" and _autoplay_rounds == 0:
		_take_screenshot_and_quit()


## Aviso del enemigo: anima la preparación, suena, escribe la nota y señala la parte amenazada en
## la ficha del paciente.
func _telegraph() -> void:
	for card: PatientCard in _cards:
		card.threat_part = &""
	for index: int in battle.enemies.size():
		var enemy: Combatant = battle.enemies[index]
		var intent: CombatAction = battle.intents.get(enemy)
		if intent == null or not enemy.is_active():
			continue
		_enemy_views[index].play(&"windup")
		if intent.attack != null and intent.attack.sound_windup != "":
			_sound(intent.attack.sound_windup, -6.0)
	_update_intent()


## La nota del enemigo y la parte amenazada en las fichas (al empezar la ronda y cada vez que una
## intención cambia: `Battle.intent_changed`).
func _update_intent() -> void:
	if _intent == null or battle.outcome != Battle.Outcome.ONGOING:
		return
	for card: PatientCard in _cards:
		card.threat_part = &""
	for enemy: Combatant in battle.enemies:
		var intent: CombatAction = battle.intents.get(enemy)
		if intent == null or not enemy.is_active():
			continue
		var threat: StringName = _threat_part(intent)
		var target_index: int = battle.party.find(intent.target)
		if threat != &"" and target_index >= 0 and target_index < _cards.size():
			_cards[target_index].threat_part = threat
	if _phase == Phase.RESOLVE:
		return
	_intent.write(_intent_lines())
	_intent.position = INTENT_AT


## Orden de la cola de resolución (`Battle.turn_order_changed`): la tira enseña lo que queda.
func _on_turn_order_changed() -> void:
	if _phase != Phase.RESOLVE:
		return
	var order: Array[Combatant] = []
	for action: CombatAction in battle.turn_order():
		if not order.has(action.actor):
			order.append(action.actor)
	_turns.set_order(battle.round_number, order, _turns.active, false)


func _refresh_marks() -> void:
	for card: PatientCard in _cards:
		card.refresh()
	for battler: PartyBattler in _battlers:
		battler.queue_redraw()


## Parte que se ve amenazada por una intención (o &"" si no se sabe).
func _threat_part(intent: CombatAction) -> StringName:
	if not battle.party_can_read_intents() or intent.attack == null or intent.target == null:
		return &""
	if intent.attack.visibility != CombatTypes.Visibility.FULL or intent.target.is_enemy:
		return &""
	return intent.part_id if intent.target.has_part(intent.part_id) else &""


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
	_phase = Phase.RESOLVE
	_aim_option = null
	_aim_target = null
	_busy = false
	_wounds.close()
	_close_papers()
	_intent.close()
	_clear_menu()
	_command_box.tab = "INFORME"
	_set_menu_width(MENU_W)
	_update_report()
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


## Espera a que la placa de mensajes haya contado todo (en rápido no espera).
func _wait_messages(fast: bool) -> void:
	if fast:
		return
	while is_inside_tree() and not _messages.is_idle():
		await get_tree().process_frame


func _current() -> Combatant:
	return battle.party[_member_index]


## Confirma una opción: sello «AUTORIZADO», la orden queda guardada y pasa al siguiente miembro.
func _confirm(option: ActionOption, target: Combatant, part_id: StringName) -> void:
	if _busy or option == null or _member_index < 0:
		return
	if not option.enabled:
		_deny(option.disabled_reason)
		return
	var order: CombatAction = _model.make_order(_current(), option, target, part_id)
	_model.reserve(order)
	_orders.append(order)
	_busy = true
	_sound("ui_battle_confirm", -10.0)
	var paper: PaperCard = _part_card if _part_card.visible else _detail
	var at: Vector2 = paper.position + paper.size * Vector2(0.55, 0.55) if paper.visible \
			else _command_box.position + Vector2(_command_box.size.x * 0.5, 30)
	var fx: StampFx = _stamp(BattleSkin.stamp("autorizado"), at, "AUTORIZADO", 0.18, 1.3)
	fx.landed.connect(func() -> void: _sound("ui_stamp", -6.0))
	await _wait(CONFIRM_DELAY)
	if not is_inside_tree():
		return
	_busy = false
	_clear_aim()
	_next_member()


## Una opción que no se puede: suena, tiembla la ficha y se sella «DENEGADO».
func _deny(reason: String) -> void:
	_sound("ui_battle_denied", -8.0)
	if _detail.visible:
		_detail.stamp_texture = BattleSkin.stamp("denegado")
		_detail.queue_redraw()
		var home: Vector2 = _detail.position
		var tween: Tween = create_tween()
		for i: int in 4:
			tween.tween_property(_detail, "position", home + Vector2(2.0 if i % 2 == 0 else -2.0, 0), 0.03)
		tween.tween_property(_detail, "position", home, 0.03)
	if reason != "" and not _detail.visible:
		_messages.push(reason, UiStyle.ASH)


func _go_back() -> void:
	var last: CombatAction = _orders.pop_back()
	_model.release(last)
	_member_index = battle.party.find(last.actor)
	_show_main_menu()


# --- menús ---------------------------------------------------------------------------------------

func _show_main_menu() -> void:
	var member: Combatant = _current()
	_phase = Phase.MAIN
	_update_report()
	_clear_aim()
	_close_papers()
	_refresh()
	_clear_menu()
	_command_box.tab = "ÓRDENES · %s" % member.display_name().to_upper()
	_set_menu_width(MENU_W)
	var options: Array[ActionOption] = _model.action_menu(member)
	var others: Array[ActionOption] = ActionMenuModel.of_category(options, ActionMenuModel.OTHER)
	# Levantarse / Recobrarse va lo primero: es lo único que se puede hacer.
	for option: ActionOption in others:
		if option.action_type == CombatTypes.ActionType.RECOVER:
			_add_direct(member, option)
	for category: StringName in [ActionMenuModel.ATTACK, ActionMenuModel.SKILL, ActionMenuModel.GUARD, ActionMenuModel.ITEM]:
		var group: Array[ActionOption] = ActionMenuModel.of_category(options, category)
		if group.is_empty() and category != ActionMenuModel.ITEM:
			continue
		var enabled: bool = false
		var amount: int = 0
		for option: ActionOption in group:
			enabled = enabled or option.enabled
			amount += maxi(1, option.quantity) if category == ActionMenuModel.ITEM else 0
		var icon: Texture2D = _model.icon_for(member, group[0]) if category == ActionMenuModel.ATTACK \
				else BattleSkin.order_icon(ActionMenuModel.CATEGORY_ICONS[category])
		var suffix: String = "×%d" % amount if amount > 0 else ""
		if category == ActionMenuModel.SKILL:
			suffix = str(group.size())
		var button: BattleOption = _add_option(ActionMenuModel.CATEGORY_LABELS[category], _open_category.bind(category),
			enabled, suffix, icon)
		button.category = category
	for option: ActionOption in others:
		if option.action_type != CombatTypes.ActionType.RECOVER:
			_add_direct(member, option)
	if not _orders.is_empty():
		_add_option("Atrás", _go_back, true, "", BattleSkin.order_icon(&"back"))
	_focus_first()


## Opción suelta del menú principal (Zafarse, Huir, Levantarse…).
func _add_direct(member: Combatant, option: ActionOption) -> void:
	var button: BattleOption = _add_option(option.label, _choose.bind(option), option.enabled, option.value_text,
		_model.icon_for(member, option))
	button.option = option


## Abre una categoría: si solo hay una forma de atacar o de cubrirse, va directa a apuntar; si no,
## a un submenú con iconos, cantidad o coste y su ficha.
func _open_category(category: StringName) -> void:
	var member: Combatant = _current()
	var group: Array[ActionOption] = ActionMenuModel.of_category(_model.action_menu(member), category)
	if group.size() == 1 and group[0].needs_part and group[0].enabled:
		_begin_aim(group[0])
		return
	_phase = Phase.SUBMENU
	_close_papers()
	_clear_menu()
	_command_box.tab = ActionMenuModel.CATEGORY_LABELS[category].to_upper()
	for option: ActionOption in group:
		var button: BattleOption = _add_option(option.label, _choose.bind(option), option.enabled,
			option.value_text if option.enabled else _short_reason(option.disabled_reason), _model.icon_for(member, option))
		button.option = option
	if group.is_empty():
		var empty: BattleOption = _add_option("Nada que sirva", Callable(), false)
		empty.option = null
	_add_option("Atrás", _show_main_menu, true, "", BattleSkin.order_icon(&"back"))
	_fit_menu_width()
	_focus_first()


## Dato corto a la derecha de una opción apagada («2 r.» si está en recarga).
static func _short_reason(reason: String) -> String:
	if reason.begins_with("Aún no"):
		return "%d r." % reason.get_slice("(", 1).to_int()
	return ""


func _choose(option: ActionOption) -> void:
	if not option.enabled:
		_deny(option.disabled_reason)
	elif option.needs_part:
		_begin_aim(option)
	elif option.needs_target:
		_begin_target(option)
	else:
		_confirm(option, null, &"")


## Opción con objetivo pero sin parte (analgésicos, sedante…): si solo hay uno, directo.
func _begin_target(option: ActionOption) -> void:
	var targets: Array[TargetOption] = _model.targets_for(_current(), option)
	if targets.size() == 1:
		if targets[0].enabled:
			_confirm(option, targets[0].combatant, &"")
		else:
			_deny(targets[0].disabled_reason)
		return
	_show_target_menu(option, targets)


## A quién (varios miembros, o varios enemigos).
func _show_target_menu(option: ActionOption, targets: Array[TargetOption]) -> void:
	_phase = Phase.SUBMENU
	_clear_menu()
	_command_box.tab = "¿A QUIÉN?"
	for target: TargetOption in targets:
		var callback: Callable = _aim.bind(option, target) if option.needs_part else _confirm.bind(option, target.combatant, &"")
		var button: BattleOption = _add_option(target.combatant.display_name(), callback, target.enabled,
			"" if target.enabled else "—")
		button.option = option
	_add_option("Atrás", _show_main_menu, true, "", BattleSkin.order_icon(&"back"))
	_fit_menu_width()
	_focus_first()


func _begin_aim(option: ActionOption) -> void:
	var targets: Array[TargetOption] = _model.targets_for(_current(), option)
	if targets.is_empty():
		_deny("No hay a quién.")
		return
	if targets.size() > 1:
		_show_target_menu(option, targets)
		return
	if not targets[0].enabled:
		_deny(targets[0].disabled_reason)
		return
	_aim(option, targets[0])


## Apuntar: la lista de partes (con acierto, estado o sangrado), la lámina, la ficha de la parte y
## el foco sobre el enemigo. Sirve también para cubrirse y para tratar una parte propia.
func _aim(option: ActionOption, target: TargetOption) -> void:
	_phase = Phase.AIM
	_aim_option = option
	_aim_target = target
	_close_papers()
	_clear_menu()
	var own: bool = not target.combatant.is_enemy
	_command_box.tab = _aim_tab(option)
	var first: BattleOption = null
	var wanted: StringName = StringName(debug.get("battle-pick", ""))
	for part: PartOption in target.parts:
		var suffix: String
		var icon: Texture2D = BattleSkin.status_icon(BattleFrame.part_icon(part.state as CombatTypes.PartState))
		if part.bleeding > 0:
			icon = BattleSkin.status_icon(BattleFrame.ICON_BLEED)
		if not part.enabled:
			suffix = "—"
		elif own:
			if part.bleeding > 0:
				suffix = "sangra ×%d" % part.bleeding
			else:
				suffix = "" if part.state == CombatTypes.PartState.HEALTHY else CombatTypes.PART_STATE_NAMES[part.state]
		else:
			suffix = "%d%%" % part.hit_chance
		var button: BattleOption = _add_option(part.label, _confirm.bind(option, target.combatant, part.id),
			part.enabled, suffix, icon)
		button.part_id = part.id
		button.option = option
		button.focus_entered.connect(_aim_at_part.bind(part.id))
		if part.enabled and (first == null or part.id == wanted):
			first = button
	_add_option("Atrás", _show_main_menu, true, "", BattleSkin.order_icon(&"back"))
	_fit_menu_width()
	var threat: StringName = &""
	if own:
		for enemy: Combatant in battle.enemies:
			var intent: CombatAction = battle.intents.get(enemy)
			if intent != null and intent.target == target.combatant:
				threat = _threat_part(intent)
	_diagram.position = DIAGRAM_AT
	_diagram.show_chance = not own
	_diagram.show_parts("LÁMINA · %s" % target.combatant.display_name().to_upper(), target.parts,
		first.part_id if first != null else &"", threat)
	_sound("ui_paper_slide", -14.0)
	if first != null:
		_aim_at_part(first.part_id)
		_grab_focus_later(first)


func _aim_tab(option: ActionOption) -> String:
	match option.category:
		ActionMenuModel.GUARD:
			return "CUBRIR"
		ActionMenuModel.ITEM:
			return "TRATAR"
	return "APUNTAR"


## Señala una parte: foco en el enemigo, lámina y ficha de la parte.
func _aim_at_part(part_id: StringName) -> void:
	if _aim_target == null:
		return
	var part: PartOption = _part_option(part_id)
	if part == null:
		return
	if _aim_part != part_id:
		_sound("ui_aim_part", -18.0)
	_aim_part = part_id
	_diagram.selected = part_id
	var target: Combatant = _aim_target.combatant
	for index: int in _enemy_views.size():
		_enemy_views[index].focus_part = part_id if battle.enemies[index] == target else &""
	if _member_index < 0:
		return
	var preview: ActionPreview = _model.preview(_current(), _aim_option, target, part_id)
	var tabs: Dictionary[StringName, String] = {ActionMenuModel.GUARD: "GUARDIA · CUBRIR",
		ActionMenuModel.ITEM: "TRATAMIENTO · %s" % _aim_option.label.to_upper()}
	_part_card.tab = ("PARTE · %s" % target.display_name().to_upper()) if target.is_enemy \
			else tabs.get(_aim_option.category, "PARTE")
	_part_card.anchor_point = PART_CARD_AT
	_part_card.max_height = TURN_RECT.position.y - PART_CARD_AT.y - 6.0
	_part_card.stamp_texture = null
	_part_card.show_rows(_part_rows(target, part, preview), PART_CARD_W)


func _part_option(part_id: StringName) -> PartOption:
	if _aim_target == null:
		return null
	for part: PartOption in _aim_target.parts:
		if part.id == part_id:
			return part
	return null


## Filas de la ficha de la parte: nombre, estado, acierto, daño, romper, amputar, estados probables,
## lo que se consigue y los riesgos.
func _part_rows(target: Combatant, part: PartOption, preview: ActionPreview) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append({"kind": "title", "text": part.label,
		"icon": BattleSkin.status_icon(BattleFrame.ICON_BLEED) if part.bleeding > 0 else null,
		"note": "sangra ×%d" % part.bleeding if part.bleeding > 0 else ""})
	rows.append({"kind": "state", "text": CombatTypes.PART_STATE_NAMES[part.state],
		"color": BattleSkin.STATE_INK[part.state], "note": part.disabled_reason})
	if target.is_enemy and part.enabled:
		var stats: Array = [["ACIERTO", "%d %%" % preview.hit_chance, _chance_color(preview.hit_chance)]]
		if preview.damage_max > 0:
			stats.append(["DAÑO", "%d–%d" % [preview.damage_min, preview.damage_max], BattleSkin.INK])
		if preview.amputation_chance > 0:
			stats.append(["AMPUT.", "%d %%" % preview.amputation_chance, BattleSkin.INK_RED])
		elif preview.break_chance > 0:
			stats.append(["ROMPER", "%d %%" % preview.break_chance, BattleSkin.INK])
		rows.append({"kind": "stats", "items": stats})
	rows.append({"kind": "rule"})
	for line: String in _chance_lines(preview):
		rows.append({"kind": "bullet", "text": line})
	for line: String in preview.lines:
		rows.append({"kind": "bullet", "text": line})
	for line: String in preview.risk_lines:
		rows.append({"kind": "risk", "text": line})
	rows.append({"kind": "text", "text": "Intro / clic: confirmar · Esc: atrás", "color": BattleSkin.INK_SOFT})
	return rows


## Frases de las probabilidades que no caben en los números grandes (romper si ya se enseña la
## amputación, estados probables y actuar antes).
func _chance_lines(preview: ActionPreview) -> PackedStringArray:
	var result: PackedStringArray = []
	if preview.amputation_chance > 0 and preview.break_chance > 0:
		result.append("Romper: %d %%." % preview.break_chance)
	for id: Variant in preview.status_chances:
		var chance: int = int(preview.status_chances[id])
		if chance <= 0:
			continue
		var status: CombatStatusDef = CombatCatalog.status(StringName(id))
		var label: String = status.display_name if status != null else String(id).capitalize()
		result.append("%s: %d %%." % [label, chance])
	if preview.act_first_chance >= 0:
		result.append("Actuar antes que el enemigo: %d %%." % preview.act_first_chance)
	return result


## Ficha de detalle de lo que se señala en el menú.
func _show_detail(button: BattleOption) -> void:
	if _phase == Phase.AIM or _member_index < 0:
		return
	var member: Combatant = _current()
	var option: ActionOption = button.option
	if option == null and button.category != &"":
		var group: Array[ActionOption] = ActionMenuModel.of_category(_model.action_menu(member), button.category)
		if group.size() == 1:
			option = group[0]
		else:
			_detail_rows_for_group(button, group)
			return
	if option == null:
		_detail.close()
		return
	var target: Combatant = member
	if option.target_side == BattleMenu.SIDE_ENEMY:
		var enemies: Array[Combatant] = _present_enemies()
		target = enemies[0] if not enemies.is_empty() else null
	var preview: ActionPreview = _model.preview(member, option, target, &"")
	var rows: Array[Dictionary] = []
	rows.append({"kind": "title", "text": option.label, "icon": button.icon_texture,
		"note": ActionMenuModel.CATEGORY_LABELS.get(option.category, "").to_upper()})
	rows.append({"kind": "rule"})
	if option.description != "":
		rows.append({"kind": "text", "text": option.description, "max_lines": 4})
	var stats: Array = []
	if option.action_type in [CombatTypes.ActionType.BREAK_FREE, CombatTypes.ActionType.FLEE_ALL,
			CombatTypes.ActionType.FLEE_SOLO]:
		stats.append(["ÉXITO", "%d %%" % preview.hit_chance, _chance_color(preview.hit_chance)])
	if option.cost_body > 0 or option.cost_mind > 0:
		stats.append(["COSTE", _cost_text(option), BattleSkin.INK_RED])
	if option.skill != null and option.skill.cooldown > 0:
		stats.append(["RECARGA", "%d r." % option.skill.cooldown, BattleSkin.INK])
	if option.category == ActionMenuModel.ATTACK:
		var grip: WeaponGrip = member.offhand_grip() if option.use_offhand else member.grip()
		stats.append(["PODER", str(grip.weapon.power), BattleSkin.INK])
		stats.append(["PRECISIÓN", str(grip.weapon.accuracy + grip.accuracy_mod), BattleSkin.INK])
	elif option.target_side == BattleMenu.SIDE_ENEMY and target != null and option.enabled:
		stats.append(["ACIERTO*", "%d %%" % preview.hit_chance, _chance_color(preview.hit_chance)])
	if not stats.is_empty():
		rows.append({"kind": "stats", "items": stats.slice(0, 3)})
	if option.value_text != "" and option.category == ActionMenuModel.SKILL and option.cost_body == 0 \
			and option.cost_mind == 0:
		rows.append({"kind": "bullet", "text": option.value_text + "."})
	for line: String in preview.lines:
		rows.append({"kind": "bullet", "text": line})
	for line: String in preview.risk_lines:
		rows.append({"kind": "risk", "text": line})
	if not option.enabled:
		rows.append({"kind": "risk", "text": "NO DISPONIBLE: " + option.disabled_reason})
	elif option.needs_part:
		rows.append({"kind": "text", "text": "Intro: elegir la parte." if option.target_side == BattleMenu.SIDE_ENEMY
			else "Intro: elegir dónde.", "color": BattleSkin.INK_SOFT})
	elif option.target_side == BattleMenu.SIDE_ENEMY and target != null:
		rows.append({"kind": "text", "text": "* contra el torso.", "color": BattleSkin.INK_SOFT})
	_detail.stamp_texture = BattleSkin.stamp("denegado") if not option.enabled else null
	_open_detail(rows)


func _detail_rows_for_group(button: BattleOption, group: Array[ActionOption]) -> void:
	var rows: Array[Dictionary] = []
	rows.append({"kind": "title", "text": button.text, "icon": button.icon_texture,
		"note": "%d" % group.size() if not group.is_empty() else ""})
	rows.append({"kind": "rule"})
	if group.is_empty():
		rows.append({"kind": "text", "text": "No lleva nada que sirva en un combate."})
	for option: ActionOption in group.slice(0, 8):
		var extra: String = (" " + option.value_text) if option.value_text != "" and option.enabled else ""
		if not option.enabled:
			extra = " (%s)" % option.disabled_reason.to_lower()
		rows.append({"kind": "risk" if not option.enabled else "bullet", "text": option.label + extra})
	if not button.disabled and not group.is_empty():
		rows.append({"kind": "text", "text": "Intro: abrir.", "color": BattleSkin.INK_SOFT})
	else:
		var reason: String = group[0].disabled_reason if not group.is_empty() else "Nada que usar."
		rows.append({"kind": "risk", "text": "NO DISPONIBLE: " + reason})
	_detail.stamp_texture = null
	_open_detail(rows)


func _open_detail(rows: Array[Dictionary]) -> void:
	var appearing: bool = not _detail.visible
	_detail.grow_up = true
	_detail.anchor_point = DETAIL_AT
	_detail.tab = "FICHA"
	_detail.max_height = DETAIL_AT.y - 86.0
	_detail.show_rows(rows, DETAIL_W)
	if appearing:
		_sound("ui_paper_slide", -16.0)


func _show_end_menu() -> void:
	_phase = Phase.END
	_clear_menu()
	_report.visible = false
	_command_box.tab = "FIN"
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


func _clear_aim() -> void:
	for view: EnemyView in _enemy_views:
		view.focus_part = &""
		view.highlight_part = &""
	_aim_part = &""
	if _diagram != null:
		_diagram.close()
	if _part_card != null:
		_part_card.close()
	if _wounds != null and not _wounds.pinned:
		_wounds.close()


func _close_papers() -> void:
	_clear_aim()
	if _detail != null:
		_detail.close()


static func _cost_text(option: ActionOption) -> String:
	var bits: PackedStringArray = []
	if option.cost_body > 0:
		bits.append("−%d C" % option.cost_body)
	if option.cost_mind > 0:
		bits.append("−%d M" % option.cost_mind)
	return " ".join(bits)


static func _chance_color(chance: int) -> Color:
	if chance >= 70:
		return Color("3c5a3a")
	if chance >= 45:
		return BattleSkin.INK
	return BattleSkin.INK_RED


# --- ratón sobre el escenario ------------------------------------------------------------------

## Ratón sobre el escenario: al apuntar a un enemigo, la parte bajo el puntero (por los píxeles de
## su capa) se señala; clic para confirmar.
func _on_stage_input(event: InputEvent) -> void:
	if _phase != Phase.AIM or _aim_target == null or not _aim_target.combatant.is_enemy or _busy:
		return
	var mouse: InputEventMouse = event as InputEventMouse
	if mouse == null:
		return
	var index: int = battle.enemies.find(_aim_target.combatant)
	if index < 0:
		return
	var view: EnemyView = _enemy_views[index]
	var point: Vector2 = mouse.position + _stage_input_rect().position - view.position
	var allowed: Array[StringName] = []
	for part: PartOption in _aim_target.parts:
		if part.enabled:
			allowed.append(part.id)
	var best: StringName = view.part_at(point, allowed)
	if best == &"":
		return
	if best != _aim_part:
		aim_at_part(best)
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_confirm(_aim_option, _aim_target.combatant, best)


func _stage_input_rect() -> Rect2:
	return Rect2(Vector2(150, 50), Vector2(290, BOX_Y - 60))


func _button_for_part(part_id: StringName) -> BattleOption:
	for button: BattleOption in menu_buttons():
		if button.part_id == part_id:
			return button
	return null


func _on_diagram_hovered(part_id: StringName) -> void:
	if _phase == Phase.AIM and not _busy:
		aim_at_part(part_id)


func _on_diagram_pressed(part_id: StringName) -> void:
	if _phase == Phase.AIM and not _busy and _aim_target != null:
		aim_at_part(part_id)
		_confirm(_aim_option, _aim_target.combatant, part_id)


# --- heridas propias -------------------------------------------------------------------------------

func _on_card_details(card: PatientCard, show: bool, pinned: bool) -> void:
	if show:
		var keep: bool = _wounds.pinned
		_wounds.show_for(card.combatant, Vector2(card.position.x, card.position.y - 12.0), card.threat_part)
		_wounds.pinned = keep
		if pinned:
			_wounds.pinned = not keep or _wounds.combatant != card.combatant
	elif not _wounds.pinned:
		_wounds.close()


# --- registro -----------------------------------------------------------------------------------

func _is_log_key(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_TAB:
		return true
	var pad: InputEventJoypadButton = event as InputEventJoypadButton
	return pad != null and pad.pressed and pad.button_index == JOY_BUTTON_BACK


func _toggle_log() -> void:
	_log.toggle()


# --- reproducción de lo que pasa ---------------------------------------------------------------------

func _play_events(fast: bool) -> void:
	while not _events.is_empty():
		var event: Dictionary = _events.pop_front()
		if event["type"] == &"action":
			await _play_action(event["action"], fast)
		else:
			await _play_strike(event["info"], fast)


func _play_action(action: CombatAction, fast: bool) -> void:
	_turns.set_order(battle.round_number, _turns.order, action.actor, false)
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
			_pop_status(point, info, target)
			_shake(6.0 if info["amputated"] else (3.5 if heavy else 2.0))
			if target.dead:
				await _enemy_death(target, view)
	else:
		var index: int = battle.party.find(target)
		var battler: PartyBattler = _battlers[index] if index >= 0 and index < _battlers.size() else null
		var card: PatientCard = _cards[index] if index >= 0 and index < _cards.size() else null
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
			if card != null:
				card.hurt(1.0 if info["amputated"] or info["broke"] else clampf(0.4 + amount * 0.04, 0.4, 1.0))
			if amount > 0:
				_blood.burst(anchor, 40 if info["amputated"] else 6 + mini(amount, 20), Vector2.UP,
						220.0 if info["amputated"] else 150.0)
				_float_text(anchor + Vector2(0, -12), "−%d" % amount, UiStyle.BLOOD.lightened(0.3))
			if int(info["mind_damage"]) > 0:
				_float_text(anchor + Vector2(40, -12), "−%d Mente" % int(info["mind_damage"]), BattleFrame.LABEL_BLUE)
			_pop_status(anchor + Vector2(-26, -20), info, target)
			_red_flash(0.55 if info["amputated"] else 0.3)
			_shake(9.0 if info["amputated"] else 4.0 + amount * 0.15)
	_refresh()
	if not fast:
		await _wait(0.32)


## Icono del estado que aparece con el golpe (amputada, rota, el estado aplicado o el sangrado),
## que sube y se desvanece.
func _pop_status(point: Vector2, info: Dictionary, target: Combatant) -> void:
	var kinds: Array[StringName] = []
	if info["amputated"]:
		kinds.append(BattleFrame.ICON_AMPUTATED)
	elif info["broke"]:
		kinds.append(BattleFrame.ICON_BROKEN)
	if StringName(info.get("status", &"")) != &"":
		kinds.append(StringName(info["status"]))
	if target.bleeding > int(_bleed_seen.get(target, 0)):
		kinds.append(BattleFrame.ICON_BLEED)
	_bleed_seen[target] = target.bleeding
	for i: int in kinds.size():
		var tex: Texture2D = BattleSkin.status_icon(kinds[i])
		if tex == null:
			continue
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = tex
		sprite.position = point + Vector2(18 + i * 15, -6)
		sprite.scale = Vector2(0.5, 0.5)
		_floaters.add_child(sprite)
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(2, 2), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(sprite, "position:y", sprite.position.y - 18.0, 0.9).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.6).set_delay(0.45)
		tween.tween_callback(sprite.queue_free)


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


## Sello que cae en `at` (en coordenadas de la vista).
func _stamp(tex: Texture2D, at: Vector2, label: String, hold: float = 0.55, big: float = 1.0) -> StampFx:
	var fx: StampFx = StampFx.new()
	_floaters.add_child(fx)
	fx.stamp(tex, at, label, hold, big)
	return fx


# --- señales de Battle ------------------------------------------------------------------------------

func _on_logged(text: String) -> void:
	var is_enemy_line: bool = false
	for enemy: Combatant in battle.enemies:
		if text.begins_with(enemy.display_name()):
			is_enemy_line = true
	_log.add(text, BattleSkin.INK_RED if is_enemy_line else BattleSkin.INK)
	_update_report()
	# El número de ronda va al registro (como cabecera), no a la placa.
	if text.begins_with("—"):
		_messages.history.append(text)
		return
	_messages.push(text, COLOR_ENEMY_LINE if is_enemy_line else UiStyle.BONE)


func _on_finished(outcome: Battle.Outcome, summary: String) -> void:
	_messages.push(summary, COLOR_SUMMARY)
	_log.add(summary, BattleSkin.INK_SOFT)
	_refresh()
	if _music != null:
		_music.fade_out(2.0)
	if outcome != Battle.Outcome.ONGOING:
		_intent.close()


func _close_after(outcome: Battle.Outcome) -> void:
	if _closing:
		return
	_closing = true
	await _wait(1.6 if outcome == Battle.Outcome.VICTORY else 1.0)
	_clear_menu()
	battle_closed.emit(outcome)


## Rótulo de impacto como sello de caucho en el centro, con aberración del filtro.
func _show_impact(text: String) -> void:
	var key: String = BattleSkin.stamp_key(text)
	var tex: Texture2D = BattleSkin.stamp(key) if key != "" else null
	var fx: StampFx = _stamp(tex, IMPACT_AT, text.trim_suffix("."), 0.6, 1.5)
	fx.landed.connect(func() -> void:
		_sound("ui_stamp", -4.0)
		_shake(2.5))
	if _vhs != null:
		_vhs.set_param(&"aberration_px", IMPACT_ABERRATION)
		var tween: Tween = create_tween()
		tween.tween_method(func(v: float) -> void: _vhs.set_param(&"aberration_px", v),
				IMPACT_ABERRATION, _aberration_before, 0.8)


# --- refresco --------------------------------------------------------------------------------------

func _refresh() -> void:
	for index: int in battle.enemies.size():
		_enemy_views[index].sync_parts(battle.enemies[index])
	for index: int in _cards.size():
		_cards[index].selected = index == _member_index
		_cards[index].refresh()
	for battler: PartyBattler in _battlers:
		battler.queue_redraw()
	if _phase != Phase.RESOLVE:
		var active: Combatant = battle.party[_member_index] if _member_index >= 0 and _member_index < battle.party.size() else null
		_turns.set_order(battle.round_number, TurnStrip.estimate(battle), active, true)


## Lo que prepara cada enemigo, para la nota: «ENFERMERO prepara TAJO», «→ torso» y el gesto.
func _intent_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for enemy: Combatant in battle.enemies:
		var what: String = battle.intent_text(enemy)
		if what == "":
			continue
		var enemy_name: String = enemy.display_name().to_upper()
		if what == "??? → ???":
			lines.append({"text": "No se ve qué prepara %s." % enemy.display_name(), "color": BattleSkin.INK_SOFT})
			continue
		# Con un solo personaje sobra «de PACIENTE 09».
		if battle.party.size() == 1:
			what = what.replace(" de " + battle.party[0].display_name(), "")
		var bits: PackedStringArray = what.split(" → ")
		lines.append({"text": "%s prepara %s" % [enemy_name, bits[0]], "color": BattleSkin.INK_RED, "bold": true})
		if bits.size() > 1 and bits[1] != "":
			lines.append({"text": "→ %s" % bits[1].to_lower(), "color": BattleSkin.INK})
		var telegraph: String = battle.intent_telegraph(enemy)
		if telegraph != "":
			lines.append({"text": "«%s»" % telegraph, "color": BattleSkin.INK_SOFT})
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
	if debug.has("battle-items"):
		built.bandages = 0
		for id: StringName in DEBUG_ITEMS:
			built.supplies[id] = 2 if id == &"venda" else 1
	return built


## Tema de las opciones: serifa blanco hueso; la elegida, sobre la franja granate.
func _build_theme() -> Theme:
	var built: Theme = Theme.new()
	built.default_font = UiStyle.ui()
	built.default_font_size = UiStyle.SIZE_TEXT
	var normal: StyleBoxEmpty = StyleBoxEmpty.new()
	normal.content_margin_left = BattleOption.LEFT
	normal.content_margin_right = 6
	var band: StyleBoxTexture = BattleSkin.band_box().duplicate() as StyleBoxTexture
	band.content_margin_left = BattleOption.LEFT
	band.content_margin_right = 6
	built.set_stylebox("normal", "Button", normal)
	built.set_stylebox("hover", "Button", normal)
	built.set_stylebox("pressed", "Button", band)
	built.set_stylebox("focus", "Button", band)
	built.set_stylebox("disabled", "Button", normal)
	built.set_color("font_color", "Button", UiStyle.BONE_DIM)
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
	var input: Control = Control.new()
	input.name = "StageInput"
	var rect: Rect2 = _stage_input_rect()
	input.position = rect.position
	input.size = rect.size
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
	_report = UiStyle.label("", UiStyle.MONO_SMALL, UiStyle.BONE_DIM, UiStyle.mono())
	_report.name = "Report"
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_report.clip_text = true
	_report.visible = false
	_command_box.add_child(_report)
	for index: int in battle.party.size():
		var member: Combatant = battle.party[index]
		var card: PatientCard = PatientCard.new()
		card.name = "PatientCard%d" % index
		var battler: PartyBattler = _battlers[index] if index < _battlers.size() else null
		card.setup(member, _weapon_icon(member), battler.textures if battler != null else [] as Array[Texture2D],
			battler.origin if battler != null else Vector2(24, 62))
		card.details_requested.connect(_on_card_details)
		_content.add_child(card)
		_cards.append(card)
	_set_menu_width(MENU_W)


## Coloca la caja de órdenes con el ancho pedido y las fichas de paciente en el resto.
func _set_menu_width(width: float) -> void:
	_command_box.position = Vector2(BOX_MARGIN, BOX_Y)
	_command_box.size = Vector2(width, BOX_H)
	var inset: float = BattleSkin.METAL_INSET
	_menu_scroll.position = Vector2(inset - 1, inset + 3)
	_menu_scroll.size = Vector2(width - inset * 2.0 + 2, BOX_H - inset * 2.0 - 4)
	_menu.custom_minimum_size = Vector2(_menu_scroll.size.x, 0)
	_report.position = Vector2(inset + 3, inset + 3)
	_report.size = Vector2(width - inset * 2.0 - 6, BOX_H - inset * 2.0 - 6)
	var x: float = BOX_MARGIN + width + BOX_GAP
	var count: int = maxi(1, _cards.size())
	var gap: float = 6.0
	var card_w: float = floorf((VIEW_SIZE.x - BOX_MARGIN - x - gap * (count - 1)) / count)
	for index: int in _cards.size():
		_cards[index].position = Vector2(x + index * (card_w + gap), BOX_Y + 2)
		_cards[index].size = Vector2(card_w, BOX_H - 4)
		_cards[index].queue_redraw()
	_command_box.queue_redraw()


## Ensancha la caja de órdenes si las opciones no caben (nombres de partes largos).
func _fit_menu_width() -> void:
	var font: Font = UiStyle.ui()
	var widest: float = 0.0
	for option: BattleOption in menu_buttons():
		var text_w: float = font.get_string_size(option.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.SIZE_TEXT).x
		var suffix_w: float = font.get_string_size(option.suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.SIZE_TEXT).x
		widest = maxf(widest, text_w + suffix_w + (14.0 if option.suffix != "" else 0.0))
	_set_menu_width(clampf(ceilf(widest + BattleOption.LEFT + 8.0 + BattleSkin.METAL_INSET * 2.0), MENU_W, MENU_W_MAX))


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


## Fichas de papel: detalle, parte, lámina, nota, tira de turno, lesiones y registro.
func _build_papers() -> void:
	_intent = IntentNote.new()
	_intent.name = "IntentNote"
	_intent.position = INTENT_AT
	_intent.typed.connect(func() -> void: _sound("ui_typewriter", -18.0))
	_content.add_child(_intent)
	_turns = TurnStrip.new()
	_turns.name = "TurnStrip"
	_turns.position = TURN_RECT.position
	_turns.size = TURN_RECT.size
	_content.add_child(_turns)
	_diagram = BodyDiagram.new()
	_diagram.name = "BodyDiagram"
	_diagram.position = DIAGRAM_AT
	_diagram.part_hovered.connect(_on_diagram_hovered)
	_diagram.part_pressed.connect(_on_diagram_pressed)
	_content.add_child(_diagram)
	_part_card = PaperCard.new()
	_part_card.name = "PartCard"
	_content.add_child(_part_card)
	_detail = PaperCard.new()
	_detail.name = "DetailCard"
	_content.add_child(_detail)
	_wounds = WoundsPanel.new()
	_wounds.name = "WoundsPanel"
	_content.add_child(_wounds)
	_log = BattleLog.new()
	_log.name = "BattleLog"
	_log.position = LOG_AT
	_log.toggled.connect(func(_open: bool) -> void: _sound("ui_folder", -12.0))
	_content.add_child(_log)


func _build_messages() -> void:
	_messages = MessageWindow.new()
	_messages.name = "MessageWindow"
	_messages.position = MESSAGE_RECT.position
	_messages.size = MESSAGE_RECT.size
	if debug.has("autoplay"):
		_messages.line_seconds = 0.0
		_messages.per_char = 0.0
	_content.add_child(_messages)
	# El registro, por encima de la placa.
	_content.move_child(_log, -1)


func _build_overlays() -> void:
	_floaters = Node2D.new()
	_content.add_child(_floaters)
	_flash = ColorRect.new()
	_flash.size = VIEW_SIZE
	_flash.color = Color(0, 0, 0, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_noise_material = ShaderMaterial.new()
	_noise_material.shader = NOISE_SHADER
	_noise_material.set_shader_parameter(&"amount", 0.0)  # el grano ya lo pone el filtro de imagen
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


## Puntero propio (plumilla) mientras dura el combate.
func _set_cursor(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if on:
		var tex: Texture2D = BattleSkin.texture("cursor")
		if tex != null:
			Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(1, 1))
			_cursor_set = true
	elif _cursor_set:
		Input.set_custom_mouse_cursor(null)
		_cursor_set = false


## Últimas líneas del registro en la caja de órdenes (solo al resolver y al terminar).
func _update_report() -> void:
	_report.visible = _phase == Phase.RESOLVE or _phase == Phase.END
	if not _report.visible:
		return
	var lines: PackedStringArray = _log.lines()
	var tail: PackedStringArray = []
	var used: int = 0
	var fit: int = int(_report.size.y / 10.0)
	for i: int in range(lines.size() - 1, -1, -1):
		if lines[i].begins_with("—"):
			continue
		var count: int = BattleSkin.wrap_text(UiStyle.mono(), "· " + lines[i], _report.size.x - 4.0, UiStyle.MONO_SMALL).size()
		if used + count > fit:
			break
		used += count
		tail.insert(0, "· " + lines[i])
	_report.text = "\n".join(tail)


func _clear_menu() -> void:
	for child: Node in _menu.get_children():
		_menu.remove_child(child)
		child.queue_free()


func _add_option(text: String, callback: Callable, enabled: bool = true, suffix: String = "",
		icon: Texture2D = null) -> BattleOption:
	var option: BattleOption = BattleOption.new()
	option.text = text
	option.suffix = suffix
	option.icon_texture = icon
	option.disabled = not enabled
	option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	option.custom_minimum_size = Vector2(0, OPTION_H)
	option.clip_text = true
	option.focus_mode = Control.FOCUS_ALL
	option.pressed.connect(func() -> void:
		if _busy:
			return
		if callback.is_valid():
			callback.call())
	option.focus_entered.connect(func() -> void:
		_sound("ui_battle_move", -16.0)
		_show_detail(option))
	option.mouse_entered.connect(func() -> void:
		if not option.has_focus() and not _busy:
			option.grab_focus())
	# Una opción desactivada también se puede señalar (su ficha dice por qué) y, si se pulsa, se niega.
	option.gui_input.connect(func(event: InputEvent) -> void:
		if not option.disabled:
			return
		var click: InputEventMouseButton = event as InputEventMouseButton
		if event.is_action_pressed(&"ui_accept") or (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
			option.accept_event()
			_deny(option.option.disabled_reason if option.option != null else ""))
	_menu.add_child(option)
	return option


func _focus_first() -> void:
	for button: BattleOption in menu_buttons():
		if not button.disabled:
			_grab_focus_later(button)
			return
	var all: Array[BattleOption] = menu_buttons()
	if not all.is_empty():
		_grab_focus_later(all[0])


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
	if name == "" or not ResourceLoader.exists(Sfx.DIR + name + ".wav"):
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
	if debug.has("battle-bleed"):
		for pair: String in debug["battle-bleed"].split(","):
			var bits: PackedStringArray = pair.split(":")
			if bits.size() == 2:
				battle.protagonist().add_bleed(StringName(bits[0]), bits[1].to_int())
	if debug.has("battle-status"):
		for id: String in debug["battle-status"].split(","):
			var status: CombatStatusDef = CombatCatalog.status(StringName(id))
			if status != null:
				battle.protagonist().add_status(status)
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
	_phase = Phase.RESOLVE
	_close_papers()
	_intent.close()
	_clear_menu()
	_command_box.tab = "INFORME"
	_update_report()
	enemy.parts[part_id].integrity = 0
	enemy.parts[part_id].state = CombatTypes.PartState.BROKEN
	battle._amputate(enemy, enemy.parts[part_id])
	enemy.body = maxi(1, enemy.body - 14)
	_play_strike({"attacker": battle.protagonist(), "target": enemy, "part_id": part_id, "hit": true, "chance": 70,
		"part_damage": 14, "body_damage": 14, "critical": false, "guarded": false, "broke": false, "amputated": true,
		"damage_type": CombatTypes.DamageType.BLUNT, "mind_damage": 0, "status": &""}, true)


func _take_screenshot_and_quit() -> void:
	if _member_index >= 0 and _phase != Phase.RESOLVE:
		if debug.has("battle-menu"):
			_open_category(StringName(debug["battle-menu"]))
			await get_tree().process_frame
		elif debug.has("battle-pick") and _phase != Phase.AIM:
			_open_category(ActionMenuModel.ATTACK)
			await get_tree().process_frame
		if debug.has("battle-choose"):
			for button: BattleOption in menu_buttons():
				if button.option != null and String(button.option.id) == debug["battle-choose"]:
					_choose(button.option)
					break
			await get_tree().process_frame
		if debug.has("battle-pick") and _phase == Phase.AIM:
			aim_at_part(StringName(debug["battle-pick"]))
		if debug.has("battle-focus"):
			await get_tree().process_frame
			var buttons: Array[BattleOption] = menu_buttons()
			var index: int = clampi(debug["battle-focus"].to_int(), 0, buttons.size() - 1)
			if not buttons.is_empty():
				buttons[index].grab_focus()
	if debug.has("battle-confirm"):
		confirm_aim()
	if debug.has("battle-strike"):
		_debug_strike(StringName(debug["battle-strike"]))
	if debug.has("battle-wounds") and not _cards.is_empty():
		_on_card_details(_cards[0], true, true)
	if debug.has("battle-log"):
		_log.set_open(true)
	if debug.has("battle-say"):
		_messages.clear()
		_messages.push(debug["battle-say"].replace("_", " "), COLOR_ENEMY_LINE)
	await _wait(float(debug.get("battle-shot-delay", "0.6")))
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_screenshot_path)
	print("Captura guardada en ", _screenshot_path)
	get_tree().quit()
