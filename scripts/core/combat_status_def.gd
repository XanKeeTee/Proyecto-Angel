class_name CombatStatusDef
extends Resource
## Estado temporal en combate (sedación, agarre…): dura unas rondas y modifica al que lo sufre.
## Lo aplican los ataques enemigos (`EnemyAttackDef.inflicts_status`). Ver docs/design/sistemas/combate.md.

@export var id: StringName = &""
## Nombre corto para la interfaz ("Sedación").
@export var display_name: String = ""
## Rondas que dura, contando la ronda en que se aplica (se descuenta al final de cada ronda).
@export_range(1, 10) var rounds: int = 2
## Multiplica la Agilidad efectiva (iniciativa, evasión y huida).
@export_range(0.0, 2.0, 0.05) var agility_mult: float = 1.0
## Suma al acierto de quien lo sufre.
@export_range(-50, 50) var accuracy_mod: int = 0
## Suma al acierto de quien ataca a quien lo sufre.
@export_range(-50, 50) var incoming_hit_mod: int = 0
## Probabilidad (0–1) de perder la acción al llegarle el turno.
@export_range(0.0, 1.0, 0.05) var skip_chance: float = 0.0
## Impide huir mientras dure.
@export var blocks_flee: bool = false
## Se puede romper con la acción Zafarse.
@export var breakable: bool = false
## Texto al aplicarse. `%s` = nombre de quien lo sufre.
@export var apply_text: String = ""
## Texto al terminarse. `%s` = nombre de quien lo sufría.
@export var end_text: String = ""
