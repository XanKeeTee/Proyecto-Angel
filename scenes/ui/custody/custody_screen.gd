class_name CustodyScreen
extends CanvasLayer
## Pantalla del Sistema de Custodia. Cuatro pestañas:
## - BANDEJA: bandeja 5x4, bolsillos, suelo (descartar), detalles del objeto y constantes.
## - FABRICAR: recetas de varios ingredientes (Fabricar) y combinaciones de dos objetos (Combinar).
## - EXPEDIENTE: documentos encontrados y lector.
## - PERSONAJE: el protagonista con la ropa puesta, sus ranuras y la mano (arma empuñada).
## Pausa el juego mientras está abierta. Ratón y teclado:
##   flechas/ratón mueven · Intro coge/suelta · R gira · E usa · X examina · C combina · T rasga
##   F empuña · Supr descarta · 1-5 al bolsillo · clic derecho menú · Q pestaña · Tab/Esc cierra.

signal closed
## Pide abrir el inspector para un objeto (lo gestiona la escena).
signal inspect_requested(stack: ItemStack)

## (El orden del enum se mantiene por compatibilidad; el de las pestañas está en TAB_ORDER.)
enum Tab { TRAY, DOSSIER, CHARACTER, CRAFT }
enum CraftMode { CRAFT, COMBINE }

const SLIDE: float = 14.0
const TAB_ORDER: Array[Tab] = [Tab.TRAY, Tab.CRAFT, Tab.DOSSIER, Tab.CHARACTER]
const TAB_NAMES: Dictionary[int, String] = {
	Tab.TRAY: "BANDEJA", Tab.CRAFT: "FABRICAR", Tab.DOSSIER: "EXPEDIENTE", Tab.CHARACTER: "PERSONAJE",
}
const SLOTS: Array[ItemDef.EquipSlot] = [
	ItemDef.EquipSlot.HEAD, ItemDef.EquipSlot.BODY, ItemDef.EquipSlot.LEGS, ItemDef.EquipSlot.FEET,
]
## Ranura de la mano en la pestaña PERSONAJE (no es una EquipSlot: el arma sigue en la custodia).
const HAND_SLOT: int = 100
const FRAME: Rect2 = Rect2(6, 6, 628, 348)
## Panel de la derecha (detalles, receta, etc.).
const PANEL: Rect2 = Rect2(238, 50, 388, 284)
const LEFT_X: float = 14.0
const TOP_Y: float = 50.0

var character: CharacterState
var _tab: Tab = Tab.TRAY
var _combine_source: ItemStack
var _root: Control
var _dim: ColorRect
var _tray: TrayView
var _tab_buttons: Dictionary[int, Button] = {}
var _tray_page: Control
var _dossier_page: Control
var _name: Label
var _meta: Label
var _weapon_info: Label
var _desc: Label
var _detail_image: TextureRect
var _actions: GridContainer
var _feedback: Label
var _body_bar: ProgressBar
var _mind_bar: ProgressBar
var _bleed: Label
var _charge: Label
var _hint: Label
var _menu_catcher: Control
var _menu: PanelContainer
var _menu_box: VBoxContainer
# Expediente.
var _doc_list: VBoxContainer
var _doc_paper: PanelContainer
var _doc_title: Label
var _doc_meta: Label
var _doc_body: RichTextLabel
var _doc_image: TextureRect
var _doc_stamp: Label
var _current_doc: StringName = &""
# Personaje.
var _outfit_page: Control
var _preview: OutfitPreview
var _slot_buttons: Dictionary[int, Button] = {}
var _wardrobe_title: Label
var _wardrobe: VBoxContainer
var _outfit_name: Label
var _outfit_desc: Label
var _outfit_stats: Label
var _outfit_feedback: Label
var _remove_button: Button
var _selected_slot: int = ItemDef.EquipSlot.BODY
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


