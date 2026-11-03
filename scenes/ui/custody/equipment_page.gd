class_name EquipmentPage
extends Control
## Pestaña EQUIPO de la custodia (al estilo de Fear & Hunger): el personaje con lo que lleva,
## sus ranuras (mano derecha, mano izquierda, cabeza, cuerpo, piernas, pies), sus estadísticas y
## las de lo equipado, y la lista de lo que se puede poner en la ranura elegida.
## Teclado/mando: ↑/↓ ranura · Intro/→ elegir de la lista · ↑/↓ e Intro equipar · ←/Esc volver ·
## Supr quitar · < > girar el retrato (Z / V). Ratón: clic en ranura y en la lista; doble clic equipa.

const TOP_Y: float = 50.0
const LEFT_X: float = 14.0
## Ranuras de las manos (no son EquipSlot: las armas siguen en la custodia).
const HAND_R: int = 100
const HAND_L: int = 101
const SLOT_ORDER: Array[int] = [
	HAND_R, HAND_L, ItemDef.EquipSlot.HEAD, ItemDef.EquipSlot.BODY, ItemDef.EquipSlot.LEGS, ItemDef.EquipSlot.FEET,
]
const STAGE: Rect2 = Rect2(14, 50, 150, 284)
const SLOTS_RECT: Rect2 = Rect2(170, 66, 188, 168)
const RIGHT_X: float = 364.0
const RIGHT_W: float = 262.0

var character: CharacterState

var _preview: OutfitPreview
var _slots: RowList
var _candidates: RowList
var _candidate_stacks: Array[ItemStack] = []
var _list_title: Label
var _name: Label
var _desc: Label
var _item_stats: Label
var _stats: Label
var _equip_button: Button
var _remove_button: Button
var _feedback: Label
## 0 = ranuras, 1 = lista de candidatos.
var _zone: int = 0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()


## Ranura elegida (HAND_R, HAND_L o una ItemDef.EquipSlot).
func selected_slot() -> int:
	return SLOT_ORDER[clampi(_slots.index, 0, SLOT_ORDER.size() - 1)]


## Rellena la página.
func refresh() -> void:
	if character == null or _slots == null:
		return
	_preview.character = character
	_preview.refresh()
	_fill_slots()
	_fill_candidates()
	_fill_details()
	_stats.text = stats_text()


## Elige una ranura (y vuelve a la columna de ranuras).
func select_slot(slot: int) -> void:
	var i: int = SLOT_ORDER.find(slot)
	if i < 0:
		return
	_zone = 0
	_slots.select(i, false)
	_feedback.text = ""
	refresh()


## Equipa en la ranura elegida (null = dejarla vacía). Devuelve el texto para el jugador.
func equip_in_slot(stack: ItemStack) -> String:
	var slot: int = selected_slot()
	var text: String = ""
	if stack == null:
		text = _clear_slot(slot)
	elif slot == HAND_R:
		if character.wielded() == stack:
			return ""
		text = character.wield(stack)
		if text == "":
			ItemSounds.play(self, stack.def, ItemSounds.Action.EQUIP)
			text = "Empuñas " + stack.def.display_name.to_lower() + "."
	elif slot == HAND_L:
		if character.offhand() == stack:
			return ""
		text = character.wield_offhand(stack)
		if text == "":
			ItemSounds.play(self, stack.def, ItemSounds.Action.EQUIP)
			text = "Llevas " + stack.def.display_name.to_lower() + " en la mano izquierda."
	else:
		text = character.equip(stack)
		if text == "":
			ItemSounds.play(self, stack.def, ItemSounds.Action.EQUIP)
			text = "Te pones " + stack.def.display_name.to_lower() + "."
	_feedback.text = text
	refresh()
	return text


## Quita lo que haya en la ranura elegida.
func clear_selected() -> String:
	var text: String = _clear_slot(selected_slot())
	_feedback.text = text
	refresh()
	return text


## Lo que hay en una ranura (arma o prenda), o null.
func item_in(slot: int) -> ItemStack:
	match slot:
		HAND_R:
			return character.wielded()
		HAND_L:
			return character.offhand()
	return character.worn(slot as ItemDef.EquipSlot)


## Lo que se puede poner en la ranura elegida (montones de la custodia).
func candidates() -> Array[ItemStack]:
	return _candidate_stacks.filter(func(s: ItemStack) -> bool: return s != null)


