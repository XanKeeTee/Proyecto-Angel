class_name BodyPartDef
extends Resource
## Definición de una parte del cuerpo (docs/design/sistemas/cuerpo-y-heridas.md).

@export var id: StringName = &""
@export var display_name: String = ""
## Fracción del Cuerpo máximo que esta parte tiene como integridad.
@export_range(0.05, 1.0, 0.01) var integrity_fraction: float = 0.3
## Modificador de acierto al apuntar a esta parte.
@export_range(-50, 50) var hit_mod: int = 0
## Multiplicador del daño que pasa al Cuerpo global.
@export_range(0.0, 3.0, 0.1) var body_mult: float = 1.0
## Si se amputa, el combatiente muere.
@export var vital: bool = false
@export var amputable: bool = false
