class_name MessageBox
extends CanvasLayer
## Caja de texto inferior, rótulos de impacto centrados y pistas de control.
## Se añade por código: `var box := MessageBox.new(); add_child(box)`.
## `show_lines()`, `stamp()` y `wait_accept()` se usan con `await`.

signal _advanced

const CHARS_PER_SECOND: float = 45.0
const BONE: Color = Color("e8e1d3")
const BONE_DIM: Color = Color("bfb6a3")
const BOX_BG: Color = Color(0.04, 0.035, 0.07, 0.88)
## Fuente con serifa del sistema mientras no haya una fuente pixel definitiva en assets/fonts/.
const SERIF_NAMES: PackedStringArray = ["Georgia", "Times New Roman", "Liberation Serif", "DejaVu Serif", "serif"]

## Si es > 0, cada línea avanza sola tras esos segundos (solo para pruebas).
var auto_advance: float = 0.0

var _font: SystemFont
var _auto_timer: float = 0.0
var _panel: PanelContainer
var _label: Label
var _arrow: Label
var _stamp: Label
var _hint: Label
var _typed: float = 0.0
var _waiting_accept: bool = false
var _hint_tween: Tween
var _choices: PackedStringArray = []
var _choice_index: int = 0
var _choosing: bool = false
var _choice_label: Label


func _init() -> void:
	layer = 20


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = SERIF_NAMES
	_build_box()
	_build_stamp()
	_build_hint()


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	var total: int = _label.get_total_character_count()
	if _label.visible_characters >= 0 and _label.visible_characters < total:
		_typed += delta * CHARS_PER_SECOND
		_label.visible_characters = mini(int(_typed), total)
	if auto_advance > 0.0:
		_auto_timer += delta
		if _auto_timer >= auto_advance:
			_auto_timer = 0.0
			_advanced.emit()
	_arrow.visible = _is_line_complete() and fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.5


func _unhandled_input(event: InputEvent) -> void:
	if _choosing:
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up") or event.is_action_pressed(&"move_left"):
			_choice_index = posmod(_choice_index - 1, _choices.size())
			_update_choice()
		elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down") or event.is_action_pressed(&"move_right"):
			_choice_index = posmod(_choice_index + 1, _choices.size())
			_update_choice()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed(&"interact"):
			_advanced.emit()
		elif event.is_action_pressed("ui_cancel"):
			_choice_index = _choices.size() - 1
			_advanced.emit()
		return
	if not (event.is_action_pressed("ui_accept") or event.is_action_pressed(&"interact")):
		return
	if _panel.visible:
		get_viewport().set_input_as_handled()
		if _is_line_complete():
			_advanced.emit()
		else:
			_label.visible_characters = -1
	elif _waiting_accept:
		get_viewport().set_input_as_handled()
		_waiting_accept = false
		_advanced.emit()


## Muestra las líneas una a una; Intro completa la línea o pasa a la siguiente.
func show_lines(lines: PackedStringArray) -> void:
	if lines.is_empty():
		return
	_panel.visible = true
	for text: String in lines:
		_label.text = text
		_label.visible_characters = 0
		_typed = 0.0
		_auto_timer = 0.0
		await _advanced
	_panel.visible = false


## Pregunta con opciones (izquierda/derecha e Intro). Devuelve el índice elegido;
## Esc elige la última opción (pon ahí la de cancelar).
func ask(question: String, options: PackedStringArray) -> int:
	_panel.visible = true
	_label.text = question
	_label.visible_characters = -1
	_choices = options
	_choice_index = 0
	_choosing = true
	_update_choice()
	await _advanced
	_choosing = false
	_choice_label.text = ""
	_panel.visible = false
	return _choice_index


func _update_choice() -> void:
	var parts: PackedStringArray = []
	for i: int in _choices.size():
		parts.append(("▸ " if i == _choice_index else "   ") + _choices[i])
	_choice_label.text = "      ".join(parts)


## Rótulo centrado en mayúsculas (estilo sello). Aparece, se mantiene y se va.
func stamp(text: String, hold: float = 1.5) -> void:
	_stamp.text = text.to_upper()
	var tween: Tween = create_tween()
	tween.tween_property(_stamp, "modulate:a", 1.0, 0.35)
	tween.tween_interval(hold)
	tween.tween_property(_stamp, "modulate:a", 0.0, 0.6)
	await tween.finished


## Deja un rótulo fijo en pantalla (sin desvanecer). Texto vacío lo quita.
func set_stamp(text: String) -> void:
	_stamp.text = text.to_upper()
	_stamp.modulate.a = 1.0 if not text.is_empty() else 0.0


## Pista pequeña abajo a la izquierda; `duration` 0 = se queda fija.
func show_hint(text: String, duration: float = 5.0) -> void:
	if _hint_tween != null:
		_hint_tween.kill()
	_hint.text = text
	_hint.modulate.a = 0.0
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 0.9, 0.6)
	if duration > 0.0:
		_hint_tween.tween_interval(duration)
		_hint_tween.tween_property(_hint, "modulate:a", 0.0, 1.0)


## Espera a que el jugador pulse Intro.
func wait_accept() -> void:
	if auto_advance > 0.0:
		await get_tree().create_timer(auto_advance).timeout
		return
	_waiting_accept = true
	await _advanced


func is_open() -> bool:
	return _panel.visible


func _is_line_complete() -> bool:
	return _label.visible_characters < 0 or _label.visible_characters >= _label.get_total_character_count()


func _build_box() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BOX_BG
	style.border_color = Color(BONE, 0.55)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	style.content_margin_left = 14
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(20, 280)
	_panel.custom_minimum_size = Vector2(600, 64)
	_panel.size = Vector2(600, 64)
	_panel.visible = false
	add_child(_panel)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.add_theme_font_override("font", _font)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", BONE)
	_panel.add_child(_label)

	_choice_label = Label.new()
	_choice_label.add_theme_font_override("font", _font)
	_choice_label.add_theme_font_size_override("font_size", 12)
	_choice_label.add_theme_color_override("font_color", BONE)
	_choice_label.position = Vector2(40, 322)
	add_child(_choice_label)

	_arrow = Label.new()
	_arrow.text = "▼"
	_arrow.add_theme_font_size_override("font_size", 8)
	_arrow.add_theme_color_override("font_color", BONE_DIM)
	_arrow.position = Vector2(604, 330)
	_arrow.visible = false
	add_child(_arrow)


func _build_stamp() -> void:
	_stamp = Label.new()
	_stamp.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stamp.add_theme_font_override("font", _font)
	_stamp.add_theme_font_size_override("font_size", 18)
	_stamp.add_theme_color_override("font_color", BONE)
	_stamp.modulate.a = 0.0
	add_child(_stamp)


func _build_hint() -> void:
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_bottom = -22
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_override("font", _font)
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_color", BONE)
	_hint.modulate.a = 0.0
	add_child(_hint)
