class_name WoundsPanel
extends Control
## Ventanita con las heridas de un miembro del grupo: cada parte con su estado e icono, sus estados
## (sangrado, agarre, pánico…) y el arma. Se abre al pasar el ratón por su fila o al pulsarla, y sola
## al elegir qué cubrir con la Guardia (con la parte señalada).

const WIDTH: float = 168.0
const LINE: float = 12.0
const PAD: float = 7.0

var combatant: Combatant
## Parte resaltada (al elegir la Guardia).
var highlight_part: StringName = &""
## Se abrió con un clic: no se cierra al sacar el ratón.
var pinned: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Abre la ventanita para un miembro, con la esquina inferior izquierda en `bottom_left`.
func show_for(member: Combatant, bottom_left: Vector2, part: StringName = &"") -> void:
	combatant = member
	highlight_part = part
	size = Vector2(WIDTH, _content_height())
	position = (bottom_left - Vector2(0, size.y)).round()
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	pinned = false
	highlight_part = &""


## Líneas de texto que muestra (para las pruebas): «Cabeza: Herida», «Sangrado x1»…
func lines() -> PackedStringArray:
	var result: PackedStringArray = []
	if combatant == null:
		return result
	for id: StringName in combatant.part_order:
		var part: BodyPartState = combatant.parts[id]
		result.append("%s: %s" % [part.def.display_name, CombatTypes.PART_STATE_NAMES[part.state]])
	var status: String = combatant.status_text()
	if status != "":
		result.append(status)
	result.append("Arma: %s" % combatant.current_weapon().display_name)
	return result


func _content_height() -> float:
	if combatant == null:
		return 0.0
	var count: int = combatant.part_order.size() + 1
	if combatant.status_text() != "":
		count += 1
	return PAD * 2.0 + 14.0 + count * LINE + 2.0


func _draw() -> void:
	if combatant == null:
		return
	BattleFrame.draw_box(self, Rect2(Vector2.ZERO, size))
	var font: Font = UiStyle.ui()
	var bold: Font = UiStyle.ui_bold()
	var small: int = UiStyle.SIZE_SMALL
	draw_string(bold, Vector2(PAD, PAD + 10), combatant.display_name(), HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2,
		UiStyle.SIZE_TEXT, UiStyle.BONE)
	var y: float = PAD + 14.0
	for id: StringName in combatant.part_order:
		var part: BodyPartState = combatant.parts[id]
		var row: Rect2 = Rect2(Vector2(PAD - 2, y), Vector2(size.x - PAD * 2 + 4, LINE))
		if id == highlight_part:
			BattleFrame.draw_band(self, row)
		var icon: StringName = BattleFrame.part_icon(part.state)
		if icon != &"":
			BattleFrame.draw_icon(self, icon, Vector2(PAD + 5, y + LINE * 0.5))
		elif id == combatant.guarded_part:
			BattleFrame.draw_icon(self, BattleFrame.ICON_GUARD, Vector2(PAD + 5, y + LINE * 0.5))
		draw_string(font, Vector2(PAD + 14, y + 10), part.def.display_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 80,
			small, UiStyle.BONE)
		var state: String = CombatTypes.PART_STATE_NAMES[part.state]
		var color: Color = [UiStyle.ASH, UiStyle.AMBER, UiStyle.BLOOD.lightened(0.25), UiStyle.BLOOD][part.state]
		var w: float = font.get_string_size(state, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
		draw_string(font, Vector2(size.x - PAD - w, y + 10), state, HORIZONTAL_ALIGNMENT_LEFT, -1, small, color)
		y += LINE
	var status: String = combatant.status_text()
	if status != "":
		draw_string(font, Vector2(PAD, y + 10), status, HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2, small,
			BattleFrame.LABEL_BLUE)
		y += LINE
	draw_string(font, Vector2(PAD, y + 10), "Arma: %s" % combatant.current_weapon().display_name,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2, small, UiStyle.BONE_DIM)
