class_name PauseMenu
extends CanvasLayer
## Menú de pausa (Esc). Guardar solo se puede en las grabadoras del hospital.

const TITLE_SCENE: String = "res://scenes/ui/title/title_screen.tscn"

var _box: VBoxContainer
var _resume: Button


func _init() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var title: Label = UiStyle.label("PAUSA", 16, UiStyle.BONE)
	title.position = Vector2(290, 110)
	add_child(title)
	_box = VBoxContainer.new()
	_box.position = Vector2(260, 145)
	_box.custom_minimum_size = Vector2(120, 0)
	_box.add_theme_constant_override("separation", 4)
	add_child(_box)
	_resume = UiStyle.button("Reanudar")
	_resume.pressed.connect(close)
	_box.add_child(_resume)
	var quit_title: Button = UiStyle.button("Volver al título")
	quit_title.pressed.connect(_to_title)
	_box.add_child(quit_title)
	var hint: Label = UiStyle.label("Se guarda en las grabadoras de cinta.", 8, UiStyle.ASH, UiStyle.mono())
	hint.position = Vector2(220, 210)
	add_child(hint)
	var keys: Label = UiStyle.label("WASD/flechas mover · E usar · R examinar · F linterna · Tab custodia · 1-5 bolsillos", 7, UiStyle.ASH, UiStyle.mono())
	keys.position = Vector2(110, 330)
	add_child(keys)


func open() -> void:
	visible = true
	get_tree().paused = true
	_resume.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(InputActions.PAUSE) or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close()


func _to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
