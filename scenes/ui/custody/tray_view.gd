class_name TrayView
extends Control
## Dibuja y maneja la bandeja de custodia (5x4), los 5 bolsillos y la zona de SUELO (descartar).
## Ratón:
##   - arrastrar coge el objeto: se levanta, sigue al cursor con su sombra y deja ver la huella de
##     dónde caería (verde = cabe, ámbar = combinar o juntar, rojo = no cabe);
##   - clic derecho mientras se arrastra lo gira; soltarlo en SUELO lo descarta; soltarlo fuera
##     de la bandeja lo devuelve a su sitio;
##   - clic derecho sobre un objeto abre el menú de acciones; doble clic lo usa.
## Teclado (lo reenvía la pantalla): flechas mueven el cursor, Intro coge/suelta, R gira.

signal selection_changed(stack: ItemStack)
signal activated(stack: ItemStack)
## Soltar un objeto sobre otro: la pantalla intenta combinarlos.
signal combine_requested(a: ItemStack, b: ItemStack)
signal feedback(text: String)
## Clic derecho sobre un objeto: la pantalla abre el menú de acciones en `at` (coordenadas de pantalla).
signal context_requested(stack: ItemStack, at: Vector2)
## Se ha soltado un objeto en la zona de SUELO.
signal discard_requested(stack: ItemStack)

enum Zone { NONE, TRAY, POCKET, FLOOR }

const CELL: int = ItemDef.ICON_CELL
const PAD: int = 8
## Hueco entre la bandeja y los bolsillos (para su rótulo).
const POCKET_GAP: int = 20
const POCKET_ROW: int = 4
const FLOOR_GAP: int = 10
const FLOOR_HEIGHT: int = 34
## Píxeles que se levanta el objeto agarrado (y desplazamiento de su sombra).
const LIFT: Vector2 = Vector2(-2, -3)
const SHADOW: Vector2 = Vector2(3, 4)
const DRAG_THRESHOLD: float = 4.0

const COLOR_OK: Color = Color("9cb85a")
const COLOR_MERGE: Color = Color("d0a24a")
const COLOR_BAD: Color = Color("b03a34")

var custody: Custody
## Arma empuñada (se marca en la bandeja).
var wielded: ItemStack
## Cursor sobre una cuadrícula virtual: filas 0-3 bandeja, fila 4 bolsillos.
var cursor: Vector2i = Vector2i.ZERO
var held: ItemStack
var held_pocket: int = -1
var held_rotated: bool = false

var _press_pos: Vector2 = Vector2.ZERO
var _press_stack: ItemStack
var _press_pocket: int = -1
var _time: float = 0.0
## El objeto agarrado sigue al ratón (si no, al cursor del teclado).
var _mouse_drag: bool = false
var _mouse: Vector2 = Vector2.ZERO
## Dónde se agarró el objeto, relativo a su esquina (para que no salte al cogerlo).
var _grab_offset: Vector2 = Vector2.ZERO
var _zone: Zone = Zone.NONE
var _drag_layer: Control


func _ready() -> void:
	custom_minimum_size = Vector2(PAD * 2 + CELL * Custody.TRAY_SIZE.x, _floor_rect().end.y + PAD)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	# Capa encima de todo lo demás de la pantalla para dibujar lo que se arrastra.
	_drag_layer = Control.new()
	_drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_layer.z_index = 20
	_drag_layer.draw.connect(_draw_drag)
	add_child(_drag_layer)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	_drag_layer.queue_redraw()


# --- consulta -----------------------------------------------------------------------------

func selected() -> ItemStack:
	if custody == null:
		return null
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
	_mouse_drag = false
	# Saltar el resto de un objeto grande al moverse por la bandeja.
	var start: ItemStack = selected() if held == null else null
	var c: Vector2i = cursor + dir
	while start != null and c.y < POCKET_ROW and custody.stack_at(c) == start and c != cursor:
		c += dir
		if c.x < 0 or c.y < 0 or c.x >= Custody.TRAY_SIZE.x or c.y > POCKET_ROW:
			c -= dir
			break
	set_cursor(c)
	_zone = Zone.POCKET if cursor.y == POCKET_ROW else Zone.TRAY


