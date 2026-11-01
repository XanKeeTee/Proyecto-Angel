class_name GlitchAction
extends EventAction
## Distorsión de cinta VHS.

@export var duration: float = 1.0
@export var strength: float = 0.6


func run(director: EventDirector) -> void:
	director.world.glitch(duration, strength)
