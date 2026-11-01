class_name BodyDiagram
extends Control
## Silueta provisional: cada parte del cuerpo es un rectángulo coloreado según su estado.

const COLOR_HEALTHY: Color = Color("e8e1d3")
const COLOR_WOUNDED: Color = Color("c9a04a")
const COLOR_BROKEN: Color = Color("8e3a35")
const COLOR_AMPUTATED: Color = Color(0.64, 0.23, 0.23, 0.7)
const COLOR_DEAD: Color = Color(0.18, 0.18, 0.2)
const COLOR_GUARD: Color = Color("5fb8b0")
const COLOR_HIGHLIGHT: Color = Color("c9a04a")
const COLOR_EYES: Color = Color("0b1026")

## Posición relativa (0–1) de cada parte. El personaje mira hacia la pantalla.
const LAYOUT: Dictionary = {
	&"head": Rect2(0.38, 0.0, 0.24, 0.2),
	&"torso": Rect2(0.32, 0.22, 0.36, 0.36),
	&"arm_r": Rect2(0.15, 0.22, 0.15, 0.34),
	&"arm_l": Rect2(0.70, 0.22, 0.15, 0.34),
	&"leg_r": Rect2(0.33, 0.6, 0.16, 0.4),
	&"leg_l": Rect2(0.51, 0.6, 0.16, 0.4),
}

var combatant: Combatant
var highlight_part: StringName = &""


func _draw() -> void:
	if combatant == null:
		return
	for id: StringName in combatant.part_order:
		if not LAYOUT.has(id):
			continue
		var relative: Rect2 = LAYOUT[id]
		var rect: Rect2 = Rect2((relative.position * size).floor(), (relative.size * size).floor())
		var part: BodyPartState = combatant.parts[id]
		if id == highlight_part:
			draw_rect(rect.grow(2.0), COLOR_HIGHLIGHT, false, 1.0)
		if part.is_amputated():
			draw_rect(rect, COLOR_AMPUTATED, false, 1.0)
			continue
		draw_rect(rect, _color_for(part.state))
		if id == combatant.guarded_part:
			draw_rect(rect.grow(1.0), COLOR_GUARD, false, 1.0)
		if id == CombatTypes.HEAD:
			_draw_hollow_eyes(rect)


func _color_for(state: CombatTypes.PartState) -> Color:
	var color: Color = COLOR_HEALTHY
	match state:
		CombatTypes.PartState.WOUNDED:
			color = COLOR_WOUNDED
		CombatTypes.PartState.BROKEN:
			color = COLOR_BROKEN
	if combatant.dead:
		return COLOR_DEAD
	if combatant.fallen or combatant.fled or combatant.mind_broken:
		return color.darkened(0.55)
	return color


## Máscara: dos cuencas vacías.
func _draw_hollow_eyes(head: Rect2) -> void:
	var eye_size: Vector2 = (head.size * Vector2(0.22, 0.25)).ceil()
	var y: float = head.position.y + head.size.y * 0.35
	draw_rect(Rect2(Vector2(head.position.x + head.size.x * 0.18, y).floor(), eye_size), COLOR_EYES)
	draw_rect(Rect2(Vector2(head.position.x + head.size.x * 0.6, y).floor(), eye_size), COLOR_EYES)
