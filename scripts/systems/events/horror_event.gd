class_name HorrorEvent
extends Resource
## Evento narrativo o de ambiente definido como datos: cuándo salta y qué hace.
## Ejemplo: al ENTRAR en la habitación 08 después de haber salido de ella, la cama
## aparece desplazada y se oye un chirrido.

enum Trigger {
	ENTER_REGION,  ## El jugador entra en `region`.
	LEAVE_REGION,  ## El jugador sale de `region`.
	FLAG,  ## Se activa `trigger_flag`.
	TIMER,  ## Pasan `delay` segundos tras cumplirse las condiciones (comprobado al entrar en cualquier casilla).
}

@export var id: StringName = &""
@export var trigger: Trigger = Trigger.ENTER_REGION
## Zona en casillas (para ENTER/LEAVE).
@export var region: Rect2i = Rect2i()
@export var trigger_flag: StringName = &""
## Banderas que deben estar activas / que no deben estarlo.
@export var requires_flags: Array[StringName] = []
@export var forbids_flags: Array[StringName] = []
## Espera antes de ejecutar (segundos).
@export var delay: float = 0.0
@export_range(0.0, 1.0) var chance: float = 1.0
## Si solo ocurre una vez (casi siempre). Se guarda como bandera "event:<id>".
@export var once: bool = true
@export var actions: Array[EventAction] = []


func done_flag() -> StringName:
	return StringName("event:" + String(id))
