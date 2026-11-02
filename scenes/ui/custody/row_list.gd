class_name RowList
extends Control
## Lista vertical dibujada a mano para la custodia (categorías, objetos, ranuras de equipo,
## candidatos): una fila por elemento con miniatura, texto, cantidad a la derecha y una etiqueta.
## Se maneja desde fuera con `select`/`move` (teclado y mando) y responde al ratón: clic elige,
## doble clic activa, clic derecho pide el menú y la rueda desplaza.
##
## Cada fila es un diccionario: {text, icon?, right?, tag?, tag_color?, color?, sub?, sub_color?,
## caption?, dim?}. `caption` es un rótulo pequeño encima del texto (filas altas: ranuras de equipo).

## Se ha elegido otra fila (con el ratón o con `select`).
signal selected(index: int)
## Doble clic sobre una fila.
signal activated(index: int)
## Clic derecho sobre una fila (posición global para el menú).
signal context_requested(index: int, at: Vector2)

const ICON_BOX: Vector2i = Vector2i(22, 20)

## Alto de cada fila en píxeles.
@export var row_height: float = 22.0
## Muestra el cursor brillante (la lista tiene el foco del teclado).
@export var active: bool = true
## Si es false, no dibuja miniaturas (solo texto).
@export var show_icons: bool = true

var rows: Array[Dictionary] = []
var index: int = -1

var _scroll: int = 0
var _hover: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Cambia las filas; mantiene la elegida si sigue existiendo (si no, la acerca).
func set_rows(new_rows: Array[Dictionary]) -> void:
	rows = new_rows
	if rows.is_empty():
		index = -1
	else:
		index = clampi(index, 0, rows.size() - 1)
	_scroll = clampi(_scroll, 0, maxi(0, rows.size() - visible_rows()))
	_keep_visible()
	queue_redraw()


## Elige una fila. `notify` = emitir `selected`.
func select(i: int, notify: bool = true) -> void:
	if rows.is_empty():
		index = -1
		queue_redraw()
		return
	var clamped: int = clampi(i, 0, rows.size() - 1)
	var changed_row: bool = clamped != index
	index = clamped
	_keep_visible()
	queue_redraw()
	if notify and changed_row:
		selected.emit(index)


## Mueve la selección `step` filas (da la vuelta en los extremos).
func move(step: int) -> void:
	if rows.is_empty():
		return
	select(posmod(index + step, rows.size()))


func visible_rows() -> int:
	return maxi(1, floori(size.y / row_height))


## Rectángulo de una fila en coordenadas globales (para abrir el menú junto a ella).
func row_global_rect(i: int) -> Rect2:
	return Rect2(global_position + Vector2(0, (i - _scroll) * row_height), Vector2(size.x, row_height))


func row_at(point: Vector2) -> int:
	var i: int = floori(point.y / row_height) + _scroll
	return i if i >= 0 and i < rows.size() and point.x >= 0.0 and point.x < size.x else -1


func _gui_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		var h: int = row_at(motion.position)
		if h != _hover:
			_hover = h
			queue_redraw()
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	match button.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_scroll_by(-1)
		MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_by(1)
		MOUSE_BUTTON_LEFT:
			var i: int = row_at(button.position)
			if i >= 0:
				select(i)
				if button.double_click:
					activated.emit(i)
		MOUSE_BUTTON_RIGHT:
			var j: int = row_at(button.position)
			if j >= 0:
				select(j)
				context_requested.emit(j, button.global_position)
	accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		queue_redraw()


