class_name ThoughtSet
extends Resource
## Pensamientos de un mapa, del más avanzado al primero: vale el primero que se cumpla.
## Es el «objetivo actual» del protagonista, contado con su voz (tecla T). No depende de la
## escena: se prueba con funciones de consulta.
## Datos: data/thoughts/*.tres (generados por tools/data/build_prologue_data.gd).

@export var thoughts: Array[Thought] = []
## Si no se cumple ninguno.
@export_multiline var fallback: String = ""
## Pensamiento extra mientras sangra (se añade al principio).
@export_multiline var bleeding_text: String = ""


## El pensamiento que vale ahora (null si ninguno).
func current(has_flag: Callable, has_item: Callable) -> Thought:
	for thought: Thought in thoughts:
		if thought.matches(has_flag, has_item):
			return thought
	return null


## Texto del pensamiento actual (o el de reserva).
func current_text(has_flag: Callable, has_item: Callable) -> String:
	var thought: Thought = current(has_flag, has_item)
	return thought.text if thought != null else fallback
