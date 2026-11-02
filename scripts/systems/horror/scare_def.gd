class_name ScareDef
extends Resource
## Un susto pequeño y aleatorio del terror ambiental (portazo lejano, algo que cae, una sombra
## que cruza…). No es un evento guionizado (eso es `HorrorEvent`): no se guarda, puede repetirse
## y lo elige `ScarePlanner` por peso, enfriamiento y contexto.
## Diseño: docs/design/sistemas/terror-ambiental.md.

enum Kind {
	SOUND,  ## Solo sonido, en un punto relativo al jugador (`place`).
	FLICKER,  ## Parpadean las luces de alrededor (y la linterna).
	PASSING_SHADOW,  ## Una sombra cruza a lo lejos, delante del jugador.
	FACE_FLASH,  ## Una cara en un fallo de cinta, uno o dos fotogramas.
	MOVE_PROP,  ## Un objeto del decorado se mueve solo, fuera de la vista (silla de ruedas…).
}

## Dónde suena, respecto al jugador.
enum Place {
	BEHIND,  ## Muy cerca, a la espalda (respiración).
	NEARBY,  ## En una sala cercana (algo que cae, un golpe en la pared).
	FAR,  ## Lejos (portazo, pasos al otro lado del edificio).
	ABOVE,  ## Sin posición: llega del piso de arriba.
	AT_PROP,  ## En el objeto que se mueve (MOVE_PROP).
}

enum Light { ANY, ON, OFF }

@export var id: StringName = &""
@export var kind: Kind = Kind.SOUND
## Peso relativo al elegir entre los sustos disponibles.
@export var weight: float = 1.0
## Peso extra que gana con la Mente baja (se suma `weight * unease_bonus * inquietud`).
@export var unease_bonus: float = 0.0
## Segundos mínimos entre dos veces este mismo susto.
@export var cooldown: float = 120.0
## Veces que puede pasar en una partida (0 = sin límite). Se cuenta con banderas "scare:<id>:<n>".
@export var max_uses: int = 0
## Inquietud mínima (0 = Mente alta, 1 = Mente muy baja) para que pueda salir.
@export_range(0.0, 1.0) var min_unease: float = 0.0
## Estado de la linterna que necesita (p. ej. la sombra que cruza solo se ve con ella encendida).
@export var flashlight: Light = Light.ANY
@export var requires_flags: Array[StringName] = []
@export var forbids_flags: Array[StringName] = []
## Zonas (en casillas) donde puede pasar. Vacío = en cualquier sitio.
@export var regions: Array[Rect2i] = []

@export_group("Efecto")
## Se elige uno al azar (nombres de `Sfx`, sin extensión).
@export var sounds: PackedStringArray = []
@export var place: Place = Place.NEARBY
@export var volume_db: float = -6.0
## Distorsión de cinta que lo acompaña (0 = ninguna).
@export_range(0.0, 1.0) var glitch_strength: float = 0.0
## Duración del parpadeo, del cruce de la sombra o del fallo de cinta (segundos).
@export var duration: float = 0.6
## Mente que resta (normalmente 0 o 1: los sustos pequeños casi no cuestan).
@export var mind_loss: int = 0

@export_group("Decorado")
## Nodos del decorado que puede mover (MOVE_PROP), por nombre. Cada uno se mueve una vez por partida.
@export var props: PackedStringArray = []
## Desplazamiento del objeto (píxeles).
@export var prop_offset: Vector2 = Vector2(6, 2)


## Si este susto encaja con la situación (sin contar enfriamientos, que lleva el planificador).
func fits(context: ScareContext) -> bool:
	if context.unease < min_unease:
		return false
	if flashlight == Light.ON and not context.flashlight_on:
		return false
	if flashlight == Light.OFF and context.flashlight_on:
		return false
	for flag: StringName in requires_flags:
		if not context.has_flag(flag):
			return false
	for flag: StringName in forbids_flags:
		if context.has_flag(flag):
			return false
	if not regions.is_empty():
		var inside: bool = false
		for region: Rect2i in regions:
			if region.has_point(context.cell):
				inside = true
				break
		if not inside:
			return false
	return true


## Peso efectivo según la inquietud.
func weight_for(unease: float) -> float:
	return weight * (1.0 + unease_bonus * unease)
