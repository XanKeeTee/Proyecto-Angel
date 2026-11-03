class_name TurnStrip
extends Control
## Tira discreta con la ronda y el orden de turno: quién actúa ahora y quién después. Mientras se
## eligen órdenes el orden es una previsión por velocidad (la iniciativa se tira al resolver); al
## resolver, se marca quien actúa. Fichas de papel pequeñas; los enemigos, en tinta roja.

const CHIP_H: float = 12.0
const GAP: float = 9.0

var round_number: int = 0
## Quiénes y en qué orden.
var order: Array[Combatant] = []
## Quien actúa o elige ahora (o null).
var active: Combatant
## true mientras se eligen órdenes (orden previsto).
var planning: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Orden previsto por velocidad: primero los más rápidos; a igualdad, el grupo.
static func estimate(battle: Battle) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for member: Combatant in battle.party:
		if member.is_active():
			result.append(member)
	for enemy: Combatant in battle.enemies:
		if enemy.is_active():
			result.append(enemy)
	result.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		if not is_equal_approx(a.effective_agility(), b.effective_agility()):
			return a.effective_agility() > b.effective_agility()
		return not a.is_enemy and b.is_enemy)
	return result


func set_order(p_round: int, p_order: Array[Combatant], p_active: Combatant, p_planning: bool) -> void:
	round_number = p_round
	order = p_order
	active = p_active
	planning = p_planning
	queue_redraw()


## Nombres en el orden de la tira (para pruebas).
func names() -> PackedStringArray:
	var result: PackedStringArray = []
	for combatant: Combatant in order:
		result.append(combatant.display_name())
	return result


func _draw() -> void:
	if order.is_empty():
		return
	var font: Font = UiStyle.mono()
	var fs: int = UiStyle.MONO_SMALL
	var label: String = "RONDA %d · %s" % [round_number, "PREVISTO" if planning else "TURNO"]
	var lw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var widths: Array[float] = []
	var total: float = lw + 8.0
	for combatant: Combatant in order:
		var w: float = font.get_string_size(_short(combatant), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0
		widths.append(w)
		total += w + GAP
	var x: float = size.x - total
	draw_rect(Rect2(Vector2(x - 6, 0), Vector2(total + 6, CHIP_H + 4)), Color(0.02, 0.02, 0.03, 0.75))
	draw_string(font, Vector2(x, CHIP_H - 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, BattleSkin.ASH)
	x += lw + 8.0
	for i: int in order.size():
		var combatant: Combatant = order[i]
		var now: bool = combatant == active
		var chip: Rect2 = Rect2(Vector2(x, 2), Vector2(widths[i], CHIP_H))
		var bg: Color = Color("8e1f1a") if now else (Color(0.82, 0.78, 0.68) if not combatant.is_enemy else Color(0.6, 0.55, 0.5))
		draw_rect(chip, bg)
		draw_rect(chip.grow(-0.5), Color(0, 0, 0, 0.6), false, 1.0)
		var color: Color = BattleSkin.BONE if now else (BattleSkin.INK_RED if combatant.is_enemy else BattleSkin.INK)
		draw_string(font, chip.position + Vector2(5, 9), _short(combatant), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
		x += widths[i]
		if i < order.size() - 1:
			UiStyle.draw_arrow(self, Vector2(x + GAP * 0.5, 2 + CHIP_H * 0.5), Vector2.RIGHT, 2.0, BattleSkin.ASH)
		x += GAP


func _short(combatant: Combatant) -> String:
	return combatant.display_name().to_upper()
