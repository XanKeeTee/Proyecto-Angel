class_name CombatTypes
extends RefCounted
## Enums y constantes compartidas por todo el sistema de combate.
## Ver docs/design/sistemas/combate.md y cuerpo-y-heridas.md.

enum DamageType { CUT, BLUNT, PIERCE, HORROR }
enum PartState { HEALTHY, WOUNDED, BROKEN, AMPUTATED }
## SKILL: habilidad (`CombatAction.skill`). RECOVER: levantarse o recobrarse (pierde la acción).
enum ActionType { ATTACK, GUARD, BREATHE, ITEM, FLEE_SOLO, FLEE_ALL, ENEMY_ATTACK, BREAK_FREE, SKILL, RECOVER }
## Qué parte del telegrafiado ve el jugador.
enum Visibility { FULL, HIDE_WHAT, HIDE_WHO }
## Alcance de un arma: corta (cuchilla, bisturí, sin arma), media (tubo) o larga (barra, palanca).
enum Reach { SHORT, MEDIUM, LONG }
## Tipo de parte, para las reglas que dependen de dónde se golpea.
enum PartKind { HEAD, TORSO, ARM, LEG, OTHER }

const HEAD: StringName = &"head"
const TORSO: StringName = &"torso"
const ARM_L: StringName = &"arm_l"
const ARM_R: StringName = &"arm_r"
const LEG_L: StringName = &"leg_l"
const LEG_R: StringName = &"leg_r"
## Comodines para EnemyAttackDef.target_part.
const ANY_ARM: StringName = &"any_arm"
const ANY_LEG: StringName = &"any_leg"
## Orden canónico de las partes humanoides (de arriba abajo).
const HUMANOID_PARTS: Array[StringName] = [HEAD, TORSO, ARM_L, ARM_R, LEG_L, LEG_R]
const ARMS: Array[StringName] = [ARM_L, ARM_R]
const LEGS: Array[StringName] = [LEG_L, LEG_R]

const PART_STATE_NAMES: Array[String] = ["Sana", "Herida", "Rota", "Amputada"]
const DAMAGE_TYPE_NAMES: Array[String] = ["Cortante", "Contundente", "Punzante", "Horror"]
const REACH_NAMES: Array[String] = ["Corto", "Medio", "Largo"]

## Ids de los estados de combate que usan las reglas (data/statuses/<id>.tres).
const STATUS_STUN: StringName = &"aturdido"
const STATUS_DOWN: StringName = &"derribado"
const STATUS_GRAB: StringName = &"agarre"
const STATUS_SEDATION: StringName = &"sedacion"
const STATUS_TERROR: StringName = &"aterrado"
const STATUS_PUSHED: StringName = &"apartado"
const STATUS_ANALGESIA: StringName = &"analgesia"
## Pseudoestado del sangrado por parte (solo para mostrarlo; vive en BodyPartState.bleeding).
const STATUS_BLEED: StringName = &"sangrado"


## Tipo de una parte por su id (las de enemigos no humanoides cuentan como OTHER).
static func part_kind(id: StringName) -> PartKind:
	match id:
		HEAD:
			return PartKind.HEAD
		TORSO:
			return PartKind.TORSO
		ARM_L, ARM_R:
			return PartKind.ARM
		LEG_L, LEG_R:
			return PartKind.LEG
	return PartKind.OTHER


static func is_limb(id: StringName) -> bool:
	var kind: PartKind = part_kind(id)
	return kind == PartKind.ARM or kind == PartKind.LEG
