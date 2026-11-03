class_name AttackBonus
extends Resource
## Táctica de la IA: un ataque enemigo pesa más cuando se cumple una condición (el objetivo sangra,
## está en el suelo, al enemigo le falta una parte…). Lo usa EnemyAI; la razón se enseña con la
## intención para que se lea por qué hace lo que hace.

enum Condition { TARGET_BLEEDING, TARGET_DOWN, SELF_PART_LOST, SELF_HURT, TARGET_DISARMED }

@export var condition: Condition = Condition.TARGET_BLEEDING
## Para SELF_PART_LOST: la parte (Rota o Amputada).
@export var part: StringName = &""
## Peso que se suma al del ataque.
@export_range(0.0, 30.0, 0.1) var weight: float = 2.0
## Frase corta que explica la táctica («Huele tu sangre»).
@export var reason: String = ""
