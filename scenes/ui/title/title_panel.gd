class_name TitlePanel
extends Control
## Panel secundario del título (Cargar, Créditos): recuadro oscuro a la derecha del menú, con
## título, contenido y «Esc: volver». Se cierra con Esc o con el botón B del mando.

signal closed

## Píxeles que se desplaza el contenido con arriba/abajo cuando no hay nada elegible (créditos).
const SCROLL_STEP: int = 12

var body: VBoxContainer

var _heading: Label
var _scroll: ScrollContainer


func _init(heading: String) -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	position = Vector2(240, 112)
	size = Vector2(370, 208)
	var frame: Panel = Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", UiStyle.steel_box(Color("0c0d10"), Color("3a4046"), 0.9))
	add_child(frame)
	_heading = UiStyle.label(heading, 13, UiStyle.BONE)
	_heading.position = Vector2(14, 8)
	add_child(_heading)
	var rule: ColorRect = ColorRect.new()
	rule.color = Color(UiStyle.BONE_DIM, 0.35)
	rule.position = Vector2(14, 28)
	rule.size = Vector2(342, 1)
	add_child(rule)
	# El contenido se desplaza si no cabe (los créditos crecerán con las atribuciones de sonido).
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(14, 36)
	_scroll.size = Vector2(342, 148)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	add_child(_scroll)
	body = VBoxContainer.new()
	body.custom_minimum_size = Vector2(330, 0)
	body.add_theme_constant_override("separation", 1)
	_scroll.add_child(body)
	var back: Label = UiStyle.label("Esc: volver", 8, UiStyle.ASH, UiStyle.mono())
	back.position = Vector2(14, 190)
	add_child(back)


func open() -> void:
	visible = true
	for child: Node in body.get_children():
		var control: Control = child as Control
		if control != null and control.focus_mode == Control.FOCUS_ALL:
			control.grab_focus()
			return


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif get_viewport().gui_get_focus_owner() == null or not is_ancestor_of(get_viewport().gui_get_focus_owner()):
		if event.is_action_pressed(&"ui_down"):
			_scroll.scroll_vertical += SCROLL_STEP
		elif event.is_action_pressed(&"ui_up"):
			_scroll.scroll_vertical -= SCROLL_STEP
