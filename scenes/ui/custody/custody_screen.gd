class_name CustodyScreen
extends CanvasLayer
## Pantalla del Sistema de Custodia (al estilo de Fear & Hunger: listas, sin casillas). Pestañas:
## - OBJETOS (`ItemsPage`): inventario por categorías (Armas, Armaduras, Útiles, Medicina,
##   Objetos principales, Otros), descripción, imagen y acciones de cada objeto.
## - EQUIPO (`EquipmentPage`): el protagonista, sus ranuras (manos, cabeza, cuerpo, piernas, pies),
##   sus estadísticas y las de lo equipado.
## - FABRICAR: recetas de varios ingredientes (Fabricar) y combinaciones de dos objetos (Combinar).
## - EXPEDIENTE: documentos encontrados y lector.
## Pausa el juego mientras está abierta. Q / Mayús+Q (o LB / RB en el mando) cambian de pestaña;
## Tab o Esc cierran. Cada página explica sus teclas en la línea de ayuda.

signal closed
## Pide abrir el inspector para un objeto (lo gestiona la escena).
signal inspect_requested(stack: ItemStack)

## (Los valores se mantienen por compatibilidad: TRAY es OBJETOS y CHARACTER es EQUIPO. El orden
## de las pestañas está en TAB_ORDER.)
enum Tab { TRAY, DOSSIER, CHARACTER, CRAFT }
enum CraftMode { CRAFT, COMBINE }

const SLIDE: float = 14.0
const TAB_ORDER: Array[Tab] = [Tab.TRAY, Tab.CHARACTER, Tab.CRAFT, Tab.DOSSIER]
const TAB_NAMES: Dictionary[int, String] = {
	Tab.TRAY: "OBJETOS", Tab.CHARACTER: "EQUIPO", Tab.CRAFT: "FABRICAR", Tab.DOSSIER: "EXPEDIENTE",
}
const HINTS: Dictionary[int, String] = {
	Tab.TRAY: "←→ categoría · ↑↓ objeto · Intro acciones · E usar · F empuñar · C combinar · 1-5 atajo",
	Tab.CHARACTER: "↑↓ ranura · Intro elegir · Supr quitar · Z/V girar",
	Tab.CRAFT: "Elige una receta y pulsa Fabricar · en Combinar, elige dos objetos",
	Tab.DOSSIER: "↑↓ documento",
}
const FRAME: Rect2 = Rect2(6, 6, 628, 348)
## Panel de la derecha (receta, documento).
const PANEL: Rect2 = Rect2(238, 50, 388, 284)
const LEFT_X: float = 14.0
const TOP_Y: float = 50.0

var character: CharacterState
var _tab: Tab = Tab.TRAY
var _root: Control
var _dim: ColorRect
var _tab_buttons: Dictionary[int, Button] = {}
var _items: ItemsPage
var _equipment: EquipmentPage
var _hint: Label
# Expediente.
var _dossier_page: Control
var _doc_list: VBoxContainer
var _doc_paper: PanelContainer
var _doc_title: Label
var _doc_meta: Label
var _doc_body: RichTextLabel
var _doc_image: TextureRect
var _doc_stamp: Label
var _current_doc: StringName = &""
# Fabricar.
var _craft_page: Control
var _craft_mode: CraftMode = CraftMode.CRAFT
var _mode_buttons: Array[Button] = []
var _craft_list: VBoxContainer
var _craft_list_title: Label
var _craft_detail: Control
var _craft_image: TextureRect
var _craft_title: Label
var _craft_desc: Label
var _craft_needs: VBoxContainer
var _craft_button: Button
var _craft_feedback: Label
var _selected_recipe: RecipeDef
var _combine_slots: Array[ItemStack] = [null, null]


func _init() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_build()


func is_open() -> bool:
	return visible


## Página de objetos (para pruebas y depuración).
func items_page() -> ItemsPage:
	return _items


## Página de equipo (para pruebas y depuración).
func equipment_page() -> EquipmentPage:
	return _equipment


func current_tab() -> Tab:
	return _tab


