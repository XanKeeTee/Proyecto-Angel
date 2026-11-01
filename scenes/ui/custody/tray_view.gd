class_name TrayView
extends Control
## Dibuja y maneja la bandeja de custodia (5x4) y los 5 bolsillos.
## Ratón: clic selecciona, arrastrar mueve, clic derecho gira lo que llevas, doble clic usa,
## soltar un objeto encima de otro intenta combinarlos.
## Teclado (lo reenvía la pantalla): flechas mueven el cursor, Intro coge/suelta, R gira.

signal selection_changed(stack: ItemStack)
signal activated(stack: ItemStack)
## Soltar un objeto sobre otro: la pantalla intenta combinarlos.
signal combine_requested(a: ItemStack, b: ItemStack)
signal feedback(text: String)

const CELL: int = 30
const PAD: int = 8
const POCKET_GAP: int = 22
const POCKET_ROW: int = 4

var custody: Custody
## Cursor sobre una cuadrícula virtual: filas 0-3 bandeja, fila 4 bolsillos.
var cursor: Vector2i = Vector2i.ZERO
var held: ItemStack
var held_pocket: int = -1
var held_rotated: bool = false

var _press_pos: Vector2 = Vector2.ZERO
var _press_stack: ItemStack
var _press_pocket: int = -1
var _time: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(PAD * 2 + CELL * Custody.TRAY_SIZE.x, PAD * 2 + CELL * Custody.TRAY_SIZE.y + POCKET_GAP + CELL)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# --- consulta -----------------------------------------------------------------------------

func selected() -> ItemStack:
	if cursor.y == POCKET_ROW:
		return custody.pockets[cursor.x]
	return custody.stack_at(cursor)


func set_cursor(c: Vector2i) -> void:
	c.x = clampi(c.x, 0, Custody.TRAY_SIZE.x - 1)
	c.y = clampi(c.y, 0, POCKET_ROW)
	if c == cursor:
		return
	cursor = c
	selection_changed.emit(selected())


func move_cursor(dir: Vector2i) -> void:
	# Saltar el resto de un objeto grande al moverse por la bandeja.
	var start: ItemStack = selected() if held == null else null
	var c: Vector2i = cursor + dir
	while start != null and c.y < POCKET_ROW and custody.stack_at(c) == start and c != cursor:
		c += dir
		if c.x < 0 or c.y < 0 or c.x >= Custody.TRAY_SIZE.x or c.y > POCKET_ROW:
			c -= dir
			break
	set_cursor(c)


# --- coger, soltar, girar ---------------------------------------------------------------------

func pick_or_drop() -> void:
	if held == null:
		pick(selected(), cursor.x if cursor.y == POCKET_ROW else -1)
	else:
		drop()


func pick(stack: ItemStack, pocket: int) -> void:
	if stack == null:
		return
	held = stack
	held_pocket = pocket
	held_rotated = stack.rotated
	if pocket < 0:
		cursor = stack.cell


func rotate_held() -> void:
	if held != null and held.def.size.x != held.def.size.y:
		held_rotated = not held_rotated
	elif held == null:
		var s: ItemStack = selected()
		if s != null and cursor.y < POCKET_ROW and s.def.size.x != s.def.size.y:
			if not custody.move(s, s.cell, not s.rotated):
				feedback.emit("No hay sitio para girarlo.")


func cancel() -> void:
	held = null
	held_pocket = -1


func drop() -> void:
	var stack: ItemStack = held
	var from_pocket: int = held_pocket
	held = null
	held_pocket = -1
	if stack == null:
		return
	if cursor.y == POCKET_ROW:
		if from_pocket >= 0:
			custody.swap_pockets(from_pocket, cursor.x)
		elif not custody.to_pocket(stack, cursor.x):
			feedback.emit("No hay sitio en la bandeja para lo que había en ese bolsillo.")
		selection_changed.emit(selected())
		return
	var target: ItemStack = custody.stack_at(cursor)
	if target != null and target != stack and not (target.def == stack.def and target.can_merge(stack)):
		combine_requested.emit(stack, target)
		return
	var ok: bool
	if from_pocket >= 0:
		ok = custody.from_pocket(from_pocket, cursor, held_rotated)
	else:
		ok = custody.move(stack, cursor, held_rotated)
	if not ok:
		feedback.emit("No cabe ahí.")
	selection_changed.emit(selected())


