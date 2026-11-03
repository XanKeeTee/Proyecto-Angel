class_name PlaySoundAction
extends EventAction
## Reproduce un sonido en una casilla del mapa (pasos al otro lado de una pared, una cama que cruje…).

@export var sound: String = ""
@export var cell: Vector2i = Vector2i.ZERO
@export var volume_db: float = 0.0


func run(director: EventDirector) -> void:
	director.world.sfx_at(sound, director.world.cell_center(cell), volume_db)