func open(tab: Tab = Tab.TRAY, document_id: StringName = &"") -> void:
	character = GameState.character
	_items.character = character
	_equipment.character = character
	if not character.custody.changed.is_connected(_refresh):
		character.custody.changed.connect(_refresh)
	visible = true
	get_tree().paused = true
	_items.say("")
	_items.cancel()
	_set_tab(tab)
	if document_id != &"":
		_show_document(document_id)
	_root.modulate.a = 0.0
	_root.position.y = SLIDE
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_root, "modulate:a", 1.0, 0.18)
	tween.tween_property(_root, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_dim.color.a = 0.0
	tween.tween_property(_dim, "color:a", 0.8, 0.2)
	_refresh()
	_apply_debug_args()


func close() -> void:
	if not visible:
		return
	_items.cancel()
	_items.close_menu()
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_root, "modulate:a", 0.0, 0.14)
	tween.tween_property(_dim, "color:a", 0.0, 0.14)
	await tween.finished
	visible = false
	get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _tab == Tab.TRAY and _items.is_menu_open():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed(InputActions.CUSTODY):
			_items.close_menu()
			get_viewport().set_input_as_handled()
		return
	var busy: bool = (_tab == Tab.TRAY and _items.cancel_pending()) or (_tab == Tab.CHARACTER and _equipment.is_choosing())
	if event.is_action_pressed(InputActions.CUSTODY) or event.is_action_pressed(InputActions.PAUSE) \
			or (event.is_action_pressed("ui_cancel") and not busy):
		get_viewport().set_input_as_handled()
		close()
		return
	if event.is_action_pressed("ui_cancel") and _tab == Tab.TRAY:
		_items.cancel()
		get_viewport().set_input_as_handled()
		return
	var step: int = _tab_step(event)
	if step != 0:
		var i: int = TAB_ORDER.find(_tab)
		_set_tab(TAB_ORDER[posmod(i + step, TAB_ORDER.size())])
		get_viewport().set_input_as_handled()
		return
	var handled: bool = false
	match _tab:
		Tab.TRAY:
			handled = _items.handle_input(event)
		Tab.CHARACTER:
			handled = _equipment.handle_input(event)
		Tab.CRAFT:
			if event.is_action_pressed("ui_accept"):
				_do_craft()
				handled = true
		Tab.DOSSIER:
			handled = _dossier_input(event)
	if handled:
		get_viewport().set_input_as_handled()


## Q / Mayús+Q y los gatillos LB / RB cambian de pestaña. Devuelve -1, 0 o 1.
func _tab_step(event: InputEvent) -> int:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_Q:
		return -1 if key.shift_pressed else 1
	var joy: InputEventJoypadButton = event as InputEventJoypadButton
	if joy != null and joy.pressed:
		if joy.button_index == JOY_BUTTON_LEFT_SHOULDER:
			return -1
		if joy.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			return 1
	return 0


func _refresh() -> void:
	if character == null or not visible:
		return
	match _tab:
		Tab.TRAY: _items.refresh()
		Tab.CHARACTER: _equipment.refresh()
		Tab.DOSSIER: _fill_dossier()
		Tab.CRAFT: _fill_craft()


# --- pestañas ------------------------------------------------------------------------------

func _set_tab(tab: Tab) -> void:
	_tab = tab
	_items.close_menu()
	_items.visible = tab == Tab.TRAY
	_equipment.visible = tab == Tab.CHARACTER
	_dossier_page.visible = tab == Tab.DOSSIER
	_craft_page.visible = tab == Tab.CRAFT
	for t: int in _tab_buttons:
		var b: Button = _tab_buttons[t]
		b.add_theme_color_override("font_color", UiStyle.BONE if t == tab else UiStyle.ASH)
		b.add_theme_stylebox_override("normal", _tab_style(t == tab))
	_hint.text = HINTS[tab]
	match tab:
		Tab.DOSSIER:
			_fill_dossier()
			if _current_doc == &"" and not character.custody.documents.is_empty():
				_show_document(character.custody.documents[-1])
		Tab.CRAFT:
			_craft_feedback.text = ""
			_fill_craft()
		Tab.CHARACTER:
			_equipment.refresh()
		_:
			_items.refresh()