## Teclado y mando. Devuelve true si lo ha usado.
func handle_input(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_Z:
				_preview.turn(-1)
				return true
			KEY_V:
				_preview.turn(1)
				return true
			KEY_DELETE, KEY_BACKSPACE:
				clear_selected()
				return true
	if _zone == 0:
		if event.is_action_pressed("ui_up"):
			_slots.move(-1)
		elif event.is_action_pressed("ui_down"):
			_slots.move(1)
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_right"):
			if not _candidate_stacks.is_empty():
				_zone = 1
				_candidates.select(maxi(0, _candidates.index), false)
				_fill_activity()
				_fill_details()
		else:
			return false
		return true
	if event.is_action_pressed("ui_up"):
		_candidates.move(-1)
	elif event.is_action_pressed("ui_down"):
		_candidates.move(1)
	elif event.is_action_pressed("ui_accept"):
		equip_in_slot(_candidate_at(_candidates.index))
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_cancel"):
		_zone = 0
		_fill_activity()
		_fill_details()
	else:
		return false
	return true


## Depuración: elige un objeto en la lista de la ranura (sin equiparlo).
func debug_pick(stack: ItemStack) -> void:
	var i: int = _candidate_stacks.find(stack)
	if i < 0:
		return
	_zone = 1
	_candidates.select(i, false)
	_fill_activity()
	_fill_details()


## ¿Está eligiendo de la lista? (Esc vuelve a las ranuras en vez de cerrar.)
func is_choosing() -> bool:
	return _zone == 1


## Estadísticas del personaje y de lo equipado (texto en columnas).
func stats_text() -> String:
	var lines: PackedStringArray = []
	var v: Vitals = character.vitals
	lines.append("Cuerpo %3d/%d   Mente %3d/%d" % [v.body, Vitals.MAX, v.mind, Vitals.MAX])
	var sheet: CombatantDef = character.combat_sheet()
	if sheet != null:
		lines.append("Fuerza   %2d   Destreza %2d" % [sheet.strength, sheet.dexterity])
		lines.append("Agilidad %2d   Voluntad %2d" % [sheet.agility, sheet.willpower])
		lines.append("Aguante  %2d   Defensa  %2d" % [sheet.resilience, character.defense()])
	else:
		lines.append("Defensa %d" % character.defense())
	var right: ItemStack = character.wielded()
	var left: ItemStack = character.offhand()
	if right != null:
		var w: WeaponDef = right.def.weapon
		lines.append("Ataque %d %s · %d %%%s" % [w.power, w.damage_type_name().to_lower(), w.accuracy,
			" · crít. +%d" % w.crit_mod if w.crit_mod > 0 else ""])
	else:
		lines.append("Ataque: manos desnudas")
	if left != null:
		lines.append("Izqda.: %d %s · %d %%" % [left.def.weapon.power, left.def.weapon.damage_type_name().to_lower(),
			left.def.weapon.accuracy])
	return "\n".join(lines)


# --- interno ---------------------------------------------------------------------------------

func _clear_slot(slot: int) -> String:
	var current: ItemStack = item_in(slot)
	if current == null:
		return ""
	match slot:
		HAND_R:
			character.unwield()
		HAND_L:
			character.unwield_offhand()
		_:
			var result: String = character.unequip(slot as ItemDef.EquipSlot)
			if result != "":
				return result
	ItemSounds.play(self, current.def, ItemSounds.Action.UNEQUIP)
	if slot == HAND_R or slot == HAND_L:
		return "Guardas " + current.def.display_name.to_lower() + "."
	return "Te quitas " + current.def.display_name.to_lower() + "."


func _slot_caption(slot: int) -> String:
	match slot:
		HAND_R:
			return "MANO DERECHA"
		HAND_L:
			return "MANO IZQUIERDA"
	return ItemDef.slot_name(slot as ItemDef.EquipSlot).to_upper()


## «Mano derecha», «Cabeza»…
func _slot_title(slot: int) -> String:
	var text: String = _slot_caption(slot).to_lower()
	return text.left(1).to_upper() + text.substr(1)


func _fill_slots() -> void:
	var rows: Array[Dictionary] = []
	var right: ItemStack = character.wielded()
	for slot: int in SLOT_ORDER:
		var stack: ItemStack = item_in(slot)
		var row: Dictionary = {"caption": _slot_caption(slot), "text": stack.def.display_name if stack != null else "—"}
		if stack != null:
			row["icon"] = ItemThumbs.thumb(stack.def, RowList.ICON_BOX)
			row["color"] = UiStyle.BONE
		else:
			row["color"] = UiStyle.ASH
		if slot == HAND_L and stack == null and right != null and right.def.weapon.two_handed:
			row["text"] = "(" + right.def.display_name.to_lower() + ": dos manos)"
			row["dim"] = true
		if slot >= HAND_R and stack != null:
			row["right"] = str(stack.def.weapon.power)
		elif stack != null and stack.def.defense > 0:
			row["right"] = "+%d" % stack.def.defense
		rows.append(row)
	_slots.set_rows(rows)
	_fill_activity()


func _fill_candidates() -> void:
	var slot: int = selected_slot()
	var custody: Custody = character.custody
	_candidate_stacks.clear()
	var current: ItemStack = item_in(slot)
	if current != null:
		_candidate_stacks.append(null)  # «Quitar»
	for stack: ItemStack in custody.items:
		var fits: bool = false
		if slot == HAND_R or slot == HAND_L:
			fits = stack.def.is_weapon()
		else:
			fits = stack.def.is_wearable() and stack.def.equip_slot == slot
		if fits:
			_candidate_stacks.append(stack)
	var rows: Array[Dictionary] = []
	for stack: ItemStack in _candidate_stacks:
		if stack == null:
			rows.append({"text": "Manos vacías" if slot >= HAND_R else "Quitar " + current.def.display_name.to_lower(),
				"color": UiStyle.ASH})
			continue
		var row: Dictionary = {"text": stack.def.display_name, "icon": ItemThumbs.thumb(stack.def, RowList.ICON_BOX)}
		if stack.def.is_weapon():
			row["right"] = "%d · %d%%" % [stack.def.weapon.power, stack.def.weapon.accuracy]
			if stack == character.wielded():
				row["tag"] = "DCHA"
			elif stack == character.offhand():
				row["tag"] = "IZDA"
			if slot == HAND_L and (stack.def.weapon.two_handed or _right_is_two_handed(stack)):
				row["dim"] = true
		elif stack.def.defense > 0:
			row["right"] = "+%d" % stack.def.defense
		rows.append(row)
	_candidates.set_rows(rows)
	if _candidates.index < 0 and not rows.is_empty():
		_candidates.index = 0
	if slot == HAND_R or slot == HAND_L:
		_list_title.text = "ARMAS EN LA CUSTODIA"
	else:
		_list_title.text = ItemDef.slot_name(slot as ItemDef.EquipSlot).to_upper() + ": ROPA EN LA CUSTODIA"


func _right_is_two_handed(candidate: ItemStack) -> bool:
	var right: ItemStack = character.wielded()
	return right != null and right != candidate and right.def.weapon.two_handed


func _candidate_at(i: int) -> ItemStack:
	return _candidate_stacks[i] if i >= 0 and i < _candidate_stacks.size() else null


func _fill_activity() -> void:
	_slots.active = _zone == 0
	_candidates.active = _zone == 1
	_slots.queue_redraw()
	_candidates.queue_redraw()


## Panel de la derecha: lo que se mira (el candidato elegido o lo que hay en la ranura).
func _fill_details() -> void:
	var slot: int = selected_slot()
	var current: ItemStack = item_in(slot)
	var looking: ItemStack = _candidate_at(_candidates.index) if _zone == 1 else current
	if _candidate_stacks.is_empty():
		var none: String = "No llevas armas. Una palanca o un tubo servirían." if slot >= HAND_R \
			else "No llevas ropa de repuesto para esta ranura."
		_name.text = _slot_title(slot)
		_desc.text = (current.def.description + "\n\n" if current != null else "") + none
		_item_stats.text = ItemsPage.item_stats_text(current.def) if current != null else ""
	elif looking == null:
		_name.text = current.def.display_name if current != null and _zone == 0 else _slot_title(slot)
		_desc.text = "Intro o → para elegir de la lista." if current == null else "Dejar la ranura vacía."
		_item_stats.text = ""
	else:
		_name.text = looking.def.display_name
		_desc.text = looking.def.description
		_item_stats.text = ItemsPage.item_stats_text(looking.def) + _compare(looking, current)
	_item_stats.visible = _item_stats.text != ""
	_equip_button.visible = _zone == 1 and looking != null and looking != current
	_remove_button.visible = current != null


## Comparación con lo que ya hay en la ranura («Daño 12 → 13»).
func _compare(candidate: ItemStack, current: ItemStack) -> String:
	if current == null or candidate == current:
		return ""
	if candidate.def.is_weapon() and current.def.is_weapon():
		var a: WeaponDef = current.def.weapon
		var b: WeaponDef = candidate.def.weapon
		return "\nAhora: daño %d → %d · precisión %d → %d %%" % [a.power, b.power, a.accuracy, b.accuracy]
	if candidate.def.is_wearable() and current.def.is_wearable():
		return "\nAhora: defensa %d → %d" % [current.def.defense, candidate.def.defense]
	return ""


func _build() -> void:
	var stage: Panel = Panel.new()
	stage.position = STAGE.position
	stage.size = STAGE.size
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("0c0d0f"), Color("2e3338"), 0.95))
	add_child(stage)
	_preview = OutfitPreview.new()
	_preview.position = Vector2(STAGE.position.x + floorf((STAGE.size.x - _preview.size.x) / 2.0), STAGE.position.y + 22)
	add_child(_preview)
	var who: Label = UiStyle.label("PACIENTE 09", UiStyle.MONO_SMALL, UiStyle.ASH, UiStyle.mono())
	who.position = Vector2(STAGE.position.x + 8, STAGE.position.y + 6)
	add_child(who)
	var turn_left: Button = UiStyle.button("<")
	turn_left.focus_mode = Control.FOCUS_NONE
	turn_left.position = Vector2(STAGE.position.x + 8, STAGE.end.y - 30)
	turn_left.pressed.connect(func() -> void: _preview.turn(-1))
	add_child(turn_left)
	var turn_right: Button = UiStyle.button(">")
	turn_right.focus_mode = Control.FOCUS_NONE
	turn_right.position = Vector2(STAGE.end.x - 30, STAGE.end.y - 30)
	turn_right.pressed.connect(func() -> void: _preview.turn(1))
	add_child(turn_right)
	var turn_hint: Label = UiStyle.label("girar Z / V", UiStyle.MONO_SMALL, UiStyle.ASH, UiStyle.mono())
	turn_hint.position = Vector2(STAGE.position.x + 44, STAGE.end.y - 26)
	add_child(turn_hint)

	var slots_title: Label = UiStyle.label("EQUIPO", UiStyle.SIZE_SMALL, UiStyle.ASH)
	slots_title.position = Vector2(SLOTS_RECT.position.x + 2, TOP_Y)
	add_child(slots_title)
	_slots = RowList.new()
	_slots.position = SLOTS_RECT.position
	_slots.size = SLOTS_RECT.size
	_slots.row_height = 28.0
	add_child(_slots)
	_slots.index = 0
	_slots.selected.connect(func(_i: int) -> void:
		_zone = 0
		_candidates.index = 0
		_feedback.text = ""
		refresh())
	_slots.activated.connect(func(_i: int) -> void:
		if not _candidate_stacks.is_empty():
			_zone = 1
			_fill_activity()
			_fill_details())

	var stats_title: Label = UiStyle.label("ESTADÍSTICAS", UiStyle.SIZE_SMALL, UiStyle.ASH)
	stats_title.position = Vector2(SLOTS_RECT.position.x + 2, SLOTS_RECT.end.y + 2)
	add_child(stats_title)
	_stats = UiStyle.label("", UiStyle.MONO_SMALL, UiStyle.BONE_DIM, UiStyle.mono())
	_stats.position = Vector2(SLOTS_RECT.position.x + 2, SLOTS_RECT.end.y + 16)
	_stats.custom_minimum_size = Vector2(SLOTS_RECT.size.x, 0)
	add_child(_stats)

	var right: VBoxContainer = VBoxContainer.new()
	right.position = Vector2(RIGHT_X, TOP_Y)
	right.add_theme_constant_override("separation", 4)
	add_child(right)
	_list_title = UiStyle.label("", UiStyle.SIZE_SMALL, UiStyle.ASH)
	right.add_child(_list_title)
	var list_bg: Panel = Panel.new()
	list_bg.custom_minimum_size = Vector2(RIGHT_W, 112)
	list_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_bg.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("0c0d0f"), Color("2e3338"), 0.9))
	right.add_child(list_bg)
	_candidates = RowList.new()
	_candidates.position = Vector2(2, 2)
	_candidates.size = Vector2(RIGHT_W - 4, 108)
	_candidates.active = false
	list_bg.add_child(_candidates)
	_candidates.selected.connect(func(_i: int) -> void:
		_zone = 1
		_fill_activity()
		_fill_details())
	_candidates.activated.connect(func(i: int) -> void: equip_in_slot(_candidate_at(i)))
	_name = UiStyle.label("", UiStyle.SIZE_TEXT, UiStyle.BONE)
	_name.add_theme_font_override("font", UiStyle.ui_bold())
	right.add_child(_name)
	_desc = UiStyle.label("", UiStyle.SIZE_SMALL, UiStyle.BONE_DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(RIGHT_W, 0)
	right.add_child(_desc)
	_item_stats = UiStyle.label("", UiStyle.MONO_SMALL, UiStyle.AMBER, UiStyle.mono())
	_item_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_stats.custom_minimum_size = Vector2(RIGHT_W, 0)
	right.add_child(_item_stats)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	right.add_child(buttons)
	_equip_button = UiStyle.button("Equipar  [Intro]")
	_equip_button.focus_mode = Control.FOCUS_NONE
	_equip_button.pressed.connect(func() -> void: equip_in_slot(_candidate_at(_candidates.index)))
	buttons.add_child(_equip_button)
	_remove_button = UiStyle.button("Quitar  [Supr]")
	_remove_button.focus_mode = Control.FOCUS_NONE
	_remove_button.pressed.connect(clear_selected)
	buttons.add_child(_remove_button)
	_feedback = UiStyle.label("", UiStyle.SIZE_SMALL, UiStyle.BONE)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size = Vector2(RIGHT_W, 0)
	right.add_child(_feedback)
