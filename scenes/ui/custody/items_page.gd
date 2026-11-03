class_name ItemsPage
extends Control
## Pestaña OBJETOS de la custodia: inventario en lista por categorías.
## - Izquierda: las seis categorías (con cuántos objetos hay), los atajos 1-5 y las constantes.
## - Centro: la lista de la categoría, con cantidad, estado y etiquetas (en la mano, puesto, atajo).
## - Derecha: imagen, descripción, datos (arma, ropa) y acciones del objeto elegido.
## Teclado/mando: ←/→ categoría · ↑/↓ objeto · Intro/A menú de acciones · E usar · F empuñar ·
## X examinar · C combinar · T rasgar · 1-5 atajo · Supr descartar. Ratón: clic elige, doble clic
## usa, clic derecho abre el menú.

## Pide abrir el inspector (la pantalla lo pasa al mundo).
signal inspect_requested(stack: ItemStack)

const TOP_Y: float = 50.0
const CATEGORY_RECT: Rect2 = Rect2(14, 66, 124, 144)
const LIST_RECT: Rect2 = Rect2(144, 66, 188, 266)
const PANEL: Rect2 = Rect2(338, 50, 288, 284)
const IMAGE_SIZE: float = 96.0

var character: CharacterState
## Categoría que se ve (ItemDef.Section).
var section: ItemDef.Section = ItemDef.Section.WEAPONS

var _categories: RowList
var _list: RowList
var _list_title: Label
var _entries: Array[ItemStack] = []
## Filas de ropa puesta (no está en la custodia): montón -> ranura.
var _worn_rows: Dictionary[ItemStack, int] = {}
var _combine_source: ItemStack
var _name: Label
var _meta: Label
var _desc: Label
var _stats: Label
var _image: TextureRect
var _actions: GridContainer
var _feedback: Label
var _body_bar: ProgressBar
var _mind_bar: ProgressBar
var _charge: Label
var _bleed: Label
var _shortcut_icons: Array[TextureRect] = []
var _menu_catcher: Control
var _menu: PanelContainer
var _menu_box: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()


## Rellena la página (al abrir y tras cada cambio).
func refresh() -> void:
	if character == null or _list == null:
		return
	_fill_categories()
	_fill_list()
	_fill_side()
	_show_details(selected())


## Objeto elegido en la lista, o null.
func selected() -> ItemStack:
	return _entries[_list.index] if _list != null and _list.index >= 0 and _list.index < _entries.size() else null


## Muestra una categoría (y elige su primer objeto).
func show_section(value: ItemDef.Section, play_sound: bool = true) -> void:
	if value == section and _list.index >= 0:
		return
	section = value
	_categories.select(ItemDef.SECTIONS.find(value), false)
	_list.index = 0
	_list.set_rows([])
	refresh()
	if play_sound:
		Sfx.ui(self, "inv_category", -12.0)


## Elige un objeto concreto (cambia a su categoría). Devuelve false si no está en la lista.
func select_stack(stack: ItemStack) -> bool:
	if stack == null:
		return false
	var target: ItemDef.Section = stack.def.resolved_section()
	if target != section:
		show_section(target, false)
	var i: int = _entries.find(stack)
	if i < 0:
		return false
	_list.select(i, false)
	_show_details(stack)
	return true


## Mensaje para el jugador al pie del panel.
func say(text: String) -> void:
	_feedback.text = "" if text == "·" else text


func is_menu_open() -> bool:
	return _menu != null and _menu.visible


func close_menu() -> void:
	if _menu == null:
		return
	_menu.visible = false
	_menu_catcher.visible = false


## ¿Hay algo a medias que Esc deba cancelar antes de cerrar (menú o combinar)?
func cancel_pending() -> bool:
	return is_menu_open() or _combine_source != null


## Rectángulo en pantalla de la fila elegida.
func selected_row_rect() -> Rect2:
	return _list.row_global_rect(maxi(0, _list.index))


