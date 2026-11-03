extends SceneTree
## Genera los datos de combate del prólogo: el enfermero transfigurado (enemigo, partes del cuerpo y
## ataques), sus estados (sedación, agarre), el protagonista del prólogo y el encuentro del mapa.
## Uso: "$GODOT_BIN" --headless --path . -s tools/data/build_enemies.gd
## Si existen las hojas del arte (tools/art/sprite_meta.json → enemy_enfermero), las hornea también
## en data/enemies/enfermero_sprites.tres. Volver a ejecutarlo sobrescribe los .tres.
## Diseño y balance: docs/design/enemigos/enfermero.md. Textos y nombres: `[PROPUESTA]`.

const PARTS: String = "res://data/body_parts/"
const STATUSES: String = "res://data/statuses/"
const ENEMIES: String = "res://data/enemies/"
const PARTY: String = "res://data/party/"
const META: String = "res://tools/art/sprite_meta.json"
const SPRITE_KEY: String = "enemy_enfermero"


func _init() -> void:
	var sedation: CombatStatusDef = _status("sedacion", "Sedación", 2, 0.6, -10, 0, 0.15, false, false,
		"El líquido entra frío. A %s le pesan los párpados.", "%s se despeja un poco.")
	var grab: CombatStatusDef = _status("agarre", "Agarrado", 2, 0.5, 0, 20, 0.0, true, true,
		"Una mano gris se cierra sobre %s. No suelta.", "%s se suelta de la mano.")
	var nurse: CombatantDef = _nurse(sedation, grab)
	_save(nurse, ENEMIES + "enfermero.tres")
	_save(_patient(), PARTY + "paciente_09.tres")
	var encounter: EncounterDef = _encounter(load(ENEMIES + "enfermero.tres"), load(PARTY + "paciente_09.tres"))
	_save(encounter, ENEMIES + "encuentro_enfermero.tres")
	var sprites: EnemySpriteDef = EnemySpriteDef.from_meta_file(META, SPRITE_KEY)
	if sprites != null:
		_save(sprites, ENEMIES + "enfermero_sprites.tres")
		var baked: CombatantDef = load(ENEMIES + "enfermero.tres")
		baked.sprites = load(ENEMIES + "enfermero_sprites.tres")
		_save(baked, ENEMIES + "enfermero.tres")
		print("Hojas del enfermero horneadas (%d capas)." % sprites.layers.size())
	else:
		print("Sin hojas del enfermero: se usará el marcador provisional.")
	print("Enfermero, paciente 09 y encuentro generados.")
	quit()


# --- estados -------------------------------------------------------------------------------------

func _status(id: String, display: String, rounds: int, agility: float, accuracy: int, incoming: int, skip: float,
		blocks_flee: bool, breakable: bool, apply_text: String, end_text: String) -> CombatStatusDef:
	var s: CombatStatusDef = CombatStatusDef.new()
	s.id = StringName(id)
	s.display_name = display
	s.rounds = rounds
	s.agility_mult = agility
	s.accuracy_mod = accuracy
	s.incoming_hit_mod = incoming
	s.skip_chance = skip
	s.blocks_flee = blocks_flee
	s.breakable = breakable
	s.apply_text = apply_text
	s.end_text = end_text
	_save(s, STATUSES + id + ".tres")
	return load(STATUSES + id + ".tres")


# --- partes ----------------------------------------------------------------------------------------

func _part(file: String, id: StringName, display: String, fraction: float, hit: int, mult: float, vital: bool,
		amputable: bool, broken: String, amputated: String, blunt_sever: bool = false) -> BodyPartDef:
	var p: BodyPartDef = BodyPartDef.new()
	p.id = id
	p.display_name = display
	p.integrity_fraction = fraction
	p.hit_mod = hit
	p.body_mult = mult
	p.vital = vital
	p.amputable = amputable
	p.severable_by_blunt = blunt_sever
	p.broken_text = broken
	p.amputated_text = amputated
	_save(p, PARTS + file + ".tres")
	return load(PARTS + file + ".tres")


# --- el enfermero ------------------------------------------------------------------------------------

func _attack(display: String, telegraph: String, power: int, accuracy: int, type: CombatTypes.DamageType,
		extra: Dictionary) -> EnemyAttackDef:
	var a: EnemyAttackDef = EnemyAttackDef.new()
	a.display_name = display
	a.telegraph = telegraph
	a.power = power
	a.accuracy = accuracy
	a.damage_type = type
	for key: String in extra:
		a.set(key, extra[key])
	return a


