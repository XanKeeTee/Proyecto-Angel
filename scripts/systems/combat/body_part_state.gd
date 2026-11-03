class_name BodyPartState
extends RefCounted
## Estado en combate de una parte del cuerpo: Sana → Herida → Rota → Amputada, y su sangrado.

## Acumulaciones de sangrado que admite una parte.
const MAX_BLEED: int = 3

var def: BodyPartDef
var max_integrity: int = 1
var integrity: int = 1
var state: CombatTypes.PartState = CombatTypes.PartState.HEALTHY
## Acumulaciones de sangrado de esta parte (cada una resta Cuerpo al final de la ronda).
var bleeding: int = 0
## Torniquete: ya no puede sangrar en este combate.
var sealed: bool = false


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


## Añade sangrado (sin pasar del máximo). Devuelve las acumulaciones añadidas.
func add_bleed(stacks: int) -> int:
	if sealed or stacks <= 0:
		return 0
	var before: int = bleeding
	bleeding = mini(MAX_BLEED, bleeding + stacks)
	return bleeding - before


## Quita sangrado. Devuelve las acumulaciones quitadas.
func stop_bleed(stacks: int) -> int:
	var removed: int = mini(bleeding, stacks)
	bleeding -= removed
	return removed


## Devuelve integridad (en fracción del máximo). Una parte Rota o Amputada no se arregla así.
func restore(fraction: float) -> int:
	if is_disabled() or fraction <= 0.0:
		return 0
	var before: int = integrity
	integrity = mini(max_integrity, integrity + maxi(1, roundi(max_integrity * fraction)))
	_refresh_state()
	return integrity - before


func _refresh_state() -> void:
	if state == CombatTypes.PartState.AMPUTATED:
		return
	if integrity <= 0:
		state = CombatTypes.PartState.BROKEN
	elif integrity * 2 <= max_integrity:
		state = CombatTypes.PartState.WOUNDED
	else:
		state = CombatTypes.PartState.HEALTHY