## Rectángulo en pantalla (coordenadas globales) de un montón, para colocar menús.
func stack_global_rect(stack: ItemStack) -> Rect2:
	var i: int = custody.pockets.find(stack)
	var r: Rect2 = _pocket_rect(i) if i >= 0 else _tray_rect_of(stack.cell, stack.footprint())
	return Rect2(global_position + r.position, r.size)


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
	held_rotated = stack.rotated if pocket < 0 else false
	if pocket < 0:
		cursor = stack.cell
	_zone = Zone.POCKET if pocket >= 0 else Zone.TRAY
	ItemSounds.play(self, stack.def, ItemSounds.Action.PICK)


func rotate_held() -> void:
	if held != null and held.def.size.x != held.def.size.y:
		held_rotated = not held_rotated
		# Al girar, se agarra por el centro (si no, la huella se iría lejos del cursor).
		_grab_offset = Vector2(held.def.footprint(held_rotated) * CELL) / 2.0
		if _mouse_drag:
			_update_drag_target()
		ItemSounds.play(self, held.def, ItemSounds.Action.ROTATE)
	elif held == null:
		var s: ItemStack = selected()
		if s != null and cursor.y < POCKET_ROW and s.def.size.x != s.def.size.y:
			if custody.move(s, s.cell, not s.rotated):
				ItemSounds.play(self, s.def, ItemSounds.Action.ROTATE)
			else:
				feedback.emit("No hay sitio para girarlo.")


## Suelta lo que se lleva sin moverlo (vuelve a su sitio).
func cancel() -> void:
	if held != null:
		ItemSounds.play(self, held.def, ItemSounds.Action.PLACE, -12.0)
	held = null
	held_pocket = -1
	_mouse_drag = false
	_press_stack = null


func drop() -> void:
	var stack: ItemStack = held
	var from_pocket: int = held_pocket
	var zone: Zone = _zone if _mouse_drag else (Zone.POCKET if cursor.y == POCKET_ROW else Zone.TRAY)
	held = null
	held_pocket = -1
	_mouse_drag = false
	if stack == null:
		return
	match zone:
		Zone.NONE:
			ItemSounds.play(self, stack.def, ItemSounds.Action.PLACE, -12.0)
			selection_changed.emit(selected())
			return
		Zone.FLOOR:
			discard_requested.emit(stack)
			selection_changed.emit(selected())
			return
		Zone.POCKET:
			if from_pocket >= 0:
				custody.swap_pockets(from_pocket, cursor.x)
			elif not custody.to_pocket(stack, cursor.x):
				feedback.emit("No hay sitio en la bandeja para lo que había en ese bolsillo.")
			ItemSounds.play(self, stack.def, ItemSounds.Action.PLACE)
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
	if ok:
		ItemSounds.play(self, stack.def, ItemSounds.Action.PLACE)
	else:
		feedback.emit("No cabe ahí.")
		ItemSounds.play(self, stack.def, ItemSounds.Action.PLACE, -12.0)
	selection_changed.emit(selected())


## Qué pasaría al soltar ahora: "ok", "merge" (juntar o combinar), "bad".
func drop_state() -> String:
	if held == null:
		return ""
	match _zone if _mouse_drag else Zone.TRAY:
		Zone.NONE:
			return "bad"
		Zone.FLOOR:
			return "ok" if held.def.can_discard() else "bad"
	if cursor.y == POCKET_ROW:
		return "ok"
	var fp: Vector2i = held.def.footprint(held_rotated)
	var target: ItemStack = custody.stack_at(cursor)
	if target != null and target != held:
		return "merge"
	var ignore: ItemStack = held if held_pocket < 0 else null
	return "ok" if custody.can_place(fp, cursor, ignore) else "bad"


