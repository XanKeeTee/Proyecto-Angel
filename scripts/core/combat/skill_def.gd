class_name SkillDef
extends Resource
## Habilidad de combate de un personaje: técnica de arma (golpe a la rodilla, barrido, empujón…),
## recurso sin arma (forcejear, morder) o del cuerpo (respirar). Cuesta Cuerpo o Mente (no hay
## barra aparte), pide un arma de cierto tipo y partes sanas, y produce efectos.
## Instancias en data/skills/. Ver docs/design/sistemas/combate.md § Habilidades.

## A quién va dirigida.
enum Target { ENEMY, NONE }

@export var id: StringName = &""
@export var display_name: String = ""
## Una o dos frases para la interfaz: qué hace.
@export_multiline var description: String = ""
## Clave del icono para la interfaz.
@export var icon_key: StringName = &""
@export var target: Target = Target.ENEMY
## Se elige la parte (si no, va a `parts` en orden o al torso).
@export var choose_part: bool = true
## Partes a las que se puede dirigir (vacío = cualquiera).
@export var allowed_parts: Array[StringName] = []
## Golpea todas las `allowed_parts` a la vez (barrido: las dos piernas).
@export var hits_all_parts: bool = false

@export_group("Coste")
@export_range(0, 50) var cost_body: int = 0
@export_range(0, 50) var cost_mind: int = 0
## Rondas antes de poder repetirla (0 = cuando quiera).
@export_range(0, 10) var cooldown: int = 0

@export_group("Requisitos")
## Necesita un arma (no vale sin arma).
@export var needs_weapon: bool = false
## Alcance mínimo y máximo del arma (sin arma = corto).
@export var min_reach: CombatTypes.Reach = CombatTypes.Reach.SHORT
@export var max_reach: CombatTypes.Reach = CombatTypes.Reach.LONG
## Tipos de daño del arma que valen (vacío = cualquiera). Sin arma = contundente.
@export var weapon_damage_types: Array[CombatTypes.DamageType] = []
## Brazos útiles (ni Rotos ni Amputados) que necesita.
@export_range(0, 2) var needs_arms: int = 0
## Necesita la cabeza útil (morder).
@export var needs_head: bool = false
## Necesita estar de pie (alguna pierna útil).
@export var needs_standing: bool = false
## El objetivo debe estar en el suelo: derribado o arrastrándose (rematar).
@export var target_must_be_down: bool = false
## El objetivo debe estar de pie (no se empuja a quien está en el suelo).
@export var target_must_stand: bool = false

@export_group("Golpe")
## Hace daño. Si no, solo aplica el estado (con su propia tirada de acierto).
@export var deals_damage: bool = true
## Usa el arma empuñada (poder, precisión, tipo y crítico). Si no, los de abajo.
@export var uses_weapon: bool = true
@export_range(0, 50) var power: int = 0
@export_range(0, 100) var accuracy: int = 75
@export var damage_type: CombatTypes.DamageType = CombatTypes.DamageType.BLUNT
## Si usa el arma: cambia su tipo de daño (clavar: punzante). -1 = el del arma.
@export_range(-1, 3) var damage_type_override: int = -1
@export_range(0.0, 3.0, 0.05) var power_mult: float = 1.0
@export_range(-50, 50) var accuracy_mod: int = 0
@export_range(0, 50) var crit_bonus: int = 0
## Acierto extra si alguno sujeta al otro (cuerpo a cuerpo: morder, forcejear).
@export_range(0, 50) var grapple_accuracy_bonus: int = 0
## Suma `3 × (FUE propia − FUE del objetivo)` al acierto (forcejear, empujar).
@export var strength_contest: bool = false
## Sangrado extra en la parte si acierta.
@export_range(0, 3) var extra_bleed: int = 0
## Suma a la probabilidad de alcanzar un órgano (torso).
@export_range(0.0, 1.0, 0.05) var organ_bonus: float = 0.0
## Iniciativa extra (empujón: rápido).
@export_range(-20, 20) var initiative_mod: int = 0

@export_group("Estado")
## Estado que aplica al objetivo si acierta.
@export var inflicts_status: CombatStatusDef
@export_range(0.0, 1.0, 0.05) var status_chance: float = 1.0
## Suma a esa probabilidad si la parte golpeada ya estaba Herida o Rota.
@export_range(0.0, 1.0, 0.05) var status_bonus_hurt_part: float = 0.0
## Si quien la usa estaba agarrado, se suelta (empujón, forcejear).
@export var frees_self: bool = false

@export_group("Mente")
## Mente que recupera (respirar). Se suma la VOL si `adds_willpower`.
@export_range(0, 50) var mind_gain: int = 0
@export var adds_willpower: bool = false

@export_group("Textos")
## Texto del registro al usarla. `%s` = nombre de quien la usa.
@export var use_text: String = ""
## Frases de la vista previa (efectos que no se calculan: «Si actúas antes, pierde su golpe»).
@export var preview_lines: PackedStringArray = []
## Riesgos para quien la usa («Es atroz: −6 Mente»).
@export var risk_lines: PackedStringArray = []
