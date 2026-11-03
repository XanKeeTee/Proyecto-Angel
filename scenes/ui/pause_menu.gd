class_name PauseMenu
extends CanvasLayer
## Menú de pausa (Esc). Guardar solo se puede en las grabadoras del hospital.

const TITLE_SCENE: String = "res://scenes/ui/title/title_screen.tscn"

var _box: VBoxContainer
var _resume: Button
var _options: OptionsMenu


func _init() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_options = OptionsMenu.new()
	add_child(_options)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var title: Label = UiStyle.title("PAUSA")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(640, 24)
	title.position = Vector2(0, 104)
	add_child(title)
	_box = VBoxContainer.new()
	_box.position = Vector2(245, 140)
	_box.custom_minimum_size = Vector2(150, 0)
	_box.add_theme_constant_override("separation", 5)
	add_child(_box)
	_resume = UiStyle.button("Reanudar")
	_resume.pressed.connect(close)
	_box.add_child(_resume)
	var options_button: Button = UiStyle.button("Opciones")
	options_button.pressed.connect(func() -> void:
		_options.open()
		await _options.closed
		options_button.grab_focus())
	_box.add_child(options_button)
	var quit_title: Button = UiStyle.button("Volver al título")
	quit_title.pressed.connect(_to_title)
	_box.add_child(quit_title)
	var hint: Label = UiStyle.label("Se guarda en las grabadoras de cinta.", UiStyle.MONO_SMALL, UiStyle.ASH, UiStyle.mono())
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(640, 14)
	hint.position = Vector2(0, 232)
	add_child(hint)
	var keys: Label = UiStyle.label("WASD/flechas mover · Shift correr · E usar · R examinar · F linterna · Tab custodia · 1-5 bolsillos",
		UiStyle.MONO_SMALL, UiStyle.ASH, UiStyle.mono())
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.size = Vector2(640, 14)
	keys.position = Vector2(0, 330)
	add_child(keys)


func open() -> void:
	visible = true
	get_tree().paused = true
	_resume.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and not _options.visible and (event.is_action_pressed(InputActions.PAUSE) or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close()


func _to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
