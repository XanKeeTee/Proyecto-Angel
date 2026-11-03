class_name CombatCatalog
extends RefCounted
## Acceso a los datos de reglas del combate (`data/`): estados, tipos de daño y tratamientos.
## Carga perezosa con `load()` (no `preload`), para que los generadores de datos puedan ejecutarse
## aunque falte algún .tres. Si falta, devuelve null y las reglas siguen sin ese efecto.

const STATUS_DIR: String = "res://data/statuses/"
const DAMAGE_DIR: String = "res://data/damage_types/"
const TREATMENT_DIR: String = "res://data/treatments/"
const SKILL_DIR: String = "res://data/skills/"
## Archivo de cada tipo de daño.
const DAMAGE_FILES: Dictionary[int, String] = {
	CombatTypes.DamageType.CUT: "cortante", CombatTypes.DamageType.BLUNT: "contundente",
	CombatTypes.DamageType.PIERCE: "punzante",
}
## Tratamientos que existen (data/treatments/<id>.tres).
const TREATMENTS: Array[String] = ["vendar", "vendar_esteril", "vendar_sucia", "torniquete", "analgesicos", "sedante"]

static var _statuses: Dictionary[StringName, CombatStatusDef] = {}
static var _damage: Dictionary[int, DamageTypeDef] = {}
static var _treatments: Array[TreatmentDef] = []
static var _treatments_loaded: bool = false


## Estado por id (data/statuses/<id>.tres), o null.
static func status(id: StringName) -> CombatStatusDef:
	if _statuses.has(id):
		return _statuses[id]
	var path: String = STATUS_DIR + String(id) + ".tres"
	var loaded: CombatStatusDef = load(path) as CombatStatusDef if ResourceLoader.exists(path) else null
	_statuses[id] = loaded
	return loaded


## Reglas de un tipo de daño, o null (horror no tiene).
static func damage_type(type: CombatTypes.DamageType) -> DamageTypeDef:
	if _damage.has(type):
		return _damage[type]
	var loaded: DamageTypeDef = null
	if DAMAGE_FILES.has(type):
		var path: String = DAMAGE_DIR + DAMAGE_FILES[type] + ".tres"
		if ResourceLoader.exists(path):
			loaded = load(path) as DamageTypeDef
	_damage[type] = loaded
	return loaded


static func treatments() -> Array[TreatmentDef]:
	if not _treatments_loaded:
		_treatments_loaded = true
		for id: String in TREATMENTS:
			var path: String = TREATMENT_DIR + id + ".tres"
			if ResourceLoader.exists(path):
				_treatments.append(load(path) as TreatmentDef)
	return _treatments


## Tratamiento que da un objeto (por su id), o null.
static func treatment_for(item_id: StringName) -> TreatmentDef:
	for treatment: TreatmentDef in treatments():
		if treatment.item_ids.has(item_id):
			return treatment
	return null


## Habilidad por id (data/skills/<id>.tres), o null.
static func skill(id: StringName) -> SkillDef:
	var path: String = SKILL_DIR + String(id) + ".tres"
	return load(path) as SkillDef if ResourceLoader.exists(path) else null