## Para capturas y pruebas: agarra `stack` con el ratón como si se arrastrara hasta `at` (local).
func debug_drag(stack: ItemStack, at: Vector2) -> void:
	_press_stack = stack
	_press_pocket = custody.pockets.find(stack)
	_press_pos = stack_global_rect(stack).get_center() - global_position
	_mouse = at
	_start_mouse_drag()


# --- ratón ----------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if custody == null:
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse = mm.position
		if held == null and _press_stack != null and mm.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_start_mouse_drag()
		if held != null and _mouse_drag:
			_update_drag_target()
		elif held == null:
			var c: Vector2i = _cell_at(mm.position)
			if c.x >= 0:
				set_cursor(c)
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null:
		return
	_mouse = mb.position
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if held != null:
			rotate_held()
		else:
			var c2: Vector2i = _cell_at(mb.position)
			if c2.x >= 0:
				set_cursor(c2)
			var s: ItemStack = selected()
			if s != null and c2.x >= 0:
				context_requested.emit(s, mb.global_position)
		accept_event()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		grab_focus()
		if held != null:
			# Se cogió con el teclado: el clic lo suelta donde apunta el ratón.
			var cell: Vector2i = _cell_at(mb.position)
			if cell.x >= 0:
				set_cursor(cell)
			_zone = _zone_at(mb.position)
			_mouse_drag = _zone == Zone.FLOOR
			drop()
			accept_event()
			return
		var c3: Vector2i = _cell_at(mb.position)
		if c3.x >= 0:
			set_cursor(c3)
		if mb.double_click and selected() != null and c3.x >= 0:
			activated.emit(selected())
			_press_stack = null
			accept_event()
			return
		_press_pos = mb.position
		_press_stack = selected() if c3.x >= 0 else null
		_press_pocket = cursor.x if cursor.y == POCKET_ROW else -1
	else:
		if held != null and _mouse_drag:
			_update_drag_target()
			drop()
		_press_stack = null
		selection_changed.emit(selected())
	accept_event()


func _start_mouse_drag() -> void:
	var stack: ItemStack = _press_stack
	_press_stack = null
	pick(stack, _press_pocket)
	_mouse_drag = true
	if _press_pocket >= 0:
		_grab_offset = Vector2(stack.def.footprint(false) * CELL) / 2.0
	else:
		_grab_offset = (_press_pos - _tray_rect_of(stack.cell, stack.footprint()).position).clamp(
			Vector2.ZERO, Vector2(stack.footprint() * CELL) - Vector2.ONE)
	_update_drag_target()


## Calcula la casilla donde caería lo que se arrastra (según su esquina, no el puntero).
func _update_drag_target() -> void:
	_zone = _zone_at(_mouse)
	if _zone == Zone.POCKET:
		set_cursor(_cell_at(_mouse))
		return
	if _zone == Zone.FLOOR:
		return
	var fp: Vector2i = held.def.footprint(held_rotated)
	var corner: Vector2 = _mouse - _grab_offset - Vector2(PAD, PAD)
	var c: Vector2i = Vector2i(roundi(corner.x / CELL), roundi(corner.y / CELL))
	# Fuera de la bandeja por más de media casilla = suelto fuera (se cancela).
	var tray_r: Rect2 = Rect2(Vector2(PAD, PAD), Vector2(Custody.TRAY_SIZE * CELL)).grow(CELL * 0.5)
	if not tray_r.has_point(_mouse):
		_zone = Zone.NONE
		return
	c.x = clampi(c.x, 0, Custody.TRAY_SIZE.x - fp.x)
	c.y = clampi(c.y, 0, Custody.TRAY_SIZE.y - fp.y)
	_zone = Zone.TRAY
	set_cursor(c)


