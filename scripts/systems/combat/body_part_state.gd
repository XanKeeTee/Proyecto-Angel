class_name BodyPartState
extends RefCounted
## Estado en combate de una parte del cuerpo: Sana → Herida → Rota → Amputada.

var def: BodyPartDef
var max_integrity: int = 1
var integrity: int = 1
var state: CombatTypes.PartState = CombatTypes.PartState.HEALTHY


func _init(p_def: BodyPartDef, body_max: int) -> void:
	def = p_def
	max_integrity = maxi(1, roundi(body_max * p_def.integrity_fraction))
	integrity = max_integrity


func is_disabled() -> bool:
	return state == CombatTypes.PartState.BROKEN or state == CombatTypes.PartState.AMPUTATED


func is_amputated() -> bool:
	return state == CombatTypes.PartState.AMPUTATED


## Resta integridad. Devuelve el exceso de daño por debajo de 0.
func take_damage(amount: int) -> int:
	if is_disabled():
		return 0
	integrity -= amount
	var overflow: int = 0
	if integrity <= 0:
		overflow = -integrity
		integrity = 0
	_refresh_state()
	return overflow


## Empeora un escalón (crítico). No amputa: eso lo decide Battle.
func worsen() -> void:
	match state:
		CombatTypes.PartState.HEALTHY:
			integrity = mini(integrity, int(max_integrity / 2.0))
			state = CombatTypes.PartState.WOUNDED
		CombatTypes.PartState.WOUNDED:
			integrity = 0
			state = CombatTypes.PartState.BROKEN


func amputate() -> void:
	integrity = 0
	state = CombatTypes.PartState.AMPUTATED


func _refresh_state() -> void:
	if state == CombatTypes.PartState.AMPUTATED:
		return
	if integrity <= 0:
		state = CombatTypes.PartState.BROKEN
	elif integrity * 2 <= max_integrity:
		state = CombatTypes.PartState.WOUNDED
	else:
		state = CombatTypes.PartState.HEALTHY
