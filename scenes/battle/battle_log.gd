class_name BattleLog
extends Control
## Registro del combate: una carpeta con la pestaña «REGISTRO» arriba a la derecha. Cerrada solo
## se ve la pestaña (con el número de entradas); abierta, la carpeta se despliega hacia abajo con
## todo lo que ha pasado, a máquina y agrupado por rondas, y se recorre con la rueda o las flechas.
## Se abre y se cierra con un clic en la pestaña, Tab o el botón Select del mando; Esc la cierra.

signal toggled(open: bool)

const TAB_SIZE: Vector2 = Vector2(78, 14)
const PANEL_SIZE: Vector2 = Vector2(250, 214)
const PAD: Vector2 = Vector2(10, 22)
const LINE_H: float = 10.0
const FONT_SIZE: int = UiStyle.MONO_SMALL

## Entradas: [{text, color, round}].
var entries: Array[Dictionary] = []
var is_open: bool = false
## Primera línea visible contando desde el final (0 = lo último abajo).
var scroll: int = 0

var _unfold: float = 0.0
var _tween: Tween
var _round: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(PANEL_SIZE.x, TAB_SIZE.y)


## Añade una línea. Las de ronda («— RONDA 3 —») abren un grupo nuevo.
func add(text: String, color: Color = BattleSkin.INK) -> void:
	if text.begins_with("— RONDA"):
		_round = text.get_slice(" ", 2).to_int()
	entries.append({"text": text, "color": color, "round": _round})
	if is_open:
		scroll = 0
	queue_redraw()


## Textos guardados, en orden.
func lines() -> PackedStringArray:
	var result: PackedStringArray = []
	for entry: Dictionary in entries:
		result.append(String(entry["text"]))
	return result


func toggle() -> void:
	set_open(not is_open)


func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	scroll = 0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_unfold, _unfold, 1.0 if open else 0.0, 0.18).set_ease(Tween.EASE_OUT)
	toggled.emit(open)


## Desplaza `amount` líneas (positivo = hacia lo antiguo).
func scroll_by(amount: int) -> void:
	var wrapped: int = _wrapped().size()
	scroll = clampi(scroll + amount, 0, maxi(0, wrapped - _visible_lines()))
	queue_redraw()


func _set_unfold(value: float) -> void:
	_unfold = value
	size = Vector2(PANEL_SIZE.x, maxf(TAB_SIZE.y, PANEL_SIZE.y * value))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_LEFT and _tab_rect().has_point(click.position):
		toggle()
		accept_event()
	elif is_open and click.button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll_by(2)
		accept_event()
	elif is_open and click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scroll_by(-2)
		accept_event()


func _has_point(point: Vector2) -> bool:
	return _tab_rect().has_point(point) or (_unfold > 0.05 and Rect2(Vector2(0, TAB_SIZE.y), size).has_point(point))


func _tab_rect() -> Rect2:
	return Rect2(Vector2(PANEL_SIZE.x - TAB_SIZE.x, 0), TAB_SIZE)


func _visible_lines() -> int:
	return int((PANEL_SIZE.y - PAD.y - 10.0) / LINE_H)


## Líneas ya partidas a lo ancho de la hoja: [{text, color, header}].
func _wrapped() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var font: Font = UiStyle.mono()
	var width: float = PANEL_SIZE.x - PAD.x * 2.0 - 4.0
	for entry: Dictionary in entries:
		var text: String = String(entry["text"])
		if text.begins_with("—"):
			result.append({"text": text.replace("—", "").strip_edges(), "color": BattleSkin.INK_RED, "header": true})
			continue
		var first: bool = true
		for piece: String in BattleSkin.wrap_text(font, text, width - 8.0, FONT_SIZE):
			result.append({"text": ("· " if first else "  ") + piece, "color": entry["color"], "header": false})
			first = false
	return result


func _draw() -> void:
	var font: Font = UiStyle.mono()
	if _unfold > 0.02:
		var panel: Rect2 = Rect2(Vector2(0, TAB_SIZE.y - 4), Vector2(PANEL_SIZE.x, size.y - TAB_SIZE.y + 4))
		BattleSkin.draw_paper(self, panel, true)
		# hoja interior, un poco más clara, con el título del expediente
		var sheet: Rect2 = panel.grow_individual(-6, -6, -6, -6)
		draw_rect(sheet, Color(0.86, 0.82, 0.72, 0.9))
		if _unfold > 0.9:
			draw_string(font, sheet.position + Vector2(4, 9), "REGISTRO DE INCIDENCIAS · PLANTA 3",
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, BattleSkin.INK_SOFT)
			BattleSkin.draw_rule(self, sheet.position + Vector2(4, 12), sheet.size.x - 8.0)
			var lines_all: Array[Dictionary] = _wrapped()
			var count: int = _visible_lines()
			var last: int = lines_all.size() - scroll
			var first: int = maxi(0, last - count)
			var y: float = sheet.position.y + 23.0
			for i: int in range(first, last):
				var line: Dictionary = lines_all[i]
				var color: Color = line["color"]
				draw_string(font, Vector2(sheet.position.x + 4, y), String(line["text"]), HORIZONTAL_ALIGNMENT_LEFT,
					sheet.size.x - 8.0, FONT_SIZE, color)
				if bool(line["header"]):
					draw_line(Vector2(sheet.position.x + 4, y + 2), Vector2(sheet.end.x - 4, y + 2), Color(BattleSkin.INK_RED, 0.4))
				y += LINE_H
			if first > 0:
				UiStyle.draw_arrow(self, Vector2(sheet.end.x - 8, sheet.position.y + 18), Vector2.UP, 3.0, BattleSkin.INK_SOFT)
			if scroll > 0:
				UiStyle.draw_arrow(self, Vector2(sheet.end.x - 8, sheet.end.y - 4), Vector2.DOWN, 3.0, BattleSkin.INK_SOFT)
	var tab: Rect2 = _tab_rect()
	var box: StyleBoxTexture = BattleSkin.folder_box()
	draw_rect(Rect2(tab.position + Vector2(1, 2), tab.size), Color(0, 0, 0, 0.5))
	if box.texture != null:
		draw_style_box(box, tab)
	draw_string(font, tab.position + Vector2(6, 10), "REGISTRO", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, BattleSkin.INK)
	var count_text: String = str(entries.size())
	var cw: float = font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string(font, Vector2(tab.end.x - cw - 12, tab.position.y + 10), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		FONT_SIZE, BattleSkin.INK_RED)
	UiStyle.draw_arrow(self, Vector2(tab.end.x - 6, tab.position.y + 7), Vector2.UP if is_open else Vector2.DOWN, 2.0,
		BattleSkin.INK)
