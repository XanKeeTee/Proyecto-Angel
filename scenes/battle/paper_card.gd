class_name PaperCard
extends Control
## Ficha de papel clínico a máquina: la usan la ficha de detalle de una orden, la ficha de la parte
## apuntada y la ventanita de heridas. Se le da una lista de filas y se dibuja sola, con su pestaña,
## su cinta y, si hace falta, un sello encima («DENEGADO»). Aparece deslizándose (el papel sale de
## debajo de la caja) y se recoloca cuando cambia el contenido.
##
## Filas (diccionarios):
##   {"kind": "title", "text", "icon": Texture2D, "note": texto pequeño a la derecha}
##   {"kind": "text", "text", "color"}            texto a máquina partido en líneas
##   {"kind": "bullet", "text"}                   «· frase»
##   {"kind": "risk", "text"}                     «! frase» en tinta roja
##   {"kind": "rule"}                             línea de tinta
##   {"kind": "stats", "items": [[etiqueta, valor, color], …]}  números grandes en columnas
##   {"kind": "state", "text", "color"}           sello pequeño del estado (SANA, ROTA…)

const PAD: Vector2 = Vector2(8, 7)
const LINE_H: float = 10.0
const FONT_SIZE: int = UiStyle.MONO_SMALL
const STATS_H: float = 24.0
const TITLE_H: float = 18.0

## Pestaña ("" = sin pestaña).
var tab: String = ""
## Si true, `position` es la esquina inferior izquierda y crece hacia arriba.
var grow_up: bool = false
## Punto de anclaje (esquina superior izquierda, o inferior si `grow_up`).
var anchor_point: Vector2 = Vector2.ZERO
## Sello encima de la ficha (o null) y su giro.
var stamp_texture: Texture2D
var stamp_angle: float = -0.12
## Carpeta (cartulina) en vez de papel blanco.
var folder: bool = false
## Alto máximo (0 = sin límite). Si no cabe, se quitan frases desde el final: primero las de «·»,
## luego los riesgos; lo demás (título, números, el motivo de lo desactivado) se queda.
var max_height: float = 0.0