func _draw() -> void:
	var font: Font = UiStyle.ui()
	var mono: Font = UiStyle.mono()
	var text_size: int = UiStyle.fit_size(font, UiStyle.SIZE_TEXT)
	var small: int = UiStyle.fit_size(mono, UiStyle.MONO_SMALL)
	var first: int = _scroll
	var last: int = mini(rows.size(), _scroll + visible_rows() + 1)
	for i: int in range(first, last):
		var row: Dictionary = rows[i]
		var r: Rect2 = Rect2(0, (i - _scroll) * row_height, size.x - 4.0, row_height - 1.0)
		if i == index:
			draw_rect(r, Color("1d2125") if active else Color("181b1e"))
			draw_rect(r.grow(-0.5), UiStyle.BONE_DIM if active else UiStyle.STEEL_LIGHT, false, 1.0)
			if active:
				draw_rect(Rect2(r.position + Vector2(1, 2), Vector2(2, r.size.y - 4)), UiStyle.AMBER)
		elif i == _hover:
			draw_rect(r, Color(UiStyle.STEEL, 0.55))
		elif i % 2 == 1:
			draw_rect(r, Color(1, 1, 1, 0.025))
		var x: float = 6.0
		var icon: Texture2D = row.get("icon")
		if show_icons:
			if icon != null:
				var s: Vector2 = icon.get_size()
				var pos: Vector2 = Vector2(x + (ICON_BOX.x - s.x) / 2.0, r.position.y + (row_height - s.y) / 2.0).floor()
				draw_texture(icon, pos)
			x += ICON_BOX.x + 4.0
		var dim: bool = row.get("dim", false)
		var color: Color = row.get("color", UiStyle.BONE if i == index else UiStyle.BONE_DIM)
		if dim:
			color = Color(color, 0.55)
		var right: String = row.get("right", "")
		var tag: String = row.get("tag", "")
		var right_w: float = 0.0
		if right != "":
			right_w = mono.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x + 6.0
		var tag_w: float = 0.0
		if tag != "":
			tag_w = mono.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x + 8.0
		var baseline: float = r.position.y + row_height / 2.0 + text_size * 0.36
		var caption: String = row.get("caption", "")
		if caption != "":
			draw_string(mono, Vector2(x, r.position.y + small + 2.0).floor(), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, small,
				UiStyle.ASH)
			baseline = r.end.y - 5.0
		var max_w: float = r.size.x - x - right_w - tag_w - 4.0
		var text: String = row.get("text", "")
		draw_string(font, Vector2(x, baseline).floor(), text, HORIZONTAL_ALIGNMENT_LEFT, max_w, text_size, color,
			TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL)
		var sub: String = row.get("sub", "")
		if sub != "":
			var used: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
			if used + 8.0 < max_w:
				draw_string(mono, Vector2(x + used + 6.0, baseline).floor(), sub, HORIZONTAL_ALIGNMENT_LEFT,
					max_w - used - 6.0, small, row.get("sub_color", UiStyle.ASH))
		var rx: float = r.end.x - 4.0
		if right != "":
			draw_string(mono, Vector2(rx - right_w + 6.0, baseline).floor(), right, HORIZONTAL_ALIGNMENT_LEFT, -1, small,
				UiStyle.BONE if i == index else UiStyle.BONE_DIM)
			rx -= right_w
		if tag != "":
			var tag_color: Color = row.get("tag_color", UiStyle.AMBER)
			var tr: Rect2 = Rect2(rx - tag_w + 2.0, r.position.y + 4.0, tag_w - 4.0, row_height - 9.0)
			draw_rect(tr, Color(tag_color, 0.16))
			draw_rect(tr.grow(-0.5), Color(tag_color, 0.7), false, 1.0)
			draw_string(mono, Vector2(tr.position.x + 2.0, baseline - 0.5).floor(), tag, HORIZONTAL_ALIGNMENT_LEFT, -1,
				small, tag_color)
	# Barra de desplazamiento si no caben.
	if rows.size() > visible_rows():
		var track: Rect2 = Rect2(size.x - 2.0, 0, 2.0, size.y)
		draw_rect(track, Color(UiStyle.STEEL, 0.8))
		var h: float = size.y * visible_rows() / rows.size()
		var y: float = (size.y - h) * _scroll / maxf(1.0, rows.size() - visible_rows())
		draw_rect(Rect2(track.position.x, y, 2.0, h), UiStyle.BONE_DIM)


func _scroll_by(step: int) -> void:
	_scroll = clampi(_scroll + step, 0, maxi(0, rows.size() - visible_rows()))
	queue_redraw()


func _keep_visible() -> void:
	if index < 0:
		return
	if index < _scroll:
		_scroll = index
	elif index >= _scroll + visible_rows():
		_scroll = index - visible_rows() + 1