func _dossier_input(event: InputEvent) -> bool:
	var docs: Array[StringName] = character.custody.documents
	if docs.is_empty():
		return false
	var step: int = 0
	if event.is_action_pressed("ui_up"):
		step = -1
	elif event.is_action_pressed("ui_down"):
		step = 1
	if step == 0:
		return false
	var i: int = docs.find(_current_doc)
	_show_document(docs[posmod(i + step, docs.size())])
	return true


## Depuración para capturas (una vez): --custody-tab=items|equip|craft|combine|dossier,
## --custody-section=armas|armaduras|utiles|medicina|principales|otros, --custody-select=id,
## --custody-menu=id (menú contextual), --custody-wield=id, --custody-offhand=id,
## --custody-slot=mano_d|mano_i|cabeza|cuerpo|piernas|pies y --custody-pick=id (lo elige en la lista
## de la ranura).
func _apply_debug_args() -> void:
	if has_meta(&"debug_done"):
		return
	set_meta(&"debug_done", true)
	var sections: Dictionary[String, ItemDef.Section] = {
		"armas": ItemDef.Section.WEAPONS, "armaduras": ItemDef.Section.ARMOR, "utiles": ItemDef.Section.UTILITY,
		"medicina": ItemDef.Section.MEDICINE, "principales": ItemDef.Section.MAIN, "otros": ItemDef.Section.OTHER,
	}
	var slots: Dictionary[String, int] = {
		"mano_d": EquipmentPage.HAND_R, "mano_i": EquipmentPage.HAND_L, "cabeza": ItemDef.EquipSlot.HEAD,
		"cuerpo": ItemDef.EquipSlot.BODY, "piernas": ItemDef.EquipSlot.LEGS, "pies": ItemDef.EquipSlot.FEET,
	}
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if pair.size() < 2:
			continue
		match pair[0]:
			"custody-tab":
				match pair[1]:
					"items": _set_tab(Tab.TRAY)
					"craft": _set_tab(Tab.CRAFT)
					"combine":
						_set_tab(Tab.CRAFT)
						_set_craft_mode(CraftMode.COMBINE)
					"dossier": _set_tab(Tab.DOSSIER)
					"equip", "character", "hand": _set_tab(Tab.CHARACTER)
			"custody-section":
				if sections.has(pair[1]):
					_items.show_section(sections[pair[1]], false)
			"custody-select":
				_items.select_stack(character.custody.find_first(StringName(pair[1])))
			"custody-wield":
				var weapon: ItemStack = character.custody.find_first(StringName(pair[1]))
				if weapon != null:
					character.wield(weapon)
					_refresh()
			"custody-offhand":
				var other: ItemStack = character.custody.find_first(StringName(pair[1]))
				if other != null:
					character.wield_offhand(other)
					_refresh()
			"custody-slot":
				if slots.has(pair[1]):
					_equipment.select_slot(slots[pair[1]])
			"custody-pick":
				_equipment.debug_pick(character.custody.find_first(StringName(pair[1])))
			"custody-menu":
				var target: ItemStack = character.custody.find_first(StringName(pair[1]))
				if target != null and _items.select_stack(target):
					await get_tree().process_frame
					_items.open_menu(target, _items.selected_row_rect().end - Vector2(60, 4))


