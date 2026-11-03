class_name DamageTypeDef
extends Resource
## Qué hace un tipo de daño (contundente, cortante, punzante) según la parte que golpea.
## Una instancia por tipo en data/damage_types/. La usan Battle (al golpear) y la vista previa.
## Ver docs/design/sistemas/combate.md § Tipos de daño.

@export var type: CombatTypes.DamageType = CombatTypes.DamageType.BLUNT
@export var display_name: String = ""
## Frase corta para la ficha del arma.
@export_multiline var summary: String = ""

@export_group("Integridad")
## Fracción de la armadura que se aplica (punzante: la mitad).
@export_range(0.0, 1.0, 0.05) var armor_factor: float = 1.0
## Multiplicador del daño a la integridad (no al Cuerpo) según la parte. Contundente rompe huesos.
@export_range(0.0, 3.0, 0.05) var limb_integrity_mult: float = 1.0
@export_range(0.0, 3.0, 0.05) var head_integrity_mult: float = 1.0
@export_range(0.0, 3.0, 0.05) var torso_integrity_mult: float = 1.0

@export_group("Efectos")
## Puede amputar partes amputables.
@export var can_amputate: bool = false
## Probabilidad (0–1) de abrir una herida que sangra (una acumulación en la parte golpeada).
@export_range(0.0, 1.0, 0.05) var bleed_chance: float = 0.0
## Daño mínimo a la parte (tras armadura) para abrir una herida que sangre (un pinchazo leve, no).
@export_range(0, 50) var bleed_min_damage: int = 0
## Probabilidad de aturdir al golpear la cabeza.
@export_range(0.0, 1.0, 0.05) var head_stun_chance: float = 0.0
## Probabilidad de derribar al romper una pierna (o al amputarla, si corta).
@export_range(0.0, 1.0, 0.05) var leg_break_knockdown: float = 0.0
## Probabilidad de alcanzar un órgano al golpear el torso: más daño al Cuerpo y sangrado.
@export_range(0.0, 1.0, 0.05) var organ_chance: float = 0.0
## Daño mínimo a la parte (tras armadura) para poder alcanzar un órgano (un pinchazo leve no llega).
@export_range(0, 50) var organ_min_damage: int = 0
## Multiplicador del daño al Cuerpo si alcanza un órgano.
@export_range(1.0, 3.0, 0.05) var organ_body_mult: float = 1.5

@export_group("Textos")
## Frases de la vista previa según la parte («Puede aturdir»).
@export var head_text: String = ""
@export var torso_text: String = ""
@export var limb_text: String = ""


func integrity_mult(kind: CombatTypes.PartKind) -> float:
	match kind:
		CombatTypes.PartKind.HEAD:
			return head_integrity_mult
		CombatTypes.PartKind.TORSO:
			return torso_integrity_mult
		CombatTypes.PartKind.ARM, CombatTypes.PartKind.LEG, CombatTypes.PartKind.OTHER:
			return limb_integrity_mult
	return 1.0


func part_text(kind: CombatTypes.PartKind) -> String:
	match kind:
		CombatTypes.PartKind.HEAD:
			return head_text
		CombatTypes.PartKind.TORSO:
			return torso_text
	return limb_text
