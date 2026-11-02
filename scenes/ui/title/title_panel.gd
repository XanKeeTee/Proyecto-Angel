class_name TitlePanel
extends Control
## Panel secundario del título (Cargar, Créditos): recuadro oscuro a la derecha del menú, con
## título, contenido y «Esc: volver». Se cierra con Esc o con el botón B del mando.

signal closed

var body: VBoxContainer

var _heading: Label


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
	body = VBoxContainer.new()
	body.position = Vector2(14, 36)
	body.size = Vector2(342, 148)
	body.add_theme_constant_override("separation", 3)
	add_child(body)
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
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
