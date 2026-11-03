extends SceneTree
## Genera los datos de reglas del combate: estados (data/statuses/), tipos de daño
## (data/damage_types/), habilidades (data/skills/) y tratamientos de heridas (data/treatments/).
## Uso: "$GODOT_BIN" --headless --path . -s tools/data/build_combat_rules.gd
## Después, tools/data/build_enemies.gd (el enfermero y el paciente 09 usan estos datos).
## Diseño y números: docs/design/sistemas/combate.md. Textos y nombres: `[PROPUESTA]`.

const STATUSES: String = "res://data/statuses/"
const DAMAGE: String = "res://data/damage_types/"
const SKILLS: String = "res://data/skills/"
const TREATMENTS: String = "res://data/treatments/"

const BLUNT: CombatTypes.DamageType = CombatTypes.DamageType.BLUNT
const CUT: CombatTypes.DamageType = CombatTypes.DamageType.CUT
const PIERCE: CombatTypes.DamageType = CombatTypes.DamageType.PIERCE


func _init() -> void:
	_statuses()
	_damage_types()
	_skills()
	_treatments()
	print("Reglas de combate generadas: estados, tipos de daño, habilidades y tratamientos.")
	quit()


# --- estados -------------------------------------------------------------------------------------

func _statuses() -> void:
	_status("agarre", "Agarrado", {"rounds": 2, "agility_mult": 0.5, "incoming_hit_mod": 20, "blocks_flee": true,
		"breakable": true, "description": "Le sujetan: no puede huir, esquiva la mitad y le aciertan más. Se rompe con Zafarse.",
		"apply_text": "Una mano se cierra sobre %s. No suelta.", "end_text": "%s se suelta."})
	_status("sedacion", "Sedación", {"rounds": 2, "agility_mult": 0.6, "accuracy_mod": -10, "skip_chance": 0.15,
		"suppresses": [CombatTypes.STATUS_TERROR],
		"description": "Lento y torpe: −10 acierto, 15 % de perder la acción. Embota el terror.",
		"apply_text": "El líquido entra frío. A %s le pesan los párpados.", "end_text": "%s se despeja un poco."})
	_status("aturdido", "Aturdido", {"rounds": 2, "loses_next_action": true, "incoming_hit_mod": 10,
		"description": "Pierde su siguiente acción.", "skip_text": "%s no reacciona: todo le zumba por dentro."})
	_status("derribado", "Derribado", {"rounds": 2, "loses_next_action": true, "allows_guard": true,
		"agility_mult": 0.5, "incoming_hit_mod": 20, "blocks_flee": true, "breaks_holds": true,
		"description": "En el suelo: gasta su siguiente acción en levantarse, le aciertan más y se le puede rematar.",
		"apply_text": "%s cae al suelo.", "skip_text": "%s se levanta del suelo como puede."})
	_status("aterrado", "Aterrado", {"rounds": 99, "skip_chance": 0.25,
		"description": "El miedo le paraliza: 25 % de perder la acción. Se pasa al recuperar Mente.",
		"apply_text": "A %s le tiemblan las manos. No consigue pensar.", "end_text": "%s recupera algo de control."})
	_status("apartado", "Apartado", {"rounds": 1, "loses_next_action": true, "breaks_holds": true,
		"description": "Lo han apartado de un empujón: si aún no había actuado, pierde su golpe.",
		"apply_text": "%s sale despedido hacia atrás.", "skip_text": "%s recupera el equilibrio y vuelve a acercarse."})
	_status("analgesia", "Analgesia", {"rounds": 3, "ignores_wound_penalties": true,
		"description": "Las heridas no estorban: sin penalizadores por heridas, el torso roto no cuesta y la cabeza no zumba.",
		"apply_text": "El dolor de %s se vuelve lejano, como de otra persona.", "end_text": "A %s le vuelve el dolor."})
	_status("sangrado", "Sangrado", {"rounds": 1,
		"description": "Cada acumulación resta %d de Cuerpo al final de la ronda. Una herida pequeña coagula sola; un hueso roto o un muñón, no sin tratarlo." % Battle.BLEED_PER_STACK})


func _status(id: String, display: String, fields: Dictionary) -> void:
	var s: CombatStatusDef = CombatStatusDef.new()
	s.id = StringName(id)
	s.display_name = display
	for key: String in fields:
		if key == "suppresses" or key == "removes":
			var ids: Array[StringName] = []
			for value: Variant in fields[key]:
				ids.append(StringName(value))
			s.set(key, ids)
		else:
			s.set(key, fields[key])
	_save(s, STATUSES + id + ".tres")


# --- tipos de daño ---------------------------------------------------------------------------------