func _zone_at(pos: Vector2) -> Zone:
	if _floor_rect().has_point(pos):
		return Zone.FLOOR
	var c: Vector2i = _cell_at(pos)
	if c.y == POCKET_ROW:
		return Zone.POCKET
	if c.x >= 0:
		return Zone.TRAY
	return Zone.NONE


func _cell_at(pos: Vector2) -> Vector2i:
	var local: Vector2 = pos - Vector2(PAD, PAD)
	if local.x >= 0 and local.y >= 0 and local.x < CELL * Custody.TRAY_SIZE.x and local.y < CELL * Custody.TRAY_SIZE.y:
		return Vector2i(int(local.x / CELL), int(local.y / CELL))
	local = pos - _pocket_origin()
	if local.y >= 0 and local.y < CELL and local.x >= 0 and local.x < CELL * Custody.POCKETS:
		return Vector2i(int(local.x / CELL), POCKET_ROW)
	return Vector2i(-1, -1)


func _pocket_origin() -> Vector2:
	return Vector2(PAD, PAD + CELL * Custody.TRAY_SIZE.y + POCKET_GAP)


func _pocket_rect(i: int) -> Rect2:
	return Rect2(_pocket_origin() + Vector2(i * CELL, 0), Vector2(CELL - 2, CELL - 2))


func _floor_rect() -> Rect2:
	var top: float = _pocket_origin().y + CELL + FLOOR_GAP
	return Rect2(Vector2(PAD, top), Vector2(CELL * Custody.TRAY_SIZE.x - 2, FLOOR_HEIGHT))


func _tray_rect_of(cell: Vector2i, fp: Vector2i) -> Rect2:
	return Rect2(Vector2(PAD, PAD) + Vector2(cell * CELL), Vector2(fp * CELL))


# --- dibujo -----------------------------------------------------------------------------------

func _draw() -> void:
	if custody == null:
		return
	var tray_rect: Rect2 = Rect2(Vector2(PAD, PAD), Vector2(CELL * Custody.TRAY_SIZE.x, CELL * Custody.TRAY_SIZE.y))
	_draw_tray_plate(tray_rect)
	for stack: ItemStack in custody.tray:
		if stack == held and held_pocket < 0:
			_draw_footprint_ghost(_tray_rect_of(stack.cell, stack.footprint()))
			continue
		_draw_stack(stack, _tray_rect_of(stack.cell, stack.footprint()), stack.rotated, 1.0)
	# Bolsillos.
	var po: Vector2 = _pocket_origin()
	draw_string(UiStyle.ui(), po + Vector2(0, -6), "BOLSILLOS", HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.SIZE_SMALL, UiStyle.ASH)
	# Indicador de ocupación de la bandeja (en rojo si casi no queda sitio).
	var used: int = custody.occupied_cells()
	var total: int = Custody.TRAY_SIZE.x * Custody.TRAY_SIZE.y
	draw_string(UiStyle.mono(), po + Vector2(CELL * Custody.POCKETS - 122, -6), "bandeja %02d/%02d" % [used, total],
		HORIZONTAL_ALIGNMENT_RIGHT, 120, UiStyle.MONO_SMALL, UiStyle.BLOOD if used >= total - 2 else UiStyle.ASH)
	for i: int in Custody.POCKETS:
		var r: Rect2 = _pocket_rect(i)
		draw_rect(r, Color(UiStyle.STEEL_DARK, 0.95))
		draw_rect(r, UiStyle.STEEL_LIGHT, false, 1.0)
		draw_string(UiStyle.mono(), r.position + Vector2(3, 11), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1,
			UiStyle.MONO_SMALL, UiStyle.ASH)
		var stack: ItemStack = custody.pockets[i]
		if stack != null and not (stack == held and held_pocket == i):
			_draw_stack(stack, r, false, 1.0, true)
	_draw_floor()
	if held == null:
		_draw_cursor(tray_rect)
	else:
		_draw_target(tray_rect)