# --- construcción ------------------------------------------------------------------------------

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.8)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var frame: Panel = Panel.new()
	frame.position = FRAME.position
	frame.size = FRAME.size
	frame.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("101214"), Color("3a4046"), 0.97))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(frame)

	var title: Label = UiStyle.title("REGISTRO DE CUSTODIA")
	title.position = Vector2(LEFT_X + 2, 5)
	_root.add_child(title)
	var who: Label = UiStyle.label("PACIENTE 09 · HAB. 09 · PERTENENCIAS", UiStyle.MONO_SMALL, UiStyle.ASH, UiStyle.mono())
	who.position = Vector2(LEFT_X + 2, 28)
	_root.add_child(who)
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	_root.add_child(tabs)
	for t: Tab in TAB_ORDER:
		var b: Button = UiStyle.button(TAB_NAMES[t])
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_set_tab.bind(t))
		tabs.add_child(b)
		_tab_buttons[t] = b
	tabs.reset_size()
	tabs.position = Vector2(FRAME.end.x - 8 - tabs.get_combined_minimum_size().x, 12)
	var line: ColorRect = ColorRect.new()
	line.color = Color("3a4046")
	line.position = Vector2(FRAME.position.x + 6, 44)
	line.size = Vector2(FRAME.size.x - 12, 1)
	_root.add_child(line)
	_hint = UiStyle.label("", UiStyle.MONO_SMALL, UiStyle.ASH, UiStyle.mono())
	_hint.position = Vector2(LEFT_X + 2, 337)
	_hint.clip_text = true
	_hint.size = Vector2(FRAME.size.x - 200, 14)
	_root.add_child(_hint)
	var keys: Label = UiStyle.label("Q pestaña · Tab cerrar", UiStyle.MONO_SMALL, UiStyle.BONE_DIM, UiStyle.mono())
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	keys.clip_text = true
	keys.size = Vector2(176, 14)
	keys.position = Vector2(FRAME.end.x - 186, 337)
	_root.add_child(keys)

	_items = ItemsPage.new()
	_root.add_child(_items)
	_items.inspect_requested.connect(func(stack: ItemStack) -> void: inspect_requested.emit(stack))
	_equipment = EquipmentPage.new()
	_root.add_child(_equipment)
	_build_craft_page()
	_build_dossier_page()


# --- expediente ------------------------------------------------------------------------------

func _tab_style(active: bool) -> StyleBoxFlat:
	var s: StyleBoxFlat = UiStyle.steel_box(Color("1d2125") if active else UiStyle.STEEL_DARK,
		UiStyle.BONE_DIM if active else UiStyle.STEEL, 0.95)
	s.content_margin_top = 3
	s.content_margin_bottom = 4
	s.content_margin_left = 9
	s.content_margin_right = 9
	return s


# --- expediente ------------------------------------------------------------------------------

func _fill_dossier() -> void:
	for child: Node in _doc_list.get_children():
		child.queue_free()
	var custody: Custody = character.custody
	if custody.documents.is_empty():
		_doc_list.add_child(UiStyle.label("Ningún documento todavía.", UiStyle.SIZE_TEXT, UiStyle.ASH))
		return
	for id: StringName in custody.documents:
		var doc: DocumentDef = Registry.document(id)
		if doc == null:
			continue
		var b: Button = UiStyle.button(("• " if custody.is_unread(id) else "  ") + doc.title)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size = Vector2(206, 0)
		if id == _current_doc:
			b.add_theme_color_override("font_color", UiStyle.BONE)
			b.add_theme_stylebox_override("normal", _tab_style(true))
		b.pressed.connect(_show_document.bind(id))
		_doc_list.add_child(b)


func _show_document(id: StringName) -> void:
	var doc: DocumentDef = Registry.document(id)
	if doc == null:
		return
	_current_doc = id
	character.custody.mark_read(id)
	if _tab != Tab.DOSSIER:
		_set_tab(Tab.DOSSIER)
	_doc_paper.visible = true
	_doc_title.text = doc.title
	_doc_meta.text = doc.kind_label() + ("  ·  " + doc.date_text if doc.date_text != "" else "")
	var handwritten: bool = doc.style == DocumentDef.Style.HANDWRITTEN
	var font: Font = UiStyle.hand() if handwritten else UiStyle.mono()
	_doc_body.add_theme_font_override("normal_font", font)
	_doc_body.add_theme_font_size_override("normal_font_size", UiStyle.HAND_TEXT if handwritten else UiStyle.MONO_TEXT)
	_doc_body.text = doc.body
	_doc_image.texture = doc.image
	_doc_image.visible = doc.image != null
	_doc_stamp.text = doc.stamp
	_doc_stamp.visible = doc.stamp != ""
	_doc_paper.modulate.a = 0.0
	create_tween().tween_property(_doc_paper, "modulate:a", 1.0, 0.2)
	Sfx.ui(self, "paper", -14.0)
	_fill_dossier()


