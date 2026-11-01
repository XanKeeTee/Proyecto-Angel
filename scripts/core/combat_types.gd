class_name CombatTypes
extends RefCounted
## Enums y constantes compartidas por todo el sistema de combate.
## Ver docs/design/sistemas/combate.md y cuerpo-y-heridas.md.

enum DamageType { CUT, BLUNT, PIERCE, HORROR }
enum PartState { HEALTHY, WOUNDED, BROKEN, AMPUTATED }
enum ActionType { ATTACK, GUARD, BREATHE, ITEM, FLEE_SOLO, FLEE_ALL, ENEMY_ATTACK }
## Qué parte del telegrafiado ve el jugador.
enum Visibility { FULL, HIDE_WHAT, HIDE_WHO }

const HEAD: StringName = &"head"
const TORSO: StringName = &"torso"
const ARM_L: StringName = &"arm_l"
const ARM_R: StringName = &"arm_r"
const LEG_L: StringName = &"leg_l"
const LEG_R: StringName = &"leg_r"
## Comodines para EnemyAttackDef.target_part.
const ANY_ARM: StringName = &"any_arm"
const ANY_LEG: StringName = &"any_leg"

const PART_STATE_NAMES: Array[String] = ["Sana", "Herida", "Rota", "Amputada"]