func _draw_tray_plate(r: Rect2) -> void:
	var outer: Rect2 = r.grow(PAD - 2)
	draw_rect(outer, Color("1d2023"))
	draw_rect(outer, Color("596067"), false, 1.0)
	draw_rect(outer.grow(-2), Color("0f1113"), false, 1.0)
	draw_rect(r, Color("121417"))
	for x: int in Custody.TRAY_SIZE.x + 1:
		draw_line(r.position + Vector2(x * CELL, 0), r.position + Vector2(x * CELL, r.size.y), Color(1, 1, 1, 0.06))
	for y: int in Custody.TRAY_SIZE.y + 1:
		draw_line(r.position + Vector2(0, y * CELL), r.position + Vector2(r.size.x, y * CELL), Color(1, 1, 1, 0.06))
	for corner: Vector2 in [outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)]:
		var c: Vector2 = (corner + (outer.get_center() - corner).normalized() * 3.5).floor()
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color("6b737a"))


func _draw_footprint_ghost(r: Rect2) -> void:
	var inner: Rect2 = r.grow(-2)
	draw_rect(inner, Color(1, 1, 1, 0.03))
	# Contorno a trazos: el hueco de donde se ha cogido.
	var dash: float = 3.0
	var x: float = inner.position.x
	while x < inner.end.x:
		draw_line(Vector2(x, inner.position.y), Vector2(minf(x + dash, inner.end.x), inner.position.y), Color(1, 1, 1, 0.18))
		draw_line(Vector2(x, inner.end.y), Vector2(minf(x + dash, inner.end.x), inner.end.y), Color(1, 1, 1, 0.18))
		x += dash * 2
	var y: float = inner.position.y
	while y < inner.end.y:
		draw_line(Vector2(inner.position.x, y), Vector2(inner.position.x, minf(y + dash, inner.end.y)), Color(1, 1, 1, 0.18))
		draw_line(Vector2(inner.end.x, y), Vector2(inner.end.x, minf(y + dash, inner.end.y)), Color(1, 1, 1, 0.18))
		y += dash * 2


## Dibuja un montón en `r`. `ci` permite dibujarlo en otra capa (lo que se arrastra).
func _draw_stack(stack: ItemStack, r: Rect2, rotated: bool, alpha: float, compact: bool = false,
		ci: CanvasItem = null, plate: bool = true) -> void:
	var c: CanvasItem = ci if ci != null else self
	var inner: Rect2 = r.grow(-2)
	if plate:
		c.draw_rect(inner, Color(0.16, 0.17, 0.18, 0.92 * alpha))
		var border: Color = Color(UiStyle.AMBER, alpha) if stack == wielded else Color(UiStyle.STEEL_LIGHT, 0.8 * alpha)
		c.draw_rect(inner, border, false, 1.0)
	var icon: Texture2D = stack.def.icon
	if icon != null:
		var isize: Vector2 = icon.get_size()
		if compact:
			# Reducción entera (1/2, 1/3) para que el pixel art no se deforme.
			var big: float = maxf(isize.x, isize.y)
			isize = (isize / ceilf(big / (inner.size.x - 2))).floor()
		var center: Vector2 = (inner.position + inner.size / 2.0).floor()
		if rotated:
			c.draw_set_transform(center, PI / 2.0, Vector2.ONE)
			c.draw_texture_rect(icon, Rect2((-isize / 2.0).floor(), isize), false, Color(1, 1, 1, alpha))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			c.draw_texture_rect(icon, Rect2((center - isize / 2.0).floor(), isize), false, Color(1, 1, 1, alpha))
	else:
		c.draw_string(UiStyle.ui(), inner.position + Vector2(3, 13), stack.def.display_name.substr(0, 5),
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.SIZE_SMALL, Color(UiStyle.BONE, alpha))
	if stack.quantity > 1:
		var q: String = "x%d" % stack.quantity
		c.draw_string(UiStyle.mono(), inner.end - Vector2(20, 1), q, HORIZONTAL_ALIGNMENT_RIGHT, 20, UiStyle.MONO_SMALL,
			Color(0, 0, 0, 0.9 * alpha))
		c.draw_string(UiStyle.mono(), inner.end - Vector2(21, 2), q, HORIZONTAL_ALIGNMENT_RIGHT, 20, UiStyle.MONO_SMALL,
			Color(UiStyle.BONE, alpha))
	if stack.contaminated:
		c.draw_rect(Rect2(inner.position + Vector2(2, 2), Vector2(4, 4)), Color(UiStyle.SICK_GREEN, alpha))
	if stack == wielded:
		c.draw_colored_polygon(PackedVector2Array([inner.position + Vector2(inner.size.x - 9, 0),
			Vector2(inner.end.x, inner.position.y), inner.position + Vector2(inner.size.x, 9)]), Color(UiStyle.AMBER, alpha))
	if stack.def.max_durability > 0:
		var ratio: float = float(stack.durability) / stack.def.max_durability
		c.draw_rect(Rect2(inner.position + Vector2(2, inner.size.y - 4), Vector2(floorf((inner.size.x - 4) * ratio), 2)),
			Color(UiStyle.BONE_DIM, alpha))
	if stack.def.max_charge > 0.0:
		var ratio2: float = stack.charge / stack.def.max_charge
		c.draw_rect(Rect2(inner.position + Vector2(2, inner.size.y - 4), Vector2(floorf((inner.size.x - 4) * ratio2), 2)),
			Color(UiStyle.SICK_GREEN if ratio2 > 0.25 else UiStyle.BLOOD, alpha))