# --- ratón ----------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		var c: Vector2i = _cell_at(mm.position)
		if c.x >= 0:
			set_cursor(c)
		if held == null and _press_stack != null and mm.position.distance_to(_press_pos) > 4.0:
			pick(_press_stack, _press_pocket)
			if _press_pocket < 0:
				set_cursor(_cell_at(mm.position))
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if held != null:
			rotate_held()
		else:
			var s: ItemStack = selected()
			if s != null:
				activated.emit(s)
		accept_event()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var cell: Vector2i = _cell_at(mb.position)
	if cell.x >= 0:
		set_cursor(cell)
	if mb.pressed:
		grab_focus()
		if mb.double_click and selected() != null:
			activated.emit(selected())
			_press_stack = null
			return
		_press_pos = mb.position
		_press_stack = selected() if held == null else null
		_press_pocket = cursor.x if cursor.y == POCKET_ROW else -1
		if held != null:
			drop()
	else:
		if held != null and _press_stack != null:
			drop()
		_press_stack = null
		selection_changed.emit(selected())
	accept_event()


func _cell_at(pos: Vector2) -> Vector2i:
	var tray_origin: Vector2 = Vector2(PAD, PAD)
	var local: Vector2 = pos - tray_origin
	if local.x >= 0 and local.y >= 0 and local.x < CELL * Custody.TRAY_SIZE.x and local.y < CELL * Custody.TRAY_SIZE.y:
		return Vector2i(int(local.x / CELL), int(local.y / CELL))
	var pocket_origin: Vector2 = _pocket_origin()
	local = pos - pocket_origin
	if local.y >= 0 and local.y < CELL and local.x >= 0 and local.x < CELL * Custody.POCKETS:
		return Vector2i(int(local.x / CELL), POCKET_ROW)
	return Vector2i(-1, -1)


func _pocket_origin() -> Vector2:
	return Vector2(PAD, PAD + CELL * Custody.TRAY_SIZE.y + POCKET_GAP)


# --- dibujo -----------------------------------------------------------------------------------

func _draw() -> void:
	if custody == null:
		return
	var tray_rect: Rect2 = Rect2(Vector2(PAD, PAD), Vector2(CELL * Custody.TRAY_SIZE.x, CELL * Custody.TRAY_SIZE.y))
	_draw_tray_plate(tray_rect)
	for stack: ItemStack in custody.tray:
		if stack == held and held_pocket < 0:
			_draw_footprint_shadow(stack)
			continue
		_draw_stack(stack, Rect2(tray_rect.position + Vector2(stack.cell * CELL), Vector2(stack.footprint() * CELL)), stack.rotated, 1.0)
	# Bolsillos.
	var po: Vector2 = _pocket_origin()
	draw_string(UiStyle.mono(), po + Vector2(0, -6), "BOLSILLOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiStyle.ASH)
	for i: int in Custody.POCKETS:
		var r: Rect2 = Rect2(po + Vector2(i * CELL, 0), Vector2(CELL - 2, CELL - 2))
		draw_rect(r, Color(UiStyle.STEEL_DARK, 0.95))
		draw_rect(r, UiStyle.STEEL_LIGHT, false, 1.0)
		draw_string(UiStyle.mono(), r.position + Vector2(2, 8), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiStyle.ASH)
		var stack: ItemStack = custody.pockets[i]
		if stack != null and not (stack == held and held_pocket == i):
			_draw_stack(stack, r, false, 1.0, true)
	_draw_cursor(tray_rect)
	if held != null:
		_draw_held(tray_rect)


func _draw_tray_plate(r: Rect2) -> void:
	var outer: Rect2 = r.grow(PAD - 2)
	draw_rect(outer, Color("1d2023"))
	draw_rect(outer, Color("596067"), false, 1.0)
	draw_rect(outer.grow(-2), Color("0f1113"), false, 1.0)
	draw_rect(r, Color("121417"))
	for x: int in Custody.TRAY_SIZE.x + 1:
		draw_line(r.position + Vector2(x * CELL, 0), r.position + Vector2(x * CELL, r.size.y), Color(1, 1, 1, 0.05))
	for y: int in Custody.TRAY_SIZE.y + 1:
		draw_line(r.position + Vector2(0, y * CELL), r.position + Vector2(r.size.x, y * CELL), Color(1, 1, 1, 0.05))
	for corner: Vector2 in [outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)]:
		var c: Vector2 = corner + (outer.get_center() - corner).normalized() * 3.5
		draw_circle(c, 1.5, Color("6b737a"))
	# Indicador de ocupación.
	var used: int = custody.occupied_cells()
	var total: int = Custody.TRAY_SIZE.x * Custody.TRAY_SIZE.y
	draw_string(UiStyle.mono(), Vector2(outer.end.x - 44, outer.position.y - 3), "%02d/%02d" % [used, total],
		HORIZONTAL_ALIGNMENT_RIGHT, 44, 8, UiStyle.BLOOD if used >= total - 2 else UiStyle.ASH)


