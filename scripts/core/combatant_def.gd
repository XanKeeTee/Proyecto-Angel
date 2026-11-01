class_name CombatantDef
extends Resource
## Definición de un combatiente, aliado o enemigo.

@export var display_name: String = ""
@export var is_protagonist: bool = false

@export_group("Recursos")
@export_range(1, 999) var body_max: int = 100
@export_range(1, 999) var mind_max: int = 100
@export var has_mind: bool = true

@export_group("Atributos")
@export_range(1, 20) var strength: int = 8
@export_range(1, 20) var dexterity: int = 8
@export_range(1, 20) var agility: int = 8
@export_range(1, 20) var willpower: int = 8
@export_range(1, 20) var resilience: int = 8

@export_group("Equipo y cuerpo")
@export var weapon: WeaponDef
## Armadura igual en todas las partes. Provisional hasta tener armaduras por parte.
@export_range(0, 20) var armor: int = 0
@export var dominant_arm: StringName = CombatTypes.ARM_R
@export var parts: Array[BodyPartDef] = []

@export_group("Enemigo")
@export var attacks: Array[EnemyAttackDef] = []
## Prefiere rematar a los Caídos.
@export var finisher: bool = false
