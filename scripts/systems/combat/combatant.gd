class_name Combatant
extends RefCounted
## Estado en combate de un aliado o enemigo, creado a partir de un CombatantDef.

## Penalizadores de empuñar (docs/design/sistemas/cuerpo-y-heridas.md § Efectos por parte).
const WOUNDED_ARM_ACCURACY: int = -10
const WOUNDED_ARM_POWER: float = 0.85
const WOUNDED_OFF_ARM_ACCURACY: int = -5
## Arma de una mano cambiada a la mano no dominante porque la buena está Rota.
const CLUMSY_HAND_ACCURACY: int = -15
const CLUMSY_HAND_POWER: float = 0.75
## Arma propia de la mano no dominante (mano izquierda).
const OFFHAND_ACCURACY: int = -10
## Huida: puntos que resta cada pierna Herida / inútil.
const FLEE_WOUNDED_LEG: int = 5
const FLEE_DISABLED_LEG: int = 15

static var _unarmed: WeaponDef

var def: CombatantDef
var is_enemy: bool = false
var body: int = 0
var mind: int = 0
var parts: Dictionary[StringName, BodyPartState] = {}
var part_order: Array[StringName] = []
## Suma del sangrado de todas las partes. Asignarlo reparte o quita acumulaciones (compatibilidad:
## 0 lo corta todo; un número mayor añade la diferencia al torso).
var bleeding: int:
	get = _get_bleeding, set = _set_bleeding
## 1 si está aturdido (pierde su siguiente acción). Asignar > 0 aplica el estado `aturdido`.
var stunned: int:
	get = _get_stunned, set = _set_stunned
var fallen: bool = false
var dead: bool = false
var mind_broken: bool = false
var fled: bool = false
var guarded_part: StringName = &""
## Estados temporales: id → rondas que quedan (y su definición en `status_defs`).
var statuses: Dictionary[StringName, int] = {}
var status_defs: Dictionary[StringName, CombatStatusDef] = {}
## Estados de «pierde la siguiente acción» que ya la han hecho perder.
var spent_skips: Dictionary[StringName, bool] = {}
## Rondas que faltan para poder repetir cada ataque (solo enemigos).
var cooldowns: Dictionary[EnemyAttackDef, int] = {}
## Rondas que faltan para poder repetir cada habilidad.
var skill_cooldowns: Dictionary[StringName, int] = {}
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
		_unarmed.reach = CombatTypes.Reach.SHORT
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


## Parte que existe y no está Rota ni Amputada.
func part_useful(id: StringName) -> bool:
	return parts.has(id) and not parts[id].is_disabled()


func off_arm() -> StringName:
	return CombatTypes.ARM_L if def.dominant_arm == CombatTypes.ARM_R else CombatTypes.ARM_R


## Brazos útiles (0–2). Un combatiente sin brazos definidos cuenta como si los tuviera.
func useful_arms() -> int:
	if not has_part(CombatTypes.ARM_L) and not has_part(CombatTypes.ARM_R):
		return 2
	var count: int = 0
	for arm: StringName in CombatTypes.ARMS:
		if part_useful(arm):
			count += 1
	return count


# --- armas -----------------------------------------------------------------------------------------

## Cómo empuña su arma principal ahora mismo (ver WeaponGrip). Reglas:
## - brazo dominante Amputado: el arma se ha caído; queda la de la otra mano o Forcejear;
## - brazo dominante Roto: un arma de una mano pasa a la otra mano (mano torpe), si no lleva otra;
## - un arma de dos manos necesita los dos brazos útiles; si no, Forcejear;
## - brazo que sostiene Herido: −10 acierto y −15 % de daño.
func grip() -> WeaponGrip:
	var result: WeaponGrip = WeaponGrip.new()
	var main_arm: StringName = def.dominant_arm
	var weapon: WeaponDef = def.weapon
	if weapon != null and part_disabled(main_arm):
		var off_free: bool = part_useful(off_arm())
		if def.offhand_weapon != null and off_free:
			return offhand_grip()
		if not weapon.two_handed and off_free and part_state(main_arm) == CombatTypes.PartState.BROKEN:
			result.weapon = weapon
			result.hand = off_arm()
			result.power_mult = CLUMSY_HAND_POWER
			result.accuracy_mod = CLUMSY_HAND_ACCURACY
			result.notes.append("En la mano torpe: %d acierto, −%d %% daño" % [CLUMSY_HAND_ACCURACY,
					roundi((1.0 - CLUMSY_HAND_POWER) * 100.0)])
			_add_arm_wound(result, off_arm())
			return result
		weapon = null
	if weapon != null and weapon.two_handed and part_disabled(off_arm()):
		result.notes.append("Con un solo brazo no puede con un arma de dos manos")
		weapon = null
	if weapon == null:
		if def.offhand_weapon != null and part_useful(off_arm()) and def.weapon == null:
			return offhand_grip()
		result.weapon = unarmed_weapon()
		result.unarmed = true
		result.hand = main_arm if part_useful(main_arm) else off_arm()
		return result
	result.weapon = weapon
	result.hand = main_arm
	_add_arm_wound(result, main_arm)
	if weapon.two_handed and part_state(off_arm()) == CombatTypes.PartState.WOUNDED and not ignores_wounds():
		result.accuracy_mod += WOUNDED_OFF_ARM_ACCURACY
		result.notes.append("Brazo de apoyo herido: %d acierto" % WOUNDED_OFF_ARM_ACCURACY)
	return result


