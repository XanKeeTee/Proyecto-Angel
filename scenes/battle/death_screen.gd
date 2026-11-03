class_name DeathScreen
extends CanvasLayer
## Pantalla de muerte `[PROPUESTA]`: la cinta se corta entre nieve y se ofrece volver a la última
## cinta grabada (si hay) o al título. Debajo del filtro VHS para que se vea como el resto.
## Uso: `var screen := DeathScreen.new(); add_child(screen); var choice := await screen.choose(hay_cinta)`.

signal chosen(choice: Choice)

enum Choice { LOAD, TITLE }

const NOISE_SHADER: Shader = preload("res://shaders/tape_noise.gdshader")
const TITLE_TEXT: String = "FIN DE LA CINTA"
const SUBTITLE_TEXT: String = "La vigilia termina aquí."
const OPTION_LOAD: String = "Volver a la última cinta"
const OPTION_TITLE: String = "Volver al título"

var _black: ColorRect
var _noise: ColorRect
var _noise_material: ShaderMaterial
var _box: VBoxContainer
var _buttons: Array[Button] = []


func _init() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_black = ColorRect.new()
	_black.color = Color(0.0, 0.0, 0.0, 0.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_black)
	_noise_material = ShaderMaterial.new()
	_noise_material.shader = NOISE_SHADER
	_noise_material.set_shader_parameter(&"amount", 0.0)
	_noise = ColorRect.new()
	_noise.material = _noise_material
	_noise.set_anchors_preset(Control.PRESET_FULL_RECT)
	_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_noise)
	_box = VBoxContainer.new()
	_box.position = Vector2(0, 120)
	_box.size = Vector2(640, 160)
	_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_box.add_theme_constant_override("separation", 6)
	_box.modulate.a = 0.0
	add_child(_box)
	var title: Label = UiStyle.label(TITLE_TEXT, UiStyle.SIZE_TITLE, UiStyle.BLOOD.lightened(0.15), UiStyle.pixel())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	var subtitle: Label = UiStyle.label(SUBTITLE_TEXT, UiStyle.SIZE_TEXT, UiStyle.ASH)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(subtitle)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	_box.add_child(spacer)


## Muestra la pantalla y espera la elección. Sin cinta grabada solo se puede volver al título.
func choose(has_save: bool) -> Choice:
	if has_save:
		_add_option(OPTION_LOAD, Choice.LOAD)
	_add_option(OPTION_TITLE, Choice.TITLE)
	var tween: Tween = create_tween()
	tween.tween_property(_black, "color:a", 1.0, 1.2)
	tween.parallel().tween_method(_set_noise, 0.9, 0.12, 2.0)
	tween.tween_property(_box, "modulate:a", 1.0, 0.8)
	await tween.finished
	_buttons[0].grab_focus()
	var choice: Choice = await chosen
	return choice


func _add_option(text: String, choice: Choice) -> void:
	var button: Button = UiStyle.button(text, UiStyle.SIZE_TEXT)
	button.custom_minimum_size = Vector2(220, 0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void: chosen.emit(choice))
	_box.add_child(button)
	_buttons.append(button)


func _set_noise(value: float) -> void:
	_noise_material.set_shader_parameter(&"amount", value)
