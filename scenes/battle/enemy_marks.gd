class_name EnemyMarks
extends Node2D
## Iconos pequeños de estado sobre el propio enemigo, junto a cada parte afectada (gota si está
## Herida, hueso partido si está Rota, muñón si está Amputada) y, sobre la cabeza, los estados de
## todo el cuerpo (sangrado, aturdimiento, agarre…). Se coloca en el mismo padre que la `EnemyView`.

## Separación del icono respecto al centro de la parte, hacia fuera del cuerpo.
const SIDE_OFFSET: float = 15.0
const ICON_STEP: float = 13.0

var view: EnemyView
var combatant: Combatant


func setup(p_view: EnemyView, p_combatant: Combatant) -> void:
	view = p_view
	combatant = p_combatant
	queue_redraw()


## Iconos que se ven ahora: lista de {kind, at, letter} en coordenadas del padre (para las pruebas).
func marks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if view == null or combatant == null or combatant.dead:
		return result
	for id: StringName in combatant.part_order:
		var anchor: Vector2 = view.anchor(id)
		var side: float = 1.0 if anchor.x >= 0.0 else -1.0
		var at: Vector2 = view.position + anchor + Vector2(side * SIDE_OFFSET, -8.0)
		var kind: StringName = BattleFrame.part_icon(combatant.parts[id].state)
		if kind != &"":
			result.append({"kind": kind, "at": at, "letter": "", "part": id})
			at += Vector2(side * ICON_STEP, 0)
		# Sangrado de esa parte, a su lado.
		if combatant.parts[id].bleeding > 0:
			result.append({"kind": BattleFrame.ICON_BLEED, "at": at, "letter": "", "part": id})
	# Estados de todo el cuerpo, en fila sobre la cabeza.
	var whole: Array[Dictionary] = []
	for entry: Dictionary in combatant.status_entries():
		if StringName(entry["part_id"]) != &"":
			continue
		whole.append({"kind": StringName(entry["icon"]), "letter": String(entry["name"])})
	var top: Vector2 = view.position + Vector2(view.anchor(CombatTypes.HEAD).x, -view.height() + 6.0)
	if combatant.has_part(CombatTypes.HEAD) and not combatant.parts[CombatTypes.HEAD].is_amputated():
		top.y = view.position.y + view.anchor(CombatTypes.HEAD).y - 30.0
	for i: int in whole.size():
		var entry: Dictionary = whole[i]
		entry["at"] = top + Vector2((i - (whole.size() - 1) * 0.5) * ICON_STEP, 0)
		entry["part"] = &""
		result.append(entry)
	return result


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for mark: Dictionary in marks():
		BattleFrame.draw_icon(self, mark["kind"], mark["at"], mark["letter"])