## Cancela lo que esté a medias (menú o combinar). Devuelve true si había algo.
func cancel() -> bool:
	if is_menu_open():
		close_menu()
		return true
	if _combine_source != null:
		_combine_source = null
		say("")
		refresh()
		return true
	return false


## Teclado y mando de la página. Devuelve true si lo ha usado.
func handle_input(event: InputEvent) -> bool:
	if is_menu_open():
		return _menu_input(event)
	if event.is_action_pressed("ui_left"):
		_step_section(-1)
	elif event.is_action_pressed("ui_right"):
		_step_section(1)
	elif event.is_action_pressed("ui_up"):
		_list.move(-1)
	elif event.is_action_pressed("ui_down"):
		_list.move(1)
	elif event.is_action_pressed("ui_page_up"):
		_list.select(_list.index - _list.visible_rows())
	elif event.is_action_pressed("ui_page_down"):
		_list.select(_list.index + _list.visible_rows())
	elif event.is_action_pressed("ui_accept"):
		if _combine_source != null:
			_finish_combine(selected())
		elif selected() != null:
			open_menu(selected(), selected_row_rect().end - Vector2(60, 4))
	else:
		var key: InputEventKey = event as InputEventKey
		if key == null or not key.pressed or key.echo:
			return false
		var stack: ItemStack = selected()
		match key.keycode:
			KEY_E: _use(stack)
			KEY_X: _examine(stack)
			KEY_C: _start_combine(stack)
			KEY_T: _tear(stack)
			KEY_F: _toggle_wield(stack)
			KEY_G: _toggle_offhand(stack)
			KEY_DELETE, KEY_BACKSPACE: _discard(stack)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5: _shortcut(stack, key.keycode - KEY_1)
			_: return false
	return true


# --- acciones -------------------------------------------------------------------------------

## Acciones de un objeto: [{label, key, call}] (para el panel y el menú contextual).
func actions_for(stack: ItemStack) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if stack == null:
		return list
	if _worn_rows.has(stack):
		list.append({"label": "Quitarse", "key": "E", "call": _take_off.bind(_worn_rows[stack])})
		list.append({"label": "Examinar", "key": "X", "call": _examine.bind(stack)})
		return list
	var custody: Custody = character.custody
	if stack.def.is_wearable():
		list.append({"label": "Ponerse", "key": "E", "call": _use.bind(stack)})
	elif stack.def.usable:
		list.append({"label": stack.def.use_verb, "key": "E", "call": _use.bind(stack)})
	if stack.def.is_weapon():
		var right: bool = character.wielded() == stack
		list.append({"label": "Guardar arma" if right else "Empuñar", "key": "F", "call": _toggle_wield.bind(stack)})
		if not stack.def.weapon.two_handed:
			var left: bool = character.offhand() == stack
			list.append({"label": "Soltar (izqda.)" if left else "Mano izquierda", "key": "G",
				"call": _toggle_offhand.bind(stack)})
	list.append({"label": "Examinar", "key": "X", "call": _examine.bind(stack)})
	list.append({"label": "Combinar", "key": "C", "call": _start_combine.bind(stack)})
	if Crafting.can_tear(custody, stack):
		list.append({"label": "Rasgar (%d tiras)" % stack.def.tear_yield(), "key": "T", "call": _tear.bind(stack)})
	var pocket: int = custody.pocket_of(stack)
	if pocket >= 0:
		list.append({"label": "Quitar del atajo %d" % (pocket + 1), "key": str(pocket + 1),
			"call": _shortcut.bind(stack, pocket)})
	else:
		var free: int = custody.pockets.find(null)
		list.append({"label": "Al atajo %d" % ((free if free >= 0 else 0) + 1), "key": "1-5",
			"call": _shortcut.bind(stack, free if free >= 0 else 0)})
	if stack.def.can_discard():
		list.append({"label": "Descartar", "key": "Supr", "call": _discard.bind(stack)})
	return list


