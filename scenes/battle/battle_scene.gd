extends Control
## Prototipo jugable del combate. Solo presentación: la lógica está en Battle.
##
## Controles: ratón o teclado (flechas + Intro). F2 activa/desactiva el filtro VHS.
## Argumentos de depuración (después de "--"):
##   --autoplay=N        juega N rondas solo, atacando partes al azar
##   --screenshot=RUTA   guarda una captura al terminar el autoplay y cierra

const COLOR_BG: Color = Color("0b1026")
const COLOR_FLOOR: Color = Color("2a0a0e")
const COLOR_FLOOR_LINE: Color = Color("3a0e14")
const COLOR_PANEL: Color = Color(0.02, 0.02, 0.05, 0.94)
const COLOR_BORDER: Color = Color(0.3, 0.29, 0.33)
const COLOR_BONE: Color = Color("e8e1d3")
const COLOR_DIM: Color = Color("8a8478")
const COLOR_INTENT: Color = Color("c9a04a")
const COLOR_BODY: Color = Color("c56a5f")
const COLOR_MIND: Color = Color("8c9ad8")
const STEP_DELAY: float = 0.75
const AUTOPLAY_DELAY: float = 0.02
const IMPACT_ABERRATION: float = 2.0
const VHS_SHADER: Shader = preload("res://shaders/vhs_post.gdshader")

@export var party_defs: Array[CombatantDef] = [
	preload("res://data/party/protagonist.tres"),
	preload("res://data/party/ally_1.tres"),
	preload("res://data/party/ally_2.tres"),
]
@export var enemy_defs: Array[CombatantDef] = [
	preload("res://data/enemies/enemy_a.tres"),
	preload("res://data/enemies/enemy_b.tres"),
]
## Semilla fija para repetir un combate. -1 = aleatoria.
@export var seed_value: int = -1


class CombatantView:
	var combatant: Combatant
	var diagram: BodyDiagram
	var name_label: Label
	var body_label: Label
	var mind_label: Label
	var status_label: Label
	var intent_label: Label


var _battle: Battle
var _orders: Array[CombatAction] = []
var _member_index: int = -1
var _enemy_views: Array[CombatantView] = []
var _party_views: Array[CombatantView] = []
var _menu: VBoxContainer
var _menu_title: Label
var _log: RichTextLabel
var _round_label: Label
var _impact: Label
var _impact_tween: Tween
var _vhs: ColorRect
var _vhs_material: ShaderMaterial
var _autoplay_rounds: int = 0
var _screenshot_path: String = ""


func _ready() -> void:
	_read_debug_args()
	theme = _build_theme()
	_build_background()
	_build_enemy_area()
	_build_bottom_panel()
	_build_impact_label()
	_build_vhs_overlay()

	_battle = Battle.new(party_defs, enemy_defs, seed_value)
	_battle.logged.connect(_on_logged)
	_battle.impact.connect(_show_impact)
	_battle.finished.connect(_on_finished)
	_create_views()
	_start_round()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F2:
		_vhs.visible = not _vhs.visible


# --- Flujo de la ronda -----------------------------------------------------------

func _start_round() -> void:
	_battle.begin_round()
	_orders.clear()
	_member_index = -1
	_refresh()
	if _autoplay_rounds > 0:
		_autoplay_rounds -= 1
		_autoplay_orders()
		_resolve()
		return
	_next_member()
	if _screenshot_path != "":
		_take_screenshot_and_quit()


func _next_member() -> void:
	_member_index += 1
	while _member_index < _battle.party.size() and not _battle.party[_member_index].is_active():
		_member_index += 1
	if _member_index >= _battle.party.size():
		_resolve()
		return
	_show_main_menu()


func _resolve() -> void:
	_member_index = -1
	_set_menu_title("...")
	_clear_menu()
	_battle.start_resolution(_orders)
	_refresh()
	var delay: float = AUTOPLAY_DELAY if _autoplay_rounds > 0 or _screenshot_path != "" else STEP_DELAY
	while _battle.step():
		_refresh()
		await get_tree().create_timer(delay).timeout
	_refresh()
	if _battle.outcome == Battle.Outcome.ONGOING:
		await get_tree().create_timer(delay).timeout
		_start_round()
	elif _screenshot_path != "":
		_take_screenshot_and_quit()


func _current() -> Combatant:
	return _battle.party[_member_index]


func _add_order(type: CombatTypes.ActionType, target: Combatant = null, part_id: StringName = &"") -> void:
	var order: CombatAction = CombatAction.new()
	order.type = type
	order.actor = _current()
	order.target = target if target != null else _current()
	order.part_id = part_id
	_orders.append(order)
	_clear_highlights()
	_next_member()


