class_name MessageWindow
extends Control
## Ventana de mensajes de arriba, en una placa de chapa oxidada: enseña 1-2 líneas cada vez de lo
## que pasa al resolver; cada mensaje se queda un rato y pasa solo al siguiente (o antes, con Intro
## o un clic). Lo dicho no se pierde: también va al registro (`BattleLog`).
## Cuando no queda nada por contar enseña el mensaje fijo (`set_sticky`): lo que prepara el enemigo
## o los datos de la parte apuntada. Todo lo dicho queda en `history`.

const MAX_LINES: int = 2
const LINE_HEIGHT: float = 16.0
const PAD: Vector2 = Vector2(13, 8)
const FONT_SIZE: int = UiStyle.SIZE_TEXT

## Segundos que se queda cada mensaje, más un poco por letra.
var line_seconds: float = 0.9
var per_char: float = 0.02
## Todo lo que se ha contado (texto plano), en orden.
var history: PackedStringArray = []

var _queue: Array[Dictionary] = []
var _shown: Array[Dictionary] = []
var _timer: float = 0.0
var _sticky: Array[Dictionary] = []
var _showing_sticky: bool = false
var _label: RichTextLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.position = PAD
	_label.size = size - PAD * 2.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("normal_font", UiStyle.ui())
	_label.add_theme_font_override("bold_font", UiStyle.ui_bold())
	_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_label.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	_label.add_theme_constant_override("line_separation", 2)
	_label.add_theme_color_override("default_color", UiStyle.BONE)
	add_child(_label)
	_render()


## Añade un mensaje a la cola. `color`: color del texto (blanco hueso por defecto).
func push(text: String, color: Color = UiStyle.BONE) -> void:
	history.append(text)
	_queue.append({"text": text, "color": color})
	if _showing_sticky:
		_shown.clear()
		_showing_sticky = false
		_timer = 0.0


## Mensaje fijo: líneas [{text, color, bbcode (opcional, sustituye a text al dibujar)}] que se ven cuando no queda nada por contar. Vacío = ninguno.
func set_sticky(lines: Array[Dictionary]) -> void:
	_sticky = lines
	if is_idle():
		_show_sticky()


## Vacía la cola y lo que se ve (no toca el historial ni el mensaje fijo).
func clear() -> void:
	_queue.clear()
	_shown.clear()
	_timer = 0.0
	_showing_sticky = false
	_render()


## No queda nada por enseñar (la cola está vacía y el último mensaje ya ha tenido su tiempo).
func is_idle() -> bool:
	return _queue.is_empty() and _timer <= 0.0


## Pasa al siguiente mensaje ya.
func skip() -> void:
	_timer = 0.0


## Texto que se ve ahora mismo (plano).
func visible_text() -> String:
	var parts: PackedStringArray = []
	for entry: Dictionary in _shown:
		parts.append(entry["text"])
	return "\n".join(parts)


func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta
		return
	if not _queue.is_empty():
		_show_next()
	elif not _showing_sticky and not _sticky.is_empty():
		_show_sticky()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _queue.is_empty():
		return
	if event.is_action_pressed(&"ui_accept"):
		skip()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		skip()
		accept_event()


func _show_next() -> void:
	var entry: Dictionary = _queue.pop_front()
	_showing_sticky = false
	_shown.append(entry)
	# Caben dos líneas: si el nuevo ocupa dos, va solo.
	while _shown.size() > 1 and _lines_of(_shown) > MAX_LINES:
		_shown.pop_front()
	_timer = line_seconds + per_char * String(entry["text"]).length()
	_render()


func _show_sticky() -> void:
	_showing_sticky = true
	_shown = _sticky.duplicate()
	_render()


func _lines_of(entries: Array[Dictionary]) -> int:
	var font: Font = UiStyle.ui()
	var width: float = maxf(1.0, size.x - PAD.x * 2.0 - 4.0)
	var count: int = 0
	for entry: Dictionary in entries:
		var w: float = font.get_string_size(String(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		count += maxi(1, ceili(w / width))
	return count


func _render() -> void:
	visible = not _shown.is_empty()
	if _label == null:
		return
	_label.size = size - PAD * 2.0
	var parts: PackedStringArray = []
	for entry: Dictionary in _shown:
		var color: Color = entry.get("color", UiStyle.BONE)
		var body: String = entry["bbcode"] if entry.has("bbcode") else _escape(String(entry["text"]))
		parts.append("[color=#%s]%s[/color]" % [color.to_html(false), body])
	_label.text = "\n".join(parts)
	queue_redraw()


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


func _draw() -> void:
	BattleSkin.draw_metal(self, Rect2(Vector2.ZERO, size))