func open(tab: Tab = Tab.TRAY, document_id: StringName = &"") -> void:
	character = GameState.character
	_tray.custody = character.custody
	if not character.custody.changed.is_connected(_refresh):
		character.custody.changed.connect(_refresh)
	visible = true
	get_tree().paused = true
	_set_tab(tab)
	if document_id != &"":
		_show_document(document_id)
	_feedback.text = ""
	_combine_source = null
	_close_menu()
	_root.modulate.a = 0.0
	_root.position.y = SLIDE
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_root, "modulate:a", 1.0, 0.18)
	tween.tween_property(_root, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_dim.color.a = 0.0
	tween.tween_property(_dim, "color:a", 0.8, 0.2)
	_tray.grab_focus()
	_refresh()
	_apply_debug_args()


func close() -> void:
	if not visible:
		return
	_tray.cancel()
	_close_menu()
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
	if _menu.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed(InputActions.CUSTODY):
			_close_menu()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(InputActions.CUSTODY) or event.is_action_pressed(InputActions.PAUSE) \
			or (event.is_action_pressed("ui_cancel") and _tray.held == null and _combine_source == null):
		get_viewport().set_input_as_handled()
		close()
		return
	if event.is_action_pressed("ui_cancel"):
		_tray.cancel()
		_combine_source = null
		_say("")
		get_viewport().set_input_as_handled()
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_Q:
		var i: int = TAB_ORDER.find(_tab)
		_set_tab(TAB_ORDER[(i + (TAB_ORDER.size() - 1 if key.shift_pressed else 1)) % TAB_ORDER.size()])
		get_viewport().set_input_as_handled()
		return
	if _tab == Tab.CRAFT and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_do_craft()
		return
	if _tab != Tab.TRAY:
		return
	var handled: bool = true
	if event.is_action_pressed("ui_left"):
		_tray.move_cursor(Vector2i.LEFT)
	elif event.is_action_pressed("ui_right"):
		_tray.move_cursor(Vector2i.RIGHT)
	elif event.is_action_pressed("ui_up"):
		_tray.move_cursor(Vector2i.UP)
	elif event.is_action_pressed("ui_down"):
		_tray.move_cursor(Vector2i.DOWN)
	elif event.is_action_pressed("ui_accept"):
		if _combine_source != null:
			_finish_combine(_tray.selected())
		else:
			_tray.pick_or_drop()
	elif key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_R: _tray.rotate_held()
			KEY_E: _use(_tray.selected())
			KEY_X: _examine(_tray.selected())
			KEY_C: _start_combine(_tray.selected())
			KEY_T: _tear(_tray.selected())
			KEY_F: _toggle_wield(_tray.selected())
			KEY_DELETE, KEY_BACKSPACE: _discard(_tray.selected() if _tray.held == null else _tray.held)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5: _to_pocket(_tray.selected(), key.keycode - KEY_1)
			_: handled = false
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()
		_refresh()


# --- acciones ----------------------------------------------------------------------------

func _use(stack: ItemStack) -> void:
	if stack == null:
		return
	if stack.def.is_wearable():
		var result: String = character.equip(stack)
		if result == "":
			ItemSounds.play(self, stack.def, ItemSounds.Action.EQUIP)
		_say(result if result != "" else "Te pones " + stack.def.display_name.to_lower() + ".")
		_refresh()
		return
	if stack.def.is_weapon() and not stack.def.usable:
		_toggle_wield(stack)
		return
	if not stack.def.usable:
		_say("No se puede usar así. Quizá combinado con otra cosa.")
		return
	# El sonido de uso lo pone CustodyWorldLink al recibir EventBus.item_used.
	var text: String = character.use_item(stack)
	_say(text if text != "" else "Ahora no lo necesitas.")
	_refresh()


func _examine(stack: ItemStack) -> void:
	if stack != null:
		inspect_requested.emit(stack)


func _start_combine(stack: ItemStack) -> void:
	if stack == null:
		return
	_combine_source = stack
	_say("Combinar %s con… (elige otro objeto e Intro)" % stack.def.display_name.to_lower())


func _finish_combine(target: ItemStack) -> void:
	var source: ItemStack = _combine_source
	_combine_source = null
	if target == null or target == source:
		_say("")
		return
	_do_combine(source, target)


func _do_combine(a: ItemStack, b: ItemStack) -> String:
	var recipe: RecipeDef = Registry.find_recipe(a.def, b.def)
	var text: String = character.custody.combine(a, b)
	if text != "" and recipe != null:
		ItemSounds.play_named(self, recipe.sound if recipe.sound != "" else "craft_combine")
	_say(text if text != "" else "No encajan.")
	_refresh()
	return text


func _to_pocket(stack: ItemStack, index: int) -> void:
	if stack == null:
		return
	var custody: Custody = character.custody
	var pocket: int = custody.pockets.find(stack)
	if pocket >= 0:
		if pocket == index:
			if not custody.from_pocket(pocket):
				_say("No hay sitio en la bandeja.")
		else:
			custody.swap_pockets(pocket, index)
	elif not custody.to_pocket(stack, index):
		_say("No hay sitio en la bandeja para lo que había en ese bolsillo.")
	ItemSounds.play(self, stack.def, ItemSounds.Action.PLACE)
	_refresh()


func _discard(stack: ItemStack) -> void:
	if stack == null:
		return
	if _tray.held == stack:
		_tray.cancel()
	var text: String = character.discard(stack)
	_say(text)
	_refresh()


func _tear(stack: ItemStack) -> void:
	if stack == null:
		return
	if not Crafting.can_tear(character.custody, stack):
		_say("Eso no se puede rasgar." if stack.def.tear_yield() <= 0 else "No puedes rasgarlo ahora.")
		return
	var text: String = Crafting.tear(character.custody, stack)
	if text != "" and not text.begins_with("No "):
		ItemSounds.play(self, stack.def, ItemSounds.Action.TEAR, -4.0)
		Crafting.discover(character.custody)
	_say(text)
	_refresh()


func _toggle_wield(stack: ItemStack) -> void:
	if stack == null or not stack.def.is_weapon():
		if stack != null:
			_say("Eso no sirve como arma.")
		return
	if character.wielded() == stack:
		character.unwield()
		ItemSounds.play(self, stack.def, ItemSounds.Action.UNEQUIP)
		_say("Guardas " + stack.def.display_name.to_lower() + ".")
	else:
		var result: String = character.wield(stack)
		if result == "":
			ItemSounds.play(self, stack.def, ItemSounds.Action.EQUIP)
		_say(result if result != "" else "Empuñas " + stack.def.display_name.to_lower() + ".")
	_refresh()


func _say(text: String) -> void:
	_feedback.text = "" if text == "·" else text


## Acciones de un objeto: [{label, key, callback}] (para el panel y el menú contextual).
func _actions_for(stack: ItemStack) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if stack == null:
		return list
	var custody: Custody = character.custody
	if stack.def.is_wearable():
		list.append({"label": "Ponerse", "key": "E", "call": _use.bind(stack)})
	elif stack.def.usable:
		list.append({"label": stack.def.use_verb, "key": "E", "call": _use.bind(stack)})
	if stack.def.is_weapon():
		var wielding: bool = character.wielded() == stack
		list.append({"label": "Guardar arma" if wielding else "Empuñar", "key": "F", "call": _toggle_wield.bind(stack)})
	list.append({"label": "Examinar", "key": "X", "call": _examine.bind(stack)})
	list.append({"label": "Combinar", "key": "C", "call": _start_combine.bind(stack)})
	if Crafting.can_tear(custody, stack):
		list.append({"label": "Rasgar (%d tiras)" % stack.def.tear_yield(), "key": "T", "call": _tear.bind(stack)})
	var in_pocket: bool = custody.pockets.has(stack)
	if in_pocket:
		list.append({"label": "A la bandeja", "key": "", "call": _to_pocket.bind(stack, custody.pockets.find(stack))})
	else:
		var free: int = custody.pockets.find(null)
		if free >= 0:
			list.append({"label": "Al bolsillo %d" % (free + 1), "key": "1-5", "call": _to_pocket.bind(stack, free)})
	if not in_pocket and stack.def.size.x != stack.def.size.y:
		list.append({"label": "Girar", "key": "R", "call": _tray.rotate_held})
	if stack.def.can_discard():
		list.append({"label": "Descartar", "key": "Supr", "call": _discard.bind(stack)})
	return list


# --- menú contextual ----------------------------------------------------------------------------

func _open_menu(stack: ItemStack, at: Vector2) -> void:
	for child: Node in _menu_box.get_children():
		child.queue_free()
	var title: Label = UiStyle.label(stack.def.display_name, UiStyle.SIZE_SMALL, UiStyle.ASH)
	_menu_box.add_child(title)
	var first: Button
	for action: Dictionary in _actions_for(stack):
		var b: Button = _action_button(action, 150)
		b.pressed.connect(_close_menu)
		_menu_box.add_child(b)
		if first == null:
			first = b
	if not stack.def.can_discard():
		_menu_box.add_child(UiStyle.label("Objeto clave: no se descarta", UiStyle.MONO_SMALL, UiStyle.ASH, UiStyle.mono()))
	_menu.visible = true
	_menu_catcher.visible = true
	_menu.reset_size()
	await get_tree().process_frame
	var s: Vector2 = _menu.get_combined_minimum_size()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_menu.position = Vector2(clampf(at.x + 4, 4, vp.x - s.x - 4), clampf(at.y + 2, 4, vp.y - s.y - 4)).floor()
	if first != null:
		first.grab_focus()


func _close_menu() -> void:
	if _menu == null:
		return
	_menu.visible = false
	_menu_catcher.visible = false
	if _tray != null and _tab == Tab.TRAY:
		_tray.grab_focus()


# --- refresco -------------------------------------------------------------------------------

func _refresh() -> void:
	if character == null:
		return
	_tray.wielded = character.wielded()
	var v: Vitals = character.vitals
	_body_bar.value = v.body
	_mind_bar.value = v.mind
	_bleed.visible = v.bleeding
	var lamp: ItemStack = character.flashlight()
	_charge.text = "Linterna %d %%" % roundi(lamp.charge / lamp.def.max_charge * 100.0) if lamp != null else ""
	_show_details(_tray.held if _tray.held != null else _tray.selected())
	match _tab:
		Tab.DOSSIER: _fill_dossier()
		Tab.CHARACTER: _fill_outfit()
		Tab.CRAFT: _fill_craft()


func _show_details(stack: ItemStack) -> void:
	for child: Node in _actions.get_children():
		child.queue_free()
	_detail_image.texture = _detail_texture(stack)
	_weapon_info.visible = false
	if stack == null:
		_name.text = "—"
		_meta.text = "Casilla vacía"
		_desc.text = "Arrastra los objetos para ordenarlos; mientras arrastras, clic derecho los gira. " \
			+ "Suelta uno sobre otro para combinarlos, o en el SUELO para descartarlo."
		return
	_name.text = stack.def.display_name
	var fp: Vector2i = stack.def.size
	var meta: PackedStringArray = ["%dx%d" % [fp.x, fp.y]]
	if stack.def.is_stackable():
		meta.append("%d/%d" % [stack.quantity, stack.def.max_stack])
	var status: String = stack.status_text()
	if status != "":
		meta.append(status)
	if stack.def.is_wearable():
		meta.append(ItemDef.slot_name(stack.def.equip_slot))
	if stack.def.key_item:
		meta.append("Objeto clave")
	if stack == character.wielded():
		meta.append("EN LA MANO")
	_meta.text = " · ".join(meta)
	_desc.text = stack.def.description
	if stack.def.is_weapon():
		_weapon_info.visible = true
		_weapon_info.text = _weapon_text(stack.def.weapon)
	for action: Dictionary in _actions_for(stack):
		_actions.add_child(_action_button(action, 184))


func _weapon_text(w: WeaponDef) -> String:
	return "%s · Poder %d · Precisión %d %%%s · %s\n%s" % [
		w.damage_type_name(), w.power, w.accuracy, (" · Crítico +%d" % w.crit_mod) if w.crit_mod > 0 else "",
		"Dos manos" if w.two_handed else "Una mano", w.effect_text()]


func _action_button(action: Dictionary, width: float) -> Button:
	var key: String = action["key"]
	var b: Button = UiStyle.button(action["label"] + ("  [%s]" % key if key != "" else ""))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(width, 0)
	b.clip_text = true
	var callback: Callable = action["call"]
	b.pressed.connect(func() -> void:
		callback.call()
		_refresh())
	return b


## Vista grande del objeto (la primera del inspector) para el panel de detalles.
func _detail_texture(stack: ItemStack) -> Texture2D:
	if stack == null:
		return null
	return _first_view(stack.def)


static func _first_view(def: ItemDef) -> Texture2D:
	var sheet: Texture2D = def.inspect_sheet
	if sheet == null:
		return def.icon
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(0, 0, sheet.get_height(), sheet.get_height())
	return atlas


# --- pestañas ------------------------------------------------------------------------------

func _set_tab(tab: Tab) -> void:
	_tab = tab
	_close_menu()
	_tray_page.visible = tab == Tab.TRAY
	_dossier_page.visible = tab == Tab.DOSSIER
	_outfit_page.visible = tab == Tab.CHARACTER
	_craft_page.visible = tab == Tab.CRAFT
	if tab != Tab.TRAY:
		_tray.cancel()
	for t: int in _tab_buttons:
		var b: Button = _tab_buttons[t]
		b.add_theme_color_override("font_color", UiStyle.BONE if t == tab else UiStyle.ASH)
		b.add_theme_stylebox_override("normal", _tab_style(t == tab))
	var hints: Dictionary[int, String] = {
		Tab.TRAY: "E usar · C combinar · T rasgar · Supr descartar · clic dcho.: menú",
		Tab.CRAFT: "Elige una receta y pulsa Fabricar · en Combinar, elige dos objetos",
		Tab.DOSSIER: "Elige un documento de la lista",
		Tab.CHARACTER: "Elige una ranura y una prenda o un arma",
	}
	_hint.text = hints[tab]
	match tab:
		Tab.CHARACTER:
			_preview.character = character
			_outfit_feedback.text = ""
			_fill_outfit()
		Tab.DOSSIER:
			_fill_dossier()
			if _current_doc == &"" and not character.custody.documents.is_empty():
				_show_document(character.custody.documents[-1])
		Tab.CRAFT:
			_craft_feedback.text = ""
			_fill_craft()
		_:
			_tray.grab_focus()
			_refresh()


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
## --custody-drag=id (lo deja agarrado con el ratón), --custody-menu=id (menú contextual) y --custody-wield=id.
func _apply_debug_args() -> void:
	if has_meta(&"debug_done"):
		return
	set_meta(&"debug_done", true)
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if pair.size() < 2:
			continue
		match pair[0]:
			"custody-tab":
				match pair[1]:
					"craft": _set_tab(Tab.CRAFT)
					"combine":
						_set_tab(Tab.CRAFT)
						_set_craft_mode(CraftMode.COMBINE)
					"dossier": _set_tab(Tab.DOSSIER)
					"character": _set_tab(Tab.CHARACTER)
					"hand":
						_set_tab(Tab.CHARACTER)
						_select_slot(HAND_SLOT)
			"custody-wield":
				var weapon: ItemStack = character.custody.find_first(StringName(pair[1]))
				if weapon != null:
					character.wield(weapon)
					_refresh()
			"custody-drag":
				var stack: ItemStack = character.custody.find_first(StringName(pair[1]))
				if stack != null:
					_tray.debug_drag(stack, Vector2(150, 150))
			"custody-menu":
				var target: ItemStack = character.custody.find_first(StringName(pair[1]))
				if target != null:
					_tray.set_cursor(target.cell)
					_open_menu(target, _tray.stack_global_rect(target).get_center())


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
	_hint.size = Vector2(FRAME.size.x - 190, 14)
	_root.add_child(_hint)
	var keys: Label = UiStyle.label("Q pestaña · Tab cerrar", UiStyle.MONO_SMALL, UiStyle.BONE_DIM, UiStyle.mono())
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	keys.size = Vector2(160, 14)
	keys.position = Vector2(FRAME.end.x - 176, 337)
	_root.add_child(keys)

	_build_tray_page()
	_build_craft_page()
	_build_dossier_page()
	_build_outfit_page()
	_build_menu()


func _build_menu() -> void:
	_menu_catcher = Control.new()
	_menu_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_catcher.visible = false
	_menu_catcher.gui_input.connect(func(e: InputEvent) -> void:
		var mb: InputEventMouseButton = e as InputEventMouseButton
		if mb != null and mb.pressed:
			_close_menu())
	_root.add_child(_menu_catcher)
	_menu = PanelContainer.new()
	var style: StyleBoxFlat = UiStyle.steel_box(Color("0c0d0f"), UiStyle.BONE_DIM, 0.98)
	style.set_content_margin_all(4)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 3
	_menu.add_theme_stylebox_override("panel", style)
	_menu.visible = false
	_root.add_child(_menu)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 1)
	_menu.add_child(_menu_box)


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