func _draw_footprint_shadow(stack: ItemStack) -> void:
	var r: Rect2 = Rect2(Vector2(PAD, PAD) + Vector2(stack.cell * CELL), Vector2(stack.footprint() * CELL))
	draw_rect(r.grow(-2), Color(1, 1, 1, 0.04))


func _draw_stack(stack: ItemStack, r: Rect2, rotated: bool, alpha: float, compact: bool = false) -> void:
	var inner: Rect2 = r.grow(-2)
	draw_rect(inner, Color(0.16, 0.17, 0.18, 0.92 * alpha))
	draw_rect(inner, Color(UiStyle.STEEL_LIGHT, 0.8 * alpha), false, 1.0)
	var icon: Texture2D = stack.def.icon
	if icon != null:
		var size: Vector2 = icon.get_size()
		if compact:
			var fit: float = minf((inner.size.x - 2) / maxf(size.x, size.y), (inner.size.y - 2) / maxf(size.x, size.y))
			size *= minf(1.0, fit)
		var center: Vector2 = inner.get_center()
		if rotated:
			draw_set_transform(center, PI / 2.0, Vector2.ONE)
			draw_texture_rect(icon, Rect2(-size / 2.0, size), false, Color(1, 1, 1, alpha))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(icon, Rect2(center - size / 2.0, size), false, Color(1, 1, 1, alpha))
	else:
		draw_string(UiStyle.serif(), inner.position + Vector2(3, 12), stack.def.display_name.substr(0, 4),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(UiStyle.BONE, alpha))
	if stack.quantity > 1:
		draw_string(UiStyle.mono(), inner.end - Vector2(14, 2), "×%d" % stack.quantity, HORIZONTAL_ALIGNMENT_RIGHT, 14, 8,
			Color(UiStyle.BONE, alpha))
	if stack.contaminated:
		draw_circle(inner.position + Vector2(4, 4), 2.0, Color(UiStyle.SICK_GREEN, alpha))
	if stack.def.max_durability > 0:
		var ratio: float = float(stack.durability) / stack.def.max_durability
		draw_rect(Rect2(inner.position + Vector2(2, inner.size.y - 3), Vector2((inner.size.x - 4) * ratio, 1)),
			Color(UiStyle.BONE_DIM, alpha))
	if stack.def.max_charge > 0.0:
		var ratio2: float = stack.charge / stack.def.max_charge
		draw_rect(Rect2(inner.position + Vector2(2, inner.size.y - 3), Vector2((inner.size.x - 4) * ratio2, 1)),
			Color(UiStyle.SICK_GREEN if ratio2 > 0.25 else UiStyle.BLOOD, alpha))


func _draw_cursor(tray_rect: Rect2) -> void:
	var pulse: float = 0.55 + 0.35 * sin(_time * 5.0)
	var r: Rect2
	if cursor.y == POCKET_ROW:
		r = Rect2(_pocket_origin() + Vector2(cursor.x * CELL, 0), Vector2(CELL - 2, CELL - 2))
	else:
		var s: ItemStack = custody.stack_at(cursor) if held == null else null
		if s != null:
			r = Rect2(tray_rect.position + Vector2(s.cell * CELL), Vector2(s.footprint() * CELL))
		else:
			r = Rect2(tray_rect.position + Vector2(cursor * CELL), Vector2(CELL, CELL))
	draw_rect(r.grow(-1), Color(UiStyle.BONE, pulse), false, 1.0)


func _draw_held(tray_rect: Rect2) -> void:
	var fp: Vector2i = held.def.footprint(held_rotated)
	if cursor.y == POCKET_ROW:
		var r: Rect2 = Rect2(_pocket_origin() + Vector2(cursor.x * CELL, 0), Vector2(CELL - 2, CELL - 2))
		_draw_stack(held, r, false, 0.75, true)
		return
	var r2: Rect2 = Rect2(tray_rect.position + Vector2(cursor * CELL), Vector2(fp * CELL))
	var ignore: ItemStack = held if held_pocket < 0 else null
	var target: ItemStack = custody.stack_at(cursor)
	var valid: bool = custody.can_place(fp, cursor, ignore) or (target != null and target != held)
	draw_rect(r2, Color(UiStyle.SICK_GREEN if valid else UiStyle.BLOOD, 0.18))
	_draw_stack(held, r2, held_rotated, 0.8)