## Depuración para capturas (una vez): --custody-tab=craft|combine|dossier|character|hand,


func _page() -> Control:
	var page: Control = Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(page)
	return page


func _panel(page: Control, rect: Rect2 = PANEL) -> Panel:
	var p: Panel = Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("15171a"), Color("2e3338"), 0.95))
	page.add_child(p)
	return p


func _build_dossier_page() -> void:
	_dossier_page = _page()
	var list_title: Label = UiStyle.label("DOCUMENTOS", UiStyle.SIZE_SMALL, UiStyle.ASH)
	list_title.position = Vector2(LEFT_X + 2, TOP_Y)
	_dossier_page.add_child(list_title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(LEFT_X, TOP_Y + 16)
	scroll.size = Vector2(214, 270)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dossier_page.add_child(scroll)
	_doc_list = VBoxContainer.new()
	_doc_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_doc_list)

	_doc_paper = PanelContainer.new()
	_doc_paper.position = Vector2(PANEL.position.x, PANEL.position.y - 2)
	_doc_paper.size = Vector2(PANEL.size.x, PANEL.size.y + 4)
	_doc_paper.custom_minimum_size = _doc_paper.size
	_doc_paper.add_theme_stylebox_override("panel", UiStyle.paper_box())
	_doc_paper.visible = false
	_dossier_page.add_child(_doc_paper)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	_doc_paper.add_child(col)
	_doc_title = UiStyle.label("", UiStyle.SIZE_LARGE, UiStyle.INK)
	_doc_title.add_theme_font_override("font", UiStyle.ui_bold())
	_doc_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_doc_title)
	_doc_meta = UiStyle.label("", UiStyle.MONO_TEXT, Color("5a5244"), UiStyle.mono())
	col.add_child(_doc_meta)
	_doc_image = TextureRect.new()
	_doc_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_doc_image.custom_minimum_size = Vector2(PANEL.size.x - 28, 110)
	_doc_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	col.add_child(_doc_image)
	_doc_body = RichTextLabel.new()
	_doc_body.bbcode_enabled = true
	_doc_body.fit_content = false
	_doc_body.scroll_active = true
	_doc_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_doc_body.custom_minimum_size = Vector2(PANEL.size.x - 28, 150)
	_doc_body.add_theme_color_override("default_color", UiStyle.PAPER_INK)
	_doc_body.add_theme_constant_override("line_separation", 1)
	_doc_body.add_theme_font_override("normal_font", UiStyle.mono())
	_doc_body.add_theme_font_size_override("normal_font_size", UiStyle.MONO_TEXT)
	_doc_body.add_theme_font_override("bold_font", UiStyle.ui_bold())
	_doc_body.add_theme_font_size_override("bold_font_size", UiStyle.SIZE_TEXT)
	_doc_body.add_theme_font_override("italics_font", UiStyle.hand())
	_doc_body.add_theme_font_size_override("italics_font_size", UiStyle.HAND_TEXT)
	col.add_child(_doc_body)
	_doc_stamp = UiStyle.label("", UiStyle.MONO_LARGE, Color(0.62, 0.1, 0.1, 0.75), UiStyle.mono())
	_doc_stamp.rotation = -0.18
	_doc_stamp.position = Vector2(PANEL.end.x - 150, PANEL.position.y + 18)
	_doc_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dossier_page.add_child(_doc_stamp)


# --- fabricar y combinar ---------------------------------------------------------------------------

func _set_craft_mode(mode: CraftMode) -> void:
	_craft_mode = mode
	_craft_feedback.text = ""
	_combine_slots = [null, null]
	_fill_craft()