func _use(stack: ItemStack) -> void:
	if stack == null:
		return
	if _worn_rows.has(stack):
		_take_off(_worn_rows[stack])
		return
	if stack.def.is_wearable():
		var result: String = character.equip(stack)
		if result == "":
			ItemSounds.play(self, stack.def, ItemSounds.Action.EQUIP)
		say(result if result != "" else "Te pones " + stack.def.display_name.to_lower() + ".")
		refresh()
		return
	if stack.def.is_weapon() and not stack.def.usable:
		_toggle_wield(stack)
		return
	if not stack.def.usable:
		say("No se puede usar así. Quizá combinado con otra cosa.")
		return
	# El sonido de uso lo pone CustodyWorldLink al recibir EventBus.item_used.
	var text: String = character.use_item(stack)
	say(text if text != "" else "Ahora no lo necesitas.")
	refresh()


func _take_off(slot: int) -> void:
	var worn: ItemStack = character.worn(slot as ItemDef.EquipSlot)
	if worn == null:
		return
	var result: String = character.unequip(slot as ItemDef.EquipSlot)
	if result == "":
		ItemSounds.play(self, worn.def, ItemSounds.Action.UNEQUIP)
	say(result if result != "" else "Te quitas " + worn.def.display_name.to_lower() + ".")
	refresh()


func _examine(stack: ItemStack) -> void:
	if stack != null:
		inspect_requested.emit(stack)


func _start_combine(stack: ItemStack) -> void:
	if stack == null or _worn_rows.has(stack):
		return
	_combine_source = stack
	say("Combinar %s con… (elige otro objeto e Intro; Esc cancela)" % stack.def.display_name.to_lower())
	refresh()


func _finish_combine(target: ItemStack) -> void:
	var source: ItemStack = _combine_source
	_combine_source = null
	if target == null or target == source or _worn_rows.has(target):
		say("")
		refresh()
		return
	do_combine(source, target)


## Combina dos objetos (suena la receta). Devuelve el texto.
func do_combine(a: ItemStack, b: ItemStack) -> String:
	var recipe: RecipeDef = Registry.find_recipe(a.def, b.def)
	var text: String = character.custody.combine(a, b)
	if text != "" and recipe != null:
		ItemSounds.play_named(self, recipe.sound if recipe.sound != "" else "craft_combine")
	say(text if text != "" else "No encajan.")
	refresh()
	return text


func _shortcut(stack: ItemStack, index: int) -> void:
	if stack == null or _worn_rows.has(stack):
		return
	var custody: Custody = character.custody
	var current: int = custody.pocket_of(stack)
	if current == index:
		custody.from_pocket(index)
		say("Quitas %s del atajo %d." % [stack.def.display_name.to_lower(), index + 1])
	elif custody.to_pocket(stack, index):
		say("%s en el atajo %d (tecla %d)." % [stack.def.display_name, index + 1, index + 1])
	ItemSounds.play(self, stack.def, ItemSounds.Action.PLACE, -10.0)
	refresh()


func _discard(stack: ItemStack) -> void:
	if stack == null or _worn_rows.has(stack):
		return
	var text: String = character.discard(stack)
	say(text)
	refresh()


func _tear(stack: ItemStack) -> void:
	if stack == null or _worn_rows.has(stack):
		return
	if not Crafting.can_tear(character.custody, stack):
		say("Eso no se puede rasgar." if stack.def.tear_yield() <= 0 else "No puedes rasgarlo ahora.")
		return
	var text: String = Crafting.tear(character.custody, stack)
	if text != "":
		ItemSounds.play(self, stack.def, ItemSounds.Action.TEAR, -4.0)
		Crafting.discover(character.custody)
	say(text)
	refresh()


func _toggle_wield(stack: ItemStack) -> void:
	if stack == null or _worn_rows.has(stack):
		return
	if not stack.def.is_weapon():
		say("Eso no sirve como arma.")
		return
	if character.wielded() == stack:
		character.unwield()
		ItemSounds.play(self, stack.def, ItemSounds.Action.UNEQUIP)
		say("Guardas " + stack.def.display_name.to_lower() + ".")
	else:
		var result: String = character.wield(stack)
		if result == "":
			ItemSounds.play(self, stack.def, ItemSounds.Action.EQUIP)
		say(result if result != "" else "Empuñas " + stack.def.display_name.to_lower() + ".")
	refresh()