func _go_back() -> void:
	var last: CombatAction = _orders.pop_back()
	_member_index = _battle.party.find(last.actor)
	_show_main_menu()


func _pending_bandages() -> int:
	var used: int = 0
	for order: CombatAction in _orders:
		if order.type == CombatTypes.ActionType.ITEM:
			used += 1
	return _battle.bandages - used


# --- Menús --------------------------------------------------------------------

func _show_main_menu() -> void:
	var member: Combatant = _current()
	_refresh()
	_set_menu_title("%s — ¿qué hace?" % member.display_name())
	_clear_menu()
	_add_button("Atacar (%s)" % member.current_weapon().display_name, _show_enemy_menu)
	_add_button("Guardia", _show_guard_menu)
	_add_button("Respirar (+%d Mente)" % (Battle.BREATHE_BASE + member.def.willpower),
			_add_order.bind(CombatTypes.ActionType.BREATHE))
	var bandages: int = _pending_bandages()
	_add_button("Vendas (%d)" % bandages, _show_bandage_menu, bandages > 0 and member.can_use_items())
	_add_button("Huir solo (%d%%)" % _battle.flee_chance_solo(member),
			_add_order.bind(CombatTypes.ActionType.FLEE_SOLO), member.can_flee())
	_add_button("Huir todos (%d%%)" % _battle.flee_chance_all(), _add_order.bind(CombatTypes.ActionType.FLEE_ALL))
	if not _orders.is_empty():
		_add_button("« Atrás", _go_back)
	_focus_first()


func _show_enemy_menu() -> void:
	_set_menu_title("¿A quién ataca?")
	_clear_menu()
	for enemy: Combatant in _battle.enemies:
		if enemy.is_present():
			_add_button(enemy.display_name(), _show_part_menu.bind(enemy))
	_add_button("« Atrás", _show_main_menu)
	_focus_first()


func _show_part_menu(enemy: Combatant) -> void:
	_set_menu_title("¿Dónde? (%s)" % enemy.display_name())
	_clear_menu()
	for id: StringName in enemy.part_order:
		var part: BodyPartState = enemy.parts[id]
		var text: String = "%s  —" % part.def.display_name.to_upper()
		if not part.is_amputated():
			text = "%s  %d%%" % [part.def.display_name.to_upper(), _battle.preview_hit_chance(_current(), enemy, id)]
		var button: Button = _add_button(text, _add_order.bind(CombatTypes.ActionType.ATTACK, enemy, id),
				not part.is_amputated())
		button.focus_entered.connect(_set_highlight.bind(enemy, id))
		button.mouse_entered.connect(_set_highlight.bind(enemy, id))
	_add_button("« Atrás", _show_enemy_menu)
	_focus_first()


func _show_guard_menu() -> void:
	var member: Combatant = _current()
	_set_menu_title("¿Qué se cubre?")
	_clear_menu()
	for id: StringName in member.part_order:
		var part: BodyPartState = member.parts[id]
		var button: Button = _add_button("Cubrir %s" % part.def.display_name.to_upper(),
				_add_order.bind(CombatTypes.ActionType.GUARD, member, id), not part.is_amputated())
		button.focus_entered.connect(_set_highlight.bind(member, id))
		button.mouse_entered.connect(_set_highlight.bind(member, id))
	_add_button("« Atrás", _show_main_menu)
	_focus_first()


func _show_bandage_menu() -> void:
	_set_menu_title("¿A quién venda?")
	_clear_menu()
	for member: Combatant in _battle.party:
		if member.is_present():
			_add_button("%s (%d/%d)" % [member.display_name(), member.body, member.def.body_max],
					_add_order.bind(CombatTypes.ActionType.ITEM, member))
	_add_button("« Atrás", _show_main_menu)
	_focus_first()


func _show_end_menu() -> void:
	_set_menu_title("FIN DEL COMBATE")
	_clear_menu()
	_add_button("Repetir combate", get_tree().reload_current_scene)
	_add_button("Salir", get_tree().quit)
	_focus_first()


func _autoplay_orders() -> void:
	for member: Combatant in _battle.party:
		if not member.is_active():
			continue
		var targets: Array[Combatant] = []
		for enemy: Combatant in _battle.enemies:
			if enemy.is_present():
				targets.append(enemy)
		if targets.is_empty():
			return
		var target: Combatant = targets[_battle.rng.randi_range(0, targets.size() - 1)]
		var order: CombatAction = CombatAction.new()
		order.type = CombatTypes.ActionType.ATTACK
		order.actor = member
		order.target = target
		order.part_id = target.part_order[_battle.rng.randi_range(0, target.part_order.size() - 1)]
		_orders.append(order)