func _damage_types() -> void:
	_damage("contundente", BLUNT, "Contundente", {"limb_integrity_mult": 1.25, "head_integrity_mult": 1.2,
		"head_stun_chance": 0.35, "leg_break_knockdown": 0.6,
		"summary": "Rompe huesos. En la cabeza aturde; si parte una pierna, derriba. No amputa.",
		"head_text": "En la cabeza puede aturdir.", "torso_text": "Golpe sordo: no hace sangrar.",
		"limb_text": "Contundente: el hueso cede antes."})
	_damage("cortante", CUT, "Cortante", {"torso_integrity_mult": 0.9, "can_amputate": true, "bleed_chance": 0.35,
		"leg_break_knockdown": 0.3,
		"summary": "Abre heridas que sangran. Lo que ya está roto se puede amputar.",
		"head_text": "Corta: hace sangrar.", "torso_text": "Abre el torso: hace sangrar.",
		"limb_text": "Corta: hace sangrar y, si está rota, se amputa."})
	_damage("punzante", PIERCE, "Punzante", {"armor_factor": 0.5, "limb_integrity_mult": 0.75,
		"head_integrity_mult": 0.85, "torso_integrity_mult": 0.8, "bleed_chance": 0.3, "organ_chance": 0.25,
		"organ_body_mult": 1.6,
		"summary": "Atraviesa media armadura. Hace sangrar y, en el torso, puede alcanzar un órgano.",
		"head_text": "Atraviesa: hace sangrar.", "torso_text": "En el torso puede alcanzar un órgano.",
		"limb_text": "Rompe poco, pero hace sangrar."})


func _damage(file: String, type: CombatTypes.DamageType, display: String, fields: Dictionary) -> void:
	var d: DamageTypeDef = DamageTypeDef.new()
	d.type = type
	d.display_name = display
	for key: String in fields:
		d.set(key, fields[key])
	_save(d, DAMAGE + file + ".tres")


# --- habilidades -----------------------------------------------------------------------------------

func _skills() -> void:
	var down: CombatStatusDef = load(STATUSES + "derribado.tres")
	var pushed: CombatStatusDef = load(STATUSES + "apartado.tres")
	var grab: CombatStatusDef = load(STATUSES + "agarre.tres")
	var legs: Array[StringName] = [CombatTypes.LEG_L, CombatTypes.LEG_R]
	var blunt_only: Array[CombatTypes.DamageType] = [BLUNT]
	var blades: Array[CombatTypes.DamageType] = [CUT, PIERCE]
	_skill("golpe_rodilla", "Golpe a la rodilla", "Un golpe seco a la articulación. Si la pierna cede, cae al suelo.", {
		"allowed_parts": legs, "needs_weapon": true, "min_reach": CombatTypes.Reach.MEDIUM,
		"weapon_damage_types": blunt_only, "needs_standing": true, "power_mult": 0.9, "accuracy_mod": -5,
		"inflicts_status": down, "status_chance": 0.25, "status_bonus_hurt_part": 0.25, "cost_body": 2, "cooldown": 1,
		"preview_lines": PackedStringArray(["En el suelo pierde su siguiente acción y se le puede rematar."])})
	_skill("barrido", "Barrido", "Un golpe bajo y ancho a las dos piernas. Pega menos, pero cuesta seguir en pie.", {
		"allowed_parts": legs, "hits_all_parts": true, "choose_part": false, "needs_weapon": true,
		"min_reach": CombatTypes.Reach.MEDIUM, "weapon_damage_types": blunt_only, "needs_standing": true,
		"power_mult": 0.55, "accuracy_mod": -10, "inflicts_status": down, "status_chance": 0.5,
		"cost_body": 4, "cooldown": 2,
		"preview_lines": PackedStringArray(["Golpea las dos piernas; si entran los dos, es más fácil que caiga."])})
	_skill("empujon", "Empujón", "Cruzas el arma contra su pecho y empujas con todo el cuerpo. Rápido. Si te tenía agarrado, te suelta.", {
		"choose_part": false, "allowed_parts": [CombatTypes.TORSO] as Array[StringName], "deals_damage": false,
		"uses_weapon": false, "accuracy": 80, "strength_contest": true, "needs_weapon": true,
		"min_reach": CombatTypes.Reach.MEDIUM, "needs_arms": 2, "needs_standing": true, "target_must_stand": true,
		"initiative_mod": 12, "inflicts_status": pushed, "status_chance": 1.0, "cost_body": 3, "cooldown": 2,
		"preview_lines": PackedStringArray(["No hace daño: gana distancia."])})
	_skill("rematar", "Rematar", "Golpear con todo a quien está en el suelo. Es atroz, y lo sabes.", {
		"target_must_be_down": true, "allowed_parts": [CombatTypes.HEAD, CombatTypes.TORSO] as Array[StringName],
		"needs_standing": true, "power_mult": 1.5, "accuracy_mod": 10, "crit_bonus": 20, "cost_mind": 6,
		"risk_lines": PackedStringArray(["Hacerlo pesa: cuesta Mente."])})
	_skill("forcejear", "Forcejear", "Le agarras con la mano libre. Sujeto, esquiva peor y se le acierta más. Si te tenía agarrado, le das la vuelta.", {
		"allowed_parts": [CombatTypes.ARM_L, CombatTypes.ARM_R, CombatTypes.TORSO] as Array[StringName],
		"uses_weapon": false, "power": 2, "accuracy": 70, "damage_type": BLUNT, "strength_contest": true,
		"max_reach": CombatTypes.Reach.SHORT, "needs_arms": 1, "inflicts_status": grab, "status_chance": 1.0,
		"frees_self": true, "cost_body": 2, "cooldown": 1})
	_skill("morder", "Morder", "Hundir los dientes donde se pueda. No hacen falta manos. Cuerpo a cuerpo es más fácil.", {
		"uses_weapon": false, "power": 6, "accuracy": 60, "damage_type": PIERCE, "extra_bleed": 1,
		"grapple_accuracy_bonus": 25, "needs_head": true, "cost_mind": 4,
		"risk_lines": PackedStringArray(["Es algo de animal: cuesta Mente."])})
	_skill("clavar", "Clavar", "Hundir el filo corto hasta el fondo. Entra poco, pero hondo: sangra y, en el torso, busca algo vital.", {
		"needs_weapon": true, "max_reach": CombatTypes.Reach.SHORT, "weapon_damage_types": blades,
		"damage_type_override": PIERCE, "power_mult": 1.3, "accuracy_mod": -10, "extra_bleed": 1, "organ_bonus": 0.2,
		"cost_body": 2, "cooldown": 1})
	_skill("respirar", "Respirar", "Cerrar los ojos un momento y contar. Recupera Mente.", {
		"target": SkillDef.Target.NONE, "choose_part": false, "deals_damage": false, "mind_gain": Battle.BREATHE_BASE,
		"adds_willpower": true, "icon_key": &"breathe"})


