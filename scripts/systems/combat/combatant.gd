class_name Combatant
extends RefCounted
## Estado en combate de un aliado o enemigo, creado a partir de un CombatantDef.

static var _unarmed: WeaponDef

var def: CombatantDef
var is_enemy: bool = false
var body: int = 0
var mind: int = 0
var parts: Dictionary[StringName, BodyPartState] = {}
var part_order: Array[StringName] = []
var bleeding: int = 0
var stunned: int = 0
var fallen: bool = false
var dead: bool = false
var mind_broken: bool = false
var fled: bool = false
var guarded_part: StringName = &""
## Estados temporales: id → rondas que quedan (y su definición en `status_defs`).
var statuses: Dictionary[StringName, int] = {}
var status_defs: Dictionary[StringName, CombatStatusDef] = {}
## Rondas que faltan para poder repetir cada ataque (solo enemigos).
var cooldowns: Dictionary[EnemyAttackDef, int] = {}
## Ha perdido (roto o amputado) una parte esta ronda: la IA puede reaccionar.
var pending_reaction: bool = false


func _init(p_def: CombatantDef, p_is_enemy: bool) -> void:
	def = p_def
	is_enemy = p_is_enemy
	body = def.body_max
	mind = def.mind_max
	for part_def: BodyPartDef in def.parts:
		parts[part_def.id] = BodyPartState.new(part_def, def.body_max)
		part_order.append(part_def.id)


## Ataque sin arma: siempre disponible.
static func unarmed_weapon() -> WeaponDef:
	if _unarmed == null:
		_unarmed = WeaponDef.new()
		_unarmed.display_name = "Forcejear"
		_unarmed.power = 4
		_unarmed.accuracy = 70
		_unarmed.damage_type = CombatTypes.DamageType.BLUNT
	return _unarmed


func display_name() -> String:
	return def.display_name


## Puede actuar.
func is_active() -> bool:
	return not dead and not fallen and not mind_broken and not fled


## Sigue en el campo (aunque esté Caído o en Quiebre).
func is_present() -> bool:
	return not dead and not fled


func has_part(id: StringName) -> bool:
	return parts.has(id)


func part_state(id: StringName) -> CombatTypes.PartState:
	if not parts.has(id):
		return CombatTypes.PartState.AMPUTATED
	return parts[id].state


func part_disabled(id: StringName) -> bool:
	return parts.has(id) and parts[id].is_disabled()


func off_arm() -> StringName:
	return CombatTypes.ARM_L if def.dominant_arm == CombatTypes.ARM_R else CombatTypes.ARM_R


func current_weapon() -> WeaponDef:
	if def.weapon == null or part_disabled(def.dominant_arm):
		return unarmed_weapon()
	if def.weapon.two_handed and part_disabled(off_arm()):
		return unarmed_weapon()
	return def.weapon


func effective_agility() -> float:
	var agility: float = def.agility
	var disabled_legs: int = 0
	for leg: StringName in [CombatTypes.LEG_L, CombatTypes.LEG_R]:
		if not parts.has(leg):
			continue
		match parts[leg].state:
			CombatTypes.PartState.WOUNDED:
				agility *= 0.8
			CombatTypes.PartState.BROKEN, CombatTypes.PartState.AMPUTATED:
				agility *= 0.5
				disabled_legs += 1
	if disabled_legs >= 2:
		return 0.0
	for id: StringName in statuses:
		agility *= status_defs[id].agility_mult
	return agility


## Las dos piernas Rotas o Amputadas: se arrastra.
func is_crawling() -> bool:
	if not has_part(CombatTypes.LEG_L) or not has_part(CombatTypes.LEG_R):
		return false
	return part_disabled(CombatTypes.LEG_L) and part_disabled(CombatTypes.LEG_R)


## Penalizadores de acierto por heridas y Mente.
func accuracy_modifier() -> int:
	var modifier: int = 0
	if has_part(def.dominant_arm) and part_state(def.dominant_arm) == CombatTypes.PartState.WOUNDED:
		modifier -= 10
	if current_weapon().two_handed and part_state(off_arm()) == CombatTypes.PartState.WOUNDED:
		modifier -= 5
	if has_part(CombatTypes.HEAD):
		match part_state(CombatTypes.HEAD):
			CombatTypes.PartState.WOUNDED:
				modifier -= 10
			CombatTypes.PartState.BROKEN:
				modifier -= 25
	if def.has_mind and not mind_broken and mind * 2 < def.mind_max:
		modifier -= 10
	for id: StringName in statuses:
		modifier += status_defs[id].accuracy_mod
	return modifier


## Lo que suman sus estados al acierto de quien le ataca.
func incoming_hit_modifier() -> int:
	var modifier: int = 0
	for id: StringName in statuses:
		modifier += status_defs[id].incoming_hit_mod
	return modifier


func has_status(id: StringName) -> bool:
	return statuses.has(id)


## Aplica (o renueva) un estado. Devuelve true si es nuevo.
func add_status(status: CombatStatusDef) -> bool:
	var fresh: bool = not statuses.has(status.id)
	statuses[status.id] = maxi(statuses.get(status.id, 0), status.rounds)
	status_defs[status.id] = status
	return fresh


func remove_status(id: StringName) -> void:
	statuses.erase(id)
	status_defs.erase(id)


## Estado que se puede romper con Zafarse (el primero), o null.
func breakable_status() -> CombatStatusDef:
	for id: StringName in statuses:
		if status_defs[id].breakable:
			return status_defs[id]
	return null


func can_use_items() -> bool:
	return not (part_disabled(CombatTypes.ARM_L) and part_disabled(CombatTypes.ARM_R))


func can_flee() -> bool:
	if effective_agility() <= 0.0:
		return false
	for id: StringName in statuses:
		if status_defs[id].blocks_flee:
			return false
	return true


func can_read_intents() -> bool:
	return not part_disabled(CombatTypes.HEAD)


func is_panicking() -> bool:
	return def.has_mind and not mind_broken and mind * 4 < def.mind_max


## Cambia la Mente. Devuelve true si este cambio provoca el Quiebre.
func change_mind(delta: int) -> bool:
	if not def.has_mind or mind_broken:
		return false
	mind = clampi(mind + delta, 0, def.mind_max)
	if mind == 0:
		mind_broken = true
		return true
	return false


func status_text() -> String:
	if dead:
		return "MUERTE"
	if fled:
		return "HUIDA"
	if fallen:
		return "EN EL SUELO"
	if mind_broken:
		return "QUIEBRE"
	var tags: PackedStringArray = []
	for id: StringName in statuses:
		tags.append(status_defs[id].display_name)
	if is_crawling():
		tags.append("Se arrastra")
	if stunned > 0:
		tags.append("Aturdimiento")
	if bleeding > 0:
		tags.append("Sangrado x%d" % bleeding)
	if is_panicking():
		tags.append("Pánico")
	elif def.has_mind and mind * 2 < def.mind_max:
		tags.append("Inquietud")
	return ", ".join(tags)
