class_name BleedAction
extends EventAction
## Se abren los puntos: empieza el sangrado (las vendas lo detienen).

@export var lines: PackedStringArray = []


func run(director: EventDirector) -> void:
	GameState.character.vitals.set_bleeding(true)
	director.world.glitch(0.4, 0.4)
	if not lines.is_empty():
		await director.world.show_lines(lines)