## El arma de la mano no dominante, si la lleva y ese brazo sirve (o null).
func offhand_grip() -> WeaponGrip:
	if def.offhand_weapon == null or not part_useful(off_arm()):
		return null
	var result: WeaponGrip = WeaponGrip.new()
	result.weapon = def.offhand_weapon
	result.hand = off_arm()
	result.accuracy_mod = OFFHAND_ACCURACY
	result.notes.append("Mano no dominante: %d acierto" % OFFHAND_ACCURACY)
	_add_arm_wound(result, off_arm())
	return result


## Formas de atacar que tiene ahora: la principal y, si es otra arma, la de la otra mano.
func grips() -> Array[WeaponGrip]:
	var result: Array[WeaponGrip] = [grip()]
	var off: WeaponGrip = offhand_grip()
	if off != null and off.weapon != result[0].weapon:
		result.append(off)
	return result


func current_weapon() -> WeaponDef:
	return grip().weapon


func _add_arm_wound(result: WeaponGrip, arm: StringName) -> void:
	if part_state(arm) == CombatTypes.PartState.WOUNDED and has_part(arm) and not ignores_wounds():
		result.accuracy_mod += WOUNDED_ARM_ACCURACY
		result.power_mult *= WOUNDED_ARM_POWER
		result.notes.append("Brazo herido: %d acierto, −%d %% daño" % [WOUNDED_ARM_ACCURACY,
				roundi((1.0 - WOUNDED_ARM_POWER) * 100.0)])


# --- movilidad -------------------------------------------------------------------------------------

func effective_agility() -> float:
	var agility: float = def.agility
	var disabled_legs: int = 0
	for leg: StringName in CombatTypes.LEGS:
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
		if not is_suppressed(id):
			agility *= status_defs[id].agility_mult
	return agility


## Las dos piernas Rotas o Amputadas: se arrastra.
func is_crawling() -> bool:
	if not has_part(CombatTypes.LEG_L) or not has_part(CombatTypes.LEG_R):
		return false
	return part_disabled(CombatTypes.LEG_L) and part_disabled(CombatTypes.LEG_R)


## En el suelo: derribado o arrastrándose (se le puede rematar).
func is_down() -> bool:
	return has_status(CombatTypes.STATUS_DOWN) or is_crawling()


## Puntos que pierde en la probabilidad de huir por sus piernas (una pierna rota: −15).
func flee_penalty() -> int:
	var penalty: int = 0
	for leg: StringName in CombatTypes.LEGS:
		if not parts.has(leg):
			continue
		match parts[leg].state:
			CombatTypes.PartState.WOUNDED:
				penalty += FLEE_WOUNDED_LEG
			CombatTypes.PartState.BROKEN, CombatTypes.PartState.AMPUTATED:
				penalty += FLEE_DISABLED_LEG
	return penalty


# --- acierto ---------------------------------------------------------------------------------------

## Penalizadores generales de acierto: cabeza, Mente y estados. Los del brazo que empuña van en
## `grip()`.
func accuracy_modifier() -> int:
	var modifier: int = 0
	if has_part(CombatTypes.HEAD) and not ignores_wounds():
		match part_state(CombatTypes.HEAD):
			CombatTypes.PartState.WOUNDED:
				modifier -= 10
			CombatTypes.PartState.BROKEN:
				modifier -= 25
	if def.has_mind and not mind_broken and mind * 2 < def.mind_max:
		modifier -= 10
	for id: StringName in statuses:
		if not is_suppressed(id):
			modifier += status_defs[id].accuracy_mod
	return modifier


## Lo que suman sus estados al acierto de quien le ataca.
func incoming_hit_modifier() -> int:
	var modifier: int = 0
	for id: StringName in statuses:
		if not is_suppressed(id):
			modifier += status_defs[id].incoming_hit_mod
	return modifier


# --- estados ---------------------------------------------------------------------------------------

func has_status(id: StringName) -> bool:
	return statuses.has(id)