func _fill_craft() -> void:
	for i: int in _mode_buttons.size():
		_mode_buttons[i].add_theme_stylebox_override("normal", _tab_style(i == _craft_mode))
		_mode_buttons[i].add_theme_color_override("font_color", UiStyle.BONE if i == _craft_mode else UiStyle.ASH)
	for child: Node in _craft_list.get_children():
		child.queue_free()
	if _craft_mode == CraftMode.CRAFT:
		_fill_recipes()
	else:
		_fill_combine()


func _fill_recipes() -> void:
	var custody: Custody = character.custody
	var recipes: Array[RecipeDef] = Crafting.known_recipes(custody)
	_craft_list_title.text = "RECETAS CONOCIDAS"
	if _selected_recipe == null or not recipes.has(_selected_recipe):
		_selected_recipe = recipes[0] if not recipes.is_empty() else null
	var last_mode: int = -1
	for recipe: RecipeDef in recipes:
		if recipe.mode != last_mode:
			last_mode = recipe.mode
			if recipe.mode != RecipeDef.Mode.CRAFT:
				_craft_list.add_child(UiStyle.label("Combinaciones ya hechas", UiStyle.MONO_SMALL, UiStyle.ASH, UiStyle.mono()))
		var ok: bool = Crafting.can_craft(custody, recipe)
		var b: Button = UiStyle.button(recipe.title())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.icon = recipe.result.icon if recipe.result != null else null
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 18)
		b.custom_minimum_size = Vector2(206, 24)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_color_override("font_color", UiStyle.BONE if ok else Color(UiStyle.ASH, 0.8))
		if recipe == _selected_recipe:
			b.add_theme_stylebox_override("normal", _tab_style(true))
		b.pressed.connect(func() -> void:
			_selected_recipe = recipe
			_craft_feedback.text = ""
			_fill_craft())
		_craft_list.add_child(b)
	var hidden: int = Crafting.unknown_count(custody)
	if recipes.is_empty():
		_craft_list.add_child(UiStyle.label("No se te ocurre nada todavía.", UiStyle.SIZE_TEXT, UiStyle.ASH))
	if hidden > 0:
		var more: Label = UiStyle.label("%d %s por descubrir" % [hidden, "receta" if hidden == 1 else "recetas"],
			UiStyle.MONO_SMALL, UiStyle.ASH, UiStyle.mono())
		_craft_list.add_child(more)
	_show_recipe(_selected_recipe)


func _show_recipe(recipe: RecipeDef) -> void:
	for child: Node in _craft_needs.get_children():
		child.queue_free()
	_craft_detail.visible = true
	_craft_button.visible = true
	if recipe == null:
		_craft_image.texture = null
		_craft_title.text = "Fabricar"
		_craft_desc.text = "Las recetas aparecen al llevar encima alguno de sus materiales. Rasga ropa (T) para conseguir tela."
		_craft_button.visible = false
		return
	var custody: Custody = character.custody
	_craft_image.texture = ItemThumbs.first_view(recipe.result)
	_craft_title.text = recipe.title() + ("  x%d" % recipe.result_quantity if recipe.result_quantity > 1 else "")
	_craft_desc.text = recipe.result.description
	_craft_needs.add_child(UiStyle.label("NECESITAS", UiStyle.SIZE_SMALL, UiStyle.ASH))
	for ing: RecipeIngredient in recipe.ingredient_list():
		var have: int = Crafting.available(custody, ing)
		var enough: bool = have >= ing.amount
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var icon: TextureRect = TextureRect.new()
		icon.texture = ing.item.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(18, 18)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var tag: String = ""
		if ing.tool:
			tag = "  (gasta un uso)" if ing.uses_durability else "  (herramienta)"
		var text: String = "%s x%d%s   (tienes %d)" % [ing.item.display_name, ing.amount, tag, have]
		if ing.tool and not ing.uses_durability:
			text = "%s%s   (%s)" % [ing.item.display_name, tag, "la tienes" if enough else "no la tienes"]
		row.add_child(UiStyle.label(text, UiStyle.SIZE_TEXT, UiStyle.SICK_GREEN if enough else UiStyle.BLOOD))
		_craft_needs.add_child(row)
	var why: String = Crafting.blocker(custody, recipe)
	_craft_button.text = "FABRICAR  [Intro]" if recipe.mode == RecipeDef.Mode.CRAFT else "COMBINAR  [Intro]"
	_craft_button.disabled = why != ""
	if why != "" and _craft_feedback.text == "":
		_craft_feedback.text = why
		_craft_feedback.add_theme_color_override("font_color", UiStyle.ASH)