func _toggle_offhand(stack: ItemStack) -> void:
	if stack == null or _worn_rows.has(stack) or not stack.def.is_weapon():
		return
	if character.offhand() == stack:
		character.unwield_offhand()
		ItemSounds.play(self, stack.def, ItemSounds.Action.UNEQUIP)
		say("Sueltas " + stack.def.display_name.to_lower() + " de la mano izquierda.")
	else:
		var result: String = character.wield_offhand(stack)
		if result == "":
			ItemSounds.play(self, stack.def, ItemSounds.Action.EQUIP)
		say(result if result != "" else "Llevas " + stack.def.display_name.to_lower() + " en la izquierda.")
	refresh()


func _step_section(step: int) -> void:
	var i: int = ItemDef.SECTIONS.find(section)
	show_section(ItemDef.SECTIONS[posmod(i + step, ItemDef.SECTIONS.size())])


# --- menú contextual -----------------------------------------------------------------------

## Abre el menú de acciones de un objeto junto a `at` (coordenadas de pantalla).
func open_menu(stack: ItemStack, at: Vector2) -> void:
	if stack == null:
		return
	for child: Node in _menu_box.get_children():
		_menu_box.remove_child(child)
		child.queue_free()
	_menu_box.add_child(UiStyle.label(stack.def.display_name, UiStyle.SIZE_SMALL, UiStyle.ASH))
	var first: Button
	for action: Dictionary in actions_for(stack):
		var b: Button = _action_button(action, 150, true)
		b.pressed.connect(close_menu)
		_menu_box.add_child(b)
		if first == null:
			first = b
	if not stack.def.can_discard() and not _worn_rows.has(stack):
		var why: String = "Objeto principal: no se descarta" if stack.def.resolved_section() == ItemDef.Section.MAIN \
			else "Objeto clave: no se descarta"
		_menu_box.add_child(UiStyle.label(why, UiStyle.MONO_SMALL, UiStyle.ASH, UiStyle.mono()))
	_menu.visible = true
	_menu_catcher.visible = true
	_menu.reset_size()
	var s: Vector2 = _menu.get_combined_minimum_size()
	var vp: Vector2 = get_viewport_rect().size
	_menu.position = Vector2(clampf(at.x + 4, 4, vp.x - s.x - 4), clampf(at.y + 2, 4, vp.y - s.y - 4)).floor()
	if first != null:
		first.grab_focus()


func _menu_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		close_menu()
		return true
	# Las flechas e Intro las gestiona el foco de los botones del menú.
	return false


# --- relleno ---------------------------------------------------------------------------------

func _fill_categories() -> void:
	var rows: Array[Dictionary] = []
	for s: ItemDef.Section in ItemDef.SECTIONS:
		var n: int = character.custody.items_in(s).size()
		if s == ItemDef.Section.ARMOR:
			n += character.equipment.size()
		rows.append({"text": ItemDef.section_name(s), "right": str(n) if n > 0 else "",
			"dim": n == 0, "color": UiStyle.BONE if s == section else UiStyle.BONE_DIM})
	_categories.set_rows(rows)
	_categories.index = ItemDef.SECTIONS.find(section)


func _fill_list() -> void:
	var custody: Custody = character.custody
	_entries.clear()
	_worn_rows.clear()
	if section == ItemDef.Section.ARMOR:
		for slot: ItemDef.EquipSlot in [ItemDef.EquipSlot.HEAD, ItemDef.EquipSlot.BODY, ItemDef.EquipSlot.LEGS,
				ItemDef.EquipSlot.FEET]:
			var worn: ItemStack = character.worn(slot)
			if worn != null:
				_entries.append(worn)
				_worn_rows[worn] = slot
	_entries.append_array(custody.items_in(section))
	var rows: Array[Dictionary] = []
	for stack: ItemStack in _entries:
		rows.append(_row_for(stack))
	var keep: ItemStack = selected()
	_list.set_rows(rows)
	if keep != null and _entries.has(keep):
		_list.index = _entries.find(keep)
	_list_title.text = ItemDef.section_name(section).to_upper()
	if _combine_source != null:
		_list_title.text = "COMBINAR CON…"