## Aplica (o renueva) un estado. Quita los que el nuevo quita (`removes`). Devuelve true si es nuevo.
func add_status(status: CombatStatusDef) -> bool:
	for other: StringName in status.removes:
		remove_status(other)
	var fresh: bool = not statuses.has(status.id)
	statuses[status.id] = maxi(statuses.get(status.id, 0), status.rounds)
	status_defs[status.id] = status
	if fresh:
		spent_skips.erase(status.id)
	return fresh


func remove_status(id: StringName) -> void:
	statuses.erase(id)
	status_defs.erase(id)
	spent_skips.erase(id)


## Otro estado activo anula los efectos de este (la sedación embota el terror).
func is_suppressed(id: StringName) -> bool:
	for other: StringName in status_defs:
		if other != id and status_defs[other].suppresses.has(id):
			return true
	return false


## Perderá con seguridad su próxima acción (aturdido, derribado, apartado): el estado que lo causa,
## o null.
func pending_skip() -> CombatStatusDef:
	for id: StringName in statuses:
		var status: CombatStatusDef = status_defs[id]
		if status.loses_next_action and not spent_skips.has(id) and not is_suppressed(id):
			return status
	return null


## Ignora los penalizadores por heridas (analgesia).
func ignores_wounds() -> bool:
	for id: StringName in statuses:
		if status_defs[id].ignores_wound_penalties:
			return true
	return false


## Estado que se puede romper con Zafarse (el primero), o null.
func breakable_status() -> CombatStatusDef:
	for id: StringName in statuses:
		if status_defs[id].breakable:
			return status_defs[id]
	return null


## Lo que hay que enseñar de su estado, para la interfaz: estados con sus rondas y el sangrado de
## cada parte. Cada entrada: {id, name, icon, rounds, part_id ("" = todo el cuerpo), stacks}.
func status_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: StringName in statuses:
		var status: CombatStatusDef = status_defs[id]
		result.append({"id": id, "name": status.display_name, "icon": status.icon(), "rounds": statuses[id],
			"part_id": &"", "stacks": 0, "suppressed": is_suppressed(id)})
	for part_id: StringName in part_order:
		var part: BodyPartState = parts[part_id]
		if part.bleeding > 0:
			result.append({"id": CombatTypes.STATUS_BLEED, "name": "Sangrado", "icon": CombatTypes.STATUS_BLEED,
				"rounds": 0, "part_id": part_id, "stacks": part.bleeding, "suppressed": false})
	return result


# --- sangrado --------------------------------------------------------------------------------------

## Partes que sangran (id → acumulaciones).
func bleeding_parts() -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for id: StringName in part_order:
		if parts[id].bleeding > 0:
			result[id] = parts[id].bleeding
	return result


## Añade sangrado a una parte (o al torso si no existe). Devuelve lo añadido.
func add_bleed(part_id: StringName, stacks: int) -> int:
	var id: StringName = part_id if parts.has(part_id) else _bleed_fallback_part()
	if id == &"":
		return 0
	return parts[id].add_bleed(stacks)


func _get_bleeding() -> int:
	var total: int = 0
	for id: StringName in parts:
		total += parts[id].bleeding
	return total


func _set_bleeding(value: int) -> void:
	var current: int = _get_bleeding()
	if value <= 0:
		for id: StringName in parts:
			parts[id].bleeding = 0
		return
	if value > current:
		add_bleed(_bleed_fallback_part(), value - current)
		return
	var to_remove: int = current - value
	while to_remove > 0:
		var worst: StringName = &""
		for id: StringName in parts:
			if parts[id].bleeding > 0 and (worst == &"" or parts[id].bleeding > parts[worst].bleeding):
				worst = id
		if worst == &"":
			return
		parts[worst].bleeding -= 1
		to_remove -= 1


func _bleed_fallback_part() -> StringName:
	if parts.has(CombatTypes.TORSO):
		return CombatTypes.TORSO
	return part_order[0] if not part_order.is_empty() else &""


func _get_stunned() -> int:
	return 1 if has_status(CombatTypes.STATUS_STUN) else 0


func _set_stunned(value: int) -> void:
	if value <= 0:
		remove_status(CombatTypes.STATUS_STUN)
		return
	var status: CombatStatusDef = CombatCatalog.status(CombatTypes.STATUS_STUN)
	if status != null:
		add_status(status)


# --- otras capacidades -----------------------------------------------------------------------------

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
	if bleeding > 0:
		tags.append("Sangrado x%d" % bleeding)
	if is_panicking():
		if not has_status(CombatTypes.STATUS_TERROR):
			tags.append("Pánico")
	elif def.has_mind and mind * 2 < def.mind_max:
		tags.append("Inquietud")
	return ", ".join(tags)
