class_name FlickerAction
extends EventAction
## Hace parpadear las luces de una zona (vacía = todas) y la linterna.

@export var region: Rect2i = Rect2i()
@export var duration: float = 1.0


func run(director: EventDirector) -> void:
	director.world.flicker_lights(region, duration)