func _build_tray_page() -> void:
	_tray_page = _page()
	_tray = TrayView.new()
	_tray.position = Vector2(LEFT_X - 2, TOP_Y)
	_tray_page.add_child(_tray)
	_tray.selection_changed.connect(func(_s: ItemStack) -> void: _refresh())
	_tray.activated.connect(_use)
	_tray.feedback.connect(_say)
	_tray.combine_requested.connect(func(a: ItemStack, b: ItemStack) -> void: _do_combine(a, b))
	_tray.context_requested.connect(_open_menu)
	_tray.discard_requested.connect(_discard)

	_panel(_tray_page)
	var x: float = PANEL.position.x + 10
	var text_w: float = PANEL.size.x - 20 - 112 - 6
	# Columna del panel: [nombre, datos, descripción | imagen], arma, acciones, …, respuesta.
	var body: VBoxContainer = VBoxContainer.new()
	body.position = Vector2(x, PANEL.position.y + 8)
	body.size = Vector2(PANEL.size.x - 20, PANEL.size.y - 36)
	body.add_theme_constant_override("separation", 6)
	_tray_page.add_child(body)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	body.add_child(top)
	var col: VBoxContainer = VBoxContainer.new()
	col.custom_minimum_size = Vector2(text_w, 0)
	col.add_theme_constant_override("separation", 3)
	top.add_child(col)
	_name = UiStyle.label("", UiStyle.SIZE_LARGE, UiStyle.BONE)
	_name.add_theme_font_override("font", UiStyle.ui_bold())
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.custom_minimum_size = Vector2(text_w, 0)
	col.add_child(_name)
	_meta = UiStyle.label("", UiStyle.MONO_TEXT, UiStyle.ASH, UiStyle.mono())
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meta.custom_minimum_size = Vector2(text_w, 0)
	col.add_child(_meta)
	_desc = UiStyle.label("", UiStyle.SIZE_TEXT, UiStyle.BONE_DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(text_w, 0)
	col.add_child(_desc)
	_detail_image = TextureRect.new()
	_detail_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail_image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_image.custom_minimum_size = Vector2(112, 112)
	_detail_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_detail_image)
	_weapon_info = UiStyle.label("", UiStyle.MONO_TEXT, UiStyle.AMBER, UiStyle.mono())
	_weapon_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weapon_info.custom_minimum_size = Vector2(PANEL.size.x - 20, 0)
	body.add_child(_weapon_info)
	_actions = GridContainer.new()
	_actions.columns = 2
	_actions.add_theme_constant_override("h_separation", 4)
	_actions.add_theme_constant_override("v_separation", 3)
	body.add_child(_actions)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	_feedback = UiStyle.label("", UiStyle.SIZE_TEXT, UiStyle.BONE)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size = Vector2(PANEL.size.x - 20, 0)
	body.add_child(_feedback)

	# Constantes: franja al pie del panel.
	var vit: HBoxContainer = HBoxContainer.new()
	vit.position = Vector2(x, PANEL.end.y - 20)
	vit.add_theme_constant_override("separation", 6)
	_tray_page.add_child(vit)
	vit.add_child(UiStyle.label("Cuerpo", UiStyle.SIZE_SMALL, UiStyle.BONE_DIM))
	_body_bar = UiStyle.bar(UiStyle.BLOOD, 70)
	_body_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vit.add_child(_body_bar)
	vit.add_child(UiStyle.label("Mente", UiStyle.SIZE_SMALL, UiStyle.BONE_DIM))
	_mind_bar = UiStyle.bar(Color("7a79b4"), 70)
	_mind_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vit.add_child(_mind_bar)
	_charge = UiStyle.label("", UiStyle.MONO_TEXT, UiStyle.BONE_DIM, UiStyle.mono())
	vit.add_child(_charge)
	_bleed = UiStyle.label("SANGRADO", UiStyle.MONO_TEXT, UiStyle.BLOOD, UiStyle.mono())
	vit.add_child(_bleed)


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
	_craft_image.texture = _first_view(recipe.result)
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
	for stack: ItemStack in custody.pockets + custody.tray:
		if stack == null:
			continue
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
	_craft_desc.text = "Elige dos objetos de la lista. También puedes soltar uno encima de otro en la bandeja."
	var recipe: RecipeDef = Registry.find_recipe(a.def, b2.def) if a != null and b2 != null else null
	var known: bool = recipe != null and custody.known_recipes.has(recipe.id)
	_craft_image.texture = _first_view(recipe.result) if known and recipe.result != null else null
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
	var text: String = _do_combine(a, b)
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


