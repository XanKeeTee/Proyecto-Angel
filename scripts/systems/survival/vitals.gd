class_name Vitals
extends RefCounted
## Constantes del personaje fuera de combate: Cuerpo, Mente y sangrado.
## (Los mismos recursos que el combate; ver docs/design/sistemas/combate.md.)

signal changed

const MAX: int = 100
## Cada cuánto resta 1 de Cuerpo el sangrado.
const BLEED_INTERVAL: float = 2.5

var body: int = 82
var mind: int = 70
var bleeding: bool = false
## Suelo de Cuerpo mientras no haya peligros mortales (el prólogo no mata al jugador).
var body_floor: int = 20

var _bleed_timer: float = 0.0


func change_body(amount: int) -> void:
	body = clampi(body + amount, body_floor if amount < 0 else 0, MAX)
	changed.emit()


func change_mind(amount: int) -> void:
	mind = clampi(mind + amount, 0, MAX)
	changed.emit()


func set_bleeding(value: bool) -> void:
	bleeding = value
	_bleed_timer = 0.0
	changed.emit()


## Llamar cada fotograma de juego (no en menús).
func tick(delta: float) -> void:
	if not bleeding:
		return
	_bleed_timer += delta
	while _bleed_timer >= BLEED_INTERVAL:
		_bleed_timer -= BLEED_INTERVAL
		if body > body_floor:
			change_body(-1)


func body_ratio() -> float:
	return float(body) / MAX


func mind_ratio() -> float:
	return float(mind) / MAX


func to_dict() -> Dictionary:
	return {"body": body, "mind": mind, "bleeding": bleeding}


static func from_dict(data: Dictionary) -> Vitals:
	var v: Vitals = Vitals.new()
	v.body = int(data.get("body", v.body))
	v.mind = int(data.get("mind", v.mind))
	v.bleeding = bool(data.get("bleeding", false))
	return v