func _skill(id: String, display: String, description: String, fields: Dictionary) -> void:
	var s: SkillDef = SkillDef.new()
	s.id = StringName(id)
	s.display_name = display
	s.description = description
	for key: String in fields:
		s.set(key, fields[key])
	_save(s, SKILLS + id + ".tres")


# --- tratamientos ------------------------------------------------------------------------------------

func _treatments() -> void:
	var analgesia: CombatStatusDef = load(STATUSES + "analgesia.tres")
	var sedation: CombatStatusDef = load(STATUSES + "sedacion.tres")
	_treatment("vendar", "Vendar", ["venda"], TreatmentDef.PartRule.ANY_HURT, {"stops_bleed": 2,
		"restores_integrity": 0.25, "body": 4,
		"description": "Apretar una venda sobre una herida: corta el sangrado de esa parte y la alivia.",
		"use_text": "%s venda: %s."})
	_treatment("vendar_esteril", "Vendar con gasa limpia", ["venda_esterilizada"], TreatmentDef.PartRule.ANY_HURT, {
		"stops_bleed": 3, "restores_integrity": 0.4, "body": 12,
		"description": "Gasa esterilizada sobre la herida: corta el sangrado, la cierra mejor y escuece como fuego.",
		"use_text": "%s venda con gasa limpia: %s."})
	_treatment("vendar_sucia", "Vendar con tela sucia", ["venda_sucia", "venda_improvisada"],
		TreatmentDef.PartRule.ANY_HURT, {"stops_bleed": 2, "restores_integrity": 0.15, "body": 2,
		"contaminated_penalty": 3, "contaminated_text": "La tela no estaba limpia. La herida empieza a picar.",
		"description": "Corta el sangrado de una parte. Si la tela está sucia, se paga después.",
		"use_text": "%s ata la tela: %s."})
	_treatment("torniquete", "Torniquete", ["torniquete"], TreatmentDef.PartRule.LIMB_BLEEDING, {"stops_bleed": 99,
		"seals_part": true,
		"description": "Por encima de la herida, hasta que duela. Ese brazo o esa pierna deja de sangrar del todo, también un muñón.",
		"use_text": "%s aprieta el torniquete: %s."})
	_treatment("analgesicos", "Analgésicos", ["analgesicos"], TreatmentDef.PartRule.NONE, {"body": 6,
		"applies_status": analgesia,
		"description": "Tragarlos en seco. Durante 3 rondas las heridas no estorban.",
		"use_text": "%s traga los analgésicos en seco."})
	_treatment("sedante", "Sedante", ["sedante"], TreatmentDef.PartRule.NONE, {"mind": 25,
		"removes_statuses": [CombatTypes.STATUS_TERROR] as Array[StringName], "applies_status": sedation,
		"description": "Frío por las venas: devuelve Mente y aleja el terror, pero embota (sedación 2 rondas).",
		"use_text": "%s se clava el sedante en el brazo."})


func _treatment(id: String, display: String, items: Array[String], rule: TreatmentDef.PartRule, fields: Dictionary) -> void:
	var t: TreatmentDef = TreatmentDef.new()
	t.id = StringName(id)
	t.display_name = display
	t.part_rule = rule
	var ids: Array[StringName] = []
	for item: String in items:
		ids.append(StringName(item))
	t.item_ids = ids
	t.icon_key = StringName("treat_" + id)
	for key: String in fields:
		t.set(key, fields[key])
	_save(t, TREATMENTS + id + ".tres")


func _save(resource: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err: Error = ResourceSaver.save(resource, path)
	if err != OK:
		push_error("No se pudo guardar " + path)