# --- Señales de Battle --------------------------------------------------------

func _on_logged(text: String) -> void:
	if text.begins_with("—"):
		_log.append_text("[color=#c9a04a]%s[/color]\n" % text)
	else:
		_log.append_text(text + "\n")


func _on_finished(_outcome: Battle.Outcome, summary: String) -> void:
	_log.append_text("[color=#e8e1d3]%s[/color]\n" % summary)
	_refresh()
	if _screenshot_path == "":
		_show_end_menu()


func _show_impact(text: String) -> void:
	_impact.text = text
	if _impact_tween != null:
		_impact_tween.kill()
	_impact.modulate.a = 1.0
	_vhs_material.set_shader_parameter("aberration_px", IMPACT_ABERRATION)
	_impact_tween = create_tween()
	_impact_tween.tween_interval(0.5)
	_impact_tween.tween_property(_impact, "modulate:a", 0.0, 0.6)
	_impact_tween.parallel().tween_method(_set_aberration, IMPACT_ABERRATION, 1.0, 0.6)


func _set_aberration(value: float) -> void:
	_vhs_material.set_shader_parameter("aberration_px", value)


# --- Refresco de la vista ------------------------------------------------------

func _refresh() -> void:
	_round_label.text = "RONDA %d   VENDAS %d" % [_battle.round_number, _battle.bandages]
	for view: CombatantView in _enemy_views:
		var enemy: Combatant = view.combatant
		view.body_label.text = "CUERPO %d/%d" % [enemy.body, enemy.def.body_max]
		view.status_label.text = enemy.status_text()
		view.intent_label.text = _battle.intent_text(enemy)
		view.diagram.queue_redraw()
	for index: int in _party_views.size():
		var view: CombatantView = _party_views[index]
		var member: Combatant = view.combatant
		var prefix: String = "▸ " if index == _member_index else ""
		view.name_label.text = prefix + member.display_name()
		view.name_label.modulate = COLOR_INTENT if index == _member_index else COLOR_BONE
		view.body_label.text = "CUERPO %d" % member.body
		view.mind_label.text = "MENTE %d" % member.mind if member.def.has_mind else ""
		view.status_label.text = member.status_text()
		view.diagram.queue_redraw()


func _set_highlight(owner: Combatant, part_id: StringName) -> void:
	_clear_highlights()
	for view: CombatantView in _enemy_views + _party_views:
		if view.combatant == owner:
			view.diagram.highlight_part = part_id
			view.diagram.queue_redraw()


func _clear_highlights() -> void:
	for view: CombatantView in _enemy_views + _party_views:
		view.diagram.highlight_part = &""
		view.diagram.queue_redraw()


# --- Construcción de la interfaz ---------------------------------------------

func _create_views() -> void:
	for enemy: Combatant in _battle.enemies:
		var view: CombatantView = _make_view(enemy, Vector2(84, 104), true)
		_enemy_views.append(view)
	for member: Combatant in _battle.party:
		var view: CombatantView = _make_view(member, Vector2(36, 44), false)
		_party_views.append(view)


func _make_view(combatant: Combatant, diagram_size: Vector2, is_enemy: bool) -> CombatantView:
	var view: CombatantView = CombatantView.new()
	view.combatant = combatant
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.custom_minimum_size = Vector2(160 if is_enemy else 88, 0)
	view.name_label = _make_label(combatant.display_name(), COLOR_BONE)
	box.add_child(view.name_label)
	if is_enemy:
		view.intent_label = _make_label("", COLOR_INTENT)
		view.intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		view.intent_label.custom_minimum_size = Vector2(160, 26)
		view.intent_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		box.add_child(view.intent_label)
	view.diagram = BodyDiagram.new()
	view.diagram.combatant = combatant
	view.diagram.custom_minimum_size = diagram_size
	view.diagram.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(view.diagram)
	view.body_label = _make_label("", COLOR_BODY)
	box.add_child(view.body_label)
	if not is_enemy:
		view.mind_label = _make_label("", COLOR_MIND)
		box.add_child(view.mind_label)
	view.status_label = _make_label("", COLOR_DIM)
	view.status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(view.status_label)
	var container: Container = get_node("Enemies") if is_enemy else get_node("Bottom/Party")
	container.add_child(box)
	return view


