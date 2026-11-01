class_name CustodyScreen
extends CanvasLayer
## Pantalla del Sistema de Custodia. Dos pestañas:
## - BANDEJA: bandeja 5x4, bolsillos, detalles del objeto y constantes.
## - EXPEDIENTE: documentos encontrados y lector.
## Pausa el juego mientras está abierta. Ratón y teclado:
##   flechas/ratón mueven · Intro coge/suelta · R gira · E usa · X examina · C combina
##   1-5 al bolsillo · Q cambia de pestaña · Tab/Esc cierra.

signal closed
## Pide abrir el inspector para un objeto (lo gestiona la escena).
signal inspect_requested(stack: ItemStack)

enum Tab { TRAY, DOSSIER }

const SLIDE: float = 14.0

var character: CharacterState
var _tab: Tab = Tab.TRAY
var _combine_source: ItemStack
var _root: Control
var _dim: ColorRect
var _tray: TrayView
var _tab_buttons: Array[Button] = []
var _tray_page: Control
var _dossier_page: Control
var _name: Label
var _meta: Label
var _desc: Label
var _actions: VBoxContainer
var _feedback: Label
var _body_bar: ProgressBar
var _mind_bar: ProgressBar
var _bleed: Label
var _charge: Label
var _doc_list: VBoxContainer
var _doc_paper: PanelContainer
var _doc_title: Label
var _doc_meta: Label
var _doc_body: RichTextLabel
var _doc_image: TextureRect
var _doc_stamp: Label
var _current_doc: StringName = &""


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
	_root.modulate.a = 0.0
	_root.position.y = SLIDE
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_root, "modulate:a", 1.0, 0.18)
	tween.tween_property(_root, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_dim.color.a = 0.0
	tween.tween_property(_dim, "color:a", 0.78, 0.2)
	_tray.grab_focus()
	_refresh()


func close() -> void:
	if not visible:
		return
	_tray.cancel()
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
		_set_tab(Tab.DOSSIER if _tab == Tab.TRAY else Tab.TRAY)
		get_viewport().set_input_as_handled()
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
	if not stack.def.usable:
		_say("No se puede usar así. Quizá combinado con otra cosa.")
		return
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


func _do_combine(a: ItemStack, b: ItemStack) -> void:
	var text: String = character.custody.combine(a, b)
	_say(text if text != "" else "No encajan.")
	_refresh()


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
	_refresh()


func _say(text: String) -> void:
	_feedback.text = "" if text == "·" else text


# --- refresco -------------------------------------------------------------------------------

func _refresh() -> void:
	if character == null:
		return
	var v: Vitals = character.vitals
	_body_bar.value = v.body
	_mind_bar.value = v.mind
	_bleed.visible = v.bleeding
	var lamp: ItemStack = character.flashlight()
	_charge.text = "Linterna: %d %%" % roundi(lamp.charge / lamp.def.max_charge * 100.0) if lamp != null else ""
	_show_details(_tray.selected())
	if _tab == Tab.DOSSIER:
		_fill_dossier()


func _show_details(stack: ItemStack) -> void:
	for child: Node in _actions.get_children():
		child.queue_free()
	if stack == null:
		_name.text = "—"
		_meta.text = "Casilla vacía."
		_desc.text = "Arrastra los objetos para ordenarlos. Suelta uno sobre otro para combinarlos."
		return
	_name.text = stack.def.display_name
	var fp: Vector2i = stack.def.size
	var meta: PackedStringArray = ["%d×%d" % [fp.x, fp.y]]
	if stack.def.is_stackable():
		meta.append("%d / %d" % [stack.quantity, stack.def.max_stack])
	var status: String = stack.status_text()
	if status != "":
		meta.append(status)
	if stack.def.key_item:
		meta.append("Objeto clave")
	_meta.text = "  ·  ".join(meta)
	_desc.text = stack.def.description
	if stack.def.usable:
		_add_action(stack.def.use_verb + "  [E]", _use.bind(stack))
	_add_action("Examinar  [X]", _examine.bind(stack))
	_add_action("Combinar  [C]", _start_combine.bind(stack))
	var in_pocket: bool = character.custody.pockets.has(stack)
	if in_pocket:
		_add_action("Devolver a la bandeja", _to_pocket.bind(stack, character.custody.pockets.find(stack)))
	else:
		var free: int = character.custody.pockets.find(null)
		if free >= 0:
			_add_action("Al bolsillo %d  [1-5]" % (free + 1), _to_pocket.bind(stack, free))
	if not in_pocket and stack.def.size.x != stack.def.size.y:
		_add_action("Girar  [R]", _tray.rotate_held)


func _add_action(text: String, callback: Callable) -> void:
	var b: Button = UiStyle.button(text)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void:
		callback.call()
		_refresh())
	_actions.add_child(b)