var _rows: Array[Dictionary] = []
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Enseña la ficha con estas filas, del ancho dado. `animate`: se desliza al aparecer.
func show_rows(rows: Array[Dictionary], width: float, animate: bool = true) -> void:
	var was_visible: bool = visible
	_rows = rows.duplicate()
	if max_height > 0.0:
		for kind: String in ["bullet", "risk"]:
			var i: int = _rows.size() - 1
			while i >= 0 and _content_height(width) > max_height:
				if String(_rows[i].get("kind", "")) == kind and not String(_rows[i].get("text", "")).begins_with("NO DISPONIBLE"):
					_rows.remove_at(i)
				i -= 1
	size = Vector2(width, _content_height(width))
	var target: Vector2 = (anchor_point - Vector2(0, size.y) if grow_up else anchor_point).round()
	visible = true
	if _tween != null:
		_tween.kill()
	if animate and not was_visible:
		position = target + Vector2(0, 10 if grow_up else -10)
		modulate.a = 0.0
		_tween = create_tween().set_parallel()
		_tween.tween_property(self, "position", target, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_tween.tween_property(self, "modulate:a", 1.0, 0.1)
	else:
		position = target
		modulate.a = 1.0
	queue_redraw()


func close() -> void:
	visible = false
	stamp_texture = null


## Textos de las filas, en orden (para las pruebas).
func texts() -> PackedStringArray:
	var result: PackedStringArray = []
	for row: Dictionary in _rows:
		if row.has("text"):
			result.append(String(row["text"]))
		if row.has("items"):
			for item: Array in row["items"]:
				result.append("%s %s" % [item[0], item[1]])
	return result


func _content_height(width: float) -> float:
	var h: float = PAD.y * 2.0 + (6.0 if tab != "" else 0.0)
	var inner: float = width - PAD.x * 2.0
	var font: Font = UiStyle.mono()
	for row: Dictionary in _rows:
		match String(row.get("kind", "text")):
			"title":
				h += TITLE_H
			"rule":
				h += 5.0
			"stats":
				h += STATS_H + 3.0
			"state":
				h += 14.0
			"bullet", "risk":
				h += BattleSkin.wrap_text(font, String(row["text"]), inner - 8.0, FONT_SIZE).size() * LINE_H + 1.0
			_:
				var count: int = BattleSkin.wrap_text(font, String(row["text"]), inner, FONT_SIZE).size()
				h += mini(count, int(row.get("max_lines", 99))) * LINE_H + 1.0
	return ceilf(h)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	BattleSkin.draw_paper(self, rect, folder)
	var font: Font = UiStyle.mono()
	var serif: Font = UiStyle.ui_bold()
	var inner: float = size.x - PAD.x * 2.0
	var y: float = PAD.y + (6.0 if tab != "" else 0.0)
	for row: Dictionary in _rows:
		var kind: String = String(row.get("kind", "text"))
		match kind:
			"title":
				var x: float = PAD.x
				var icon: Texture2D = row.get("icon") as Texture2D
				if icon != null:
					BattleSkin.draw_icon_at(self, icon, Vector2(x + 8, y + 8), 16.0)
					x += 20.0
				var note: String = String(row.get("note", ""))
				var note_w: float = font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x if note != "" else 0.0
				draw_string(serif, Vector2(x, y + 12), String(row["text"]), HORIZONTAL_ALIGNMENT_LEFT,
					size.x - x - PAD.x - note_w - 4, UiStyle.SIZE_TEXT, BattleSkin.INK)
				if note != "":
					draw_string(font, Vector2(size.x - PAD.x - note_w, y + 11), note, HORIZONTAL_ALIGNMENT_LEFT, -1,
						FONT_SIZE, BattleSkin.INK_SOFT)
				y += TITLE_H
			"rule":
				BattleSkin.draw_rule(self, Vector2(PAD.x, y + 1), inner)
				y += 5.0
			"stats":
				y += 3.0
				var items: Array = row["items"]
				var col: float = inner / maxf(1.0, items.size())
				for i: int in items.size():
					var item: Array = items[i]
					var cx: float = PAD.x + col * i
					draw_string(font, Vector2(cx, y + 7), String(item[0]), HORIZONTAL_ALIGNMENT_LEFT, col, FONT_SIZE,
						BattleSkin.INK_SOFT)
					var color: Color = item[2] if item.size() > 2 else BattleSkin.INK
					draw_string(serif, Vector2(cx, y + 21), String(item[1]), HORIZONTAL_ALIGNMENT_LEFT, col,
						UiStyle.SIZE_LARGE, color)
				y += STATS_H
			"state":
				var text: String = String(row["text"]).to_upper()
				var color: Color = row.get("color", BattleSkin.INK)
				var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 8.0
				var chip: Rect2 = Rect2(Vector2(PAD.x, y + 1), Vector2(w, 11))
				draw_rect(chip, Color(color, 0.12))
				draw_rect(chip.grow(-0.5), Color(color, 0.85), false, 1.0)
				draw_string(font, chip.position + Vector2(4, 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
				var extra: String = String(row.get("note", ""))
				if extra != "":
					draw_string(font, Vector2(chip.end.x + 6, y + 10), extra, HORIZONTAL_ALIGNMENT_LEFT,
						size.x - chip.end.x - 6 - PAD.x, FONT_SIZE, BattleSkin.INK_SOFT)
				y += 14.0
			"bullet", "risk":
				var risk: bool = kind == "risk"
				var color: Color = BattleSkin.INK_RED if risk else BattleSkin.INK
				draw_string(font, Vector2(PAD.x, y + 8), "!" if risk else "·", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE,
					color)
				y += BattleSkin.draw_wrapped(self, font, Vector2(PAD.x + 8, y + 8), String(row["text"]), inner - 8.0,
					FONT_SIZE, color, LINE_H) + 1.0
			_:
				var color: Color = row.get("color", BattleSkin.INK)
				y += BattleSkin.draw_wrapped(self, font, Vector2(PAD.x, y + 8), String(row["text"]), inner, FONT_SIZE,
					color, LINE_H, int(row.get("max_lines", 99))) + 1.0
	if tab != "":
		BattleSkin.draw_tab(self, Vector2(10, -8), tab)
	if stamp_texture != null:
		var center: Vector2 = Vector2(size.x * 0.58, size.y * 0.55)
		draw_set_transform(center, stamp_angle, Vector2.ONE)
		draw_texture(stamp_texture, -stamp_texture.get_size() * 0.5, Color(1, 1, 1, 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