func _do_craft() -> void:
	if _craft_mode == CraftMode.COMBINE:
		_do_combine_slots()
		return
	var recipe: RecipeDef = _selected_recipe
	if recipe == null:
		return
	var text: String = Crafting.craft(character.custody, recipe)
	_craft_feedback.add_theme_color_override("font_color", UiStyle.BONE)
	if text == "":
		_craft_feedback.text = Crafting.blocker(character.custody, recipe)
	else:
		ItemSounds.play_named(self, recipe.sound if recipe.sound != "" else "craft_generic")
		_craft_feedback.text = text
	_fill_craft()


func _fill_combine() -> void:
	_craft_list_title.text = "OBJETOS"
	var custody: Custody = character.custody
	for stack: ItemStack in custody.items:
		var b: Button = UiStyle.button(stack.def.display_name + ("  x%d" % stack.quantity if stack.quantity > 1 else ""))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.icon = stack.def.icon
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 18)
		b.custom_minimum_size = Vector2(206, 24)
		b.focus_mode = Control.FOCUS_NONE
		if _combine_slots.has(stack):
			b.add_theme_stylebox_override("normal", _tab_style(true))
			b.add_theme_color_override("font_color", UiStyle.BONE)
		b.pressed.connect(_pick_for_combine.bind(stack))
		_craft_list.add_child(b)
	# Detalle: A + B = ?
	for child: Node in _craft_needs.get_children():
		child.queue_free()
	var a: ItemStack = _combine_slots[0]
	var b2: ItemStack = _combine_slots[1]
	_craft_title.text = "Combinar dos objetos"
	_craft_desc.text = "Elige dos objetos de la lista. También puedes usar Combinar (C) en la pestaña OBJETOS."
	var recipe: RecipeDef = Registry.find_recipe(a.def, b2.def) if a != null and b2 != null else null
	var known: bool = recipe != null and custody.known_recipes.has(recipe.id)
	_craft_image.texture = ItemThumbs.first_view(recipe.result) if known and recipe.result != null else null
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for i: int in 2:
		row.add_child(_combine_slot_view(_combine_slots[i]))
		row.add_child(UiStyle.label("+" if i == 0 else "=", UiStyle.SIZE_TITLE, UiStyle.ASH))
	var result_label: String = "?"
	if known and recipe.result != null:
		result_label = recipe.result.display_name
	elif known and recipe.mode == RecipeDef.Mode.RECHARGE:
		result_label = "Recargar"
	row.add_child(UiStyle.label(result_label, UiStyle.SIZE_TEXT, UiStyle.BONE if known else UiStyle.ASH))
	_craft_needs.add_child(row)
	_craft_button.visible = true
	_craft_button.text = "COMBINAR  [Intro]"
	_craft_button.disabled = a == null or b2 == null


func _combine_slot_view(stack: ItemStack) -> Control:
	var p: Panel = Panel.new()
	p.custom_minimum_size = Vector2(44, 44)
	p.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("0c0d0f"), UiStyle.STEEL_LIGHT, 0.95))
	if stack != null and stack.def.icon != null:
		var icon: TextureRect = TextureRect.new()
		icon.texture = stack.def.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = Vector2(2, 2)
		icon.size = Vector2(40, 40)
		p.add_child(icon)
	return p


