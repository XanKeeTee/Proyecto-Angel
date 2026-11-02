class_name PartyRow
extends Control
## Fila de un miembro del grupo en la caja de abajo a la derecha: nombre, icono del arma empuñada,
## barra fina de **Cuerpo** con su número y barra fina de **Mente** con su número. El miembro que
## está eligiendo, resaltado con una franja. Al pasar el ratón (o al pulsar) pide enseñar sus
## heridas (`details_requested`).

## Pide abrir (true) o cerrar (false) la ventanita de heridas. `pinned`: se pulsó (se queda abierta).
signal details_requested(row: PartyRow, show: bool, pinned: bool)

const HEIGHT: float = 18.0
const NAME_SIZE: int = UiStyle.SIZE_LARGE
const NUMBER_SIZE: int = UiStyle.SIZE_LARGE
const LABEL_SIZE: int = UiStyle.SIZE_TEXT
const STATUS_ICONS_MAX: int = 3

var combatant: Combatant
## Icono del arma empuñada (null = a mano desnuda).
var weapon_icon: Texture2D
var selected: bool = false

var _hurt: float = 0.0
var _hurt_tween: Tween


func setup(member: Combatant, icon: Texture2D) -> void:
	combatant = member
	weapon_icon = icon
	custom_minimum_size = Vector2(0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not mouse_entered.is_connected(_on_hover):
		mouse_entered.connect(_on_hover.bind(true))
		mouse_exited.connect(_on_hover.bind(false))
	queue_redraw()


func refresh() -> void:
	queue_redraw()


## Destello rojo de la fila al recibir un golpe.
func hurt(strength: float = 1.0) -> void:
	if _hurt_tween != null:
		_hurt_tween.kill()
	_hurt_tween = create_tween()
	_hurt_tween.tween_method(func(v: float) -> void:
		_hurt = v
		queue_redraw(), strength, 0.0, 0.5)


## Columnas de la fila: [nombre, icono, bloque Cuerpo, bloque Mente] (x inicial y ancho).
func columns() -> Dictionary[StringName, Vector2]:
	var w: float = size.x
	var body_x: float = roundf(w * 0.40)
	var mind_x: float = roundf(w * 0.72)
	return {
		&"name": Vector2(6, body_x - 46),
		&"icon": Vector2(body_x - 34, 14),
		&"body": Vector2(body_x, mind_x - body_x - 10),
		&"mind": Vector2(mind_x, w - mind_x - 6),
	}


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		details_requested.emit(self, true, true)
		accept_event()


func _on_hover(inside: bool) -> void:
	details_requested.emit(self, inside, false)


func _draw() -> void:
	if combatant == null:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if selected:
		BattleFrame.draw_band(self, rect)
	var cols: Dictionary[StringName, Vector2] = columns()
	var font: Font = UiStyle.ui()
	var baseline: float = 13.0
	var out: bool = not combatant.is_active()
	var text_color: Color = UiStyle.ASH if out else UiStyle.BONE
	var name_col: Vector2 = cols[&"name"]
	draw_string(font, Vector2(name_col.x, baseline), combatant.display_name(), HORIZONTAL_ALIGNMENT_LEFT, name_col.y,
		NAME_SIZE, text_color)
	# Estados del personaje (sangrado, agarre…) en pequeño tras el nombre.
	var name_w: float = minf(name_col.y, font.get_string_size(combatant.display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1,
		NAME_SIZE).x)
	var icons: Array[Dictionary] = status_icons(combatant)
	for i: int in mini(icons.size(), STATUS_ICONS_MAX):
		BattleFrame.draw_icon(self, icons[i]["kind"], Vector2(name_col.x + name_w + 9 + i * 12, HEIGHT * 0.5),
			icons[i]["letter"])
	# Arma empuñada.
	var icon_col: Vector2 = cols[&"icon"]
	var icon_rect: Rect2 = Rect2(Vector2(icon_col.x, 2), Vector2(14, 14))
	draw_rect(icon_rect, Color(0.12, 0.11, 0.11, 0.9))
	draw_rect(icon_rect.grow(-0.5), Color("6d685f"), false, 1.0)
	if weapon_icon != null:
		var tex_size: Vector2 = weapon_icon.get_size()
		var fit: float = minf(12.0 / tex_size.x, 12.0 / tex_size.y)
		var drawn: Vector2 = (tex_size * fit).round()
		draw_texture_rect(weapon_icon, Rect2(icon_rect.get_center() - drawn * 0.5, drawn), false)
	_draw_stat(cols[&"body"], "Cuerpo", combatant.body, combatant.def.body_max, BattleFrame.BAR_BODY, out)
	if combatant.def.has_mind:
		_draw_stat(cols[&"mind"], "Mente", combatant.mind, combatant.def.mind_max, BattleFrame.BAR_MIND, out)
	if _hurt > 0.0:
		draw_rect(rect, Color(0.7, 0.05, 0.05, 0.4 * _hurt))


## Etiqueta azul grisácea a la izquierda, número a la derecha y barra fina debajo, como en la referencia.
func _draw_stat(col: Vector2, label: String, value: int, maximum: int, color: Color, out: bool) -> void:
	var font: Font = UiStyle.ui()
	draw_string(font, Vector2(col.x, 13), label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, BattleFrame.LABEL_BLUE)
	var number: String = str(value)
	var width: float = font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_SIZE).x
	draw_string(font, Vector2(col.x + col.y - width, 13), number, HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_SIZE,
		UiStyle.ASH if out else UiStyle.BONE)
	var bar: Rect2 = Rect2(Vector2(col.x, 15), Vector2(col.y, 2))
	draw_rect(bar, BattleFrame.BAR_BACK)
	draw_rect(Rect2(bar.position, Vector2(roundf(col.y * clampf(float(value) / maximum, 0.0, 1.0)), 2)), color)


## Iconos de los estados de un combatiente: [{kind, letter}].
static func status_icons(member: Combatant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if member.bleeding > 0:
		result.append({"kind": BattleFrame.ICON_BLEED, "letter": ""})
	if member.stunned > 0:
		result.append({"kind": BattleFrame.ICON_STUN, "letter": ""})
	if member.guarded_part != &"":
		result.append({"kind": BattleFrame.ICON_GUARD, "letter": ""})
	for id: StringName in member.statuses:
		result.append({"kind": id, "letter": member.status_defs[id].display_name})
	return result
