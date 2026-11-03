class_name EncounterDef
extends Resource
## Un encuentro de combate en el mapa: qué lo dispara, dónde aparece el enemigo, qué se dice y qué
## queda después. Lo ejecuta `EncounterDirector` (se crea con una línea desde el guion del mapa).
## El estado (vivo, huido, muerto, sus heridas y dónde quedó el cuerpo) se guarda en
## `GameState.objects["enemy:<id>"]`.

@export var id: StringName = &""
@export var enemy: CombatantDef
## El protagonista (atributos y partes). El arma y las constantes salen del CharacterState.
@export var party_base: CombatantDef

@export_group("Disparo")
## Al recibir este objeto se activa `trigger_flag` (y, si no lleva nada empuñado, lo empuña).
@export var trigger_item: StringName = &""
@export var trigger_flag: StringName = &""
## Zonas (en casillas) donde aparece la primera vez: al entrar en ellas con la bandera puesta.
@export var first_regions: Array[Rect2i] = []
## Zonas donde puede volver a aparecer tras una huida.
@export var return_regions: Array[Rect2i] = []
## Segundos de juego que tarda en volver tras una huida.
@export var return_delay: float = 75.0
## A cuántas casillas del jugador aparece y a cuántas se para antes de empezar el combate.
@export var spawn_distance: int = 8
@export var stop_distance: int = 3
## Se puede huir del combate.
@export var can_flee: bool = true

@export_group("Textos")
@export var intro_lines: PackedStringArray = []
@export var return_lines: PackedStringArray = []
@export var flee_lines: PackedStringArray = []
@export var victory_lines: PackedStringArray = []
## El cuerpo que queda en el mapa.
@export var corpse_name: String = ""
@export_multiline var corpse_examine: String = ""

@export_group("Sonido")
## Pista de música del combate (assets/audio/music/<nombre>.ogg). Si no existe, no suena nada.
@export var music: String = ""


## Clave del guardado.
func state_key() -> StringName:
	return StringName("enemy:" + String(id))