func _pick_for_combine(stack: ItemStack) -> void:
	var i: int = _combine_slots.find(stack)
	if i >= 0:
		_combine_slots[i] = null
	elif _combine_slots[0] == null:
		_combine_slots[0] = stack
	elif _combine_slots[1] == null:
		_combine_slots[1] = stack
	else:
		_combine_slots = [_combine_slots[1], stack]
	ItemSounds.play(self, stack.def, ItemSounds.Action.PICK, -12.0)
	_craft_feedback.text = ""
	_fill_craft()


func _do_combine_slots() -> void:
	var a: ItemStack = _combine_slots[0]
	var b: ItemStack = _combine_slots[1]
	if a == null or b == null:
		return
	var text: String = _items.do_combine(a, b)
	_craft_feedback.add_theme_color_override("font_color", UiStyle.BONE)
	_craft_feedback.text = text if text != "" else "No encajan."
	_combine_slots = [null, null]
	_fill_craft()


func _build_craft_page() -> void:
	_craft_page = _page()
	var modes: HBoxContainer = HBoxContainer.new()
	modes.position = Vector2(LEFT_X, TOP_Y)
	modes.add_theme_constant_override("separation", 3)
	_craft_page.add_child(modes)
	for i: int in 2:
		var b: Button = UiStyle.button(["FABRICAR", "COMBINAR"][i])
		b.custom_minimum_size = Vector2(102, 0)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_set_craft_mode.bind(i))
		modes.add_child(b)
		_mode_buttons.append(b)
	_craft_list_title = UiStyle.label("", UiStyle.SIZE_SMALL, UiStyle.ASH)
	_craft_list_title.position = Vector2(LEFT_X + 2, TOP_Y + 26)
	_craft_page.add_child(_craft_list_title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(LEFT_X, TOP_Y + 42)
	scroll.size = Vector2(214, 244)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_craft_page.add_child(scroll)
	_craft_list = VBoxContainer.new()
	_craft_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_craft_list)

	_panel(_craft_page)
	_craft_detail = Control.new()
	_craft_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_craft_page.add_child(_craft_detail)
	var x: float = PANEL.position.x + 10
	var text_w: float = PANEL.size.x - 20 - 112 - 6
	_craft_image = TextureRect.new()
	_craft_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_craft_image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_craft_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_craft_image.position = Vector2(PANEL.end.x - 8 - 112, PANEL.position.y + 6)
	_craft_image.size = Vector2(112, 112)
	_craft_detail.add_child(_craft_image)
	var col: VBoxContainer = VBoxContainer.new()
	col.position = Vector2(x, PANEL.position.y + 8)
	col.add_theme_constant_override("separation", 4)
	_craft_detail.add_child(col)
	_craft_title = UiStyle.label("", UiStyle.SIZE_LARGE, UiStyle.BONE)
	_craft_title.add_theme_font_override("font", UiStyle.ui_bold())
	_craft_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_craft_title.custom_minimum_size = Vector2(text_w, 0)
	col.add_child(_craft_title)
	_craft_desc = UiStyle.label("", UiStyle.SIZE_TEXT, UiStyle.BONE_DIM)
	_craft_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_craft_desc.custom_minimum_size = Vector2(text_w, 0)
	col.add_child(_craft_desc)
	_craft_needs = VBoxContainer.new()
	_craft_needs.position = Vector2(x, PANEL.position.y + 124)
	_craft_needs.add_theme_constant_override("separation", 3)
	_craft_detail.add_child(_craft_needs)
	_craft_button = UiStyle.button("FABRICAR  [Intro]")
	_craft_button.position = Vector2(x, PANEL.end.y - 62)
	_craft_button.custom_minimum_size = Vector2(160, 0)
	_craft_button.focus_mode = Control.FOCUS_NONE
	_craft_button.pressed.connect(_do_craft)
	_craft_detail.add_child(_craft_button)
	_craft_feedback = UiStyle.label("", UiStyle.SIZE_TEXT, UiStyle.BONE)
	_craft_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_craft_feedback.position = Vector2(x, PANEL.end.y - 36)
	_craft_feedback.custom_minimum_size = Vector2(PANEL.size.x - 20, 0)
	_craft_detail.add_child(_craft_feedback)