# --- expediente ------------------------------------------------------------------------------

func _set_tab(tab: Tab) -> void:
	_tab = tab
	_tray_page.visible = tab == Tab.TRAY
	_dossier_page.visible = tab == Tab.DOSSIER
	for i: int in _tab_buttons.size():
		_tab_buttons[i].modulate = Color.WHITE if i == tab else Color(1, 1, 1, 0.45)
	if tab == Tab.DOSSIER:
		_fill_dossier()
		if _current_doc == &"" and not character.custody.documents.is_empty():
			_show_document(character.custody.documents[-1])
	else:
		_tray.grab_focus()


func _fill_dossier() -> void:
	for child: Node in _doc_list.get_children():
		child.queue_free()
	var custody: Custody = character.custody
	if custody.documents.is_empty():
		_doc_list.add_child(UiStyle.label("Ningún documento todavía.", 10, UiStyle.ASH))
		return
	for id: StringName in custody.documents:
		var doc: DocumentDef = Registry.document(id)
		if doc == null:
			continue
		var mark: String = "• " if custody.is_unread(id) else "   "
		var b: Button = UiStyle.button(mark + doc.title)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size = Vector2(178, 0)
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
	var font: Font = UiStyle.hand() if doc.style == DocumentDef.Style.HANDWRITTEN else UiStyle.mono()
	_doc_body.add_theme_font_override("normal_font", font)
	_doc_body.text = doc.body
	_doc_image.texture = doc.image
	_doc_image.visible = doc.image != null
	_doc_stamp.text = doc.stamp
	_doc_stamp.visible = doc.stamp != ""
	_doc_paper.modulate.a = 0.0
	create_tween().tween_property(_doc_paper, "modulate:a", 1.0, 0.2)
	_fill_dossier()


