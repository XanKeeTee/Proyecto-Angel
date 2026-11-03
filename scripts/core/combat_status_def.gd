class_name CombatStatusDef
extends Resource
## Estado temporal en combate (sedación, agarre, derribo…): dura unas rondas y modifica al que lo
## sufre. Lo aplican ataques enemigos (`EnemyAttackDef.inflicts_status`), habilidades
## (`SkillDef.inflicts_status`), objetos y las propias reglas (aturdir, derribar, aterrar).
## Ver docs/design/sistemas/combate.md § Estados.

@export var id: StringName = &""
## Nombre corto para la interfaz ("Sedación").
@export var display_name: String = ""
## Una frase para la interfaz: qué le pasa a quien lo sufre.
@export_multiline var description: String = ""
## Clave del icono que la interfaz traduce a una imagen (vacío = el id).
@export var icon_key: StringName = &""
## Rondas que dura, contando la ronda en que se aplica (se descuenta al final de cada ronda).
@export_range(1, 99) var rounds: int = 2
## Multiplica la Agilidad efectiva (iniciativa, evasión y huida).
@export_range(0.0, 2.0, 0.05) var agility_mult: float = 1.0
## Suma al acierto de quien lo sufre.
@export_range(-50, 50) var accuracy_mod: int = 0
## Suma al acierto de quien ataca a quien lo sufre.
@export_range(-50, 50) var incoming_hit_mod: int = 0
## Probabilidad (0–1) de perder la acción al llegarle el turno, cada vez.
@export_range(0.0, 1.0, 0.05) var skip_chance: float = 0.0
## Pierde su siguiente acción, una sola vez (aturdido, derribado, apartado). Cuando la pierde, el
## estado dura solo hasta el final de esa ronda (ventana para rematar).
@export var loses_next_action: bool = false
## Texto al perder la acción por este estado. `%s` = nombre. Vacío = uno genérico.
@export var skip_text: String = ""
## Impide huir mientras dure.
@export var blocks_flee: bool = false
## Se puede romper con la acción Zafarse.
@export var breakable: bool = false
## Mientras lo sufre, puede cubrirse (Guardia) aunque pierda la acción (derribado: se encoge).
@export var allows_guard: bool = false
## Al aplicarse, suelta a todos los que sujetaba quien lo sufre (empujado, derribado).
@export var breaks_holds: bool = false
## Ignora los penalizadores de acierto por heridas, el coste del torso Roto y el desgaste de Mente
## de la cabeza herida (analgésicos).
@export var ignores_wound_penalties: bool = false
## Estados cuyos efectos se anulan mientras dure este (la sedación embota el terror).
@export var suppresses: Array[StringName] = []
## Estados que se quitan al aplicarse este.
@export var removes: Array[StringName] = []
## Texto al aplicarse. `%s` = nombre de quien lo sufre.
@export var apply_text: String = ""
## Texto al terminarse. `%s` = nombre de quien lo sufría.
@export var end_text: String = ""


func icon() -> StringName:
	return icon_key if icon_key != &"" else id