# --- personaje, ropa y arma ----------------------------------------------------------------------

func _fill_outfit() -> void:
	for slot: ItemDef.EquipSlot in SLOTS:
		var stack: ItemStack = character.worn(slot)
		var b: Button = _slot_buttons[slot]
		b.text = ItemDef.slot_name(slot).to_upper() + "\n" + (stack.def.display_name if stack != null else "—")
		b.icon = stack.def.icon if stack != null else null
		b.add_theme_stylebox_override("normal", _tab_style(slot == _selected_slot))
	var weapon: ItemStack = character.wielded()
	var hand: Button = _slot_buttons[HAND_SLOT]
	hand.text = "MANO\n" + (weapon.def.display_name if weapon != null else "—")
	hand.icon = weapon.def.icon if weapon != null else null
	hand.add_theme_stylebox_override("normal", _tab_style(_selected_slot == HAND_SLOT))
	for child: Node in _wardrobe.get_children():
		child.queue_free()
	var any: bool = false
	var custody: Custody = character.custody
	var hand_selected: bool = _selected_slot == HAND_SLOT
	_wardrobe_title.text = "ARMAS EN LA CUSTODIA" if hand_selected else "ROPA EN LA CUSTODIA"
	for stack: ItemStack in custody.tray + custody.pockets:
		if stack == null:
			continue
		if hand_selected and not stack.def.is_weapon():
			continue
		if not hand_selected and not stack.def.is_wearable():
			continue
		any = true
		var label: String = stack.def.display_name
		if not hand_selected:
			label += "  ·  " + ItemDef.slot_name(stack.def.equip_slot)
		elif stack == weapon:
			label += "  ·  en la mano"
		var b: Button = UiStyle.button(label)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = stack.def.icon
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 22)
		b.custom_minimum_size = Vector2(214, 26)
		b.clip_text = true
		b.pressed.connect((_wield_from_list if hand_selected else _wear).bind(stack))
		_wardrobe.add_child(b)
	if not any:
		var none: String = "No llevas armas. Una palanca o un tubo servirían." if hand_selected else "No llevas ropa de repuesto."
		var l: Label = UiStyle.label(none, UiStyle.SIZE_TEXT, UiStyle.ASH)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(214, 0)
		_wardrobe.add_child(l)
	_outfit_stats.visible = false
	if hand_selected:
		_outfit_name.text = weapon.def.display_name if weapon != null else "Mano: vacía"
		_outfit_desc.text = weapon.def.description if weapon != null else "Elige un arma de la lista para empuñarla. Sigue ocupando su sitio en la bandeja."
		if weapon != null:
			_outfit_stats.visible = true
			_outfit_stats.text = _weapon_text(weapon.def.weapon)
		_remove_button.text = "Guardar arma"
		_remove_button.visible = weapon != null
		return
	var worn: ItemStack = character.worn(_selected_slot as ItemDef.EquipSlot)
	_outfit_name.text = worn.def.display_name if worn != null else ItemDef.slot_name(_selected_slot as ItemDef.EquipSlot) + ": nada"
	_outfit_desc.text = worn.def.description if worn != null else "Elige una prenda de la lista para ponértela."
	_remove_button.text = "Quitarse"
	_remove_button.visible = worn != null