func _row_for(stack: ItemStack) -> Dictionary:
	var row: Dictionary = {"text": stack.def.display_name, "icon": ItemThumbs.thumb(stack.def, RowList.ICON_BOX)}
	if stack.quantity > 1 or stack.def.is_stackable():
		row["right"] = "×%d" % stack.quantity
	if stack.contaminated:
		row["sub"] = "contam."
		row["sub_color"] = UiStyle.SICK_GREEN
	elif stack.def.max_charge > 0.0:
		row["sub"] = "%d %%" % roundi(stack.charge / stack.def.max_charge * 100.0)
	elif stack.def.max_durability > 0 and stack.durability < stack.def.max_durability:
		row["sub"] = "%d/%d" % [stack.durability, stack.def.max_durability]
	if _worn_rows.has(stack):
		row["tag"] = "PUESTO"
		row["tag_color"] = UiStyle.SICK_GREEN
	elif stack == character.wielded():
		row["tag"] = "DCHA"
	elif stack == character.offhand():
		row["tag"] = "IZDA"
	else:
		var pocket: int = character.custody.pocket_of(stack)
		if pocket >= 0:
			row["tag"] = str(pocket + 1)
			row["tag_color"] = UiStyle.BONE_DIM
	if stack == _combine_source:
		row["tag"] = "+"
		row["tag_color"] = UiStyle.AMBER
	return row


func _fill_side() -> void:
	var v: Vitals = character.vitals
	_body_bar.value = v.body
	_mind_bar.value = v.mind
	_bleed.visible = v.bleeding
	var lamp: ItemStack = character.flashlight()
	_charge.text = "Linterna %d %%" % roundi(lamp.charge / lamp.def.max_charge * 100.0) if lamp != null else ""
	for i: int in Custody.POCKETS:
		var stack: ItemStack = character.custody.pockets[i]
		_shortcut_icons[i].texture = ItemThumbs.thumb(stack.def, Vector2i(16, 16)) if stack != null else null


func _show_details(stack: ItemStack) -> void:
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	_image.texture = ItemThumbs.first_view(stack.def) if stack != null else null
	_stats.visible = false
	if stack == null:
		_name.text = ItemDef.section_name(section)
		_meta.text = "Nada en esta categoría"
		_desc.text = _empty_text()
		return
	_name.text = stack.def.display_name
	var meta: PackedStringArray = [ItemDef.section_name(stack.def.resolved_section())]
	if stack.def.is_stackable() or stack.quantity > 1:
		meta.append("×%d" % stack.quantity)
	var status: String = stack.status_text()
	if status != "":
		meta.append(status)
	if _worn_rows.has(stack):
		meta.append("Puesto: " + ItemDef.slot_name(stack.def.equip_slot).to_lower())
	elif stack.def.is_wearable():
		meta.append(ItemDef.slot_name(stack.def.equip_slot))
	if stack == character.wielded():
		meta.append("EN LA MANO DCHA.")
	elif stack == character.offhand():
		meta.append("EN LA MANO IZDA.")
	_meta.text = " · ".join(meta)
	_desc.text = stack.def.description
	var stats: String = item_stats_text(stack.def)
	if stats != "":
		_stats.visible = true
		_stats.text = stats
	for action: Dictionary in actions_for(stack):
		_actions.add_child(_action_button(action, 136))


