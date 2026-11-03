class_name IntentNote
extends Control
## Aviso de lo que prepara el enemigo: una nota de observación mecanografiada, pegada con cinta
## arriba a la izquierda, que se escribe sola letra a letra al empezar la ronda («ENFERMERO prepara
## TAJO → torso» y, debajo, el gesto que lo delata). Si no se ve lo que prepara, lo dice.

## Se ha escrito una letra (para el sonido de la máquina).
signal typed

const WIDTH: float = 198.0
const PAD: Vector2 = Vector2(8, 8)
const LINE_H: float = 10.0
const CHARS_PER_SECOND: float = 70.0

## Líneas: [{text, color, bold}].
var lines: Array[Dictionary] = []
## Letras escritas hasta ahora (todo el texto si es -1).
var _shown: float = -1.0
var _total: int = 0
var _wrapped: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Escribe estas líneas (si son las mismas que ya hay, no vuelve a escribirlas).
func write(p_lines: Array[Dictionary], instant: bool = false) -> void:
	if _same(p_lines) and visible:
		return
	lines = p_lines
	_wrap()
	visible = not lines.is_empty()
	_shown = -1.0 if instant else 0.0
	queue_redraw()


func close() -> void:
	visible = false


## Texto completo (plano), para pruebas.
func text() -> String:
	var parts: PackedStringArray = []
	for line: Dictionary in lines:
		parts.append(String(line["text"]))
	return "\n".join(parts)


## Termina de escribir ya.
func finish() -> void:
	_shown = -1.0
	queue_redraw()


func is_typing() -> bool:
	return _shown >= 0.0 and _shown < _total


func _process(delta: float) -> void:
	if not visible or _shown < 0.0:
		return
	var before: int = int(_shown)
	_shown += delta * CHARS_PER_SECOND
	if int(_shown) != before and int(_shown) % 3 == 0 and int(_shown) <= _total:
		typed.emit()
	if _shown >= _total:
		_shown = -1.0
	queue_redraw()


func _same(other: Array[Dictionary]) -> bool:
	if other.size() != lines.size():
		return false
	for i: int in other.size():
		if String(other[i]["text"]) != String(lines[i]["text"]):
			return false
	return true


func _wrap() -> void:
	_wrapped.clear()
	_total = 0
	var font: Font = UiStyle.mono()
	for line: Dictionary in lines:
		for piece: String in BattleSkin.wrap_text(font, String(line["text"]), WIDTH - PAD.x * 2.0, UiStyle.MONO_SMALL):
			_wrapped.append({"text": piece, "color": line.get("color", BattleSkin.INK), "bold": line.get("bold", false)})
			_total += piece.length()
	size = Vector2(WIDTH, PAD.y * 2.0 + 12.0 + _wrapped.size() * LINE_H)


func _draw() -> void:
	if lines.is_empty():
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_set_transform(Vector2.ZERO, -0.012, Vector2.ONE)
	BattleSkin.draw_paper(self, rect)
	var font: Font = UiStyle.mono()
	draw_string(font, PAD + Vector2(0, 7), "OBSERVACIÓN · RONDA EN CURSO", HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiStyle.MONO_SMALL, BattleSkin.INK_SOFT)
	BattleSkin.draw_rule(self, PAD + Vector2(0, 10), size.x - PAD.x * 2.0)
	var budget: int = _total if _shown < 0.0 else int(_shown)
	var y: float = PAD.y + 21.0
	for entry: Dictionary in _wrapped:
		var text: String = String(entry["text"])
		var visible_text: String = text.substr(0, clampi(budget, 0, text.length()))
		budget -= text.length()
		var color: Color = entry["color"]
		draw_string(font, Vector2(PAD.x, y), visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.MONO_SMALL, color)
		if bool(entry["bold"]):
			draw_string(font, Vector2(PAD.x + 0.6, y), visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.MONO_SMALL, color)
		if budget < 0 and _shown >= 0.0:
			# carro de la máquina: un cursor que parpadea donde se escribe
			var w: float = font.get_string_size(visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.MONO_SMALL).x
			draw_rect(Rect2(Vector2(PAD.x + w + 1, y - 7), Vector2(4, 8)), Color(BattleSkin.INK, 0.6))
			break
		y += LINE_H
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	BattleSkin.draw_tape(self, Vector2(size.x * 0.5 - 11, -4), 0.05)
