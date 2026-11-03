class_name EnemyAttackDef
extends Resource
## Ataque de un enemigo, cómo se telegrafía y cuándo lo elige su IA (EnemyAI).

## Nombre que aparece en el telegrafiado (se muestra en mayúsculas).
@export var display_name: String = ""
## Aviso legible que se ve antes del golpe («Levanta el brazo de bisturíes»). Vacío = solo el nombre.
@export_multiline var telegraph: String = ""
@export_range(0, 50) var power: int = 10
@export_range(0, 100) var accuracy: int = 75
@export var damage_type: CombatTypes.DamageType = CombatTypes.DamageType.CUT
## Daño a la Mente. Con daño de horror es lo único que hace; en un ataque físico se suma si acierta.
## Se reduce en VOL / 2 del objetivo.
@export_range(0, 100) var mind_damage: int = 0
## Parte objetivo: un id concreto, any_arm, any_leg o vacío (al azar, con preferencia por el torso).
@export var target_part: StringName = &""
## Parte que el enemigo necesita útil para usar el ataque. Vacío = ninguna.
@export var required_part: StringName = &""
@export var visibility: CombatTypes.Visibility = CombatTypes.Visibility.FULL

@export_group("IA")
## Peso al elegir entre los ataques disponibles (más = más a menudo).
@export_range(0.0, 20.0, 0.1) var weight: float = 1.0
## Rondas que tienen que pasar antes de repetirlo (0 = puede repetirlo seguido).
@export_range(0, 10) var cooldown: int = 0
## Solo se usa contra quien sufre este estado (p. ej. «serrar» a quien está agarrado).
@export var requires_target_status: StringName = &""
## Necesita alguna pierna útil (de pie). Arrastrándose no lo puede hacer.
@export var requires_standing: bool = false
## Solo lo usa arrastrándose (las dos piernas Rotas o Amputadas).
@export var crawl_only: bool = false
## Reacción: lo elige con prioridad la ronda siguiente a perder (romper o amputar) una parte.
@export var reaction: bool = false
## Tácticas: peso extra cuando se cumple una condición (el objetivo sangra, está en el suelo…).
@export var bonuses: Array[AttackBonus] = []

@export_group("Efectos")
## Estado que aplica si acierta (o siempre, si es de horror).
@export var inflicts_status: CombatStatusDef
@export_range(0.0, 1.0, 0.05) var status_chance: float = 1.0

@export_group("Presentación")
## Animación de la vista del enemigo al ejecutarlo.
@export var anim: StringName = &"attack"
## Sonido al prepararlo (al anunciarse) y al acertar. Nombres de `Sfx` (assets/audio/sfx).
@export var sound_windup: String = ""
@export var sound_hit: String = ""
