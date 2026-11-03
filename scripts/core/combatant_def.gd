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
## Arma de una mano en la mano no dominante (CharacterState.wield_offhand). Si el brazo dominante
## queda inútil, se pelea con ella.
@export var offhand_weapon: WeaponDef
## Habilidades que conoce. Cada una pide su arma y sus partes (SkillDef); el menú enseña las que
## tienen sentido con lo que lleva.
@export var skills: Array[SkillDef] = []
## Armadura igual en todas las partes. Provisional hasta tener armaduras por parte.
@export_range(0, 20) var armor: int = 0
@export var dominant_arm: StringName = CombatTypes.ARM_R
@export var parts: Array[BodyPartDef] = []

@export_group("Enemigo")
@export var attacks: Array[EnemyAttackDef] = []
## Prefiere rematar a los Caídos.
@export var finisher: bool = false
## Descripción corta para la interfaz y el registro al empezar el combate.
@export_multiline var intro_text: String = ""

@export_group("Presentación")
## Hojas por capas (contrato con el arte: docs/design/sistemas/combate.md § Vista del enemigo).
@export var sprites: EnemySpriteDef
## Clave de tools/art/sprite_meta.json para leer las capas en desarrollo si `sprites` falta.
@export var sprite_key: String = ""
## Aliados: figura de espaldas en el combate (arte definitivo). Vacío = fotograma de espaldas del
## sprite del mapa ampliado (provisional; ver `PartyBattler`).
@export var battle_back: Texture2D
## Pies dentro de `battle_back`, en píxeles.
@export var battle_back_origin: Vector2 = Vector2.ZERO
## Sonidos (nombres de `Sfx`): respiración o gruñido de espera, dolor y muerte.
@export var sound_idle: String = ""
@export var sound_hurt: String = ""
@export var sound_death: String = ""