func _wear(stack: ItemStack) -> void:
	var result: String = character.equip(stack)
	_selected_slot = stack.def.equip_slot
	if result == "":
		ItemSounds.play(self, stack.def, ItemSounds.Action.EQUIP)
	_outfit_feedback.text = result if result != "" else "Te pones " + stack.def.display_name.to_lower() + "."
	_fill_outfit()


func _wield_from_list(stack: ItemStack) -> void:
	if character.wielded() == stack:
		return
	var result: String = character.wield(stack)
	if result == "":
		ItemSounds.play(self, stack.def, ItemSounds.Action.EQUIP)
	_outfit_feedback.text = result if result != "" else "Empuñas " + stack.def.display_name.to_lower() + "."
	_fill_outfit()


func _take_off() -> void:
	if _selected_slot == HAND_SLOT:
		var weapon: ItemStack = character.wielded()
		if weapon != null:
			character.unwield()
			ItemSounds.play(self, weapon.def, ItemSounds.Action.UNEQUIP)
			_outfit_feedback.text = "Guardas " + weapon.def.display_name.to_lower() + "."
		_fill_outfit()
		return
	var worn: ItemStack = character.worn(_selected_slot as ItemDef.EquipSlot)
	if worn == null:
		return
	var result: String = character.unequip(_selected_slot as ItemDef.EquipSlot)
	if result == "":
		ItemSounds.play(self, worn.def, ItemSounds.Action.UNEQUIP)
	_outfit_feedback.text = result if result != "" else "Te quitas " + worn.def.display_name.to_lower() + ". Va a la bandeja."
	_fill_outfit()