## Datos de combate o de protección de un objeto (vacío si no tiene).
static func item_stats_text(def: ItemDef) -> String:
	if def.is_weapon():
		var w: WeaponDef = def.weapon
		return "Daño %d · %s · Precisión %d %%%s · %s\n%s" % [
			w.power, w.damage_type_name(), w.accuracy, (" · Crítico +%d" % w.crit_mod) if w.crit_mod > 0 else "",
			"Dos manos" if w.two_handed else "Una mano", w.effect_text()]
	if def.is_wearable():
		return "Defensa +%d · %s" % [def.defense, ItemDef.slot_name(def.equip_slot)]
	return ""


func _empty_text() -> String:
	match section:
		ItemDef.Section.WEAPONS:
			return "No llevas armas. Una palanca o un tubo servirían."
		ItemDef.Section.ARMOR:
			return "No llevas ropa de repuesto."
		ItemDef.Section.MEDICINE:
			return "Nada para curarte."
		ItemDef.Section.MAIN:
			return "Aquí irán las llaves y las piezas que abren camino."
	return "Vacío."


## Botón de una acción. Los del panel no cogen el foco (las flechas siguen moviendo la lista);
## los del menú sí (se recorren con las flechas o el mando).
func _action_button(action: Dictionary, width: float, focusable: bool = false) -> Button:
	var key: String = action["key"]
	var b: Button = UiStyle.button(action["label"] + ("  [%s]" % key if key != "" else ""))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(width, 0)
	b.clip_text = true
	b.focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
	var callback: Callable = action["call"]
	b.pressed.connect(func() -> void: callback.call())
	return b


# --- construcción ------------------------------------------------------------------------------