func _build_theme() -> Theme:
	var built: Theme = Theme.new()
	built.default_font_size = 10
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.07, 0.11)
	normal.border_color = COLOR_BORDER
	normal.set_border_width_all(1)
	normal.set_content_margin_all(1)
	normal.content_margin_left = 5
	var hover: StyleBoxFlat = normal.duplicate()
	hover.border_color = COLOR_INTENT
	var focus: StyleBoxFlat = hover.duplicate()
	focus.draw_center = false
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.04, 0.04, 0.06)
	built.set_stylebox("normal", "Button", normal)
	built.set_stylebox("hover", "Button", hover)
	built.set_stylebox("pressed", "Button", hover)
	built.set_stylebox("focus", "Button", focus)
	built.set_stylebox("disabled", "Button", disabled)
	built.set_color("font_color", "Button", COLOR_BONE)
	built.set_color("font_hover_color", "Button", COLOR_INTENT)
	built.set_color("font_focus_color", "Button", COLOR_INTENT)
	built.set_color("font_pressed_color", "Button", COLOR_INTENT)
	built.set_color("font_disabled_color", "Button", Color(0.38, 0.37, 0.4))
	built.set_color("font_color", "Label", COLOR_BONE)
	built.set_color("default_color", "RichTextLabel", COLOR_DIM)
	return built


func _build_background() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = COLOR_BG
	background.size = Vector2(640, 360)
	add_child(background)
	var floor_rect: ColorRect = ColorRect.new()
	floor_rect.color = COLOR_FLOOR
	floor_rect.position = Vector2(0, 118)
	floor_rect.size = Vector2(640, 82)
	add_child(floor_rect)
	for index: int in 9:
		var line: ColorRect = ColorRect.new()
		line.color = COLOR_FLOOR_LINE
		line.position = Vector2(0, 118 + index * 10)
		line.size = Vector2(640, 1)
		add_child(line)
	_round_label = _make_label("", COLOR_DIM)
	_round_label.position = Vector2(8, 4)
	add_child(_round_label)


func _build_enemy_area() -> void:
	var enemies: HBoxContainer = HBoxContainer.new()
	enemies.name = "Enemies"
	enemies.position = Vector2(0, 14)
	enemies.size = Vector2(640, 184)
	enemies.alignment = BoxContainer.ALIGNMENT_CENTER
	enemies.add_theme_constant_override("separation", 48)
	add_child(enemies)


func _build_bottom_panel() -> void:
	var bottom: Control = Control.new()
	bottom.name = "Bottom"
	bottom.position = Vector2(0, 200)
	bottom.size = Vector2(640, 160)
	add_child(bottom)
	var panel: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.border_width_top = 1
	panel.add_theme_stylebox_override("panel", style)
	panel.size = bottom.size
	bottom.add_child(panel)

	_menu_title = _make_label("", COLOR_INTENT)
	_menu_title.position = Vector2(8, 3)
	_menu_title.size = Vector2(160, 14)
	_menu_title.clip_text = true
	bottom.add_child(_menu_title)
	_menu = VBoxContainer.new()
	_menu.position = Vector2(8, 18)
	_menu.size = Vector2(150, 138)
	_menu.add_theme_constant_override("separation", 1)
	bottom.add_child(_menu)

	var party: HBoxContainer = HBoxContainer.new()
	party.name = "Party"
	party.position = Vector2(168, 4)
	party.size = Vector2(272, 152)
	party.add_theme_constant_override("separation", 4)
	bottom.add_child(party)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.position = Vector2(444, 4)
	_log.size = Vector2(190, 152)
	_log.add_theme_font_size_override("normal_font_size", 8)
	bottom.add_child(_log)


func _build_impact_label() -> void:
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = 24
	settings.font_color = COLOR_BONE
	settings.outline_size = 4
	settings.outline_color = Color.BLACK
	_impact = Label.new()
	_impact.label_settings = settings
	_impact.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_impact.position = Vector2(0, 150)
	_impact.size = Vector2(640, 32)
	_impact.modulate.a = 0.0
	_impact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_impact)


func _build_vhs_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_vhs_material = ShaderMaterial.new()
	_vhs_material.shader = VHS_SHADER
	_vhs = ColorRect.new()
	_vhs.material = _vhs_material
	_vhs.size = Vector2(640, 360)
	_vhs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_vhs)


func _make_label(text: String, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


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
	button.custom_minimum_size = Vector2(150, 0)
	button.clip_text = true
	button.pressed.connect(callback)
	_menu.add_child(button)
	return button


func _focus_first() -> void:
	for child: Node in _menu.get_children():
		var button: Button = child as Button
		if button != null and not button.disabled:
			button.grab_focus.call_deferred()
			return


# --- Depuración --------------------------------------------------------------------

func _read_debug_args() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--autoplay="):
			_autoplay_rounds = argument.get_slice("=", 1).to_int()
		elif argument.begins_with("--screenshot="):
			_screenshot_path = argument.get_slice("=", 1)


func _take_screenshot_and_quit() -> void:
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_screenshot_path)
	print("Captura guardada en ", _screenshot_path)
	get_tree().quit()