func _select_slot(slot: int) -> void:
	_selected_slot = slot
	_outfit_feedback.text = ""
	_fill_outfit()


func _build_outfit_page() -> void:
	_outfit_page = _page()
	var stage: Panel = Panel.new()
	stage.position = Vector2(LEFT_X, TOP_Y)
	stage.size = Vector2(170, 288)
	stage.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("0c0d0f"), Color("2e3338"), 0.95))
	_outfit_page.add_child(stage)
	_preview = OutfitPreview.new()
	_preview.position = Vector2(LEFT_X + floorf((170 - _preview.size.x) / 2.0), TOP_Y + 18)
	_outfit_page.add_child(_preview)
	var turn_left: Button = UiStyle.button("<")
	turn_left.position = Vector2(LEFT_X + 8, TOP_Y + 254)
	turn_left.pressed.connect(func() -> void: _preview.turn(-1))
	_outfit_page.add_child(turn_left)
	var turn_right: Button = UiStyle.button(">")
	turn_right.position = Vector2(LEFT_X + 170 - 30, TOP_Y + 254)
	turn_right.pressed.connect(func() -> void: _preview.turn(1))
	_outfit_page.add_child(turn_right)
	var who: Label = UiStyle.label("PACIENTE 09", UiStyle.MONO_SMALL, UiStyle.ASH, UiStyle.mono())
	who.position = Vector2(LEFT_X + 56, TOP_Y + 258)
	_outfit_page.add_child(who)

	var slots: VBoxContainer = VBoxContainer.new()
	slots.position = Vector2(LEFT_X + 178, TOP_Y)
	slots.add_theme_constant_override("separation", 4)
	_outfit_page.add_child(slots)
	slots.add_child(UiStyle.label("PUESTO", UiStyle.SIZE_SMALL, UiStyle.ASH))
	var all_slots: Array[int] = []
	for s: ItemDef.EquipSlot in SLOTS:
		all_slots.append(s)
	all_slots.append(HAND_SLOT)
	for slot: int in all_slots:
		var b: Button = UiStyle.button("")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 40)
		b.custom_minimum_size = Vector2(190, 48)
		b.pressed.connect(_select_slot.bind(slot))
		slots.add_child(b)
		_slot_buttons[slot] = b
		if slot == HAND_SLOT:
			b.add_theme_color_override("font_color", UiStyle.AMBER)

	var right: VBoxContainer = VBoxContainer.new()
	right.position = Vector2(LEFT_X + 376, TOP_Y)
	right.add_theme_constant_override("separation", 4)
	_outfit_page.add_child(right)
	_wardrobe_title = UiStyle.label("ROPA EN LA CUSTODIA", UiStyle.SIZE_SMALL, UiStyle.ASH)
	right.add_child(_wardrobe_title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(222, 86)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_wardrobe = VBoxContainer.new()
	_wardrobe.add_theme_constant_override("separation", 2)
	scroll.add_child(_wardrobe)
	var line: ColorRect = ColorRect.new()
	line.color = Color("3a4046")
	line.custom_minimum_size = Vector2(222, 1)
	right.add_child(line)
	_outfit_name = UiStyle.label("", UiStyle.SIZE_TEXT, UiStyle.BONE)
	_outfit_name.add_theme_font_override("font", UiStyle.ui_bold())
	right.add_child(_outfit_name)
	_outfit_desc = UiStyle.label("", UiStyle.SIZE_SMALL, UiStyle.BONE_DIM)
	_outfit_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outfit_desc.custom_minimum_size = Vector2(222, 0)
	right.add_child(_outfit_desc)
	_outfit_stats = UiStyle.label("", UiStyle.MONO_SMALL, UiStyle.AMBER, UiStyle.mono())
	_outfit_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outfit_stats.custom_minimum_size = Vector2(222, 0)
	right.add_child(_outfit_stats)
	_remove_button = UiStyle.button("Quitarse")
	_remove_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_remove_button.pressed.connect(_take_off)
	right.add_child(_remove_button)
	_outfit_feedback = UiStyle.label("", UiStyle.SIZE_SMALL, UiStyle.BONE)
	_outfit_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outfit_feedback.custom_minimum_size = Vector2(222, 0)
	right.add_child(_outfit_feedback)
