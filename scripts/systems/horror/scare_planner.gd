class_name ScarePlanner
extends RefCounted
## Decide cuándo toca un susto pequeño y cuál: peso, enfriamiento de cada susto, espera
## global entre sustos (más corta con la Mente baja), contexto y memoria de los últimos para
## no repetirse. Lógica pura: se prueba sin escena (tests/unit/test_horror.gd).

## Si toca un susto pero ninguno encaja, se vuelve a mirar tras estos segundos.
const RETRY_DELAY: float = 5.0

var profile: HorrorProfile
## Veces que ha salido cada susto en la partida (lo guarda el director en GameState).
var uses: Dictionary[StringName, int] = {}

var _last_used: Dictionary[StringName, float] = {}
var _recent: Array[StringName] = []
var _next_at: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(horror_profile: HorrorProfile, seed_value: int = -1) -> void:
	profile = horror_profile
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


## Programa el primer susto (o el siguiente) a partir de `now`.
func schedule(now: float, unease: float) -> void:
	var gap: Vector2 = profile.gap_calm.lerp(profile.gap_uneasy, clampf(unease, 0.0, 1.0))
	_next_at = now + _rng.randf_range(gap.x, gap.y)


## Retrasa el siguiente susto al menos hasta `now + seconds` (tras un evento o un texto).
func hold(now: float, seconds: float) -> void:
	_next_at = maxf(_next_at, now + seconds)


## Segundos de juego a partir de los cuales puede salir el siguiente susto.
func next_at() -> float:
	return _next_at


func is_due(now: float) -> bool:
	return now >= _next_at


## Si un susto concreto puede salir ahora (contexto, enfriamiento y usos).
func is_available(scare: ScareDef, context: ScareContext) -> bool:
	if scare.max_uses > 0 and uses.get(scare.id, 0) >= scare.max_uses:
		return false
	if _last_used.has(scare.id) and context.now - _last_used[scare.id] < scare.cooldown:
		return false
	return scare.fits(context)


## Elige un susto disponible por peso, o null si no hay ninguno.
func pick(context: ScareContext) -> ScareDef:
	var options: Array[ScareDef] = []
	var weights: PackedFloat32Array = []
	var total: float = 0.0
	for scare: ScareDef in profile.scares:
		if not is_available(scare, context):
			continue
		var w: float = scare.weight_for(context.unease)
		if _recent.has(scare.id):
			w *= profile.recent_factor
		if w <= 0.0:
			continue
		options.append(scare)
		weights.append(w)
		total += w
	if options.is_empty():
		return null
	var roll: float = _rng.randf() * total
	for i: int in options.size():
		roll -= weights[i]
		if roll <= 0.0:
			return options[i]
	return options[-1]


## Anota que ha salido un susto y programa el siguiente.
func mark(scare: ScareDef, context: ScareContext) -> void:
	_last_used[scare.id] = context.now
	uses[scare.id] = uses.get(scare.id, 0) + 1
	_recent.append(scare.id)
	while _recent.size() > profile.memory:
		_recent.pop_front()
	schedule(context.now, context.unease)


## Si toca, elige y anota un susto. Devuelve null si no toca o no hay ninguno posible
## (en ese caso vuelve a intentarlo un poco más tarde).
func next(context: ScareContext) -> ScareDef:
	if not is_due(context.now):
		return null
	var scare: ScareDef = pick(context)
	if scare == null:
		_next_at = context.now + RETRY_DELAY
		return null
	mark(scare, context)
	return scare