# --- construcción ------------------------------------------------------------------------------

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.78)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var frame: Panel = Panel.new()
	frame.position = Vector2(12, 10)
	frame.size = Vector2(616, 340)
	frame.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("101214"), Color("3a4046"), 0.97))
	_root.add_child(frame)

	var title: Label = UiStyle.label("REGISTRO DE CUSTODIA", 13, UiStyle.BONE)
	title.position = Vector2(26, 16)
	_root.add_child(title)
	var who: Label = UiStyle.label("PACIENTE 09  ·  HAB. 09  ·  PERTENENCIAS", 8, UiStyle.ASH, UiStyle.mono())
	who.position = Vector2(26, 34)
	_root.add_child(who)
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.position = Vector2(410, 16)
	_root.add_child(tabs)
	for i: int in 2:
		var b: Button = UiStyle.button(["BANDEJA", "EXPEDIENTE"][i])
		b.pressed.connect(_set_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	var hint: Label = UiStyle.label("Q pestaña  ·  Tab cerrar", 7, UiStyle.ASH, UiStyle.mono())
	hint.position = Vector2(520, 36)
	_root.add_child(hint)
	var line: ColorRect = ColorRect.new()
	line.color = Color("3a4046")
	line.position = Vector2(22, 48)
	line.size = Vector2(596, 1)
	_root.add_child(line)

	_build_tray_page()
	_build_dossier_page()


func _build_tray_page() -> void:
	_tray_page = Control.new()
	_tray_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tray_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tray_page)

	_tray = TrayView.new()
	_tray.position = Vector2(24, 58)
	_tray_page.add_child(_tray)
	_tray.selection_changed.connect(func(_s: ItemStack) -> void: _refresh())
	_tray.activated.connect(_use)
	_tray.feedback.connect(_say)
	_tray.combine_requested.connect(_do_combine)

	# Constantes.
	var vit: VBoxContainer = VBoxContainer.new()
	vit.position = Vector2(26, 274)
	vit.add_theme_constant_override("separation", 3)
	_tray_page.add_child(vit)
	vit.add_child(UiStyle.label("CONSTANTES", 8, UiStyle.ASH, UiStyle.mono()))
	var row1: HBoxContainer = HBoxContainer.new()
	row1.add_child(UiStyle.label("Cuerpo", 9, UiStyle.BONE_DIM))
	_body_bar = UiStyle.bar(UiStyle.BLOOD)
	_body_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row1.add_child(_body_bar)
	vit.add_child(row1)
	var row2: HBoxContainer = HBoxContainer.new()
	row2.add_child(UiStyle.label("Mente ", 9, UiStyle.BONE_DIM))
	_mind_bar = UiStyle.bar(Color("6b6aa0"))
	_mind_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row2.add_child(_mind_bar)
	vit.add_child(row2)
	_bleed = UiStyle.label("Sangrado: los puntos se han abierto", 8, UiStyle.BLOOD, UiStyle.mono())
	vit.add_child(_bleed)
	_charge = UiStyle.label("", 8, UiStyle.BONE_DIM, UiStyle.mono())
	vit.add_child(_charge)

	# Detalles.
	var details: PanelContainer = PanelContainer.new()
	details.position = Vector2(212, 58)
	details.custom_minimum_size = Vector2(404, 280)
	details.size = Vector2(404, 280)
	details.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("15171a"), Color("2e3338"), 0.95))
	_tray_page.add_child(details)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	details.add_child(box)
	_name = UiStyle.label("", 14, UiStyle.BONE)
	box.add_child(_name)
	_meta = UiStyle.label("", 8, UiStyle.ASH, UiStyle.mono())
	box.add_child(_meta)
	_desc = UiStyle.label("", 10, UiStyle.BONE_DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(380, 70)
	box.add_child(_desc)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 2)
	box.add_child(_actions)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	_feedback = UiStyle.label("", 10, UiStyle.BONE)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size = Vector2(380, 0)
	box.add_child(_feedback)


func _build_dossier_page() -> void:
	_dossier_page = Control.new()
	_dossier_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dossier_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dossier_page)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(24, 58)
	scroll.size = Vector2(186, 280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dossier_page.add_child(scroll)
	_doc_list = VBoxContainer.new()
	_doc_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_doc_list)

	_doc_paper = PanelContainer.new()
	_doc_paper.position = Vector2(222, 56)
	_doc_paper.size = Vector2(392, 284)
	_doc_paper.custom_minimum_size = Vector2(392, 284)
	_doc_paper.add_theme_stylebox_override("panel", UiStyle.paper_box())
	_doc_paper.visible = false
	_dossier_page.add_child(_doc_paper)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_doc_paper.add_child(col)
	_doc_title = UiStyle.label("", 13, UiStyle.INK)
	col.add_child(_doc_title)
	_doc_meta = UiStyle.label("", 8, Color("5a5244"), UiStyle.mono())
	col.add_child(_doc_meta)
	_doc_image = TextureRect.new()
	_doc_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_doc_image.custom_minimum_size = Vector2(360, 120)
	_doc_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	col.add_child(_doc_image)
	_doc_body = RichTextLabel.new()
	_doc_body.bbcode_enabled = true
	_doc_body.fit_content = false
	_doc_body.scroll_active = true
	_doc_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_doc_body.custom_minimum_size = Vector2(360, 150)
	_doc_body.add_theme_color_override("default_color", Color("2a2620"))
	_doc_body.add_theme_font_size_override("normal_font_size", 10)
	_doc_body.add_theme_font_override("bold_font", UiStyle.mono())
	col.add_child(_doc_body)
	_doc_stamp = UiStyle.label("", 14, Color(0.6, 0.1, 0.1, 0.75), UiStyle.mono())
	_doc_stamp.rotation = -0.18
	_doc_stamp.position = Vector2(470, 70)
	_dossier_page.add_child(_doc_stamp)