func _draw_floor() -> void:
	var r: Rect2 = _floor_rect()
	var active: bool = held != null
	var hover: bool = active and _mouse_drag and _zone == Zone.FLOOR
	var bad: bool = hover and not held.def.can_discard()
	var base: Color = COLOR_BAD if bad else (Color("c8b89a") if hover else UiStyle.STEEL_LIGHT)
	draw_rect(r, Color(0.07, 0.07, 0.07, 0.9))
	# Rayado diagonal, como una rejilla de desagüe.
	var step: float = 6.0
	var x: float = r.position.x - r.size.y
	while x < r.end.x:
		var a: Vector2 = Vector2(maxf(x, r.position.x), r.position.y + maxf(0.0, r.position.x - x))
		var b: Vector2 = Vector2(minf(x + r.size.y, r.end.x), r.end.y - maxf(0.0, x + r.size.y - r.end.x))
		draw_line(a, b, Color(base, 0.22 if active else 0.1))
		x += step
	draw_rect(r, Color(base, 0.9 if active else 0.5), false, 1.0)
	var title: String = "SUELO"
	var hint: String = "arrastra aquí para descartar  ·  Supr"
	if bad:
		hint = "objeto clave: no se puede descartar"
	elif hover:
		hint = "suelta para dejarlo en el suelo"
	draw_string(UiStyle.ui(), r.position + Vector2(8, 14), title, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.SIZE_SMALL,
		Color(base.lightened(0.3), 1.0 if active else 0.7))
	draw_string(UiStyle.mono(), r.position + Vector2(8, 28), hint, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12,
		UiStyle.MONO_SMALL, Color(UiStyle.BONE_DIM if not bad else COLOR_BAD.lightened(0.3), 0.9 if active else 0.55))


func _draw_cursor(tray_rect: Rect2) -> void:
	var pulse: float = 0.55 + 0.35 * sin(_time * 5.0)
	var r: Rect2
	if cursor.y == POCKET_ROW:
		r = _pocket_rect(cursor.x)
	else:
		var s: ItemStack = custody.stack_at(cursor)
		if s != null:
			r = _tray_rect_of(s.cell, s.footprint())
		else:
			r = Rect2(tray_rect.position + Vector2(cursor * CELL), Vector2(CELL, CELL))
	draw_rect(r.grow(-1), Color(UiStyle.BONE, pulse), false, 1.0)