func _build() -> void:
	var cat_title: Label = UiStyle.label("CATEGORÍAS", UiStyle.SIZE_SMALL, UiStyle.ASH)
	cat_title.position = Vector2(CATEGORY_RECT.position.x + 2, TOP_Y)
	add_child(cat_title)
	_categories = RowList.new()
	_categories.position = CATEGORY_RECT.position
	_categories.size = CATEGORY_RECT.size
	_categories.row_height = 24.0
	_categories.show_icons = false
	_categories.active = false
	add_child(_categories)
	_categories.selected.connect(func(i: int) -> void: show_section(ItemDef.SECTIONS[i]))

	# Atajos y constantes bajo las categorías.
	var side: VBoxContainer = VBoxContainer.new()
	side.position = Vector2(CATEGORY_RECT.position.x + 2, CATEGORY_RECT.end.y + 8)
	side.add_theme_constant_override("separation", 3)
	add_child(side)
	side.add_child(UiStyle.label("ATAJOS (1-5)", UiStyle.SIZE_SMALL, UiStyle.ASH))
	var strip: HBoxContainer = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 2)
	side.add_child(strip)
	for i: int in Custody.POCKETS:
		var slot: Panel = Panel.new()
		slot.custom_minimum_size = Vector2(20, 20)
		slot.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("0e1012"), Color("3a4046"), 0.9))
		strip.add_child(slot)
		var icon: TextureRect = TextureRect.new()
		icon.position = Vector2(2, 2)
		icon.size = Vector2(16, 16)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.add_child(icon)
		var n: Label = UiStyle.label(str(i + 1), 8, UiStyle.ASH, UiStyle.mono())
		n.position = Vector2(1, -2)
		slot.add_child(n)
		_shortcut_icons.append(icon)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	side.add_child(gap)
	side.add_child(UiStyle.label("Cuerpo", UiStyle.SIZE_SMALL, UiStyle.BONE_DIM))
	_body_bar = UiStyle.bar(UiStyle.BLOOD, 100)
	side.add_child(_body_bar)
	side.add_child(UiStyle.label("Mente", UiStyle.SIZE_SMALL, UiStyle.BONE_DIM))
	_mind_bar = UiStyle.bar(Color("7a79b4"), 100)
	side.add_child(_mind_bar)
	_charge = UiStyle.label("", UiStyle.MONO_SMALL, UiStyle.BONE_DIM, UiStyle.mono())
	side.add_child(_charge)
	_bleed = UiStyle.label("SANGRADO", UiStyle.MONO_SMALL, UiStyle.BLOOD, UiStyle.mono())
	side.add_child(_bleed)

	_list_title = UiStyle.label("", UiStyle.SIZE_SMALL, UiStyle.ASH)
	_list_title.position = Vector2(LIST_RECT.position.x + 2, TOP_Y)
	add_child(_list_title)
	var list_bg: Panel = Panel.new()
	list_bg.position = LIST_RECT.position - Vector2(2, 2)
	list_bg.size = LIST_RECT.size + Vector2(4, 4)
	list_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_bg.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("0c0d0f"), Color("2e3338"), 0.9))
	add_child(list_bg)
	_list = RowList.new()
	_list.position = LIST_RECT.position
	_list.size = LIST_RECT.size
	add_child(_list)
	_list.selected.connect(func(_i: int) -> void:
		var stack: ItemStack = selected()
		if stack != null:
			ItemSounds.play(self, stack.def, ItemSounds.Action.PICK, -18.0)
		_show_details(stack))
	_list.activated.connect(func(_i: int) -> void:
		if _combine_source != null:
			_finish_combine(selected())
		else:
			_use(selected()))
	_list.context_requested.connect(func(_i: int, at: Vector2) -> void: open_menu(selected(), at))

	var panel: Panel = Panel.new()
	panel.position = PANEL.position
	panel.size = PANEL.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("15171a"), Color("2e3338"), 0.95))
	add_child(panel)
	var x: float = PANEL.position.x + 10
	var text_w: float = PANEL.size.x - 20 - IMAGE_SIZE - 6
	var body: VBoxContainer = VBoxContainer.new()
	body.position = Vector2(x, PANEL.position.y + 8)
	body.size = Vector2(PANEL.size.x - 20, PANEL.size.y - 16)
	body.add_theme_constant_override("separation", 5)
	add_child(body)
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
	_meta = UiStyle.label("", UiStyle.MONO_SMALL, UiStyle.ASH, UiStyle.mono())
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meta.custom_minimum_size = Vector2(text_w, 0)
	col.add_child(_meta)
	_desc = UiStyle.label("", UiStyle.SIZE_SMALL, UiStyle.BONE_DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(text_w, 0)
	col.add_child(_desc)
	var frame: Panel = Panel.new()
	frame.custom_minimum_size = Vector2(IMAGE_SIZE, IMAGE_SIZE)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("0c0d0f"), Color("2b2f33"), 0.9))
	top.add_child(frame)
	_image = TextureRect.new()
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.size = Vector2(IMAGE_SIZE, IMAGE_SIZE)
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_image)
	_stats = UiStyle.label("", UiStyle.MONO_SMALL, UiStyle.AMBER, UiStyle.mono())
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.custom_minimum_size = Vector2(PANEL.size.x - 20, 0)
	body.add_child(_stats)
	_actions = GridContainer.new()
	_actions.columns = 2
	_actions.add_theme_constant_override("h_separation", 4)
	_actions.add_theme_constant_override("v_separation", 3)
	body.add_child(_actions)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	_feedback = UiStyle.label("", UiStyle.SIZE_SMALL, UiStyle.BONE)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size = Vector2(PANEL.size.x - 20, 0)
	body.add_child(_feedback)
	_build_menu()


func _build_menu() -> void:
	_menu_catcher = Control.new()
	_menu_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_catcher.visible = false
	_menu_catcher.gui_input.connect(func(e: InputEvent) -> void:
		var mb: InputEventMouseButton = e as InputEventMouseButton
		if mb != null and mb.pressed:
			close_menu())
	add_child(_menu_catcher)
	_menu = PanelContainer.new()
	var style: StyleBoxFlat = UiStyle.steel_box(Color("0c0d0f"), UiStyle.BONE_DIM, 0.98)
	style.set_content_margin_all(4)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 3
	_menu.add_theme_stylebox_override("panel", style)
	_menu.visible = false
	add_child(_menu)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 1)
	_menu.add_child(_menu_box)