func _nurse(sedation: CombatStatusDef, grab: CombatStatusDef) -> CombatantDef:
	var d: CombatantDef = CombatantDef.new()
	d.display_name = "ENFERMERO"
	d.intro_text = "Un enfermero. Lo que queda de uno."
	d.body_max = 115
	d.has_mind = false
	d.strength = 10
	d.dexterity = 9
	d.agility = 7
	d.willpower = 6
	d.resilience = 6
	d.armor = 1
	d.sprite_key = SPRITE_KEY
	d.sound_idle = "enfermero_breath"
	d.sound_hurt = "enfermero_scream"
	d.sound_death = "enfermero_death"
	d.parts = [
		_part("enfermero_head", CombatTypes.HEAD, "Cabeza", 0.25, -25, 2.0, true, true,
			"La máscara se raja de arriba abajo. Por la grieta gotea algo oscuro.",
			"La cabeza rueda con la máscara puesta. La mascarilla cosida sigue moviéndose un momento."),
		_part("enfermero_torso", CombatTypes.TORSO, "Torso", 0.5, 10, 1.0, true, false,
			"Algo cruje dentro del uniforme. Los tubos del pecho se sueltan y escupen líquido oscuro.", ""),
		_part("enfermero_arm_l", CombatTypes.ARM_L, "Brazo de la jeringa", 0.3, -10, 0.6, false, true,
			"Los dedos rotos ya no aprietan: la jeringa cuelga de la mano.",
			"La mano de la jeringa cae al suelo y sigue apretando el émbolo."),
		_part("enfermero_arm_r", CombatTypes.ARM_R, "Brazo de instrumental", 0.24, 0, 0.6, false, true,
			"El brazo de instrumental cuelga torcido. Los bisturíes arañan el suelo.",
			"El brazo de instrumental se desprende por la costura de metal y cae con un ruido de cubertería.", true),
		_part("enfermero_leg_l", CombatTypes.LEG_L, "Pierna izq.", 0.35, 0, 0.6, false, true,
			"La rodilla se dobla hacia atrás. Cojea, pero sigue viniendo.",
			"La pierna se queda en el suelo. El resto sigue arrastrándose."),
		_part("enfermero_leg_r", CombatTypes.LEG_R, "Pierna der.", 0.35, 0, 0.6, false, true,
			"La pierna cede con un chasquido. Se apoya en la pared para no caer.",
			"La pierna se queda en el suelo. El resto sigue arrastrándose."),
	]
	d.attacks = [
		# Tajo: el ataque principal. Corta: puede amputar.
		_attack("Tajo", "Levanta el brazo de bisturíes por encima de la máscara.", 13, 72, CombatTypes.DamageType.CUT,
			{"required_part": CombatTypes.ARM_R, "weight": 3.0, "requires_standing": true,
			"sound_windup": "enfermero_growl", "sound_hit": "combat_scalpel_slash"}),
		# Agarrar: prepara el serrado de la ronda siguiente.
		_attack("Agarrar", "Abre la mano izquierda y se inclina hacia ti.", 3, 70, CombatTypes.DamageType.BLUNT,
			{"target_part": CombatTypes.ANY_ARM, "required_part": CombatTypes.ARM_L, "weight": 1.6, "cooldown": 3,
			"requires_standing": true, "inflicts_status": grab, "status_chance": 1.0,
			"sound_windup": "enfermero_breath", "sound_hit": "enfermero_growl"}),
		# Serrar: solo a quien está agarrado. Muy certero; la Guardia en esa parte lo para.
		_attack("Serrar", "Te sujeta y apoya la sierra de hueso en el brazo.", 15, 82, CombatTypes.DamageType.CUT,
			{"target_part": CombatTypes.ANY_ARM, "required_part": CombatTypes.ARM_R, "weight": 9.0,
			"requires_target_status": &"agarre", "sound_windup": "combat_saw", "sound_hit": "combat_saw"}),
		# Pinchazo: poco daño, resta Mente y puede sedar.
		_attack("Pinchazo", "Sacude la jeringa. El líquido oscuro burbujea dentro.", 4, 76, CombatTypes.DamageType.PIERCE,
			{"required_part": CombatTypes.ARM_L, "weight": 1.8, "cooldown": 1, "mind_damage": 10,
			"inflicts_status": sedation, "status_chance": 0.7, "target_part": CombatTypes.TORSO,
			"sound_windup": "enfermero_breath", "sound_hit": "combat_syringe"}),
		# Chillido: reacción al perder una parte. Solo Mente.
		_attack("Chillido", "Se encoge. Algo se hincha detrás de la mascarilla cosida.", 0, 100,
			CombatTypes.DamageType.HORROR, {"mind_damage": 14, "required_part": CombatTypes.HEAD, "reaction": true,
			"weight": 0.0, "anim": &"stagger", "sound_windup": "enfermero_scream", "sound_hit": "enfermero_scream"}),
		# Sin brazo de instrumental (y de pie): embiste con el hombro.
		_attack("Embestida", "Baja la cabeza y carga con el hombro.", 5, 65, CombatTypes.DamageType.BLUNT,
			{"requires_standing": true, "weight": 0.6, "sound_windup": "enfermero_drag_steps",
			"sound_hit": "combat_pipe_flesh"}),
		# Arrastrándose: va a por los tobillos.
		_attack("Zarpazo", "Se arrastra hacia tus tobillos con los bisturíes por delante.", 9, 68,
			CombatTypes.DamageType.CUT, {"target_part": CombatTypes.ANY_LEG, "required_part": CombatTypes.ARM_R,
			"crawl_only": true, "weight": 3.0, "sound_windup": "enfermero_drag_steps",
			"sound_hit": "combat_scalpel_slash"}),
		_attack("Agarrar el tobillo", "Estira la mano desde el suelo hacia tu pierna.", 3, 66, CombatTypes.DamageType.BLUNT,
			{"target_part": CombatTypes.ANY_LEG, "required_part": CombatTypes.ARM_L, "crawl_only": true, "weight": 1.5,
			"cooldown": 3, "inflicts_status": grab, "sound_windup": "enfermero_breath", "sound_hit": "enfermero_growl"}),
	]
	return d


