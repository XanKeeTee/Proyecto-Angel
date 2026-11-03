class_name WoundsPanel
extends PaperCard
## Hoja de lesiones de un miembro del grupo: cada parte con su estado, sus estados (sangrado,
## agarre, pánico…) y el arma. Se abre al pasar el ratón por su ficha de paciente o al pulsarla
## (se queda abierta; Esc la cierra).

const WIDTH: float = 176.0

var combatant: Combatant
## Parte resaltada.
var highlight_part: StringName = &""
## Se abrió con un clic: no se cierra al sacar el ratón.
var pinned: bool = false


## Abre la hoja para un miembro, con la esquina inferior izquierda en `bottom_left`.
func show_for(member: Combatant, bottom_left: Vector2, part: StringName = &"") -> void:
	combatant = member
	highlight_part = part
	grow_up = true
	anchor_point = bottom_left
	tab = "LESIONES · %s" % member.display_name().to_upper()
	var rows: Array[Dictionary] = []
	for line: Dictionary in _part_rows():
		rows.append(line)
	show_rows(rows, WIDTH)


func close() -> void:
	super.close()
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


func _part_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for id: StringName in combatant.part_order:
		var part: BodyPartState = combatant.parts[id]
		var mark: String = "» " if id == highlight_part else ""
		rows.append({"kind": "text", "text": "%s%s: %s" % [mark, part.def.display_name, CombatTypes.PART_STATE_NAMES[part.state]],
			"color": BattleSkin.STATE_INK[part.state] if part.state != CombatTypes.PartState.HEALTHY else BattleSkin.INK})
	rows.append({"kind": "rule"})
	var status: String = combatant.status_text()
	if status != "":
		rows.append({"kind": "risk", "text": status})
	rows.append({"kind": "text", "text": "Arma: %s" % combatant.current_weapon().display_name, "color": BattleSkin.INK_SOFT})
	return rows