## Huella de dónde caería lo que se lleva agarrado.
func _draw_target(tray_rect: Rect2) -> void:
	var state: String = drop_state()
	var color: Color = COLOR_OK if state == "ok" else (COLOR_MERGE if state == "merge" else COLOR_BAD)
	var zone: Zone = _zone if _mouse_drag else (Zone.POCKET if cursor.y == POCKET_ROW else Zone.TRAY)
	if zone == Zone.NONE or zone == Zone.FLOOR:
		return
	var r: Rect2
	if zone == Zone.POCKET:
		r = _pocket_rect(cursor.x)
	else:
		var target: ItemStack = custody.stack_at(cursor)
		if state == "merge" and target != null:
			r = _tray_rect_of(target.cell, target.footprint())
		else:
			r = Rect2(tray_rect.position + Vector2(cursor * CELL), Vector2(held.def.footprint(held_rotated) * CELL))
	var pulse: float = 0.75 + 0.25 * sin(_time * 8.0)
	draw_rect(r.grow(-1), Color(color, 0.2))
	draw_rect(r.grow(-1), Color(color, pulse), false, 1.0)
	if state == "merge":
		var t: ItemStack = custody.stack_at(cursor)
		var label: String = "juntar" if t != null and t.def == held.def else "combinar"
		draw_string(UiStyle.mono(), r.position + Vector2(3, r.size.y - 4), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 4,
			UiStyle.MONO_SMALL, color.lightened(0.3))


## Lo que se lleva agarrado, levantado y con sombra, encima de todo.
func _draw_drag() -> void:
	if held == null:
		return
	var fp: Vector2i = held.def.footprint(held_rotated)
	var r: Rect2
	if _mouse_drag:
		r = Rect2((_mouse - _grab_offset).floor(), Vector2(fp * CELL))
	elif cursor.y == POCKET_ROW:
		r = _pocket_rect(cursor.x)
		fp = Vector2i.ONE
	else:
		r = Rect2(Vector2(PAD, PAD) + Vector2(cursor * CELL), Vector2(fp * CELL))
	var compact: bool = not _mouse_drag and cursor.y == POCKET_ROW
	# Sombra: el icono en negro, desplazado.
	if held.def.icon != null:
		var shadow_r: Rect2 = Rect2(r.position + SHADOW, r.size)
		_draw_icon_only(held, shadow_r, held_rotated and not compact, Color(0, 0, 0, 0.55), compact)
	var lifted: Rect2 = Rect2(r.position + LIFT, r.size)
	_draw_stack(held, lifted, held_rotated and not compact, 0.97, compact, _drag_layer, false)
	if _mouse_drag and _zone == Zone.FLOOR and not held.def.can_discard():
		_drag_layer.draw_rect(lifted.grow(-2), Color(COLOR_BAD, 0.8), false, 1.0)


func _draw_icon_only(stack: ItemStack, r: Rect2, rotated: bool, tint: Color, compact: bool) -> void:
	var icon: Texture2D = stack.def.icon
	var inner: Rect2 = r.grow(-2)
	var isize: Vector2 = icon.get_size()
	if compact:
		isize = (isize / ceilf(maxf(isize.x, isize.y) / (inner.size.x - 2))).floor()
	var center: Vector2 = (inner.position + inner.size / 2.0).floor()
	if rotated:
		_drag_layer.draw_set_transform(center, PI / 2.0, Vector2.ONE)
		_drag_layer.draw_texture_rect(icon, Rect2((-isize / 2.0).floor(), isize), false, tint)
		_drag_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_drag_layer.draw_texture_rect(icon, Rect2((center - isize / 2.0).floor(), isize), false, tint)