# --- el protagonista del prólogo ------------------------------------------------------------------------

## El arma no va aquí: se pone en el combate según lo que lleve empuñado (CharacterState.wielded()).
func _patient() -> CombatantDef:
	var d: CombatantDef = CombatantDef.new()
	d.display_name = "PACIENTE 09"
	d.is_protagonist = true
	d.body_max = Vitals.MAX
	d.mind_max = Vitals.MAX
	d.strength = 8
	d.dexterity = 8
	d.agility = 8
	d.willpower = 9
	d.resilience = 8
	d.armor = 0
	d.parts = [load(PARTS + "head.tres"), load(PARTS + "torso.tres"), load(PARTS + "arm_l.tres"),
		load(PARTS + "arm_r.tres"), load(PARTS + "leg_l.tres"), load(PARTS + "leg_r.tres")]
	return d


# --- el encuentro del mapa ---------------------------------------------------------------------------------

func _encounter(enemy: CombatantDef, party: CombatantDef) -> EncounterDef:
	var e: EncounterDef = EncounterDef.new()
	e.id = &"enfermero"
	e.enemy = enemy
	e.party_base = party
	e.trigger_item = &"tubo_metal"
	e.trigger_flag = &"tubo_cogido"
	# Pasillo del ala de pacientes (planta 3) y, si vuelve, también el de mantenimiento del sótano.
	e.first_regions = [Rect2i(1, 14, 71, 3)]
	e.return_regions = [Rect2i(1, 14, 71, 3), Rect2i(1, 44, 34, 3)]
	e.return_delay = 75.0
	e.spawn_distance = 8
	e.stop_distance = 3
	e.intro_lines = PackedStringArray([
		"Los fluorescentes del fondo se encienden solos. Zumban. Se apagan.",
		"Al final del pasillo hay alguien de pie. Blanco. Muy alto.",
		"Un uniforme de enfermero. Una máscara pálida donde debería estar la cara.",
		"Viene hacia ti. Arrastra un pie. Lo que lleva en el brazo derecho no es una mano.",
	])
	e.return_lines = PackedStringArray([
		"Otra vez ese pie que se arrastra.",
		"Ha vuelto a encontrarte.",
	])
	e.flee_lines = PackedStringArray([
		"Corres sin mirar atrás hasta que dejas de oír el pie que se arrastra.",
		"No ha caído. Volverá a buscarte.",
	])
	e.victory_lines = PackedStringArray([
		"Deja de moverse. La respiración detrás de la mascarilla se apaga.",
		"Entre sus omóplatos, bajo el uniforme roto, una incisión larga cosida sobre la columna.",
		"Te llevas la mano a la espalda. Tus puntos están en el mismo sitio.",
	])
	e.corpse_name = "Enfermero"
	e.corpse_examine = "No se mueve. La máscara de porcelana está agrietada; debajo, la mascarilla quirúrgica cosida a la piel.\nSobre la columna tiene una incisión cosida. Como la tuya."
	e.music = "music_combat_drone"
	return e


func _save(resource: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err: Error = ResourceSaver.save(resource, path)
	if err != OK:
		push_error("No se pudo guardar " + path)
